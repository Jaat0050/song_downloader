import 'dart:io';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../models/history_item.dart';
import '../services/download_storage.dart';
import '../services/library_service.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});
  @override State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  final _storage = DownloadStorageService();
  final _library = LibraryService();
  final _player = AudioPlayer();
  final _search = TextEditingController();
  List<HistoryItem> _items = [];
  HistoryItem? _current;
  bool _loading = true, _playing = false, _favoritesOnly = false;
  Duration _duration = Duration.zero, _position = Duration.zero;

  @override void initState() { super.initState(); _load();
    _player.onPlayerStateChanged.listen((s) { if (mounted) setState(() => _playing = s == PlayerState.playing); });
    _player.onDurationChanged.listen((d) { if (mounted) setState(() => _duration = d); });
    _player.onPositionChanged.listen((p) { if (mounted) setState(() => _position = p); });
    _player.onPlayerComplete.listen((_) { if (mounted) { setState(() { _playing=false; _position=Duration.zero; }); _playNext(); } });
    _search.addListener(() { if (mounted) setState(() {}); });
  }
  Future<void> _load() async { setState(() => _loading=true); final x=await _library.load(); if(mounted)setState(()=>{_items=x,_loading=false}); }
  List<HistoryItem> get _visible { final q=_search.text.trim().toLowerCase(); return _items.where((x)=>(_favoritesOnly?!x.favorite:true)&&(q.isEmpty||x.title.toLowerCase().contains(q)||x.artist.toLowerCase().contains(q))).toList(); }
  Future<void> _play(HistoryItem item) async { if(_current?.id==item.id){ if(_playing) await _player.pause(); else await _player.resume(); return; } final f=File(item.localPath); if(!await f.exists()){_snack('Audio file not found.'); return;} await _player.stop(); await _player.play(DeviceFileSource(item.localPath)); if(mounted)setState(()=>_current=item); }
  Future<void> _playNext() async { if(_current==null)return; final list=_visible; final i=list.indexWhere((x)=>x.id==_current!.id); if(i>=0&&i+1<list.length) await _play(list[i+1]); }
  Future<void> _playPrevious() async { final list=_visible; final i=list.indexWhere((x)=>x.id==_current?.id); if(i>0) await _play(list[i-1]); }
  Future<void> _favorite(HistoryItem item) async { await _library.toggleFavorite(item.id); await _load(); }
  Future<void> _delete(HistoryItem item) async { if(_current?.id==item.id){await _player.stop();_current=null;} await _storage.deleteHistoryItem(item.id); await _load(); }
  Future<void> _rename(HistoryItem item) async { final c=TextEditingController(text:item.title); final value=await showDialog<String>(context:context,builder:(_)=>AlertDialog(title:const Text('Rename song'),content:TextField(controller:c,autofocus:true),actions:[TextButton(onPressed:()=>Navigator.pop(context),child:const Text('Cancel')),FilledButton(onPressed:()=>Navigator.pop(context,c.text),child:const Text('Save'))])); if(value!=null)try{await _library.rename(item,value);await _load();}catch(e){_snack(e.toString());} }
  void _snack(String s)=>ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text(s)));
  String _size(int b)=>b<1024*1024?'${(b/1024).toStringAsFixed(1)} KB':'${(b/1024/1024).toStringAsFixed(1)} MB';
  @override void dispose(){_search.dispose();_player.dispose();super.dispose();}
  @override Widget build(BuildContext context){return Scaffold(appBar:AppBar(title:const Text('Music Library',style:TextStyle(fontWeight:FontWeight.bold)),actions:[IconButton(onPressed:_load,icon:const Icon(Icons.refresh_rounded))]),body:Column(children:[Padding(padding:const EdgeInsets.fromLTRB(16,8,16,4),child:Row(children:[Expanded(child:TextField(controller:_search,decoration:InputDecoration(hintText:'Search songs or artists',prefixIcon:const Icon(Icons.search),filled:true,fillColor:const Color(0xFF15151B),border:OutlineInputBorder(borderRadius:BorderRadius.circular(14),borderSide:BorderSide.none)))),const SizedBox(width:8),IconButton(onPressed:()=>setState(()=>_favoritesOnly=!_favoritesOnly),icon:Icon(_favoritesOnly?Icons.favorite:Icons.favorite_border,color:_favoritesOnly?const Color(0xFFEF5350):null))])),Expanded(child:_loading?const Center(child:CircularProgressIndicator()):_visible.isEmpty?const Center(child:Text('No songs found',style:TextStyle(color:Colors.white54))):ListView.builder(padding:const EdgeInsets.fromLTRB(16,8,16,110),itemCount:_visible.length,itemBuilder:(_,i)=>_tile(_visible[i]))),if(_current!=null)_playerBar()]) );}
  Widget _tile(HistoryItem x){final active=_current?.id==x.id&&_playing;return Card(color:active?const Color(0xFF211B32):const Color(0xFF15151B),margin:const EdgeInsets.only(bottom:8),child:ListTile(contentPadding:const EdgeInsets.symmetric(horizontal:10,vertical:3),leading:ClipRRect(borderRadius:BorderRadius.circular(9),child:SizedBox(width:52,height:52,child:x.thumbnail.isNotEmpty?Image.network(x.thumbnail,fit:BoxFit.cover,errorBuilder:(_,__,___)=>const Icon(Icons.music_note)):const Icon(Icons.music_note))),title:Text(x.title,maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(fontWeight:FontWeight.w700)),subtitle:Text('${x.artist} • ${_size(x.fileSize)}',maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(color:Colors.white54)),trailing:Row(mainAxisSize:MainAxisSize.min,children:[IconButton(onPressed:()=>_favorite(x),icon:Icon(x.favorite?Icons.favorite:Icons.favorite_border,color:x.favorite?const Color(0xFFEF5350):Colors.white54)),IconButton(onPressed:()=>_play(x),icon:Icon(active?Icons.pause_circle_filled:Icons.play_circle_fill,color:const Color(0xFF8B5CF6),size:32)),PopupMenuButton<String>(onSelected:(v){if(v=='rename')_rename(x);if(v=='share')Share.shareXFiles([XFile(x.localPath)],text:x.title);if(v=='delete')_delete(x);},itemBuilder:(_)=>const[PopupMenuItem(value:'rename',child:Text('Rename')),PopupMenuItem(value:'share',child:Text('Share')),PopupMenuItem(value:'delete',child:Text('Delete'))])])));}
  Widget _playerBar(){final x=_current!;final max=_duration.inMilliseconds.toDouble();final val=_position.inMilliseconds.clamp(0,_duration.inMilliseconds).toDouble();return Container(decoration:const BoxDecoration(color:Color(0xFF211B32)),padding:const EdgeInsets.fromLTRB(12,8,12,10),child:Column(mainAxisSize:MainAxisSize.min,children:[Row(children:[Expanded(child:Text(x.title,maxLines:1,overflow:TextOverflow.ellipsis,style:const TextStyle(fontWeight:FontWeight.bold))),IconButton(onPressed:_playPrevious,icon:const Icon(Icons.skip_previous_rounded)),IconButton(onPressed:()=>_play(x),icon:Icon(_playing?Icons.pause_rounded:Icons.play_arrow_rounded)),IconButton(onPressed:_playNext,icon:const Icon(Icons.skip_next_rounded)),IconButton(onPressed:()=>setState(()=>_current=null),icon:const Icon(Icons.close))]),if(max>0)Slider(value:val,max:max,onChanged:(v)=>_player.seek(Duration(milliseconds:v.toInt()))) ]));}
}
