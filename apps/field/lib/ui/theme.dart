import 'package:flutter/material.dart';

ThemeData workspaceTheme()=>ThemeData(
  useMaterial3:true,
  colorScheme:ColorScheme.fromSeed(seedColor:const Color(0xff087f72),surface:const Color(0xfff8fafb)),
  scaffoldBackgroundColor:const Color(0xfff8fafb),
  appBarTheme:const AppBarTheme(backgroundColor:Colors.white,foregroundColor:Color(0xff18252c),elevation:0,scrolledUnderElevation:1),
  inputDecorationTheme:const InputDecorationTheme(border:OutlineInputBorder(borderRadius:BorderRadius.all(Radius.circular(6))),isDense:true,filled:true,fillColor:Colors.white),
  cardTheme:const CardThemeData(elevation:0,shape:RoundedRectangleBorder(borderRadius:BorderRadius.all(Radius.circular(6)),side:BorderSide(color:Color(0xffdce4e8)))),
  textTheme:const TextTheme(titleLarge:TextStyle(fontSize:22,fontWeight:FontWeight.w700,letterSpacing:0),titleMedium:TextStyle(fontSize:16,fontWeight:FontWeight.w600,letterSpacing:0),bodyMedium:TextStyle(fontSize:14,letterSpacing:0)),
);

Color priorityColor(String priority)=>switch(priority){'critical'=>const Color(0xffb42336),'high'=>const Color(0xff99610a),_=>const Color(0xff26735e)};
String label(String text)=>text.replaceAll('_',' ');
