import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import '../models/history_item.dart';

class MusicPlayerService extends ChangeNotifier {
  final AudioPlayer _player = AudioPlayer();
  HistoryItem? _current;
  List<HistoryItem> _queue = [];
  int _index = -1;
  bool _shuffle = false;
  bool _repeat = false;
  bool _playing = false;
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  MusicPlayerService() {
    _player.onPlayerStateChanged.listen((state) { _playing = state == PlayerState.playing; notifyListeners(); });
    _player.onPositionChanged.listen((value) { _position = value; notifyListeners(); });
    _player.onDurationChanged.listen((value) { _duration = value; notifyListeners(); });
    _player.onPlayerComplete.listen((_) => _handleComplete());
  }

  HistoryItem? get current => _current;
  List<HistoryItem> get queue => List.unmodifiable(_queue);
  bool get playing => _playing;
  bool get shuffle => _shuffle;
  bool get repeat => _repeat;
  Duration get position => _position;
  Duration get duration => _duration;

  Future<void> play(HistoryItem item, {List<HistoryItem>? source}) async {
    if (_current?.id == item.id) { if (_playing) await pause(); else await resume(); return; }
    if (source != null) { _queue = List.of(source); _index = _queue.indexWhere((x) => x.id == item.id); }
    else if (_queue.isEmpty) { _queue = [item]; _index = 0; }
    await _player.stop();
    await _player.play(DeviceFileSource(item.localPath));
    _current = item; _position = Duration.zero; notifyListeners();
  }

  Future<void> pause() async => _player.pause();
  Future<void> resume() async => _player.resume();
  Future<void> seek(Duration value) async => _player.seek(value);

  Future<void> next() async {
    if (_queue.isEmpty) return;
    var nextIndex = _index + 1;
    if (_shuffle && _queue.length > 1) {
      nextIndex = (_index + 1 + DateTime.now().millisecond) % _queue.length;
    }
    if (nextIndex >= _queue.length) { if (_repeat) nextIndex = 0; else return; }
    _index = nextIndex;
    await _playCurrent();
  }

  Future<void> previous() async {
    if (_position.inSeconds > 3) { await seek(Duration.zero); return; }
    if (_queue.isEmpty) return;
    var previousIndex = _index - 1;
    if (previousIndex < 0) previousIndex = _repeat ? _queue.length - 1 : 0;
    _index = previousIndex;
    await _playCurrent();
  }

  Future<void> _playCurrent() async {
    if (_index < 0 || _index >= _queue.length) return;
    final item = _queue[_index];
    await _player.stop();
    await _player.play(DeviceFileSource(item.localPath));
    _current = item; _position = Duration.zero; notifyListeners();
  }

  Future<void> _handleComplete() async {
    _playing = false;
    notifyListeners();
    if (_repeat) { await _playCurrent(); return; }
    await next();
  }

  void setShuffle(bool value) { _shuffle = value; notifyListeners(); }
  void setRepeat(bool value) { _repeat = value; notifyListeners(); }
  void setQueue(List<HistoryItem> items, {int startIndex = 0}) { _queue = List.of(items); _index = startIndex.clamp(0, _queue.isEmpty ? 0 : _queue.length - 1); notifyListeners(); }
  Future<void> clearQueue() async { await _player.stop(); _queue = []; _index = -1; _current = null; _playing = false; notifyListeners(); }

  @override void dispose() { _player.dispose(); super.dispose(); }
}
