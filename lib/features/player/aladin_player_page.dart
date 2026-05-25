import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:provider/provider.dart';
import '../../core/models/aladin_channel_model.dart';
import '../../core/models/aladin_playlist_model.dart';
import '../../core/services/aladin_channel_service.dart';
import '../../core/services/aladin_metadata_sync_service.dart';
import '../../core/state/aladin_app_prefs.dart';
import '../../core/state/aladin_app_state.dart';
import '../../shared/theme/aladin_app_theme.dart';
import '../series/aladin_series_page.dart';

class PlayerPage extends StatefulWidget {
  final ChannelModel channel;
  final List<ChannelModel> playlist;
  final PlaylistModel? playlistModel;

  const PlayerPage({
    super.key,
    required this.channel,
    required this.playlist,
    this.playlistModel,
  });

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  late final Player _player;
  late final VideoController _controller;

  late List<ChannelModel> _playable;
  late int _currentIndex;

  bool _showControls = true;
  bool _isLive = false;
  bool _isLoading = true;
  bool _hasError = false;
  bool _initialized = false;

  Timer? _hideTimer;
  Timer? _progressTimer;

  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;

  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();

    MetadataSyncService.instance.stopSync();

    _playable = widget.playlist
        .where((e) => e.url.trim().isNotEmpty)
        .toList();

    if (widget.channel.url.trim().isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => AladinSeriesDetailPage(
              playlistId: widget.channel.playlistId,
              seriesName: widget.channel.seriesName ?? widget.channel.name,
              seriesId: widget.channel.tvgId,
              playlistModel: widget.playlistModel,
            ),
          ),
        );
      });
      return;
    }

    _currentIndex = _playable.indexWhere((e) => e.id == widget.channel.id);
    if (_currentIndex < 0) _currentIndex = 0;

    _isLive = _detectLive(widget.channel.url);

    try {
      _player = Player();
      _controller = VideoController(_player);
      _initialized = true;
      
      _setupStreams();
      _playChannel(_playable[_currentIndex]);
    } catch (e) {
      debugPrint('[PlayerPage] Init error: $e');
      _hasError = true;
    }
    
    _startHideTimer();
  }

  void _setupStreams() {
    _player.stream.buffering.listen((buffering) {
      if (mounted) setState(() => _isLoading = buffering);
    });

    _player.stream.playing.listen((p) {
      if (mounted && p) setState(() => _hasError = false);
    });

    _player.stream.error.listen((error) {
      if (mounted) setState(() => _hasError = true);
    });

    _player.stream.position.listen((pos) {
      if (mounted) setState(() => _position = pos);
    });

    _player.stream.duration.listen((dur) {
      if (mounted) setState(() => _duration = dur);
    });

    _progressTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      _saveProgress();
    });
  }

  void _playChannel(ChannelModel ch) {
    setState(() {
      _isLive = _detectLive(ch.url);
      _hasError = false;
      _isLoading = true;
    });
    _player.open(Media(ch.url));
  }

  bool _detectLive(String url) {
    final u = url.toLowerCase();
    return u.startsWith('rtsp') ||
        u.startsWith('rtp') ||
        u.startsWith('udp') ||
        (!u.contains('.mp4') &&
            !u.contains('.mkv') &&
            !u.contains('.avi') &&
            !u.contains('.ts'));
  }

  void _channelUp() {
    if (_currentIndex > 0) {
      setState(() => _currentIndex--);
      _playChannel(_playable[_currentIndex]);
    }
  }

  void _channelDown() {
    if (_currentIndex < _playable.length - 1) {
      setState(() => _currentIndex++);
      _playChannel(_playable[_currentIndex]);
    }
  }

  void _seekForward() => _player.seek(_position + const Duration(seconds: 30));
  void _seekBack() => _player.seek(_position - const Duration(seconds: 10));

  void _startHideTimer() {
    _hideTimer?.cancel();
    _hideTimer = Timer(const Duration(seconds: 4), () {
      if (mounted) setState(() => _showControls = false);
    });
  }

  void _onTap() {
    setState(() => _showControls = !_showControls);
    if (_showControls) _startHideTimer();
  }

  Future<void> _saveProgress() async {
    final ch = _playable.isNotEmpty ? _playable[_currentIndex] : null;
    if (ch == null) return;
    if (_duration.inSeconds < 10) return;
    await ChannelService.instance.updateProgressByUrl(
      ch.url,
      _position.inSeconds,
      _duration.inSeconds,
    );
  }

  @override
  void dispose() {
    _saveProgress();
    _hideTimer?.cancel();
    _progressTimer?.cancel();
    _focusNode.dispose();
    _player.dispose();
    MetadataSyncService.instance.startSync(
      widget.channel.playlistId,
      lang: AppState.instance.lang,
    );
    super.dispose();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;
    setState(() => _showControls = true);
    _startHideTimer();

    switch (event.logicalKey) {
      case LogicalKeyboardKey.arrowUp: if (_isLive) _channelUp(); return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowDown: if (_isLive) _channelDown(); return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowLeft: if (!_isLive) _seekBack(); return KeyEventResult.handled;
      case LogicalKeyboardKey.arrowRight: if (!_isLive) _seekForward(); return KeyEventResult.handled;
      case LogicalKeyboardKey.select:
      case LogicalKeyboardKey.enter:
      case LogicalKeyboardKey.space: _player.playOrPause(); return KeyEventResult.handled;
      case LogicalKeyboardKey.escape:
      case LogicalKeyboardKey.goBack: Navigator.pop(context); return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Focus(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: _handleKeyEvent,
        child: GestureDetector(
          onTap: _onTap,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (_initialized)
                Center(
                  child: Video(controller: _controller),
                ),
              if (_isLoading)
                const Center(child: CircularProgressIndicator(color: AppTheme.accent)),
              if (_hasError)
                Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, color: Colors.white54, size: 48),
                      const SizedBox(height: 12),
                      const Text('Yayın yüklenemedi', style: TextStyle(color: Colors.white70)),
                      TextButton(
                        onPressed: () => _playChannel(_playable[_currentIndex]),
                        child: const Text('Yeniden Dene', style: TextStyle(color: AppTheme.accent)),
                      ),
                    ],
                  ),
                ),
              AnimatedOpacity(
                opacity: _showControls ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 300),
                child: _buildControls(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildControls() {
    final ch = _playable.isNotEmpty ? _playable[_currentIndex] : widget.channel;
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 48, 16, 16),
          decoration: const BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: [Colors.black87, Colors.transparent]),
          ),
          child: Row(
            children: [
              IconButton(icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white), onPressed: () => Navigator.pop(context)),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(ch.name, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
                    if (ch.categoryName.isNotEmpty) Text(ch.categoryName, style: const TextStyle(color: Colors.white60, fontSize: 13)),
                  ],
                ),
              ),
              if (_isLive)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: Colors.red, borderRadius: BorderRadius.circular(4)),
                  child: const Text('LIVE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                ),
            ],
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 40),
          decoration: const BoxDecoration(
            gradient: LinearGradient(begin: Alignment.bottomCenter, end: Alignment.topCenter, colors: [Colors.black87, Colors.transparent]),
          ),
          child: Column(
            children: [
              if (!_isLive && _duration.inSeconds > 0)
                Slider(
                  value: _position.inSeconds.clamp(0, _duration.inSeconds).toDouble(),
                  max: _duration.inSeconds.toDouble(),
                  onChanged: (v) => _player.seek(Duration(seconds: v.toInt())),
                  activeColor: AppTheme.accent,
                ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (_isLive) IconButton(icon: const Icon(Icons.skip_previous, color: Colors.white, size: 36), onPressed: _channelUp),
                  if (!_isLive) IconButton(icon: const Icon(Icons.replay_10, color: Colors.white, size: 36), onPressed: _seekBack),
                  const SizedBox(width: 16),
                  IconButton(
                    icon: Icon(_player.state.playing ? Icons.pause_circle_filled : Icons.play_circle_filled, color: Colors.white, size: 64),
                    onPressed: () => setState(() => _player.playOrPause()),
                  ),
                  const SizedBox(width: 16),
                  if (!_isLive) IconButton(icon: const Icon(Icons.forward_30, color: Colors.white, size: 36), onPressed: _seekForward),
                  if (_isLive) IconButton(icon: const Icon(Icons.skip_next, color: Colors.white, size: 36), onPressed: _channelDown),
                ],
              ),
              if (!_isLive && _duration.inSeconds > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('${_formatDuration(_position)} / ${_formatDuration(_duration)}', style: const TextStyle(color: Colors.white60, fontSize: 13)),
                ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return h > 0 ? '$h:$m:$s' : '$m:$s';
  }
}
