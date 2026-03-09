import 'dart:async';
import 'dart:io';

/// Watches a workspace directory for filesystem changes.
///
/// Emits [FileSystemEvent]s for any files or directories that are
/// created, modified, moved, or deleted within [watchPath].
class WorkspaceWatcher {
  WorkspaceWatcher({required String watchPath}) : _watchPath = watchPath;

  final String _watchPath;
  StreamSubscription<FileSystemEvent>? _subscription;
  StreamController<FileSystemEvent>? _controller;

  /// A stream of filesystem events for the watched workspace directory.
  Stream<FileSystemEvent> get events {
    _controller ??= StreamController<FileSystemEvent>.broadcast();
    return _controller!.stream;
  }

  /// Starts watching the workspace directory.
  ///
  /// If already started, the previous subscription is cancelled before
  /// creating a new one.
  void start() {
    // Cancel any existing subscription to avoid duplicated events / leaks.
    _subscription?.cancel();
    _controller ??= StreamController<FileSystemEvent>.broadcast();

    final dir = Directory(_watchPath);
    _subscription = dir
        .watch(recursive: true)
        .listen(_controller!.add, onError: _controller!.addError);
  }

  /// Stops watching and releases resources.
  Future<void> stop() async {
    await _subscription?.cancel();
    _subscription = null;
    await _controller?.close();
    _controller = null;
  }
}
