import 'package:flutter/material.dart';
import '../domain/operation.dart';
import '../domain/workspace_controller.dart';
import 'confirm.dart';

Future<void> editField(BuildContext context,WorkspaceController controller,String record,String field,List<Operation> observed)async{
  await showDialog<void>(context:context,builder:(context)=>_FieldDialog(controller:controller,record:record,field:field,observed:observed));
}
class _FieldDialog extends StatefulWidget {
  final WorkspaceController controller;final String record,field;final List<Operation> observed;
  const _FieldDialog({required this.controller,required this.record,required this.field,required this.observed});
  @override State<_FieldDialog> createState()=>_FieldDialogState();
}
class _FieldDialogState extends State<_FieldDialog>{
  late final TextEditingController text=TextEditingController(text:widget.observed.firstOrNull?.value??'');
  bool saving=false;String? error;
  @override void dispose(){text.dispose();super.dispose();}
  @override Widget build(BuildContext context)=>AlertDialog(title:Text('Edit ${widget.field}'),content:SizedBox(width:520,child:TextField(controller:text,autofocus:true,maxLines:widget.field=='notes'?8:1,maxLength:fieldLimits[widget.field],decoration:InputDecoration(labelText:widget.field=='notes'?'Field notes':widget.field,errorText:error))),actions:[
    TextButton(onPressed:saving?null:()async{final original=widget.observed.firstOrNull?.value??'';if(text.text==original||await confirm(context,'Discard changes?','The unsaved edit will be discarded.','Discard')){if(context.mounted){Navigator.pop(context);}}},child:const Text('Cancel')),
    FilledButton(onPressed:saving?null:()async{setState(()=>saving=true);try{await widget.controller.edit(widget.record,widget.field,text.text,widget.observed.map((o)=>o.id).toList());if(context.mounted){Navigator.pop(context);}}catch(e){if(mounted){setState((){error=e.toString();saving=false;});}}},child:Text(saving?'Saving...':'Save')),
  ]);
}
