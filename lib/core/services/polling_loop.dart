import 'dart:async';

/// A serial, visibility-gated scheduler. The callback handles/report its errors.
class PollingLoop {
  PollingLoop(this.poll, {this.interval = const Duration(seconds: 4)});
  final Future<void> Function() poll;
  final Duration interval;
  Timer? _timer;
  bool _active = false, _disposed = false, _running = false;
  bool get active => _active && !_disposed;
  void start() {
    if (_disposed || _active) return;
    _active = true;
    if (!_running) _schedule();
  }

  void _schedule() {
    _timer?.cancel();
    if (active) _timer = Timer(interval, _tick);
  }

  Future<void> _tick() async {
    if (!active || _running) return;
    _running = true;
    try {
      await poll();
    } finally {
      _running = false;
      _schedule();
    }
  }

  void stop() {
    _active = false;
    _timer?.cancel();
    _timer = null;
  }

  void dispose() {
    stop();
    _disposed = true;
  }
}
