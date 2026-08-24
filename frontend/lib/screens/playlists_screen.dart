import 'package:flutter/material.dart';
import '../models/history_item.dart';
import '../services/download_storage.dart';

class PlaylistsScreen extends StatefulWidget {
  final List<HistoryItem> library;
  const PlaylistsScreen({super.key, required this.library});
  @override State<PlaylistsScreen> createState() => _PlaylistsScreenState();
}

class _PlaylistsScreenState extends State<PlaylistsScreen> {
  final _storage = DownloadStorageService();
  Map<String,List<String>> _playlists = {};
  @override void initState(){super.initState();_load();}
  Future<void> _load() async { final x=await _storage.loadPlaylists(); if(mounted)setState(()=>_playlists=x); }
  Future<void> _create() async { final c=TextEditingController(); final name=await showDialog<String>(context:context,builder:(_)=>AlertDialog(title:const Text('New playlist'),content:TextField(controller:c,autofocus:true,decoration:const InputDecoration(hintText:'Playlist name')),actions:[TextButton(onPressed:()=>Navigator.pop(context),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(context,c.text.trim()),child:const Text('Create'))])); if(name==null||name.isEmpty)return; if(_playlists.containsKey(name)){_snack('Playlist already exists.');return;} _playlists[name]=[];await _storage.savePlaylists(_playlists);setState((){});}
  Future<void> _delete(String name) async { _playlists.remove(name); await _storage.savePlaylists(_playlists);setState((){}); }
  Future<void> _addSongs(String name) async { final selected=<String>{...(_playlists[name]??[])}; await showDialog(context:context,builder:(_)=>StatefulBuilder(builder:(context,setLocal)=>AlertDialog(title:Text('Add songs to $name'),content:SizedBox(width:double.maxFinite,height:400,child:ListView(children:widget.library.map((song)=>CheckboxListTile(value:selected.contains(song.id),onChanged:(v){setLocal((){if(v==true)selected.add(song.id);else selected.remove(song.id);});},title:Text(song.title,maxLines:1,overflow:TextOverflow.ellipsis),subtitle:Text(song.artist))).toList())),actions:[TextButton(onPressed:()=>Navigator.pop(context),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(context),child:const Text('Save'))])); _playlists[name]=selected.toList();await _storage.savePlaylists(_playlists);setState((){});}
  void _snack(String text)=>ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(text)));
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('Playlists')),floatingActionButton:FloatingActionButton(onPressed:_create,child:const Icon(Icons.add)),body:_playlists.isEmpty?const Center(child:Text('No playlists yet')):ListView(padding:const EdgeInsets.all(16),children:_playlists.entries.map((e)=>Card(child:ListTile(leading:const CircleAvatar(child:Icon(Icons.queue_music)),title:Text(e.key,style:const TextStyle(fontWeight:FontWeight.bold)),subtitle:Text('${e.value.length} songs'),trailing:PopupMenuButton<String>(onSelected:(v){if(v=='add')_addSongs(e.key);if(v=='delete')_delete(e.key);},itemBuilder:(_)=>const[PopupMenuItem(value:'add',child:Text('Add / edit songs')),PopupMenuItem(value:'delete',child:Text('Delete playlist'))])))).toList()));
}
