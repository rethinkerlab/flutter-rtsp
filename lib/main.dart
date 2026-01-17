import 'dart:async';
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
  SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.immersiveSticky,
    overlays: [],
  );
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
  String _baseUrl = 'rtsp://admin:hkezit_root@61.238.85.218';
  String _liveUrl = 'rtsp://admin:hkezit_root@61.238.85.218/rtsp/streaming?channel=01';

  bool _isPlaying = false;
  bool _isLoading = true;
  String _errorMessage = '';
  bool _isLiveMode = true;
  DateTime? _currentPlayerTime;
  DateTime? _playbackStartTime;
  bool _isFullscreen = true;
  String? _adImagePath;
  final ImagePicker _imagePicker = ImagePicker();
  bool _showAppBar = false;

  // Score tracking
  int _homeScore = 0;
  int _awayScore = 0;

  // Timer for clock display
  Timer? _clockTimer;
  DateTime _currentTime = DateTime.now();

  @override
  void initState() {
    super.initState();
    _player = Player();
    _videoController = VideoController(_player);
    _initializePlayer();
    _startClockTimer();
  }

  void _startClockTimer() {
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _currentTime = DateTime.now();
        });
      }
    });
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
            _errorMessage = '串流播放錯誤：$error';
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
          _errorMessage = '播放器初始化失敗：$e';
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
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

  String _getChannelFromLiveUrl() {
    final regex = RegExp(r'channel=(\d+)');
    final match = regex.firstMatch(_liveUrl);
    return match?.group(1) ?? '01';
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

    String channel = _getChannelFromLiveUrl();
    String url = '$_baseUrl/rtsp/playback?channel=$channel&subtype=0&starttime=${formatDateTime(startTime)}&endtime=${formatDateTime(endTime)}';
    print('Playback URL: $url');
    return url;
  }

  Future<void> _seekBackward60s() async {
    DateTime now = DateTime.now();
    DateTime currentTime = _currentPlayerTime ?? now;

    // Calculate start time (60 seconds before current player time)
    DateTime startTime = currentTime.subtract(const Duration(seconds: 60));
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

  Future<void> _switchToLiveMode() async {
    setState(() {
      _isLiveMode = true;
      _playbackStartTime = null;
      _currentPlayerTime = DateTime.now();
      _isLoading = true;
    });
    await _player.stop();
    await _player.open(Media(_liveUrl));
  }

  Future<void> _pickAdImage() async {
    final XFile? image = await _imagePicker.pickImage(source: ImageSource.gallery);
    if (image != null) {
      setState(() {
        _adImagePath = image.path;
      });
    }
  }

  void _showSettingsDialog() {
    final TextEditingController baseUrlController = TextEditingController(text: _baseUrl);
    final TextEditingController liveUrlController = TextEditingController(text: _liveUrl);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          title: const Text(
            '設定',
            style: TextStyle(color: Colors.white),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'RTSP 網址',
                  style: TextStyle(
                    color: Colors.blue,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: baseUrlController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: '基礎網址',
                    labelStyle: TextStyle(color: Colors.grey[400]),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.grey[600]!),
                    ),
                    focusedBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.blue),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: liveUrlController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: '直播串流網址',
                    labelStyle: TextStyle(color: Colors.grey[400]),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.grey[600]!),
                    ),
                    focusedBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: Colors.blue),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  '廣告圖片',
                  style: TextStyle(
                    color: Colors.blue,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.image, color: Colors.blue),
                  title: const Text(
                    '廣告圖片',
                    style: TextStyle(color: Colors.white),
                  ),
                  subtitle: Text(
                    _adImagePath == null ? '未選擇圖片' : '已選擇圖片',
                    style: TextStyle(color: Colors.grey[400]),
                  ),
                  trailing: const Icon(Icons.upload, color: Colors.white),
                  onTap: () {
                    Navigator.pop(context);
                    _pickAdImage();
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                setState(() {
                  _adImagePath = null;
                });
                Navigator.pop(context);
              },
              child: const Text('清除廣告'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('取消'),
            ),
            TextButton(
              onPressed: () async {
                setState(() {
                  _baseUrl = baseUrlController.text;
                  _liveUrl = liveUrlController.text;
                });
                Navigator.pop(context);
                // Reconnect with new URLs
                await _reconnect();
              },
              child: const Text('儲存'),
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
            bottom: false,
            child: _isFullscreen ? _buildFullscreenLayout() : _buildAdModeLayout(),
          ),
        ],
      ),
    );
  }

  Widget _buildFullscreenLayout() {
    return Column(
      children: [
        Expanded(
          child: Row(
            children: [
              // Video area - 80% width
              Expanded(
                flex: 80,
                child: Center(
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: _buildVideoPlayer(),
                  ),
                ),
              ),
              // Side panel - 20% width
              Expanded(
                flex: 20,
                child: _buildSidePanel(),
              ),
            ],
          ),
        ),
        _buildControls(),
      ],
    );
  }

  Widget _buildSidePanel() {
    return Container(
      color: Colors.grey[900],
      child: Column(
        children: [
          // Date/Time display - 1/3 height
          Expanded(
            flex: 1,
            child: _buildDateTimeDisplay(),
          ),
          // Score panel - 2/3 height
          Expanded(
            flex: 2,
            child: _buildScorePanel(),
          ),
        ],
      ),
    );
  }

  Widget _buildDateTimeDisplay() {
    final dateStr = '${_currentTime.year}/${_currentTime.month.toString().padLeft(2, '0')}/${_currentTime.day.toString().padLeft(2, '0')}';
    final timeStr = '${_currentTime.hour.toString().padLeft(2, '0')}:${_currentTime.minute.toString().padLeft(2, '0')}:${_currentTime.second.toString().padLeft(2, '0')}';

    return GestureDetector(
      onTap: () {
        setState(() {
          _showAppBar = !_showAppBar;
        });
      },
      child: Container(
        padding: const EdgeInsets.all(8),
        color: Colors.transparent,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                dateStr,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                timeStr,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 48,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScorePanel() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: Colors.grey[700]!, width: 1),
        ),
      ),
      child: Column(
        children: [
          // Title row with reset button
          Row(
            children: [
              // Spacer for balance
              const SizedBox(width: 44),
              // Centered title
              const Expanded(
                child: Text(
                  '得分',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              // Right-aligned reset button
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _homeScore = 0;
                      _awayScore = 0;
                    });
                  },
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.5),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.refresh,
                      color: Colors.black,
                      size: 28,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          // Home score row
          Expanded(
            child: _buildScoreRow('主', _homeScore, (delta) {
              setState(() {
                _homeScore = (_homeScore + delta).clamp(0, 999);
              });
            }),
          ),
          const SizedBox(height: 16),
          // Away score row
          Expanded(
            child: _buildScoreRow('客', _awayScore, (delta) {
              setState(() {
                _awayScore = (_awayScore + delta).clamp(0, 999);
              });
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreRow(String label, int score, Function(int) onScoreChange) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(width: 12),
        // Minus button
        GestureDetector(
          onTap: () => onScoreChange(-1),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.5),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.remove,
              color: Colors.black,
              size: 28,
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Score display
        Container(
          constraints: const BoxConstraints(minWidth: 60),
          child: Text(
            score.toString(),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 40,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(width: 12),
        // Plus button
        GestureDetector(
          onTap: () => onScoreChange(1),
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.5),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.add,
              color: Colors.black,
              size: 28,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAdModeLayout() {
    return Column(
      children: [
        // Top row: Video (80%) + Side panel (20%)
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Video - 80% width
            Expanded(
              flex: 80,
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: _buildVideoPlayer(),
              ),
            ),
            // Side panel - 20% width, same height as video
            Expanded(
              flex: 20,
              child: AspectRatio(
                aspectRatio: 4 / 9, // Match video height (20/80 * 16/9 = 4/9)
                child: _buildSidePanel(),
              ),
            ),
          ],
        ),
        // Ad area - full width
        Expanded(
          child: _buildAdPlaceholder(Colors.grey[800]!, _adImagePath),
        ),
        _buildControls(),
      ],
    );
  }

  Widget _buildAdPlaceholder(Color backgroundColor, String? imagePath) {
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
                    '廣告空間',
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildVideoPlayer() {
    Widget content;

    if (_errorMessage.isNotEmpty) {
      content = Column(
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
            label: const Text('重試'),
          ),
        ],
      );
    } else if (_isLoading) {
      content = const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(color: Colors.blue),
          SizedBox(height: 16),
          Text(
            '正在連接串流...',
            style: TextStyle(color: Colors.white),
          ),
        ],
      );
    } else {
      content = Video(
        controller: _videoController,
      );
    }

    return Container(
      color: Colors.black,
      child: content,
    );
  }

  Widget _buildControls() {
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    return Container(
      padding: EdgeInsets.only(left: 8, right: 8, top: 2, bottom: bottomPadding),
      color: Colors.black87,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Mode indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: _isLiveMode ? Colors.red.withOpacity(0.3) : Colors.orange.withOpacity(0.3),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              _isLiveMode ? '直播' : '回放',
              style: TextStyle(
                color: _isLiveMode ? Colors.red : Colors.orange,
                fontWeight: FontWeight.bold,
                fontSize: 10,
              ),
            ),
          ),
          const SizedBox(width: 16),
          // -60s button
          GestureDetector(
            onTap: _isLoading ? null : _seekBackward60s,
            child: Icon(
              Icons.replay,
              color: _isLoading ? Colors.grey : Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          if (_isLiveMode) ...[
            // Play/Pause button (only in live mode)
            GestureDetector(
              onTap: _togglePlayPause,
              child: Icon(
                _isPlaying ? Icons.pause : Icons.play_arrow,
                color: Colors.white,
                size: 28,
              ),
            ),
          ] else ...[
            // Return to live button (only in playback mode)
            GestureDetector(
              onTap: _isLoading ? null : _switchToLiveMode,
              child: Icon(
                Icons.live_tv,
                color: _isLoading ? Colors.grey : Colors.red,
                size: 24,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
