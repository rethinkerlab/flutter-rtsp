import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MediaKit.ensureInitialized();
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RTSP Viewer',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const RTSPPlayerScreen(),
    );
  }
}

class RTSPPlayerScreen extends StatefulWidget {
  const RTSPPlayerScreen({super.key});

  @override
  State<RTSPPlayerScreen> createState() => _RTSPPlayerScreenState();
}

class _RTSPPlayerScreenState extends State<RTSPPlayerScreen> {
  late final Player _player;
  late final VideoController _videoController;

  // RTSP URL components
  final String _baseUrl = 'rtsp://admin:hkezit_root@61.238.85.218';
  final String _liveUrl = 'rtsp://admin:hkezit_root@61.238.85.218/rtsp/streaming?channel=01';

  bool _isPlaying = false;
  bool _isLoading = true;
  String _errorMessage = '';
  bool _isLiveMode = true;
  DateTime? _currentPlayerTime;
  DateTime? _playbackStartTime;

  @override
  void initState() {
    super.initState();
    _player = Player();
    _videoController = VideoController(_player);
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });

      // Listen to player state changes
      _player.stream.playing.listen((playing) {
        if (mounted) {
          setState(() {
            _isPlaying = playing;
            if (playing) {
              _isLoading = false;
            }
          });
        }
      });

      _player.stream.error.listen((error) {
        if (mounted && error != null) {
          setState(() {
            _errorMessage = 'Error playing stream: $error';
            _isLoading = false;
          });
        }
      });

      _player.stream.buffering.listen((buffering) {
        if (mounted) {
          setState(() {
            _isLoading = buffering;
          });
        }
      });

      // Listen to position changes to track current player time
      _player.stream.position.listen((position) {
        if (mounted) {
          if (_isLiveMode) {
            _currentPlayerTime = DateTime.now();
          } else if (_playbackStartTime != null) {
            _currentPlayerTime = _playbackStartTime!.add(position);
          }
        }
      });

      // Open and play the RTSP stream
      await _player.open(Media(_liveUrl));
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to initialize player: $e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  void _togglePlayPause() {
    _player.playOrPause();
  }

  Future<void> _reconnect() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    await _player.stop();
    await _player.open(Media(_liveUrl));
  }

  String _buildPlaybackUrl(DateTime startTime, DateTime endTime) {
    // Format: 2025-12-09T01:30:00Z
    String formatDateTime(DateTime dt) {
      final utc = dt.toUtc();
      return '${utc.year.toString().padLeft(4, '0')}-'
          '${utc.month.toString().padLeft(2, '0')}-'
          '${utc.day.toString().padLeft(2, '0')}T'
          '${utc.hour.toString().padLeft(2, '0')}:'
          '${utc.minute.toString().padLeft(2, '0')}:'
          '${utc.second.toString().padLeft(2, '0')}Z';
    }

    String url = '$_baseUrl/rtsp/playback?channel=01&subtype=0&starttime=${formatDateTime(startTime)}&endtime=${formatDateTime(endTime)}';
    print('Playback URL: $url');
    return url;
  }

  Future<void> _seekBackward30s() async {
    DateTime now = DateTime.now();
    DateTime currentTime = _currentPlayerTime ?? now;

    // Calculate start time (30 seconds before current player time)
    DateTime startTime = currentTime.subtract(const Duration(seconds: 30));
    DateTime endTime = now;

    setState(() {
      _isLiveMode = false;
      _playbackStartTime = startTime;
      _isLoading = true;
    });

    String playbackUrl = _buildPlaybackUrl(startTime, endTime);
    await _player.stop();
    await _player.open(Media(playbackUrl));
  }

  Future<void> _seekForward30s() async {
    DateTime now = DateTime.now();
    DateTime currentTime = _currentPlayerTime ?? now;

    // Calculate start time (30 seconds after current player time)
    DateTime startTime = currentTime.add(const Duration(seconds: 30));
    DateTime endTime = now;

    // Check if we should switch back to live mode
    Duration timeDiff = now.difference(startTime);
    if (timeDiff.inSeconds < 30) {
      // Switch back to live mode
      setState(() {
        _isLiveMode = true;
        _playbackStartTime = null;
        _currentPlayerTime = now;
        _isLoading = true;
      });
      await _player.stop();
      await _player.open(Media(_liveUrl));
      return;
    }

    setState(() {
      _isLiveMode = false;
      _playbackStartTime = startTime;
      _isLoading = true;
    });

    String playbackUrl = _buildPlaybackUrl(startTime, endTime);
    await _player.stop();
    await _player.open(Media(playbackUrl));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('RTSP Viewer'),
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _reconnect,
            tooltip: 'Reconnect',
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: _buildVideoPlayer(),
              ),
            ),
            _buildControls(),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoPlayer() {
    if (_errorMessage.isNotEmpty) {
      return Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            color: Colors.red,
            size: 64,
          ),
          const SizedBox(height: 16),
          Text(
            _errorMessage,
            style: const TextStyle(color: Colors.white),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _reconnect,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      );
    }

    if (_isLoading) {
      return const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Colors.blue),
          SizedBox(height: 16),
          Text(
            'Connecting to stream...',
            style: TextStyle(color: Colors.white),
          ),
        ],
      );
    }

    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Video(
        controller: _videoController,
      ),
    );
  }

  Widget _buildControls() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.black87,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Mode indicator
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              _isLiveMode ? 'LIVE MODE' : 'PLAYBACK MODE',
              style: TextStyle(
                color: _isLiveMode ? Colors.red : Colors.orange,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          // Control buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // -30s button
              IconButton(
                icon: const Icon(
                  Icons.replay_30,
                  color: Colors.white,
                ),
                iconSize: 32,
                onPressed: _isLoading ? null : _seekBackward30s,
                tooltip: 'Go back 30 seconds',
              ),
              const SizedBox(width: 8),
              // Play/Pause button
              IconButton(
                icon: Icon(
                  _isPlaying ? Icons.pause : Icons.play_arrow,
                  color: Colors.white,
                ),
                iconSize: 40,
                onPressed: _togglePlayPause,
                tooltip: 'Play/Pause',
              ),
              const SizedBox(width: 8),
              // +30s button
              IconButton(
                icon: const Icon(
                  Icons.forward_30,
                  color: Colors.white,
                ),
                iconSize: 32,
                onPressed: _isLoading ? null : _seekForward30s,
                tooltip: 'Go forward 30 seconds',
              ),
            ],
          ),
        ],
      ),
    );
  }
}
