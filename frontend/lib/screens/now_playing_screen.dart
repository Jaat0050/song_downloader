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
      if (song == null) {
        return const Scaffold(body: Center(child: Text('Nothing is playing')));
      }
      final d = player.duration,
          p = player.position,
          max = d.inMilliseconds > 0 ? d.inMilliseconds.toDouble() : 1.0,
          value = p.inMilliseconds.clamp(0, d.inMilliseconds).toDouble();
      return Scaffold(
        appBar: AppBar(title: const Text('Now Playing'), centerTitle: true),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(22, 8, 22, 30),
            children: [
              NeuSurface(
                padding: const EdgeInsets.all(12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: AspectRatio(
                    aspectRatio: 1,
                    child:
                        song.thumbnail.isEmpty
                            ? Image.asset(
                              'assets/images/app_icon.png',
                              fit: BoxFit.cover,
                            )
                            : Image.network(
                              song.thumbnail,
                              fit: BoxFit.cover,
                              errorBuilder:
                                  (_, __, ___) => Image.asset(
                                    'assets/images/app_icon.png',
                                    fit: BoxFit.cover,
                                  ),
                            ),
                  ),
                ),
              ),
              SizedBox(height: 24),
              Text(
                song.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                song.artist,
                style: const TextStyle(color: NeuTheme.muted, fontSize: 15),
              ),
              const SizedBox(height: 18),
              NeuSurface(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 3,
                ),
                // pressed: true,
                child: Column(
                  children: [
                    Slider(
                      value: value,
                      max: max,
                      onChanged:
                          d.inMilliseconds == 0
                              ? null
                              : (v) => player.seek(
                                Duration(milliseconds: v.toInt()),
                              ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _time(p),
                          style: const TextStyle(
                            color: NeuTheme.subtle,
                            fontSize: 11,
                          ),
                        ),
                        Text(
                          _time(d),
                          style: const TextStyle(
                            color: NeuTheme.subtle,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),
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
      );
    },
  );
}
