import 'package:flutter/material.dart';
import '../domain/inspection.dart';
import '../domain/workspace_controller.dart';
import 'edit_field.dart';

class ConflictPanel extends StatelessWidget {
  final Inspection record;final WorkspaceController controller;
  const ConflictPanel({super.key,required this.record,required this.controller});
  @override Widget build(BuildContext context)=>Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
    if(record.conflicts.isNotEmpty)const Padding(padding:EdgeInsets.symmetric(vertical:12),child:Text('Concurrent edits',style:TextStyle(fontSize:18,fontWeight:FontWeight.w700,color:Color(0xffa62539)))),
    for(final field in record.conflicts)Padding(padding:const EdgeInsets.only(bottom:16),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Row(children:[Expanded(child:Text(field,style:const TextStyle(fontWeight:FontWeight.w700))),TextButton.icon(onPressed:()=>editField(context,controller,record.id,field,record.fields[field]!),icon:const Icon(Icons.merge),label:const Text('Resolve'))]),
      for(final version in record.fields[field]!)Container(width:double.infinity,margin:const EdgeInsets.only(bottom:6),padding:const EdgeInsets.all(12),decoration:const BoxDecoration(color:Color(0xfffff1f1),border:Border(left:BorderSide(color:Color(0xffb42336),width:3))),child:SelectableText(version.value)),
    ])),
  ]);
}
