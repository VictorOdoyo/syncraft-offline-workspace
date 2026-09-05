import 'dart:async';
import 'package:flutter/material.dart';
import '../sync/api_client.dart';
class AuditPanel extends StatefulWidget{
 final ApiClient api;const AuditPanel({super.key,required this.api});
 @override State<AuditPanel> createState()=>_AuditPanelState();
}
class _AuditPanelState extends State<AuditPanel>{
 final List<dynamic> rows=[];bool busy=false,more=true;String? error;
 @override void initState(){super.initState();unawaited(load());}
 Future<void> load()async{if(busy){return;}setState(()=>busy=true);try{final after=rows.isEmpty?0:rows.last['sequence'];final result=await widget.api.get('/api/v1/audit?after=$after') as List;if(mounted){setState((){rows.addAll(result);more=result.length==100;error=null;});}}catch(e){if(mounted){setState(()=>error=e.toString());}}finally{if(mounted){setState(()=>busy=false);}}}
 @override Widget build(BuildContext context)=>ListView(padding:const EdgeInsets.all(24),children:[
  const Text('Workspace audit',style:TextStyle(fontSize:22,fontWeight:FontWeight.w700)),const SizedBox(height:16),
  if(error!=null)Text(error!,style:const TextStyle(color:Color(0xffb42336))),
  for(final row in rows)ListTile(contentPadding:EdgeInsets.zero,leading:const Icon(Icons.history),title:Text(row['action'] as String),subtitle:Text('${row['actor']} · ${row['created']}\n${row['target']}'),isThreeLine:true),
  if(rows.isEmpty&&!busy&&error==null)const Text('No audit events'),
  if(busy)const LinearProgressIndicator(),if(more&&!busy)TextButton(onPressed:load,child:Text(error==null?'Load more':'Retry')),
 ]);
}
