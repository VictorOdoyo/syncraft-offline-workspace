import 'dart:async';
import 'package:flutter/foundation.dart';
import '../data/local_store.dart';
import '../data/attachment_store.dart';
import 'api_client.dart';

class SyncEngine extends ChangeNotifier {
  final LocalStore store;final ApiClient api;
  bool busy=false,paused=false,connected=false;
  String? error;DateTime? lastSuccess;int failures=0;
  Timer? _timer;bool _disposed=false;
  SyncEngine(this.store,this.api);
  Future<void> login(String username,String password)async{
    final binding='${api.base}|$username';
    final existing=await store.metadata('account');
    if(existing!=null&&existing!=binding){throw const FormatException('This device is bound to another account. Export recovery data before using a separate browser profile.');}
    final response=await api.post('/api/v1/login',{'username':username,'password':password}) as Map;
    api.token=response['token'] as String;api.device=await store.deviceId();
    try{await api.post('/api/v1/devices',{'id':api.device,'name':'Syncraft field device'});}
    catch(_){api.token=null;rethrow;}
    await store.setMetadata('account',binding);connected=true;error=null;_notify();
    await synchronize();_schedule();
  }
  Future<void> synchronize()async{
    if(busy||paused||!connected||_disposed){return;}
    busy=true;error=null;_notify();
    try{
      // Push causal batches in insertion order; never advance the pull cursor from a push response.
      for(var i=0;i<100;i++){
        final pending=await store.pending();if(pending.isEmpty){break;}
        try{await api.post('/api/v1/sync/push',{'operations':pending.map((o)=>o.toJson()).toList()});}
        catch(e){await store.failed(pending.map((o)=>o.id).toList(),e.toString());rethrow;}
        await store.acknowledge(pending.map((o)=>o.id).toList());
      }
      for(var i=0;i<100;i++){
        final page=Map<String,dynamic>.from(await api.get('/api/v1/sync/pull?after=${await store.cursor()}') as Map);
        await store.applyPage(page);if(page['more']!=true){break;}
      }
      await AttachmentStore(store).uploadPending(api);
      lastSuccess=DateTime.now();failures=0;
    }catch(e){error=e.toString();failures++;if(e is ApiFailure && (e.status==401||e.status==403)){connected=false;api.token=null;}}
    finally{busy=false;_notify();}
  }
  void setPaused(bool value){paused=value;_notify();if(!paused){unawaited(synchronize());}}
  void _schedule(){_timer?.cancel();if(_disposed){return;}_timer=Timer(Duration(seconds:failures==0?15:(5*(1<<failures.clamp(0,6))).clamp(5,300)),()async{await synchronize();_schedule();});}
  void logout(){connected=false;api.token=null;_timer?.cancel();_notify();}
  void _notify(){if(!_disposed){notifyListeners();}}
  @override void dispose(){_disposed=true;_timer?.cancel();api.close();super.dispose();}
}
