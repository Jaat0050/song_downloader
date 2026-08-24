import 'package:flutter/foundation.dart';
import 'background_audio_handler.dart';
import '../models/history_item.dart';

class MusicPlayerService extends ChangeNotifier {
  final BackgroundAudioHandler handler;
  HistoryItem? _current;
  List<HistoryItem> _queue = [];
  bool _shuffle = false;
  bool _repeat = false;

  MusicPlayerService({required this.handler}) {
    handler.mediaItem.listen((item) {
      if (item == null) return;
      final index = _queue.indexWhere((x) => x.id == item.id);
      if (index >= 0) _current = _queue[index];
      notifyListeners();
    });
    handler.playbackState.listen((_) => notifyListeners());
  }

  HistoryItem? get current => _current;
  List<HistoryItem> get queue => List.unmodifiable(_queue);
  bool get playing => handler.playbackState.value.playing;
  bool get shuffle => _shuffle;
  bool get repeat => _repeat;
  Duration get position => handler.playbackState.value.position;
  Duration get duration => handler.mediaItem.value?.duration ?? Duration.zero;

  Future<void> play(HistoryItem item, {List<HistoryItem>? source}) async {
    _queue = List.of(source ?? [item]);
    _current = item;
    await handler.playItem(item, queueItems: _queue);
    notifyListeners();
  }
  Future<void> pause() async { await handler.pause(); notifyListeners(); }
  Future<void> resume() async { await handler.play(); notifyListeners(); }
  Future<void> seek(Duration value) => handler.seek(value);
  Future<void> next() => handler.skipToNext();
  Future<void> previous() => handler.skipToPrevious();
  void setShuffle(bool value) { _shuffle=value; handler.setShuffle(value); notifyListeners(); }
  void setRepeat(bool value) { _repeat=value; handler.setRepeat(value); notifyListeners(); }
  Future<void> clearQueue() async { await handler.stop(); _queue=[]; _current=null; notifyListeners(); }
  @override void dispose() { handler.stop(); super.dispose(); }
}
