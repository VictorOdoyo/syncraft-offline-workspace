import 'dart:async';
import 'package:flutter/material.dart';
import 'data/local_store.dart';
import 'data/demo_seed.dart';
import 'domain/workspace_controller.dart';
import 'sync/api_client.dart';
import 'sync/sync_engine.dart';
import 'sync/live_hints.dart';
import 'ui/theme.dart';
import 'ui/inspection_list.dart';
import 'ui/inspection_detail.dart';
import 'ui/search_toolbar.dart';
import 'ui/sync_status.dart';
import 'ui/login_dialog.dart';
import 'ui/new_inspection.dart';
import 'ui/confirm.dart';

Future<void> main()async{
  WidgetsFlutterBinding.ensureInitialized();
  try{
    final store=await LocalStore.open();
    const endpoint=String.fromEnvironment('API_URL',defaultValue:'http://127.0.0.1:8091');
    final sync=SyncEngine(store,ApiClient(endpoint));final controller=WorkspaceController(store,sync);await controller.refresh();
    runApp(SyncraftApp(controller:controller));
  }catch(e){runApp(MaterialApp(home:Scaffold(body:Center(child:Padding(padding:const EdgeInsets.all(24),child:SelectableText('Local workspace could not open.\n$e'))))));}
}
class SyncraftApp extends StatelessWidget{
  final WorkspaceController controller;
  const SyncraftApp({super.key,required this.controller});
  @override Widget build(BuildContext context)=>MaterialApp(title:'Syncraft Field Workspace',debugShowCheckedModeBanner:false,theme:workspaceTheme(),home:WorkspaceScreen(controller:controller));
}
class WorkspaceScreen extends StatefulWidget{
  final WorkspaceController controller;const WorkspaceScreen({super.key,required this.controller});
  @override State<WorkspaceScreen> createState()=>_WorkspaceScreenState();
}
class _WorkspaceScreenState extends State<WorkspaceScreen> with WidgetsBindingObserver{
  LiveHints? hints;
  @override void initState(){super.initState();WidgetsBinding.instance.addObserver(this);}
  @override void didChangeAppLifecycleState(AppLifecycleState state){if(state==AppLifecycleState.resumed){unawaited(widget.controller.sync.synchronize());}}
  @override void dispose(){WidgetsBinding.instance.removeObserver(this);unawaited(hints?.close());super.dispose();}
  Future<void> connect()async{if(await loginDialog(context,widget.controller.sync)){await hints?.close();hints=LiveHints(widget.controller.sync);await hints!.connect();}}
  @override Widget build(BuildContext context)=>ListenableBuilder(listenable:widget.controller,builder:(context,_){final c=widget.controller;final record=c.selected;
    return Scaffold(appBar:AppBar(title:const Row(children:[Icon(Icons.hub_outlined,color:Color(0xff087f72)),SizedBox(width:10),Text('Syncraft')]),actions:[
      IconButton(tooltip:'New inspection',onPressed:()=>newInspection(context,c),icon:const Icon(Icons.add)),
      if(c.inspections.isEmpty)TextButton(onPressed:()async{try{await loadDemo(c.store);await c.refresh();}catch(e){if(context.mounted){showError(context,e);}}},child:const Text('Load demo')),
    ]),body:Column(children:[SyncStatus(controller:c,onConnect:connect),Expanded(child:LayoutBuilder(builder:(context,constraints){
      final list=Column(children:[SearchToolbar(controller:c),Padding(padding:const EdgeInsets.symmetric(horizontal:16),child:Align(alignment:Alignment.centerLeft,child:Text('${c.filtered.length} inspections',style:const TextStyle(color:Color(0xff596970))))),Expanded(child:InspectionList(controller:c))]);
      final detail=record==null?const Center(child:Column(mainAxisSize:MainAxisSize.min,children:[Icon(Icons.assignment_outlined,size:64,color:Color(0xff8ca6a1)),SizedBox(height:16),Text('Select an inspection')])):InspectionDetail(record:record,controller:c);
      if(constraints.maxWidth<850){return record==null?list:detail;}
      return Row(children:[SizedBox(width:400,child:list),const VerticalDivider(width:1),Expanded(child:detail)]);
    }))]));
  });
}
