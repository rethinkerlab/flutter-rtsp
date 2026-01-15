import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:image_picker/image_picker.dart';

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
  bool _isFullscreen = true;
  bool _showControls = true;
  String? _rightAdImagePath;
  String? _bottomAdImagePath;
  final ImagePicker _imagePicker = ImagePicker();
  bool _showAppBar = false;

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

  Future<void> _pickRightAdImage() async {
    final XFile? image = await _imagePicker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _rightAdImagePath = image.path;
      });
    }
  }

  Future<void> _pickBottomAdImage() async {
    final XFile? image = await _imagePicker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _bottomAdImagePath = image.path;
      });
    }
  }

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          title: const Text(
            'Ad Settings',
            style: TextStyle(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.image, color: Colors.blue),
                title: const Text(
                  'Right Ad Image',
                  style: TextStyle(color: Colors.white),
                ),
                subtitle: Text(
                  _rightAdImagePath == null ? 'No image selected' : 'Image selected',
                  style: TextStyle(color: Colors.grey[400]),
                ),
                trailing: const Icon(Icons.upload, color: Colors.white),
                onTap: () {
                  Navigator.pop(context);
                  _pickRightAdImage();
                },
              ),
              const Divider(color: Colors.grey),
              ListTile(
                leading: const Icon(Icons.image, color: Colors.blue),
                title: const Text(
                  'Bottom Ad Image',
                  style: TextStyle(color: Colors.white),
                ),
                subtitle: Text(
                  _bottomAdImagePath == null ? 'No image selected' : 'Image selected',
                  style: TextStyle(color: Colors.grey[400]),
                ),
                trailing: const Icon(Icons.upload, color: Colors.white),
                onTap: () {
                  Navigator.pop(context);
                  _pickBottomAdImage();
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                setState(() {
                  _rightAdImagePath = null;
                  _bottomAdImagePath = null;
                });
                Navigator.pop(context);
              },
              child: const Text('Clear All'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: _showAppBar ? AppBar(
        backgroundColor: Colors.black87,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.settings),
          onPressed: _showSettingsDialog,
          tooltip: 'Settings',
        ),
        actions: [
          IconButton(
            icon: Icon(_showControls ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up),
            onPressed: () {
              setState(() {
                _showControls = !_showControls;
              });
            },
            tooltip: _showControls ? 'Hide Controls' : 'Show Controls',
          ),
          IconButton(
            icon: Icon(_isFullscreen ? Icons.view_sidebar : Icons.fullscreen),
            onPressed: () {
              setState(() {
                _isFullscreen = !_isFullscreen;
              });
            },
            tooltip: _isFullscreen ? 'Ad Mode' : 'Fullscreen',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _reconnect,
            tooltip: 'Reconnect',
          ),
        ],
      ) : null,
      body: Stack(
        children: [
          SafeArea(
            child: _isFullscreen ? _buildFullscreenLayout() : _buildAdModeLayout(),
          ),
          // Floating toggle button in top right
          Positioned(
            top: 8,
            right: 8,
            child: Material(
              color: Colors.black54,
              borderRadius: BorderRadius.circular(20),
              child: InkWell(
                onTap: () {
                  setState(() {
                    _showAppBar = !_showAppBar;
                  });
                },
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  child: Icon(
                    _showAppBar ? Icons.expand_less : Icons.expand_more,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFullscreenLayout() {
    return Column(
      children: [
        Expanded(
          child: Center(
            child: AspectRatio(
              aspectRatio: 16 / 9,
              child: _buildVideoPlayer(),
            ),
          ),
        ),
        if (_showControls) _buildControls(),
      ],
    );
  }

  Widget _buildAdModeLayout() {
    return Column(
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              // Calculate video width based on available height to maintain 16:9
              double videoWidth = constraints.maxHeight * 16 / 9;
              return Row(
                children: [
                  // Video on the left with fixed 16:9 ratio
                  SizedBox(
                    width: videoWidth,
                    child: Center(
                      child: AspectRatio(
                        aspectRatio: 16 / 9,
                        child: _buildVideoPlayer(),
                      ),
                    ),
                  ),
                  // Right ad area - takes remaining width
                  Expanded(
                    child: _buildAdPlaceholder('Right Ad', Colors.grey[800]!, _rightAdImagePath),
                  ),
                ],
              );
            },
          ),
        ),
        // Bottom ad area
        SizedBox(
          height: 150,
          child: _buildAdPlaceholder('Bottom Ad Banner', Colors.grey[850]!, _bottomAdImagePath),
        ),
        if (_showControls) _buildControls(),
      ],
    );
  }

  Widget _buildAdPlaceholder(String label, Color backgroundColor, String? imagePath) {
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
      ),
      child: imagePath != null
          ? Image.file(
              File(imagePath),
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
            )
          : Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.image,
                    size: 48,
                    color: Colors.grey[500],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    label,
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '(Advertisement)',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 12,
                    ),
                  ),
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

    return Video(
      controller: _videoController,
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
