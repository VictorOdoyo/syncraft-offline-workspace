import 'package:flutter/material.dart';
Future<bool> confirm(BuildContext context,String title,String message,String action)async=>await showDialog<bool>(context:context,builder:(context)=>AlertDialog(
  title:Text(title),content:Text(message),actions:[TextButton(onPressed:()=>Navigator.pop(context,false),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(context,true),child:Text(action))],
))??false;
void showError(BuildContext context,Object error){ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(error.toString()),behavior:SnackBarBehavior.floating));}
