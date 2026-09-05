import 'package:flutter/material.dart';
import '../domain/workspace_controller.dart';
class SyncStatus extends StatelessWidget {
 final WorkspaceController controller;final VoidCallback onConnect;
 const SyncStatus({super.key,required this.controller,required this.onConnect});
 @override Widget build(BuildContext context){final sync=controller.sync;return Container(padding:const EdgeInsets.symmetric(horizontal:16,vertical:10),color:sync.error==null?const Color(0xffe9f4ef):const Color(0xffffeded),child:Wrap(spacing:12,runSpacing:8,crossAxisAlignment:WrapCrossAlignment.center,children:[
  Icon(sync.busy?Icons.sync:sync.connected?Icons.cloud_done_outlined:Icons.cloud_off_outlined,size:20),
  Text(sync.busy?'Synchronizing':sync.paused?'Sync paused':sync.connected?'Connected':'Working offline',style:const TextStyle(fontWeight:FontWeight.w600)),
  Text('${controller.pending} pending edits'),
  if(sync.lastSuccess!=null)Text('Last sync ${TimeOfDay.fromDateTime(sync.lastSuccess!).format(context)}'),
  if(sync.connected)...[IconButton(tooltip:'Synchronize now',onPressed:sync.busy||sync.paused?null:sync.synchronize,icon:const Icon(Icons.sync)),IconButton(tooltip:sync.paused?'Resume synchronization':'Pause synchronization',onPressed:()=>sync.setPaused(!sync.paused),icon:Icon(sync.paused?Icons.play_arrow:Icons.pause)),TextButton(onPressed:sync.logout,child:const Text('Disconnect'))]
  else TextButton.icon(onPressed:onConnect,icon:const Icon(Icons.login),label:const Text('Connect')),
  if(sync.error!=null)Text(sync.error!,style:const TextStyle(color:Color(0xff9e2437))),
 ]));}
}
