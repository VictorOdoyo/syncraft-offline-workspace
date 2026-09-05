import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'sync_engine.dart';

class LiveHints {
  final SyncEngine engine;
  WebSocketChannel? _channel;StreamSubscription<dynamic>? _subscription;
  Timer? _retry;bool _closed=false;
  LiveHints(this.engine);
  Future<void> connect()async{
    if(_closed||!engine.connected){return;}
    await _subscription?.cancel();await _channel?.sink.close();
    try{
      final uri=engine.api.uri('/api/v1/events').replace(scheme:engine.api.base.scheme=='https'?'wss':'ws');
      final channel=WebSocketChannel.connect(uri);_channel=channel;
      await channel.ready.timeout(const Duration(seconds:10));
      if(_closed){await channel.sink.close();return;}
      channel.sink.add(jsonEncode({'token':engine.api.token,'device':engine.api.device}));
      _subscription=channel.stream.listen((event){
        if(event is String && event.length<4096 && jsonDecode(event)['type']=='sync-needed'){unawaited(engine.synchronize());}
      },onError:(Object error){_schedule();},onDone:_schedule,cancelOnError:true);
    }catch(_){_schedule();}
  }
  void _schedule(){_retry?.cancel();if(!_closed&&engine.connected){_retry=Timer(const Duration(seconds:10),(){unawaited(connect());});}}
  Future<void> close()async{_closed=true;_retry?.cancel();await _subscription?.cancel();await _channel?.sink.close();}
}
