import 'package:flutter/material.dart';
import '../domain/workspace_controller.dart';
import 'theme.dart';
class SearchToolbar extends StatefulWidget {
  final WorkspaceController controller;const SearchToolbar({super.key,required this.controller});
  @override State<SearchToolbar> createState()=>_SearchToolbarState();
}
class _SearchToolbarState extends State<SearchToolbar>{
  late final text=TextEditingController(text:widget.controller.query);
  @override void dispose(){text.dispose();super.dispose();}
  @override Widget build(BuildContext context){final c=widget.controller;if(text.text!=c.query){text.value=TextEditingValue(text:c.query,selection:TextSelection.collapsed(offset:c.query.length));}
    return Padding(padding:const EdgeInsets.all(16),child:Column(children:[
      TextField(controller:text,decoration:InputDecoration(labelText:'Search inspections',prefixIcon:const Icon(Icons.search),suffixIcon:IconButton(tooltip:'Clear search',onPressed:()=>c.filter(text:''),icon:const Icon(Icons.clear))),onChanged:(value)=>c.filter(text:value)),
      const SizedBox(height:12),Wrap(spacing:12,runSpacing:12,children:[
        SizedBox(width:160,child:DropdownButtonFormField<String>(key:ValueKey('status-${c.status}'),initialValue:c.status,decoration:const InputDecoration(labelText:'Status'),items:['all','draft','in_progress','complete'].map((s)=>DropdownMenuItem(value:s,child:Text(label(s)))).toList(),onChanged:(v)=>c.filter(state:v))),
        SizedBox(width:160,child:DropdownButtonFormField<String>(key:ValueKey('priority-${c.priority}'),initialValue:c.priority,decoration:const InputDecoration(labelText:'Priority'),items:['all','normal','high','critical'].map((s)=>DropdownMenuItem(value:s,child:Text(s))).toList(),onChanged:(v)=>c.filter(urgency:v))),
        FilterChip(label:const Text('Conflicts'),selected:c.conflictsOnly,onSelected:(v)=>c.filter(conflicts:v)),
        FilterChip(label:const Text('Archived'),selected:c.showArchived,onSelected:(v)=>c.filter(archived:v)),
        IconButton(tooltip:'Reset filters',onPressed:c.clearFilters,icon:const Icon(Icons.filter_alt_off)),
      ]),
    ]));
  }
}
