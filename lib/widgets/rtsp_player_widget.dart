import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

class RTSPPlayerWidget extends StatefulWidget {
  final String rtspUrl;
  final VoidCallback? onError;
  final VoidCallback? onConnected;

  const RTSPPlayerWidget({
    super.key,
    required this.rtspUrl,
    this.onError,
    this.onConnected,
  });

  @override
  State<RTSPPlayerWidget> createState() => _RTSPPlayerWidgetState();
}

class _RTSPPlayerWidgetState extends State<RTSPPlayerWidget> {
  late final Player _player;
  late final VideoController _videoController;
  bool _isPlaying = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _player = Player();
    _videoController = VideoController(_player);
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    try {
      // Listen to player state changes
      _player.stream.playing.listen((playing) {
        if (mounted) {
          if (playing && !_isPlaying) {
            setState(() {
              _isPlaying = true;
            });
            widget.onConnected?.call();
          } else if (!playing && _isPlaying) {
            setState(() {
              _isPlaying = false;
            });
          }
        }
      });

      _player.stream.error.listen((error) {
        if (mounted && error != null && !_hasError) {
          setState(() {
            _hasError = true;
          });
          widget.onError?.call();
        }
      });

      // Open and play the RTSP stream
      await _player.open(Media(widget.rtspUrl));
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
        });
        widget.onError?.call();
      }
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return const Center(
        child: Icon(
          Icons.error_outline,
          color: Colors.red,
          size: 64,
        ),
      );
    }

    if (!_isPlaying) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Video(
        controller: _videoController,
      ),
    );
  }
}
