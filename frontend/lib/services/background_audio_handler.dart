import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';
import '../models/history_item.dart';

class BackgroundAudioHandler extends BaseAudioHandler with QueueHandler, SeekHandler {
  final AudioPlayer _player = AudioPlayer();
  final List<HistoryItem> _items=[];
  int _index=-1; bool _repeat=false; bool _shuffle=false;
  StreamSubscription<PlaybackEvent>? _eventSub; StreamSubscription<int?>? _indexSub;
  BackgroundAudioHandler(){_eventSub=_player.playbackEventStream.listen(_broadcastState);_indexSub=_player.currentIndexStream.listen((index){if(index!=null&&index>=0&&index<_items.length){_index=index;mediaItem.add(_media(_items[index],_player.duration));}});}
  MediaItem _media(HistoryItem item,Duration? duration)=>MediaItem(id:item.id,title:item.title,artist:item.artist,artUri:item.thumbnail.isEmpty?null:Uri.tryParse(item.thumbnail),duration:duration,extras:{'path':item.localPath});
  void _broadcastState(PlaybackEvent event){final playing=_player.playing;if(_index>=0&&_index<_items.length)mediaItem.add(_media(_items[_index],_player.duration));playbackState.add(playbackState.value.copyWith(controls:[MediaControl.skipToPrevious,playing?MediaControl.pause:MediaControl.play,MediaControl.skipToNext],systemActions:const{MediaAction.seek,MediaAction.seekForward,MediaAction.seekBackward},androidCompactActionIndices:const[0,1,2],playing:playing,processingState:{ProcessingState.idle:AudioProcessingState.idle,ProcessingState.loading:AudioProcessingState.loading,ProcessingState.buffering:AudioProcessingState.buffering,ProcessingState.ready:AudioProcessingState.ready,ProcessingState.completed:AudioProcessingState.completed}[_player.processingState]!,updatePosition:_player.position,bufferedPosition:_player.bufferedPosition,speed:_player.speed,queueIndex:event.currentIndex));}
  Future<void> setQueue(List<HistoryItem> items,{int startIndex=0})async{_items..clear()..addAll(items);_index=items.isEmpty?-1:startIndex.clamp(0,items.length-1);queue.add(items.map((x)=>_media(x,null)).toList());if(items.isEmpty){await _player.stop();mediaItem.add(null);return;}final sources=items.map((item)=>AudioSource.file(item.localPath,tag:_media(item,null))).toList();await _player.setAudioSources(sources,initialIndex:_index,initialPosition:Duration.zero);mediaItem.add(_media(items[_index],_player.duration));}
  Future<void> playItem(HistoryItem item,{List<HistoryItem>? queueItems})async{if(queueItems!=null&&queueItems.isNotEmpty){final index=queueItems.indexWhere((x)=>x.id==item.id);await setQueue(queueItems,startIndex:index<0?0:index);}else{await setQueue([item]);}await play();}
  void setRepeat(bool value){_repeat=value;_player.setLoopMode(value?LoopMode.one:LoopMode.off);}
  void setShuffle(bool value){_shuffle=value;_player.setShuffleModeEnabled(value);}
  bool get repeat=>_repeat; bool get shuffle=>_shuffle;
  @override Future<void> play()=>_player.play(); @override Future<void> pause()=>_player.pause(); @override Future<void> stop()async{await _player.stop();await super.stop();} @override Future<void> seek(Duration position)=>_player.seek(position); @override Future<void> skipToNext()=>_player.seekToNext(); @override Future<void> skipToPrevious()=>_player.seekToPrevious(); @override Future<void> onTaskRemoved()async{await stop();}
  @override Future<void> customAction(String name,[Map<String,dynamic>? extras])async{if(name=='set_repeat')setRepeat(extras?['enabled']==true);if(name=='set_shuffle')setShuffle(extras?['enabled']==true);}
  Future<void> dispose()async{await _eventSub?.cancel();await _indexSub?.cancel();await _player.dispose();}
}

Future<BackgroundAudioHandler> initBackgroundAudio() async {
  final session=await AudioSession.instance; await session.configure(const AudioSessionConfiguration.music());
  return AudioService.init(builder:()=>BackgroundAudioHandler(),config:const AudioServiceConfig(androidNotificationChannelId:'song_downloader.playback',androidNotificationChannelName:'Music playback',androidNotificationOngoing:false,androidStopForegroundOnPause:false));
}
