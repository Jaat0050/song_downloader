import 'dart:io';
import '../models/history_item.dart';
import 'download_storage.dart';

class LibraryService {
  final DownloadStorageService _storage = DownloadStorageService();

  Future<List<HistoryItem>> load({bool pruneMissingFiles = true}) async {
    final items = await _storage.loadHistory();
    if (!pruneMissingFiles) return items;
    final valid = <HistoryItem>[];
    var changed = false;
    for (final item in items) {
      if (item.localPath.isNotEmpty && await File(item.localPath).exists()) {
        valid.add(item);
      } else {
        changed = true;
      }
    }
    if (changed) await _storage.saveHistory(valid);
    return valid;
  }

  Future<void> toggleFavorite(String id) async {
    final items = await _storage.loadHistory();
    final updated =
        items
            .map(
              (item) =>
                  item.id == id
                      ? item.copyWith(favorite: !item.favorite)
                      : item,
            )
            .toList();
    await _storage.saveHistory(updated);
  }

  Future<void> rename(HistoryItem item, String newName) async {
    final clean = newName.trim().replaceAll(RegExp(r'[\\/:*?"<>|]'), '_');
    if (clean.isEmpty) throw ArgumentError('Name cannot be empty.');
    final oldFile = File(item.localPath);
    if (!await oldFile.exists())
      throw StateError('Audio file no longer exists.');
    final dir = oldFile.parent;
    final target = File('${dir.path}/$clean.mp3');
    if (target.path != oldFile.path && await target.exists())
      throw StateError('A file with this name already exists.');
    final renamed =
        target.path == oldFile.path
            ? oldFile
            : await oldFile.rename(target.path);
    final updated = item.copyWith();
    final all = await _storage.loadHistory();
    final index = all.indexWhere((x) => x.id == item.id);
    if (index >= 0) {
      all[index] = HistoryItem(
        id: updated.id,
        title: clean,
        artist: updated.artist,
        thumbnail: updated.thumbnail,
        filename: renamed.uri.pathSegments.last,
        localPath: renamed.path,
        downloadedAt: updated.downloadedAt,
        fileSize: updated.fileSize,
        favorite: updated.favorite,
      );
      await _storage.saveHistory(all);
    }
  }
}
