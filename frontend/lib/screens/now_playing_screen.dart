import 'package:flutter/material.dart';
import '../services/music_player_service.dart';
import '../theme/neumorphic_widgets.dart';

class NowPlayingScreen extends StatelessWidget {
  final MusicPlayerService player;
  const NowPlayingScreen({super.key, required this.player});

  String _time(Duration d) =>
      '${d.inMinutes.remainder(60).toString().padLeft(2, '0')}:${d.inSeconds.remainder(60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: player,
    builder: (context, _) {
      final song = player.current;
      if (song == null)
        return const Scaffold(body: Center(child: Text('Nothing is playing')));
      final duration = player.duration;
      final position = player.position;
      final max =
          duration.inMilliseconds > 0
              ? duration.inMilliseconds.toDouble()
              : 1.0;
      final value =
          position.inMilliseconds.clamp(0, duration.inMilliseconds).toDouble();
      return Scaffold(
        appBar: AppBar(title: const Text('Now Playing'), centerTitle: true),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 30),
            child: Column(
              children: [
                Expanded(
                  child: NeuSurface(
                    padding: const EdgeInsets.all(12),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(22),
                      child: AspectRatio(
                        aspectRatio: 1,
                        child:
                            song.thumbnail.isEmpty
                                ? Container(
                                  color: const Color(0xFF19191F),
                                  child: const Icon(
                                    Icons.music_note_rounded,
                                    size: 100,
                                  ),
                                )
                                : Image.network(
                                  song.thumbnail,
                                  fit: BoxFit.cover,
                                  errorBuilder:
                                      (_, __, ___) => Container(
                                        color: const Color(0xFF19191F),
                                        child: const Icon(
                                          Icons.music_note_rounded,
                                          size: 100,
                                        ),
                                      ),
                                ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    song.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    song.artist,
                    style: const TextStyle(color: Colors.white60, fontSize: 16),
                  ),
                ),
                const SizedBox(height: 18),
                Slider(
                  value: value,
                  max: max,
                  onChanged:
                      duration.inMilliseconds == 0
                          ? null
                          : (v) =>
                              player.seek(Duration(milliseconds: v.toInt())),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _time(position),
                      style: const TextStyle(color: Colors.white54),
                    ),
                    Text(
                      _time(duration),
                      style: const TextStyle(color: Colors.white54),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    NeuIconButton(
                      icon: Icons.shuffle_rounded,
                      active: player.shuffle,
                      onPressed: () => player.setShuffle(!player.shuffle),
                    ),
                    NeuIconButton(
                      icon: Icons.skip_previous_rounded,
                      onPressed: player.previous,
                    ),
                    NeuIconButton(
                      icon:
                          player.playing
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                      active: true,
                      onPressed: player.playing ? player.pause : player.resume,
                    ),
                    NeuIconButton(
                      icon: Icons.skip_next_rounded,
                      onPressed: player.next,
                    ),
                    NeuIconButton(
                      icon: Icons.repeat_rounded,
                      active: player.repeat,
                      onPressed: () => player.setRepeat(!player.repeat),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
