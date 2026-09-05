import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../data/attachment_store.dart';
import '../domain/workspace_controller.dart';
import 'confirm.dart';

class AttachmentPanel extends StatefulWidget{
 final String record;final WorkspaceController controller;
 const AttachmentPanel({super.key,required this.record,required this.controller});
 @override State<AttachmentPanel> createState()=>_AttachmentPanelState();
}
class _AttachmentPanelState extends State<AttachmentPanel>{
 late final store=AttachmentStore(widget.controller.store);List<Map<String,Object?>> rows=[];bool busy=false;String? error;
 @override void initState(){super.initState();unawaited(refresh());}
 Future<void> refresh()async{final result=await store.list(widget.record);if(mounted){setState(()=>rows=result);}}
 Future<void> run(Future<void> Function() action)async{setState((){busy=true;error=null;});try{await action();await refresh();}catch(e){if(mounted){setState(()=>error=e.toString());}}finally{if(mounted){setState(()=>busy=false);}}}
 @override Widget build(BuildContext context)=>Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
  Wrap(spacing:12,crossAxisAlignment:WrapCrossAlignment.center,children:[const Text('Attachments',style:TextStyle(fontSize:18,fontWeight:FontWeight.w700)),IconButton(tooltip:'Attach file',onPressed:busy?null:()=>run(()async{
    final picked=await FilePicker.platform.pickFiles(type:FileType.custom,allowedExtensions:['jpg','jpeg','png','pdf','txt'],withData:true);if(picked==null){return;}final file=picked.files.single;if(file.bytes==null){throw const FormatException('File could not be read');}
    final media=switch(file.extension?.toLowerCase()){'jpg'||'jpeg'=>'image/jpeg','png'=>'image/png','pdf'=>'application/pdf',_=>'text/plain'};
    await store.add(widget.record,file.name,media,file.bytes!);unawaited(widget.controller.sync.synchronize());
  }),icon:const Icon(Icons.attach_file)),IconButton(tooltip:'Download remote attachments',onPressed:busy||!widget.controller.sync.connected?null:()=>run(()=>store.fetch(widget.controller.sync.api,widget.record)),icon:const Icon(Icons.cloud_download_outlined))]),
  if(busy)const LinearProgressIndicator(),if(error!=null)Text(error!,style:const TextStyle(color:Color(0xffb42336))),
  if(rows.isEmpty&&!busy)const Padding(padding:EdgeInsets.symmetric(vertical:12),child:Text('No attachments')),
  for(final row in rows)ListTile(contentPadding:EdgeInsets.zero,leading:const Icon(Icons.insert_drive_file_outlined),title:Text(row['name'] as String),subtitle:Text(row['uploaded']==1?'Available offline':'Pending upload'),trailing:IconButton(tooltip:'Save attachment',icon:const Icon(Icons.download),onPressed:()async{try{await FilePicker.platform.saveFile(fileName:row['name'] as String,bytes:await store.bytes(row['id'] as String));}catch(e){if(context.mounted){showError(context,e);}}})),
 ]);
}
