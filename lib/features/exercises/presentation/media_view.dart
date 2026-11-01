import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:video_player/video_player.dart';
import '../../../app/localization/app_strings.dart';
import '../../../app/providers.dart';
import '../../../app/config/app_config.dart';
import '../../../app/router/route_observer.dart';
import '../../../app/theme/app_theme.dart';
import '../../../shared/widgets/app_widgets.dart';

class MediaView extends ConsumerStatefulWidget {
  const MediaView({super.key, required this.url, required this.type});
  final String url, type;
  @override
  ConsumerState<MediaView> createState() => _MediaViewState();
}

class _MediaViewState extends ConsumerState<MediaView>
    with WidgetsBindingObserver, RouteAware {
  VideoPlayerController? _video;
  bool _error = false;
  bool _fullscreen = false;
  Uri? _uri;
  int _generation = 0;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void didUpdateWidget(MediaView old) {
    super.didUpdateWidget(old);
    if (old.url != widget.url || old.type != widget.type) _load();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null) appRouteObserver.subscribe(this, route);
  }

  @override
  void didPushNext() {
    // The fullscreen route shares this controller, so it must keep playing.
    if (!_fullscreen) _video?.pause();
  }

  Future<void> _load() async {
    final generation = ++_generation;
    final old = _video;
    _video = null;
    await old?.dispose();
    if (!mounted || generation != _generation) return;
    setState(() => _error = false);
    final gateway = Uri.tryParse(ref.read(configProvider).gateway);
    final raw = Uri.tryParse(widget.url);
    _uri = raw == null ? null : gateway?.resolveUri(raw);
    final config = ref.read(configProvider);
    final developmentMedia =
        config.isConfigured &&
        config.environment == Environment.development &&
        _uri?.scheme == 'http' &&
        _uri?.origin == gateway?.origin;
    if (_uri == null ||
        (_uri!.scheme != 'https' && !developmentMedia) ||
        _uri!.userInfo.isNotEmpty) {
      setState(() => _error = true);
      return;
    }
    if (widget.type != 'VIDEO') return;
    final controller = VideoPlayerController.networkUrl(_uri!);
    _video = controller;
    try {
      await controller.initialize();
      if (mounted && generation == _generation) setState(() {});
    } on Object {
      if (mounted && generation == _generation) setState(() => _error = true);
    }
  }

  Future<void> _openFullscreen(VideoPlayerController video) async {
    setState(() => _fullscreen = true);
    await Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => _FullscreenVideo(video: video)),
    );
    if (mounted) setState(() => _fullscreen = false);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) _video?.pause();
  }

  @override
  void deactivate() {
    if (!_fullscreen) _video?.pause();
    super.deactivate();
  }

  @override
  void dispose() {
    _generation++;
    appRouteObserver.unsubscribe(this);
    WidgetsBinding.instance.removeObserver(this);
    _video?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_error) return MediaMessage(onRetry: _load);
    if (_uri == null) return const MediaSkeleton();
    if (widget.type == 'IMAGE') {
      return ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          height: 280,
          width: double.infinity,
          child: ColoredBox(
            color: Colors.black,
            child: CachedNetworkImage(
              imageUrl: _uri.toString(),
              fit: BoxFit.contain,
              placeholder: (_, _) => const MediaSkeleton(),
              errorWidget: (_, _, _) => MediaMessage(onRetry: _load),
            ),
          ),
        ),
      );
    }
    final video = _video;
    if (widget.type != 'VIDEO') return MediaMessage(onRetry: _load);
    if (video == null || !video.value.isInitialized) {
      return const MediaSkeleton();
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: VideoSurface(
        video: video,
        onFullscreen: () => _openFullscreen(video),
        onRetry: _load,
      ),
    );
  }
}

class VideoSurface extends StatefulWidget {
  const VideoSurface({
    super.key,
    required this.video,
    required this.onRetry,
    this.onFullscreen,
    this.fullscreen = false,
  });
  final VideoPlayerController video;
  final VoidCallback onRetry;
  final VoidCallback? onFullscreen;
  final bool fullscreen;
  @override
  State<VideoSurface> createState() => _VideoSurfaceState();
}

class _VideoSurfaceState extends State<VideoSurface> {
  static const _linger = Duration(seconds: 3);
  bool _visible = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _scheduleHide();
  }

  void _scheduleHide() {
    _timer?.cancel();
    if (!widget.video.value.isPlaying) return;
    _timer = Timer(_linger, () {
      if (mounted) setState(() => _visible = false);
    });
  }

  void _reveal({bool toggle = false}) {
    setState(() => _visible = toggle ? !_visible : true);
    if (_visible) {
      _scheduleHide();
    } else {
      _timer?.cancel();
    }
  }

  Future<void> _togglePlay() async {
    final value = widget.video.value;
    if (value.isPlaying) {
      await widget.video.pause();
    } else {
      if (value.position >= value.duration) {
        await widget.video.seekTo(Duration.zero);
      }
      await widget.video.play();
    }
    if (mounted) _reveal();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  static String _clock(Duration value) {
    final seconds = value.inSeconds.clamp(0, 86399);
    return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: widget.video,
    builder: (context, value, _) {
      if (value.hasError) return MediaMessage(onRetry: widget.onRetry);
      final ended = !value.isPlaying && value.position >= value.duration;
      final showing = _visible || !value.isPlaying;
      final surface = GestureDetector(
        onTap: () => _reveal(toggle: true),
        child: ColoredBox(
          color: Colors.black,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Center(
                child: AspectRatio(
                  aspectRatio: value.aspectRatio,
                  child: VideoPlayer(widget.video),
                ),
              ),
              AnimatedOpacity(
                opacity: showing ? 1 : 0,
                duration: const Duration(milliseconds: 180),
                child: IgnorePointer(
                  ignoring: !showing,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.center,
                            end: Alignment.bottomCenter,
                            colors: [Colors.transparent, Color(0x99000000)],
                          ),
                        ),
                      ),
                      Center(
                        child: Material(
                          color: const Color(0x73000000),
                          shape: const CircleBorder(),
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: _togglePlay,
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Icon(
                                ended
                                    ? Icons.replay_rounded
                                    : value.isPlaying
                                    ? Icons.pause_rounded
                                    : Icons.play_arrow_rounded,
                                color: Colors.white,
                                size: 34,
                                semanticLabel: context.t(
                                  value.isPlaying ? 'pause' : 'play',
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        // Timelines read left-to-right regardless of locale.
                        child: Directionality(
                          textDirection: TextDirection.ltr,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(8, 0, 8, 2),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                VideoProgressIndicator(
                                  widget.video,
                                  allowScrubbing: true,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 10,
                                  ),
                                  colors: const VideoProgressColors(
                                    playedColor: AppColors.accent,
                                    bufferedColor: Color(0x4DFFFFFF),
                                    backgroundColor: Color(0x33FFFFFF),
                                  ),
                                ),
                                Row(
                                  children: [
                                    Text(
                                      '${_clock(value.position)} / ${_clock(value.duration)}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 12,
                                      ),
                                    ),
                                    const Spacer(),
                                    if (widget.onFullscreen != null)
                                      IconButton(
                                        tooltip: context.t('fullscreen'),
                                        onPressed: widget.onFullscreen,
                                        visualDensity: VisualDensity.compact,
                                        icon: const Icon(
                                          Icons.fullscreen_rounded,
                                          color: Colors.white,
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (value.isBuffering)
                const Center(
                  child: SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
      // A fixed inline frame keeps portrait clips from swallowing the card.
      return widget.fullscreen
          ? SizedBox.expand(child: surface)
          : SizedBox(height: 280, width: double.infinity, child: surface);
    },
  );
}

class _FullscreenVideo extends StatelessWidget {
  const _FullscreenVideo({required this.video});
  final VideoPlayerController video;
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    body: SafeArea(
      child: Stack(
        children: [
          VideoSurface(
            video: video,
            fullscreen: true,
            onRetry: () => Navigator.of(context).pop(),
          ),
          PositionedDirectional(
            top: 4,
            start: 4,
            child: IconButton(
              tooltip: context.t('close'),
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close_rounded, color: Colors.white),
            ),
          ),
        ],
      ),
    ),
  );
}

class MediaSkeleton extends StatelessWidget {
  const MediaSkeleton({super.key});
  @override
  Widget build(BuildContext context) => const AspectRatio(
    aspectRatio: 16 / 9,
    child: AppSkeleton(height: double.infinity, radius: 16),
  );
}

class MediaMessage extends StatelessWidget {
  const MediaMessage({super.key, required this.onRetry});
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => AspectRatio(
    aspectRatio: 16 / 9,
    child: Container(
      decoration: BoxDecoration(
        color: AppColors.canvas,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.videocam_off_rounded,
            color: AppColors.muted,
            size: 28,
          ),
          const SizedBox(height: 6),
          Text(
            context.t('mediaUnavailable'),
            style: const TextStyle(color: AppColors.muted, fontSize: 13),
          ),
          TextButton(onPressed: onRetry, child: Text(context.t('retry'))),
        ],
      ),
    ),
  );
}
