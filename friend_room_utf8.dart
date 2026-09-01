import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:livekit_client/livekit_client.dart' hide ConnectionState;
import 'package:livekit_client/livekit_client.dart' as lk show ConnectionState;
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:math';
import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:open_filex/open_filex.dart';
import 'dart:ui' as ui;
import 'package:geolocator/geolocator.dart';
import 'whiteboard_canvas.dart';
import 'web_download_stub.dart' if (dart.library.html) 'web_download_web.dart';
import '../services/supabase_storage_service.dart';
import 'bg_images.dart';
import 'package:shared_preferences/shared_preferences.dart';
// dart:js is only available on web — conditional import
// ignore: avoid_web_libraries_in_flutter
import 'dart:js' as js;

class ChatMessage {
  final String text;
  final bool isMe;
  final String time;
  final bool isFile;
  final String? fileName;
  final String? filePath; // local path where the received file was saved
  final String? memoryKey; // lookup key for in-memory bytes (web)
  final DateTime?
      receivedAt; // when the file arrived (used for Supabase metadata)
  ChatMessage(
    this.text,
    this.isMe,
    this.time, {
    this.isFile = false,
    this.fileName,
    this.filePath,
    this.memoryKey,
    this.receivedAt,
  });
}

class ConsultationRoom extends StatefulWidget {
  final String url;
  final String token;
  final String roomName;
  final String apiKey;
  final String apiSecret;
  final bool initialVideoOn;
  final bool initialAudioOn;
  final String publicUrl;
  final bool isPip;
  final VoidCallback? onExpand;
  final bool isDoctor;

  const ConsultationRoom({
    super.key,
    required this.url,
    required this.token,
    this.roomName = '',
    this.apiKey = '',
    this.apiSecret = '',
    this.initialVideoOn = true,
    this.initialAudioOn = true,
    this.publicUrl = '',
    this.isPip = false,
    this.onExpand,
    this.isDoctor = false,
  });

  @override
  State<ConsultationRoom> createState() => _ConsultationRoomState();
}

class _ConsultationRoomState extends State<ConsultationRoom>
    with TickerProviderStateMixin {
  late bool isVideoOn = widget.initialVideoOn;
  late bool isAudioOn = widget.initialAudioOn;
  bool isChatOpen = false;
  bool isBlurActive = false;
  String _currentBgTheme = 'none';

  String? _customBgBase64;

  // Background effects state
  String _previewBgTheme = 'none';
  String? _previewBgUrl;
  double _blurStrength = 15.0; // Low=8, Med=15, High=25
  bool _bgIsLoading = false;

  final List<Map<String, String>> _bgThemes = [
    {
      'id': 'none',
      'title': 'None',
    },
    {
      'id': 'blur',
      'title': 'Blur',
    },
    {
      'id': 'office',
      'title': 'Office',
      'url': BgImages.office,
    },
    {
      'id': 'hospital',
      'title': 'Hospital Room',
      'url': BgImages.hospital,
    },
    {
      'id': 'clinic',
      'title': 'Clinic',
      'url': BgImages.clinic,
    },
    {
      'id': 'white',
      'title': 'Plain White',
      'url':
          'data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+ip1sAAAAASUVORK5CYII=',
    },
    {
      'id': 'nature',
      'title': 'Nature',
      'url': BgImages.nature,
    },
    {
      'id': 'home_office',
      'title': 'Home Office',
      'url': BgImages.home_office,
    },
    {
      'id': 'custom',
      'title': 'Custom Image',
    }
  ];

  bool _blurAvailable = false; // true after MediaPipe loads on web
  String? _mediaErrorMessage;
  bool isWhiteboardOpen = false;
  bool _showInlineInviteCard = true;
  bool _inviteLinkCopied = false;
  int _unreadMessageCount = 0;

  // For reassembling incoming CHAT file chunks (files sent in the chatbox)
  final Map<String, List<String?>> _incomingChatFileChunks = {};
  final Map<String, String> _incomingChatFileNames = {};

  // Local folder (for this call) where received chat files are saved
  Directory? _chatFilesDir;

  final Map<String, Uint8List> _inMemoryChatFiles = {};
  // Tracks Blob URLs created for web file preview so they can be revoked when
  // the call ends (frees browser memory — the file never touches disk).
  final List<String> _webBlobUrls = [];

  // Location Tracking
  final Map<String, Map<String, dynamic>> _participantLocations = {};
  bool _isSharingLocation = false; // For reassembling incoming file chunks
  final Map<String, List<String?>> _incomingFileChunks = {};

  final TextEditingController _chatController = TextEditingController();
  final TextEditingController _ipOverrideController = TextEditingController();
  final List<ChatMessage> _messages = [];
  final StreamController<dynamic> _whiteboardStreamController =
      StreamController<dynamic>.broadcast();

  // Smart Virtual Waiting Room state variables
  int _completedAppointments = 18;
  int _totalAppointments = 20;
  int _queuePosition = 2; // Starts at 2, becomes 1
  int _estimatedWaitMinutes = 8;
  int _secondsWaiting = 0;
  Timer? _waitingTimer;
  int _currentTimelineStage =
      2; // 0: Confirmed, 1: Waiting Room, 2: Doctor Preparing, 3: Doctor Joining, 4: Consultation
  String _liveUpdateMessage = 'Doctor is reviewing your medical history.';
  final List<String> _liveUpdateMessages = [
    'Doctor is reviewing your medical history.',
    'Doctor is finishing the current consultation.',
    'Preparing your consultation room...',
    'Video room is almost ready.',
  ];
  int _liveMessageIndex = 0;
  bool _doctorJoinedTriggered = false;
  bool _showCountdown = false;
  int _countdownSeconds = 3;
  Timer? _countdownTimer;
  bool _isCameraReady = true;
  bool _isMicReady = true;
  bool _showRescheduleOptions = false;

  // LiveKit WebRTC Tracks
  LocalVideoTrack? _localVideoTrack;
  LocalAudioTrack? _localAudioTrack;
  late final Room _room = Room(
    roomOptions: const RoomOptions(
      // Dynacast: server dynamically adjusts quality per subscriber -> reduces latency
      dynacast: true,
      // Adaptive stream: SDK adjusts video resolution based on rendered widget size
      adaptiveStream: true,
      // Audio: presetSpeech = 24 kbps, ideal for voice/medical consultation
      defaultAudioPublishOptions: AudioPublishOptions(
        encoding: AudioEncoding.presetSpeech,
        dtx: true, // Discontinuous Transmission: saves bandwidth during silence
      ),
      // Video: 1.2 Mbps cap + simulcast layers for adaptive quality
      defaultVideoPublishOptions: VideoPublishOptions(
        videoEncoding: VideoEncoding(
          maxFramerate: 30,
          maxBitrate: 1200000, // 1.2 Mbps target for 720p
        ),
        simulcast:
            true, // send multiple layers; receiver subscribes to best layer
      ),
    ),
  );
  EventsListener<RoomEvent>? _listener;

  // Renamed variables to force a fresh state reset on hot reload
  double _chatBoxX = 24;
  double _chatBoxY = 100;
  double _chatBoxW = 320;
  double _chatBoxH = 450;

  // Self Video draggable coordinates
  double? _selfVideoX;
  double? _selfVideoY;
  bool _isDraggingSelfVideo = false;
  bool? _lastIsPip;
  late AnimationController _selfVideoGradientController;

  @override
  void initState() {
    super.initState();
    _selfVideoGradientController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    // Rebuild UI when connection state or participants change
    _room.addListener(_onRoomChanged);

    // Pre-populate IP override if the session URL or web host is an IP address
    try {
      final uri = Uri.parse(widget.url);
      final host = uri.host;
      if (host.isNotEmpty &&
          host != 'localhost' &&
          host != '127.0.0.1' &&
          host != '::1') {
        _ipOverrideController.text = host;
      } else {
        final webHost = Uri.base.host;
        if (webHost.isNotEmpty &&
            webHost != 'localhost' &&
            webHost != '127.0.0.1' &&
            webHost != '::1') {
          _ipOverrideController.text = webHost;
        }
      }
    } catch (e) {
      debugPrint("Error parsing initial URL: $e");
    }

    // 2. Listen to data channel messages (real-time chat)
    _listener = _room.createListener();
    _listener!.on<DataReceivedEvent>((event) {
      final decoded = utf8.decode(event.data);
      try {
        final decodedMap = jsonDecode(decoded) as Map<String, dynamic>;

        // 1. Intercept whiteboard topic events first
        if (event.topic == 'whiteboard') {
          _whiteboardStreamController.add(decodedMap);
          if (!isWhiteboardOpen) {
            if (mounted) {
              setState(() {
                isWhiteboardOpen = true;
              });
            }
          }
          return;
        }

        // 2. Intercept room call controls (e.g. Doctor ending the call)
        if (event.topic == 'room_control') {
          final action = decodedMap['action'] as String;
          if (action == 'end_call') {
            _exitRoom(message: 'The doctor has ended this consultation.');
          }
          return;
        }

        // Location sharing
        if (event.topic == 'location') {
          final city = decodedMap['city'] as String?;
          final identity = event.participant?.identity ?? 'Unknown';
          final name = event.participant?.name ?? identity;

          if (mounted && city != null) {
            setState(() {
              _participantLocations[identity] = {
                'name': name,
                'city': city,
                'timestamp': DateTime.now().millisecondsSinceEpoch,
              };
            });
          }
          return;
        }

        // 3. Reassemble chunked file sharing for the whiteboard
        if (event.topic == 'whiteboard_file') {
          final type = decodedMap['type'] as String;
          if (type == 'file_chunk') {
            final fileId = decodedMap['fileId'] as String;
            final fileName = decodedMap['fileName'] as String;
            final index = decodedMap['index'] as int;
            final total = decodedMap['total'] as int;
            final chunkData = decodedMap['data'] as String;

            if (!_incomingFileChunks.containsKey(fileId)) {
              _incomingFileChunks[fileId] = List<String?>.filled(total, null);
            }

            _incomingFileChunks[fileId]![index] = chunkData;

            // Once all pieces arrive, combine and load background
            if (_incomingFileChunks[fileId]!.every((c) => c != null)) {
              final completeBase64 = _incomingFileChunks[fileId]!.join('');
              _incomingFileChunks.remove(fileId);

              _whiteboardStreamController.add({
                'action': 'set_background',
                'fileName': fileName,
                'base64': completeBase64,
              });

              if (!isWhiteboardOpen) {
                if (mounted) {
                  setState(() {
                    isWhiteboardOpen = true;
                  });
                }
              }
            }
          }
          return;
        }

        if (event.topic == 'chat_file') {
          final type = decodedMap['type'] as String;
          if (type == 'file_chunk') {
            final fileId = decodedMap['fileId'] as String;
            final fileName = decodedMap['fileName'] as String;
            final index = decodedMap['index'] as int;
            final total = decodedMap['total'] as int;
            final chunkData = decodedMap['data'] as String;

            if (!_incomingChatFileChunks.containsKey(fileId)) {
              _incomingChatFileChunks[fileId] =
                  List<String?>.filled(total, null);
              _incomingChatFileNames[fileId] = fileName;
            }
            _incomingChatFileChunks[fileId]![index] = chunkData;

            // Once every chunk has arrived, combine, save to disk, and show in chat
            if (_incomingChatFileChunks[fileId]!.every((c) => c != null)) {
              final completeBase64 = _incomingChatFileChunks[fileId]!.join('');
              _incomingChatFileChunks.remove(fileId);
              _incomingChatFileNames.remove(fileId);
              _saveReceivedChatFile(fileName, completeBase64);
            }
          }
          return;
        }

        // 4. Standard chat message processing
        final text = decodedMap['text'] as String;
        final sender = decodedMap['sender'] as String;
        final isMe = sender == _room.localParticipant?.identity;

        if (mounted) {
          setState(() {
            _messages.add(
              ChatMessage(
                text,
                isMe,
                DateFormat('hh:mm a').format(DateTime.now()),
              ),
            );
            if (!isMe) {
              if (!isChatOpen) {
                _unreadMessageCount++;
              } else {
                isChatOpen = true;
              }
            }
          });
        }
      } catch (e) {
        debugPrint("Error parsing data packet: $e");
      }
    });

    _initLocalCamera();
    // Check if MediaPipe background blur is available (web only)
    if (kIsWeb) {
      Future.delayed(const Duration(seconds: 2), () {
        try {
          final available =
              js.context.callMethod('isBgBlurAvailable') as bool? ?? false;
          if (mounted) setState(() => _blurAvailable = available);
        } catch (_) {
          // JS not available (non-web build)
        }
      });
    }

    // Restore the last-used background effect after camera is ready
    _loadSavedBackground();
    if (!widget.isDoctor) {
      _startWaitingTimer();
    }
  }

  void _exitRoom({String? message}) {
    _room.disconnect();
    if (mounted) {
      if (message != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: Colors.indigo.shade800,
            duration: const Duration(seconds: 4),
          ),
        );
      }
      context.go('/');
    }
  }

  Future<void> _loadSavedBackground() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedTheme = prefs.getString('bg_effect_theme') ?? 'none';
      final savedBlur = prefs.getDouble('bg_effect_blur') ?? 15.0;
      final savedCustom = prefs.getString('bg_effect_custom_image');
      if (savedCustom != null) _customBgBase64 = savedCustom;
      if (savedBlur != _blurStrength && mounted)
        setState(() => _blurStrength = savedBlur);
      if (savedTheme != 'none') {
        // Wait for camera to be ready, then apply
        await Future.delayed(const Duration(seconds: 3));
        if (!mounted) return;
        String? url;
        if (savedTheme == 'custom' && _customBgBase64 != null) {
          url = _customBgBase64;
        } else {
          final themeData = _bgThemes.firstWhere(
            (t) => t['id'] == savedTheme,
            orElse: () => {},
          );
          url = themeData['url'];
        }
        _setBgTheme(savedTheme, url);
      }
    } catch (e) {
      debugPrint('Could not load saved background: \$e');
    }
  }

  Future<void> _saveBackground(String themeId, double blurStrength) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('bg_effect_theme', themeId);
      await prefs.setDouble('bg_effect_blur', blurStrength);
      if (_customBgBase64 != null) {
        await prefs.setString('bg_effect_custom_image', _customBgBase64!);
      }
    } catch (e) {
      debugPrint('Could not save background preference: \$e');
    }
  }

  void _onRoomChanged() {
    if (mounted) {
      setState(() {});
      // If the doctor joins, trigger the transitions
      if (!widget.isDoctor &&
          _room.remoteParticipants.isNotEmpty &&
          !_doctorJoinedTriggered) {
        _triggerDoctorJoined();
      }
    }
  }

  void _startWaitingTimer() {
    _waitingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        _secondsWaiting++;

        // Rotate live update messages every 4 seconds
        if (_secondsWaiting % 4 == 0) {
          _liveMessageIndex =
              (_liveMessageIndex + 1) % _liveUpdateMessages.length;
          _liveUpdateMessage = _liveUpdateMessages[_liveMessageIndex];
        }

        // Simulate appointment progress
        // At 15 seconds (representing doctor finishing an appointment):
        if (_secondsWaiting == 15) {
          _completedAppointments = 19;
          _queuePosition = 1;
          _estimatedWaitMinutes = 3;
          _currentTimelineStage = 3; // Doctor Joining
        }

        _isCameraReady = isVideoOn && _localVideoTrack != null;
        _isMicReady = isAudioOn && _localAudioTrack != null;
      });
    });
  }

  void _triggerDoctorJoined() {
    _doctorJoinedTriggered = true;
    _waitingTimer?.cancel();

    setState(() {
      _showCountdown = true;
      _countdownSeconds = 3;
      _currentTimelineStage = 4; // Consultation
    });

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        if (_countdownSeconds > 1) {
          _countdownSeconds--;
        } else {
          _countdownSeconds = 0;
          _showCountdown = false;
          _countdownTimer?.cancel();
        }
      });
    });
  }

  Future<void> _initLocalCamera() async {
    _mediaErrorMessage = null;

    // 1. Request permissions on native platforms
    if (!kIsWeb) {
      try {
        final cameraStatus = await Permission.camera.request();
        final micStatus = await Permission.microphone.request();
        if (cameraStatus.isDenied || micStatus.isDenied) {
          setState(() {
            _mediaErrorMessage = "Camera or Mic permission denied.";
          });
        }
      } catch (e) {
        debugPrint("Permission request failed: $e");
      }
    }

    // 2. Initialize camera track with explicit capture options for lower latency
    if (_mediaErrorMessage == null) {
      try {
        final videoTrack = await LocalVideoTrack.createCameraTrack(
          const CameraCaptureOptions(
            params: VideoParametersPresets.h720_169,
            maxFrameRate: 30,
          ),
        );
        if (!isVideoOn) {
          await videoTrack.mute();
        }
        _localVideoTrack = videoTrack;
      } catch (e) {
        debugPrint("Camera hardware failed/blocked: $e");
        _mediaErrorMessage = "Camera blocked or not found.";
      }
    }

    // 3. Initialize microphone track with echo cancellation and noise suppression
    try {
      final audioTrack = await LocalAudioTrack.create(
        const AudioCaptureOptions(
          echoCancellation: true,
          noiseSuppression: true,
          autoGainControl: true,
        ),
      );
      if (!isAudioOn) {
        await audioTrack.mute();
      }
      _localAudioTrack = audioTrack;
    } catch (e) {
      debugPrint("Microphone hardware failed/blocked: $e");
      _mediaErrorMessage = (_mediaErrorMessage == null)
          ? "Microphone blocked or not found."
          : "Devices blocked or not found.";
    }

    if (mounted) {
      setState(() {});
    }

    // 4. ALWAYS attempt to connect to LiveKit server, even if media hardware failed!
    if (widget.url.isNotEmpty && widget.token.isNotEmpty) {
      await _connectToLiveKit(widget.url, widget.token);
    }
  }

  @override
  void dispose() {
    _selfVideoGradientController.dispose();
    _waitingTimer?.cancel();
    _countdownTimer?.cancel();
    _listener?.dispose();
    _whiteboardStreamController.close();
    _localVideoTrack?.dispose();
    _localAudioTrack?.dispose();
    _room.dispose();
    _chatController.dispose();
    _ipOverrideController.dispose();
    _cleanupChatFiles();
    super.dispose();
  }

  void _sendMessage() {
    final text = _chatController.text.trim();
    if (text.isEmpty) return;

    // Publish data channel message to all remote participants
    final payload = jsonEncode({
      'text': text,
      'sender': _room.localParticipant?.identity ?? 'User',
    });

    _room.localParticipant?.publishData(
      utf8.encode(payload),
      reliable: true,
    );

    setState(() {
      _messages.add(ChatMessage(
          text, true, DateFormat('hh:mm a').format(DateTime.now())));
      _chatController.clear();
    });
  }

  // Returns (creating it if needed) the local folder used to store files
  // received during THIS call. Scoped by room name so different calls don't mix.
  Future<Directory> _getChatFilesDir() async {
    if (_chatFilesDir != null) return _chatFilesDir!;
    final tempDir = await getTemporaryDirectory();
    final safeRoomName =
        widget.roomName.isNotEmpty ? widget.roomName : 'default';
    final dir =
        Directory('${tempDir.path}/consultation_chat_files/$safeRoomName');
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    _chatFilesDir = dir;
    return dir;
  }

  // Decodes a fully-reassembled base64 file, writes it to local storage,
  // then adds a file message bubble.
  // NOTE: The SENDER already uploaded this file to Supabase in _pickFile().
  //       The receiver must NOT upload again — doing so would create duplicates.
  Future<void> _saveReceivedChatFile(String fileName, String base64Data) async {
    try {
      final bytes = base64Decode(base64Data);
      final receivedAt = DateTime.now();

      String? savedFilePath;
      String? memoryKey;

      if (kIsWeb) {
        memoryKey = '${receivedAt.millisecondsSinceEpoch}_$fileName';
        _inMemoryChatFiles[memoryKey] = bytes;
      } else {
        final dir = await _getChatFilesDir();
        final safeFileName = '${receivedAt.millisecondsSinceEpoch}_$fileName';
        final file = File('${dir.path}/$safeFileName');
        await file.writeAsBytes(bytes);
        savedFilePath = file.path;
      }

      if (mounted) {
        setState(() {
          _messages.add(
            ChatMessage(
              fileName,
              false,
              DateFormat('hh:mm a').format(DateTime.now()),
              isFile: true,
              fileName: fileName,
              filePath: savedFilePath,
              memoryKey: memoryKey,
              receivedAt: receivedAt,
            ),
          );
          if (!isChatOpen) {
            _unreadMessageCount++;
          }
        });
      }
    } catch (e) {
      debugPrint("Error saving received chat file: $e");
    }
  }

  // Opens a received file using the device's native application.
  // On web the bytes are pushed to the browser as a download.
  Future<void> _openReceivedFile(ChatMessage msg) async {
    if (kIsWeb) {
      // Web: open the file in a new browser tab using a Blob URL.
      // Only browser-renderable types (PDF, images, audio, video, text) are
      // opened. Non-renderable types (DOCX, XLSX, ZIP, …) return '' to
      // prevent a download dialog from appearing.
      final key = msg.memoryKey;
      if (key == null) return;
      final bytes = _inMemoryChatFiles[key];
      if (bytes == null) return;
      final name = msg.fileName ?? msg.text;
      final blobUrl = openFileInBrowser(name, bytes);
      if (blobUrl.isNotEmpty) {
        _webBlobUrls.add(blobUrl);
      } else if (mounted) {
        // File type cannot be rendered in the browser — do NOT download.
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Cannot preview "$name" in the browser. '
              'This file type is not supported for in-browser viewing.',
            ),
            backgroundColor: Colors.orange.shade800,
            duration: const Duration(seconds: 4),
          ),
        );
      }
      return;
    }

    final path = msg.filePath;
    if (path == null || path.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('File path not available.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
      return;
    }

    final result = await OpenFilex.open(path);
    if (result.type != ResultType.done && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not open file: ${result.message}'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  // Clears local chat file storage when the call ends.
  // MinIO uploads already happened at the moment each file was sent/received.
  Future<void> _cleanupChatFiles() async {
    if (kIsWeb) {
      for (final url in _webBlobUrls) {
        revokeBlobUrl(url);
      }
      _webBlobUrls.clear();
      _inMemoryChatFiles.clear();
      return;
    }
    try {
      if (_chatFilesDir != null && await _chatFilesDir!.exists()) {
        await _chatFilesDir!.delete(recursive: true);
        debugPrint('Chat files cleaned up for room: ${widget.roomName}');
      }
    } catch (e) {
      debugPrint('Error cleaning up chat files: $e');
    }
    _chatFilesDir = null;
  }

  Future<void> _pickFile() async {
    // withData: true ensures we get the raw bytes back (needed on web too)
    FilePickerResult? result =
        await FilePicker.platform.pickFiles(withData: true);
    if (result == null) return;

    final pickedFile = result.files.single;
    Uint8List? bytes = pickedFile.bytes;

    if (bytes == null && pickedFile.path != null) {
      try {
        final file = File(pickedFile.path!);
        bytes = await file.readAsBytes();
      } catch (e) {
        debugPrint("Error reading picked file from path: $e");
      }
    }

    if (bytes == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not read the selected file.'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
      return;
    }

    final fileName = pickedFile.name;
    final fileId = '${DateTime.now().millisecondsSinceEpoch}_$fileName';
    final base64Data = base64Encode(bytes);

    // Upload to Supabase Storage immediately (fire-and-forget).
    // Only the SENDER uploads — the receiver skips upload to avoid duplicates.
    final sentAt = DateTime.now();
    debugPrint('Supabase: triggering upload for sent file "$fileName"');
    unawaited(SupabaseStorageService.uploadFile(
      fileName: fileName,
      bytes: bytes,
      receivedAt: sentAt,
      callEndedAt: sentAt,
    ));

    // Data channel messages have a size limit, so we split the base64 string
    // into smaller chunks and send them one by one (same pattern already
    // used for whiteboard background images).
    const chunkSize = 12000; // characters per chunk
    final totalChunks = (base64Data.length / chunkSize).ceil();

    bool sendFailed = false;

    for (int i = 0; i < totalChunks; i++) {
      final start = i * chunkSize;
      final end = (start + chunkSize < base64Data.length)
          ? start + chunkSize
          : base64Data.length;
      final chunk = base64Data.substring(start, end);

      final payload = jsonEncode({
        'type': 'file_chunk',
        'fileId': fileId,
        'fileName': fileName,
        'index': i,
        'total': totalChunks,
        'data': chunk,
      });

      // _room.localParticipant?.publishData(
      //   utf8.encode(payload),
      //   reliable: true,
      //   topic: 'chat_file',
      // );
      try {
        // IMPORTANT: await each send and wait a beat before the next one.
        // Firing all chunks back-to-back without waiting can overflow the
        // WebRTC data channel's send buffer, silently dropping chunks - which
        // means the file can never be reassembled on the other end.
        await _room.localParticipant?.publishData(
          utf8.encode(payload),
          reliable: true,
          topic: 'chat_file',
        );
        await Future.delayed(const Duration(milliseconds: 20));
      } catch (e) {
        debugPrint("Error sending file chunk $i/$totalChunks: $e");
        sendFailed = true;
        break;
      }
    }

    // Show the file we just sent in our own chat list
    if (mounted) {
      setState(() {
        _messages.add(
          ChatMessage(
            fileName,
            true,
            DateFormat('hh:mm a').format(DateTime.now()),
            isFile: true,
            fileName: fileName,
          ),
        );
      });
    }
  }

  Future<void> _shareMyLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    try {
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;

      permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return;
      }
      if (permission == LocationPermission.deniedForever) return;

      Position position = await Geolocator.getCurrentPosition();

      String locationStr =
          "${position.latitude.toStringAsFixed(2)}, ${position.longitude.toStringAsFixed(2)}";

      final data = jsonEncode({'city': locationStr});

      await _room.localParticipant?.publishData(
        utf8.encode(data),
        topic: 'location',
      );

      final identity = _room.localParticipant?.identity ?? 'Me';
      final name = _room.localParticipant?.name ?? 'Me';

      if (mounted) {
        setState(() {
          _participantLocations[identity] = {
            'name': name,
            'city': locationStr,
            'timestamp': DateTime.now().millisecondsSinceEpoch,
          };
        });
      }
    } catch (e) {
      debugPrint("Error sharing location: $e");
    }
  }

  bool _isTogglingVideo = false;
  bool _isTogglingAudio = false;

  void _setBgTheme(String themeId, String? url) {
    if (!kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
              'Background effects are not supported on this device.'),
          backgroundColor: Colors.orange.shade800,
        ),
      );
      return;
    }

    setState(() {
      _currentBgTheme = themeId;
      isBlurActive = themeId != 'none';
      _bgIsLoading = themeId != 'none';
    });

    // Save preference
    _saveBackground(themeId, _blurStrength);

    try {
      if (themeId == 'none') {
        js.context.callMethod('stopBgBlur');
        setState(() => _bgIsLoading = false);
      } else if (themeId == 'blur') {
        final amt = _blurStrength.toInt();
        js.context.callMethod('startBgBlur', [amt]);
        js.context.callMethod('setBgTheme', ['blur', amt]);
        Future.delayed(const Duration(milliseconds: 900), () {
          if (mounted) setState(() => _bgIsLoading = false);
        });
      } else if (themeId == 'custom') {
        if (_customBgBase64 != null) {
          js.context.callMethod('startBgBlur', [_blurStrength.toInt()]);
          js.context.callMethod('setBgTheme', ['image', _customBgBase64]);
          Future.delayed(const Duration(milliseconds: 900), () {
            if (mounted) setState(() => _bgIsLoading = false);
          });
        } else {
          setState(() {
            _currentBgTheme = 'none';
            isBlurActive = false;
            _bgIsLoading = false;
          });
          js.context.callMethod('stopBgBlur');
        }
      } else {
        js.context.callMethod('startBgBlur', [_blurStrength.toInt()]);
        js.context.callMethod('setBgTheme', ['image', url]);
        Future.delayed(const Duration(milliseconds: 900), () {
          if (mounted) setState(() => _bgIsLoading = false);
        });
      }
    } catch (e) {
      debugPrint('BgBlur JS error: $e');
      setState(() => _bgIsLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Failed to apply background effect.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  void _showBackgroundMenu(BuildContext context) {
    // Check support first
    if (!kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
              'Background effects are not supported on this device.'),
          backgroundColor: Colors.orange.shade800,
        ),
      );
      return;
    }

    // Initialise preview to the currently-active theme
    _previewBgTheme = _currentBgTheme;
    _previewBgUrl = null;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (sheetCtx) {
        return StatefulBuilder(
          builder: (stCtx, setModalState) {
            // ── helpers ──────────────────────────────────────────────────────
            String _pTheme = _previewBgTheme;
            String? _pUrl = _previewBgUrl;

            void _onPreviewSelect(String themeId, String? url) {
              setModalState(() {
                _pTheme = themeId;
                _pUrl = url;
                _previewBgTheme = themeId;
                _previewBgUrl = url;
              });
              // Live preview locally; don't push to WebRTC yet
              if (kIsWeb) {
                try {
                  if (themeId == 'none') {
                    js.context.callMethod('stopBgBlur');
                  } else if (themeId == 'blur') {
                    js.context
                        .callMethod('startBgBlur', [_blurStrength.toInt()]);
                    js.context.callMethod(
                        'setBgTheme', ['blur', _blurStrength.toInt()]);
                    js.context.callMethod('setBgPreviewMode', [true]);
                  } else {
                    final imgUrl = themeId == 'custom' ? _customBgBase64 : url;
                    if (imgUrl != null) {
                      js.context
                          .callMethod('startBgBlur', [_blurStrength.toInt()]);
                      js.context.callMethod('setBgTheme', ['image', imgUrl]);
                      js.context.callMethod('setBgPreviewMode', [true]);
                    }
                  }
                } catch (_) {}
              }
            }

            // ── UI ────────────────────────────────────────────────────────
            return DraggableScrollableSheet(
              initialChildSize: 0.75,
              minChildSize: 0.5,
              maxChildSize: 0.95,
              expand: false,
              builder: (_, scrollCtrl) => Container(
                decoration: const BoxDecoration(
                  color: Color(0xFF0F172A),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: Column(
                  children: [
                    // ── Drag Handle ─────────────────────────────────────────
                    Container(
                      width: 44,
                      height: 5,
                      margin: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),

                    // ── Header Row ──────────────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(children: [
                            const Icon(Icons.wallpaper_rounded,
                                color: Color(0xFF6366F1), size: 22),
                            const SizedBox(width: 10),
                            const Text(
                              'Virtual Backgrounds',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ]),
                          // Reset button
                          TextButton.icon(
                            onPressed: () {
                              if (kIsWeb) {
                                try {
                                  js.context.callMethod('stopBgBlur');
                                } catch (_) {}
                              }
                              Navigator.pop(sheetCtx);
                              setState(() {
                                _currentBgTheme = 'none';
                                isBlurActive = false;
                                _bgIsLoading = false;
                              });
                              _saveBackground('none', _blurStrength);
                            },
                            icon: const Icon(Icons.refresh_rounded,
                                size: 16, color: Colors.white54),
                            label: const Text('Reset',
                                style: TextStyle(
                                    color: Colors.white54, fontSize: 13)),
                          ),
                        ],
                      ),
                    ),

                    const Divider(color: Colors.white12, height: 1),

                    // ── Scrollable Content ──────────────────────────────────
                    Expanded(
                      child: ListView(
                        controller: scrollCtrl,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 16),
                        children: [
                          // ── Gallery Grid ──────────────────────────────────
                          GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                              childAspectRatio: 1.4,
                            ),
                            itemCount: _bgThemes.length,
                            itemBuilder: (ctx, idx) {
                              final theme = _bgThemes[idx];
                              final tid = theme['id']!;
                              final isPreviewing = _pTheme == tid;
                              final isApplied = _currentBgTheme == tid;

                              return AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                curve: Curves.easeOut,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: isPreviewing
                                        ? const Color(0xFF6366F1)
                                        : isApplied
                                            ? const Color(0xFF22D3EE)
                                            : Colors.white10,
                                    width: isPreviewing || isApplied ? 2.5 : 1,
                                  ),
                                  boxShadow: isPreviewing
                                      ? [
                                          BoxShadow(
                                            color: const Color(0xFF6366F1)
                                                .withValues(alpha: 0.4),
                                            blurRadius: 10,
                                            spreadRadius: 1,
                                          )
                                        ]
                                      : [],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: GestureDetector(
                                    onTap: () async {
                                      if (tid == 'custom') {
                                        FilePickerResult? result =
                                            await FilePicker.platform.pickFiles(
                                          type: FileType.image,
                                          withData: true,
                                        );
                                        if (result != null &&
                                            result.files.single.bytes != null) {
                                          final b64 = base64Encode(
                                              result.files.single.bytes!);
                                          final ext = result
                                                  .files.single.extension
                                                  ?.toLowerCase() ??
                                              'png';
                                          final mime =
                                              (ext == 'jpg' || ext == 'jpeg')
                                                  ? 'image/jpeg'
                                                  : 'image/png';
                                          setState(() => _customBgBase64 =
                                              'data:$mime;base64,$b64');
                                          _onPreviewSelect(
                                              'custom', _customBgBase64);
                                        }
                                      } else {
                                        _onPreviewSelect(tid, theme['url']);
                                      }
                                    },
                                    child: Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        // Thumbnail
                                        if (tid == 'none')
                                          Container(
                                            color: const Color(0xFF1E293B),
                                            child: const Icon(
                                                Icons.block_rounded,
                                                color: Colors.white38,
                                                size: 28),
                                          )
                                        else if (tid == 'blur')
                                          Container(
                                            color: const Color(0xFF1E293B),
                                            child: const Icon(
                                                Icons.blur_on_rounded,
                                                color: Color(0xFF6366F1),
                                                size: 30),
                                          )
                                        else if (tid == 'custom')
                                          Container(
                                            color: const Color(0xFF1E293B),
                                            child: _customBgBase64 != null
                                                ? Image.memory(
                                                    base64Decode(
                                                        _customBgBase64!
                                                            .split(',')[1]),
                                                    fit: BoxFit.cover,
                                                  )
                                                : const Icon(
                                                    Icons
                                                        .add_photo_alternate_rounded,
                                                    color: Colors.white38,
                                                    size: 30),
                                          )
                                        else
                                          Image.memory(
                                            base64Decode(
                                                theme['url']!.split(',')[1]),
                                            fit: BoxFit.cover,
                                          ),

                                        // Dark overlay for non-selected
                                        if (!isPreviewing)
                                          Container(
                                              color: Colors.black
                                                  .withValues(alpha: 0.25)),

                                        // "Active" badge
                                        if (isApplied)
                                          Positioned(
                                            top: 6,
                                            right: 6,
                                            child: Container(
                                              padding: const EdgeInsets.all(3),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF22D3EE),
                                                borderRadius:
                                                    BorderRadius.circular(99),
                                              ),
                                              child: const Icon(
                                                  Icons.check_rounded,
                                                  color: Colors.white,
                                                  size: 10),
                                            ),
                                          ),

                                        // Label at bottom
                                        Positioned(
                                          left: 0,
                                          right: 0,
                                          bottom: 0,
                                          child: Container(
                                            padding: const EdgeInsets.symmetric(
                                                vertical: 5),
                                            decoration: const BoxDecoration(
                                              gradient: LinearGradient(
                                                begin: Alignment.topCenter,
                                                end: Alignment.bottomCenter,
                                                colors: [
                                                  Colors.transparent,
                                                  Color(0xCC000000),
                                                ],
                                              ),
                                            ),
                                            child: Text(
                                              theme['title']!,
                                              textAlign: TextAlign.center,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 10,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),

                          const SizedBox(height: 20),

                          // ── Blur Strength Slider ──────────────────────────
                          if (_pTheme == 'blur') ...[
                            const Text('Blur Strength',
                                style: TextStyle(
                                    color: Colors.white70,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600)),
                            const SizedBox(height: 8),
                            StatefulBuilder(builder: (_, setSlider) {
                              return Column(
                                children: [
                                  SliderTheme(
                                    data: SliderTheme.of(stCtx).copyWith(
                                      activeTrackColor: const Color(0xFF6366F1),
                                      inactiveTrackColor: Colors.white12,
                                      thumbColor: const Color(0xFF6366F1),
                                      overlayColor: const Color(0xFF6366F1)
                                          .withValues(alpha: 0.25),
                                      trackHeight: 4,
                                    ),
                                    child: Slider(
                                      min: 5,
                                      max: 28,
                                      divisions: 2,
                                      value: _blurStrength,
                                      onChanged: (v) {
                                        setSlider(() => _blurStrength = v);
                                        setState(() => _blurStrength = v);
                                        if (kIsWeb) {
                                          try {
                                            js.context.callMethod('setBgTheme',
                                                ['blur', v.toInt()]);
                                          } catch (_) {}
                                        }
                                      },
                                    ),
                                  ),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: const [
                                      Text('Low',
                                          style: TextStyle(
                                              color: Colors.white38,
                                              fontSize: 11)),
                                      Text('Medium',
                                          style: TextStyle(
                                              color: Colors.white38,
                                              fontSize: 11)),
                                      Text('High',
                                          style: TextStyle(
                                              color: Colors.white38,
                                              fontSize: 11)),
                                    ],
                                  ),
                                ],
                              );
                            }),
                            const SizedBox(height: 8),
                          ],
                        ],
                      ),
                    ),

                    // ── Apply / Cancel footer ───────────────────────────────
                    Container(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                      decoration: const BoxDecoration(
                        border: Border(top: BorderSide(color: Colors.white12)),
                      ),
                      child: Row(children: [
                        // Cancel
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () {
                              // Revert preview – restore the actually-active bg
                              if (kIsWeb) {
                                try {
                                  js.context
                                      .callMethod('setBgPreviewMode', [false]);
                                  if (_currentBgTheme == 'none') {
                                    js.context.callMethod('stopBgBlur');
                                  }
                                } catch (_) {}
                              }
                              Navigator.pop(sheetCtx);
                            },
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: Colors.white24),
                              foregroundColor: Colors.white70,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('Cancel'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Apply
                        Expanded(
                          flex: 2,
                          child: ElevatedButton(
                            onPressed: () {
                              // Commit preview to actual state
                              if (kIsWeb) {
                                try {
                                  js.context
                                      .callMethod('setBgPreviewMode', [false]);
                                } catch (_) {}
                              }
                              Navigator.pop(sheetCtx);
                              final applyUrl =
                                  _pTheme == 'custom' ? _customBgBase64 : _pUrl;
                              _setBgTheme(_pTheme, applyUrl);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF6366F1),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('Apply',
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 15)),
                          ),
                        ),
                      ]),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _toggleVideo() async {
    if (_isTogglingVideo) return; // prevent double-tap race
    _isTogglingVideo = true;
    final nextState = !isVideoOn;
    // Update UI immediately for instant button response
    setState(() {
      isVideoOn = nextState;
    });

    try {
      if (_room.connectionState == lk.ConnectionState.connected) {
        // When connected, use LiveKit API to enable/disable camera
        await _room.localParticipant?.setCameraEnabled(nextState);
        // Sync local track reference
        if (nextState) {
          final pub = _room.localParticipant?.videoTrackPublications
              .where((p) => p.source == TrackSource.camera)
              .firstOrNull;
          if (pub?.track is LocalVideoTrack) {
            _localVideoTrack = pub!.track as LocalVideoTrack;
          }
        } else {
          _localVideoTrack = null;
        }
      } else {
        // Not connected — dispose old track and recreate (web-safe approach)
        if (nextState) {
          // Turn ON: create a fresh camera track
          final oldTrack = _localVideoTrack;
          _localVideoTrack = null;
          if (mounted) setState(() {});
          await oldTrack?.dispose();
          final newTrack = await LocalVideoTrack.createCameraTrack();
          if (mounted) {
            setState(() {
              _localVideoTrack = newTrack;
            });
          } else {
            await newTrack.dispose();
          }
        } else {
          // Turn OFF: dispose track and clear reference
          final oldTrack = _localVideoTrack;
          setState(() {
            _localVideoTrack = null;
          });
          await oldTrack?.dispose();
        }
      }
    } catch (e) {
      debugPrint("Error toggling video: $e");
      // Revert UI state on failure
      if (mounted)
        setState(() {
          isVideoOn = !nextState;
        });
    } finally {
      _isTogglingVideo = false;
    }
  }

  Future<void> _toggleAudio() async {
    if (_isTogglingAudio) return; // prevent double-tap race
    _isTogglingAudio = true;
    final nextState = !isAudioOn;
    // Update UI immediately for instant button response
    setState(() {
      isAudioOn = nextState;
    });

    try {
      if (_room.connectionState == lk.ConnectionState.connected) {
        // When connected, use LiveKit API
        await _room.localParticipant?.setMicrophoneEnabled(nextState);
      } else {
        // Not connected — dispose and recreate (web-safe approach)
        if (nextState) {
          // Turn ON: create fresh mic track
          final oldTrack = _localAudioTrack;
          _localAudioTrack = null;
          await oldTrack?.dispose();
          final newTrack = await LocalAudioTrack.create();
          if (mounted) {
            setState(() {
              _localAudioTrack = newTrack;
            });
          } else {
            await newTrack.dispose();
          }
        } else {
          // Turn OFF: dispose and clear
          final oldTrack = _localAudioTrack;
          setState(() {
            _localAudioTrack = null;
          });
          await oldTrack?.dispose();
        }
      }
    } catch (e) {
      debugPrint("Error toggling audio: $e");
      if (mounted)
        setState(() {
          isAudioOn = !nextState;
        });
    } finally {
      _isTogglingAudio = false;
    }
  }

  // Connect to the self-hosted LiveKit server
  Future<void> _connectToLiveKit(String url, String token) async {
    try {
      await _room.connect(
        url,
        token,
        connectOptions: const ConnectOptions(
          // Subscribe to all tracks as soon as they are published (no manual subscribe needed)
          autoSubscribe: true,
          // Faster initial ICE gathering (less candidates to try = quicker connection)
          rtcConfiguration: RTCConfiguration(
            iceTransportPolicy: RTCIceTransportPolicy.all,
          ),
        ),
      );
      if (_localVideoTrack != null)
        await _room.localParticipant?.publishVideoTrack(_localVideoTrack!);
      if (_localAudioTrack != null)
        await _room.localParticipant?.publishAudioTrack(_localAudioTrack!);

      // Automatically request and share location after connecting
      _shareMyLocation();
    } catch (e) {
      debugPrint("LiveKit Connect Error: $e");
    }
  }

  String _generateInviteLink() {
    final baseUri = Uri.base;
    String origin;
    if (widget.publicUrl.isNotEmpty) {
      origin = widget.publicUrl;
      if (origin.endsWith('/')) {
        origin = origin.substring(0, origin.length - 1);
      }
    } else {
      origin =
          '${baseUri.scheme}://${baseUri.host}${baseUri.hasPort ? ":${baseUri.port}" : ""}';
    }

    var overrideIp = _ipOverrideController.text.trim();
    if (overrideIp.isNotEmpty) {
      // Clean up input if the user enters a full URL instead of just the IP
      if (overrideIp.startsWith('http://'))
        overrideIp = overrideIp.substring(7);
      if (overrideIp.startsWith('https://'))
        overrideIp = overrideIp.substring(8);
      if (overrideIp.startsWith('ws://')) overrideIp = overrideIp.substring(5);
      if (overrideIp.startsWith('wss://')) overrideIp = overrideIp.substring(6);

      final portIndex = overrideIp.indexOf(':');
      if (portIndex != -1) {
        overrideIp = overrideIp.substring(0, portIndex);
      }
      final pathIndex = overrideIp.indexOf('/');
      if (pathIndex != -1) {
        overrideIp = overrideIp.substring(0, pathIndex);
      }

      origin = origin
          .replaceAll('localhost', overrideIp)
          .replaceAll('127.0.0.1', overrideIp);
    }

    String serverUrl = widget.url;
    if (overrideIp.isNotEmpty) {
      serverUrl = serverUrl
          .replaceAll('localhost', overrideIp)
          .replaceAll('127.0.0.1', overrideIp);
    }

    final Map<String, String> queryParams = {
      if (widget.roomName.isNotEmpty) 'room': widget.roomName,
      if (serverUrl.isNotEmpty) 'url': serverUrl,
      if (widget.apiKey.isNotEmpty) 'key': widget.apiKey,
      if (widget.apiSecret.isNotEmpty) 'secret': widget.apiSecret,
    };

    final queryString = Uri(queryParameters: queryParams).query;
    return '$origin/#/?$queryString';
  }

  void _showInviteDialog() {
    bool copied = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final inviteUrl = _generateInviteLink();
            final isLocalhost = widget.url.contains('localhost') ||
                widget.url.contains('127.0.0.1') ||
                Uri.base.host == 'localhost' ||
                Uri.base.host == '127.0.0.1';

            return Dialog(
              backgroundColor: Colors.transparent,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 480),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black54,
                      blurRadius: 40,
                      offset: Offset(0, 10),
                    )
                  ],
                ),
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.indigoAccent.withOpacity(0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.person_add,
                              color: Colors.indigoAccent, size: 24),
                        ),
                        const SizedBox(width: 16),
                        const Text(
                          'Invite Participants',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Anyone with this link can join this secure session and participate in the audio/video call.',
                      style: TextStyle(
                          color: Colors.white54, fontSize: 13, height: 1.4),
                    ),
                    if (isLocalhost) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orangeAccent.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                              color: Colors.orangeAccent.withOpacity(0.3)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.warning_amber_rounded,
                                color: Colors.orangeAccent, size: 20),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Warning: Meeting is running on localhost. Other devices on your Wi-Fi will need your computer\'s IP address to connect.',
                                style: TextStyle(
                                    color: Colors.orangeAccent,
                                    fontSize: 11,
                                    height: 1.3),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'HOST COMPUTER IP OVERRIDE',
                        style: TextStyle(
                          color: Colors.white60,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _ipOverrideController,
                        onChanged: (_) {
                          setDialogState(() {});
                        },
                        style:
                            const TextStyle(color: Colors.white, fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'Enter PC local IP (e.g., 192.168.1.50)',
                          hintStyle: const TextStyle(color: Colors.white30),
                          filled: true,
                          fillColor: const Color(0xFF0F172A),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.clear,
                                color: Colors.white30, size: 16),
                            onPressed: () {
                              _ipOverrideController.clear();
                              setDialogState(() {});
                            },
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(16),
                        border:
                            Border.all(color: Colors.white.withOpacity(0.05)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'SHAREABLE MEETING LINK',
                                style: TextStyle(
                                  color: Colors.indigoAccent,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              if (widget.roomName.isNotEmpty)
                                Text(
                                  'Room: ${widget.roomName}',
                                  style: const TextStyle(
                                    color: Colors.white38,
                                    fontSize: 11,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          SelectableText(
                            inviteUrl,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.white54,
                          ),
                          child: const Text('Close',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: inviteUrl));
                            setDialogState(() {
                              copied = true;
                            });
                            // Close dialog after copy is clicked
                            Future.delayed(const Duration(milliseconds: 500),
                                () {
                              if (context.mounted) {
                                Navigator.of(context).pop();
                              }
                            });
                          },
                          icon: Icon(
                            copied ? Icons.check : Icons.copy,
                            color: Colors.white,
                            size: 18,
                          ),
                          label: Text(
                            copied ? 'Copied!' : 'Copy Link',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                copied ? Colors.green : Colors.indigoAccent,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 20, vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    )
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildParticipantGrid(List<RemoteParticipant> participants) {
    if (participants.length == 1) {
      return _buildParticipantTile(participants.first);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final count = participants.length;
        int cols = 1;
        int rows = 1;

        if (count == 2) {
          if (constraints.maxWidth > constraints.maxHeight) {
            cols = 2;
            rows = 1;
          } else {
            cols = 1;
            rows = 2;
          }
        } else if (count <= 4) {
          cols = 2;
          rows = 2;
        } else if (count <= 6) {
          cols = 3;
          rows = 2;
        } else {
          cols = 3;
          rows = 3;
        }

        final itemWidth = constraints.maxWidth / cols;
        final itemHeight = constraints.maxHeight / rows;

        return GridView.builder(
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: cols,
            childAspectRatio: itemWidth / itemHeight,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: count,
          itemBuilder: (context, index) {
            final participant = participants[index];
            return _buildParticipantTile(participant);
          },
        );
      },
    );
  }

  Widget _buildParticipantTile(RemoteParticipant participant) {
    // Filter specifically for the camera track (not screen-share), and only
    // use it when it has been subscribed and is not muted.
    final videoPublication = participant.videoTrackPublications
        .where((p) => p.source == TrackSource.camera)
        .firstOrNull;
    // A track is only renderable when it is subscribed AND not null
    final videoTrack = (videoPublication?.subscribed ?? false)
        ? videoPublication?.track as VideoTrack?
        : null;
    final isVideoMuted = videoPublication?.muted ?? true;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (videoTrack != null && !isVideoMuted)
            VideoTrackRenderer(videoTrack, fit: VideoViewFit.cover)
          else
            _buildParticipantPlaceholder(participant.identity),
          Positioned(
            bottom: 12,
            left: 12,
            right: 12,
            child: Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.65),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: participant.isSpeaking
                              ? Colors.greenAccent
                              : Colors.white30,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              participant.identity,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            if (_participantLocations
                                .containsKey(participant.identity))
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.location_on,
                                      color: Colors.redAccent, size: 10),
                                  const SizedBox(width: 2),
                                  Text(
                                    _participantLocations[
                                        participant.identity]!['city'],
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 9,
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                _buildAudioIndicator(participant),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParticipantPlaceholder(String identity) {
    String initials = '';
    final parts = identity.split(' ');
    if (parts.isNotEmpty) {
      initials += parts[0].isNotEmpty ? parts[0][0] : '';
      if (parts.length > 1 && parts[1].isNotEmpty) {
        initials += parts[1][0];
      }
    }
    if (initials.isEmpty) initials = '?';
    initials = initials.toUpperCase();

    final colors = [
      Colors.indigo,
      Colors.blueGrey,
      Colors.teal,
      Colors.pink,
      Colors.purple,
      Colors.blue,
    ];
    final color = colors[identity.hashCode % colors.length];

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF1E293B),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: color,
              child: Text(
                initials,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1,
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Icon(Icons.videocam_off, color: Colors.white24, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildAudioIndicator(RemoteParticipant participant) {
    final audioPublication = participant.audioTrackPublications.isNotEmpty
        ? participant.audioTrackPublications.first
        : null;
    final isAudioMuted = audioPublication?.muted ?? true;

    return Container(
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: isAudioMuted
            ? const Color(0xFFEF4444).withOpacity(0.9)
            : Colors.black.withOpacity(0.65),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white10),
      ),
      child: Icon(
        isAudioMuted ? Icons.mic_off : Icons.mic,
        color: Colors.white,
        size: 14,
      ),
    );
  }

  Widget _buildWaitingOrDisconnectedScreen(String message) {
    if (!widget.isDoctor) {
      return _buildSmartWaitingRoom();
    }
    bool isConnected = _room.connectionState == lk.ConnectionState.connected;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Loading/Connection Status
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isConnected
                      ? Colors.greenAccent.withOpacity(0.1)
                      : Colors.orangeAccent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: isConnected
                          ? Colors.greenAccent.withOpacity(0.3)
                          : Colors.orangeAccent.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!isConnected)
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.orangeAccent),
                      )
                    else
                      Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.greenAccent,
                          shape: BoxShape.circle,
                        ),
                      ),
                    const SizedBox(width: 8),
                    Text(
                      message,
                      style: TextStyle(
                        color: isConnected
                            ? Colors.greenAccent
                            : Colors.orangeAccent,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              if (widget.isDoctor && _showInlineInviteCard) ...[
                Builder(builder: (context) {
                  final inviteUrl = _generateInviteLink();
                  final isLocalhost = widget.url.contains('localhost') ||
                      widget.url.contains('127.0.0.1') ||
                      Uri.base.host == 'localhost' ||
                      Uri.base.host == '127.0.0.1';

                  return Container(
                    constraints: const BoxConstraints(maxWidth: 460),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white.withOpacity(0.08)),
                      boxShadow: const [
                        BoxShadow(
                          color: Colors.black38,
                          blurRadius: 20,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.share,
                                color: Colors.indigoAccent, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Share Meeting Invitation',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          'Send this link to anyone you want to join. They will be able to join directly with their name.',
                          style: TextStyle(
                              color: Colors.white54, fontSize: 12, height: 1.4),
                        ),
                        if (isLocalhost) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.orangeAccent.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: Colors.orangeAccent.withOpacity(0.3)),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.warning_amber_rounded,
                                    color: Colors.orangeAccent, size: 20),
                                SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    'Warning: Meeting is running on localhost. Other devices on your Wi-Fi will need your computer\'s IP address to connect.',
                                    style: TextStyle(
                                        color: Colors.orangeAccent,
                                        fontSize: 11,
                                        height: 1.3),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'HOST COMPUTER IP OVERRIDE',
                            style: TextStyle(
                              color: Colors.white60,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(height: 6),
                          TextField(
                            controller: _ipOverrideController,
                            onChanged: (_) {
                              setState(() {});
                            },
                            style: const TextStyle(
                                color: Colors.white, fontSize: 13),
                            decoration: InputDecoration(
                              hintText:
                                  'Enter PC local IP (e.g., 192.168.1.50)',
                              hintStyle: const TextStyle(color: Colors.white30),
                              filled: true,
                              fillColor: const Color(0xFF0F172A),
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide: BorderSide.none,
                              ),
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.clear,
                                    color: Colors.white30, size: 16),
                                onPressed: () {
                                  _ipOverrideController.clear();
                                  setState(() {});
                                },
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: 20),

                        // Link display field
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: Colors.white.withOpacity(0.05)),
                          ),
                          child: SelectableText(
                            inviteUrl,
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                              fontFamily: 'monospace',
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Copy Button
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            gradient: const LinearGradient(
                              colors: [Colors.indigoAccent, Color(0xFF4F46E5)],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.indigoAccent.withOpacity(0.2),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: inviteUrl));
                              setState(() {
                                _inviteLinkCopied = true;
                              });
                              // Hide the inline invite component after copying
                              Future.delayed(const Duration(milliseconds: 500),
                                  () {
                                if (mounted) {
                                  setState(() {
                                    _showInlineInviteCard = false;
                                  });
                                }
                              });
                            },
                            icon: Icon(
                              _inviteLinkCopied ? Icons.check : Icons.copy,
                              color: Colors.white,
                              size: 16,
                            ),
                            label: Text(
                              _inviteLinkCopied
                                  ? 'Copied Link!'
                                  : 'Copy Invitation Link',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _inviteLinkCopied
                                  ? Colors.green
                                  : Colors.transparent,
                              shadowColor: Colors.transparent,
                              minimumSize: const Size.fromHeight(46),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ] else if (widget.isDoctor) ...[
                // Minimalist waiting state once the link is copied
                const SizedBox(height: 20),
                const CircularProgressIndicator(color: Colors.indigoAccent),
                const SizedBox(height: 16),
                const Text(
                  'Invitation link copied to clipboard!',
                  style: TextStyle(
                      color: Colors.greenAccent,
                      fontWeight: FontWeight.bold,
                      fontSize: 14),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Waiting for other participants to join the call...',
                  style: TextStyle(color: Colors.white54, fontSize: 13),
                ),
                const SizedBox(height: 24),
                TextButton.icon(
                  icon: const Icon(Icons.share,
                      size: 16, color: Colors.indigoAccent),
                  label: const Text('Show Invite Link Again',
                      style: TextStyle(
                          color: Colors.indigoAccent,
                          fontWeight: FontWeight.bold)),
                  onPressed: () {
                    setState(() {
                      _inviteLinkCopied = false;
                      _showInlineInviteCard = true;
                    });
                  },
                ),
              ] else ...[
                // Patient waiting screen
                const SizedBox(height: 20),
                const CircularProgressIndicator(color: Colors.indigoAccent),
                const SizedBox(height: 16),
                const Text(
                  'Waiting for the doctor to join...',
                  style: TextStyle(color: Colors.white54, fontSize: 13),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final screenWidth = constraints.maxWidth;
        final screenHeight = constraints.maxHeight;
        final isMobile = screenWidth < 600;

        final double rightMargin = widget.isPip ? 8 : (isMobile ? 12 : 24);
        final double topMargin = widget.isPip ? 8 : (isMobile ? 12 : 24);
        final double selfWidth = widget.isPip ? 100 : (isMobile ? 120 : 220);
        final double selfHeight = widget.isPip ? 56 : (isMobile ? 68 : 124);

        if (_lastIsPip != widget.isPip) {
          _lastIsPip = widget.isPip;
          _selfVideoX = null;
          _selfVideoY = null;
        }

        if (_selfVideoX == null || _selfVideoY == null) {
          _selfVideoX = screenWidth - selfWidth - rightMargin;
          _selfVideoY = topMargin;
        } else {
          _selfVideoX =
              _selfVideoX!.clamp(0.0, max(0.0, screenWidth - selfWidth));
          _selfVideoY =
              _selfVideoY!.clamp(0.0, max(0.0, screenHeight - selfHeight));
        }

        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF161E2E), // Darker slate
          ),
          child: Stack(
            children: [
              // Remote Participants (REAL TIME WEBRTC GRID)
              Positioned.fill(
                child: Padding(
                  padding: EdgeInsets.only(
                    top: widget.isPip ? 12 : (isMobile ? 12 : 24),
                    left: widget.isPip ? 12 : (isMobile ? 12 : 24),
                    right: widget.isPip ? 12 : (isMobile ? 12 : 24),
                    bottom: widget.isPip ? 60 : (isMobile ? 80 : 100),
                  ),
                  child: Builder(builder: (context) {
                    final remoteParticipants =
                        _room.remoteParticipants.values.toList();
                    if (remoteParticipants.isNotEmpty) {
                      return _buildParticipantGrid(remoteParticipants);
                    }

                    // If no one is connected, show waiting screen with share link
                    return _buildWaitingOrDisconnectedScreen(
                      _room.connectionState == lk.ConnectionState.connected
                          ? 'Waiting for others to join the room...'
                          : 'Not connected to LiveKit Server',
                    );
                  }),
                ).animate().fadeIn(duration: 800.ms),
              ),

              // Local Participant PiP (Top Right)
              AnimatedPositioned(
                duration: _isDraggingSelfVideo
                    ? Duration.zero
                    : const Duration(milliseconds: 300),
                curve: Curves.easeOutBack,
                left: _selfVideoX,
                top: _selfVideoY,
                width: selfWidth,
                height: selfHeight,
                child: GestureDetector(
                  onPanStart: (details) {
                    setState(() {
                      _isDraggingSelfVideo = true;
                      _selfVideoGradientController.repeat();
                    });
                  },
                  onPanUpdate: (details) {
                    setState(() {
                      _selfVideoX = (_selfVideoX! + details.delta.dx)
                          .clamp(0.0, screenWidth - selfWidth);
                      _selfVideoY = (_selfVideoY! + details.delta.dy)
                          .clamp(0.0, screenHeight - selfHeight);
                    });
                  },
                  onPanEnd: (details) {
                    setState(() {
                      _isDraggingSelfVideo = false;
                      _selfVideoGradientController.stop();
                    });
                  },
                  onPanCancel: () {
                    setState(() {
                      _isDraggingSelfVideo = false;
                      _selfVideoGradientController.stop();
                    });
                  },
                  child: AnimatedBuilder(
                    animation: _selfVideoGradientController,
                    builder: (context, child) {
                      final double value = _selfVideoGradientController.value;
                      return Container(
                        padding:
                            EdgeInsets.all(_isDraggingSelfVideo ? 2.5 : 1.0),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(13),
                          gradient: LinearGradient(
                            colors: _isDraggingSelfVideo
                                ? [
                                    Colors.pinkAccent,
                                    Colors.indigoAccent,
                                    Colors.cyanAccent,
                                    Colors.pinkAccent,
                                  ]
                                : [
                                    isBlurActive
                                        ? Colors.indigoAccent.withOpacity(0.7)
                                        : Colors.white12,
                                    isBlurActive
                                        ? Colors.indigoAccent.withOpacity(0.7)
                                        : Colors.white12,
                                  ],
                            begin: Alignment(
                                cos(value * 2 * pi), sin(value * 2 * pi)),
                            end: Alignment(
                                -cos(value * 2 * pi), -sin(value * 2 * pi)),
                          ),
                          boxShadow: _isDraggingSelfVideo
                              ? [
                                  BoxShadow(
                                    color: Colors.indigoAccent.withOpacity(0.5),
                                    blurRadius: 16,
                                    spreadRadius: 2,
                                  ),
                                  BoxShadow(
                                    color: Colors.pinkAccent.withOpacity(0.3),
                                    blurRadius: 24,
                                    spreadRadius: 4,
                                  ),
                                ]
                              : (isBlurActive
                                  ? [
                                      BoxShadow(
                                          color: Colors.indigoAccent
                                              .withOpacity(0.3),
                                          blurRadius: 12,
                                          spreadRadius: 1)
                                    ]
                                  : []),
                        ),
                        child: child,
                      );
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            // Video or placeholder
                            (isVideoOn && _localVideoTrack != null)
                                ? VideoTrackRenderer(_localVideoTrack!)
                                : Container(
                                    color: const Color(0xFF1E293B),
                                    child: Center(
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 4.0),
                                        child: Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              _mediaErrorMessage ??
                                                  (isVideoOn
                                                      ? 'No Camera Device Found\n(VM / Permission Blocked)'
                                                      : 'Camera Off'),
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                  color: Colors.white54,
                                                  fontSize: widget.isPip
                                                      ? 8
                                                      : (isMobile ? 9 : 10)),
                                            ),
                                            if (_mediaErrorMessage != null) ...[
                                              const SizedBox(height: 6),
                                              GestureDetector(
                                                onTap: _initLocalCamera,
                                                child: Container(
                                                  padding: const EdgeInsets
                                                      .symmetric(
                                                      horizontal: 8,
                                                      vertical: 4),
                                                  decoration: BoxDecoration(
                                                    color: Colors.indigoAccent,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                            4),
                                                  ),
                                                  child: Text(
                                                    'Retry',
                                                    style: TextStyle(
                                                      fontSize: widget.isPip
                                                          ? 8
                                                          : (isMobile ? 9 : 10),
                                                      color: Colors.white,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),

                            // Blur active indicator badge (MediaPipe JS handles the actual bg blur)
                            if (isBlurActive)
                              Positioned(
                                top: 6,
                                left: 6,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF4F46E5)
                                        .withOpacity(0.9),
                                    borderRadius: BorderRadius.circular(8),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF4F46E5)
                                            .withOpacity(0.4),
                                        blurRadius: 6,
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(Icons.blur_on,
                                          color: Colors.white, size: 10),
                                      const SizedBox(width: 3),
                                      Text(
                                        'BG Blur',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: widget.isPip ? 7 : 9,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                            Positioned(
                              bottom: 8,
                              left: 8,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(widget.isDoctor ? 'You (Doctor)' : 'You',
                                      style: TextStyle(
                                          fontSize: widget.isPip
                                              ? 8
                                              : (isMobile ? 10 : 12),
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          shadows: const [
                                            Shadow(
                                                blurRadius: 2,
                                                color: Colors.black)
                                          ])),
                                  if (_participantLocations.containsKey(
                                      _room.localParticipant?.identity ?? 'Me'))
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.location_on,
                                            color: Colors.redAccent,
                                            size: widget.isPip
                                                ? 6
                                                : (isMobile ? 8 : 10)),
                                        const SizedBox(width: 2),
                                        Text(
                                          _participantLocations[_room
                                                  .localParticipant?.identity ??
                                              'Me']!['city'],
                                          style: TextStyle(
                                            color: Colors.white70,
                                            fontSize: widget.isPip
                                                ? 6
                                                : (isMobile ? 8 : 10),
                                            shadows: const [
                                              Shadow(
                                                  blurRadius: 2,
                                                  color: Colors.black)
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                            ),
                            if (widget.isPip && widget.onExpand != null)
                              Positioned(
                                top: 4,
                                right: 4,
                                child: GestureDetector(
                                  onTap: widget.onExpand,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: const BoxDecoration(
                                        color: Colors.black45,
                                        shape: BoxShape.circle),
                                    child: const Icon(Icons.open_in_full,
                                        size: 12, color: Colors.white),
                                  ),
                                ),
                              )
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),

              // Shared Whiteboard Overlay Panel
              if (isWhiteboardOpen)
                Positioned.fill(
                  child: Container(
                    color: Colors.black45, // Dim background
                    padding: isMobile
                        ? const EdgeInsets.fromLTRB(8, 64, 8, 76)
                        : const EdgeInsets.fromLTRB(24, 80, 24, 110),
                    child: WhiteboardCanvas(
                      remoteEventStream: _whiteboardStreamController.stream,
                      onLocalDraw: (point) {
                        final payload = jsonEncode({
                          'action': point.action,
                          'x': point.x,
                          'y': point.y,
                          'color': point.color,
                          'width': point.strokeWidth,
                        });
                        _room.localParticipant?.publishData(
                          utf8.encode(payload),
                          reliable: true,
                          topic: 'whiteboard',
                        );
                      },
                      onLocalClear: () {
                        final payload = jsonEncode({
                          'action': 'clear',
                        });
                        _room.localParticipant?.publishData(
                          utf8.encode(payload),
                          reliable: true,
                          topic: 'whiteboard',
                        );
                      },
                    ),
                  ),
                ),

              // Bottom Controls Bar
              AnimatedPositioned(
                duration: 300.ms,
                bottom: widget.isPip ? 12 : (isMobile ? 16 : 32),
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: widget.isPip ? 12 : (isMobile ? 12 : 24),
                      vertical: widget.isPip ? 8 : (isMobile ? 10 : 12),
                    ),
                    decoration: BoxDecoration(
                      color:
                          const Color(0xFF1E293B).withOpacity(0.9), // Slate 800
                      borderRadius: BorderRadius.circular(
                          widget.isPip ? 16 : (isMobile ? 20 : 30)),
                      border: Border.all(color: Colors.white12),
                      boxShadow: const [
                        BoxShadow(color: Colors.black26, blurRadius: 10)
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildControlButton(
                          icon: isAudioOn ? Icons.mic_none : Icons.mic_off,
                          isDanger: !isAudioOn,
                          onTap: _toggleAudio,
                          isMobile: isMobile,
                        ),
                        SizedBox(
                            width: widget.isPip ? 8 : (isMobile ? 10 : 16)),
                        _buildControlButton(
                          icon: isVideoOn
                              ? Icons.videocam_outlined
                              : Icons.videocam_off_outlined,
                          isDanger: !isVideoOn,
                          onTap: _toggleVideo,
                          isMobile: isMobile,
                        ),
                        SizedBox(
                            width: widget.isPip ? 8 : (isMobile ? 10 : 16)),
                        _buildControlButton(
                          icon: Icons.chat_bubble_outline,
                          isActive: isChatOpen,
                          badgeCount: _unreadMessageCount,
                          onTap: () {
                            setState(() {
                              isChatOpen = !isChatOpen;
                              if (isChatOpen) {
                                _unreadMessageCount = 0;
                              }
                            });
                          },
                          isMobile: isMobile,
                        ),
                        if (!isMobile) ...[
                          const SizedBox(width: 16),
                          _buildControlButton(
                            icon: Icons.gesture,
                            isActive: isWhiteboardOpen,
                            label: widget.isPip ? null : 'Whiteboard',
                            onTap: () => setState(
                                () => isWhiteboardOpen = !isWhiteboardOpen),
                          ),
                          const SizedBox(width: 16),
                          _buildControlButton(
                            icon: isBlurActive
                                ? Icons.image
                                : Icons.image_outlined,
                            label: widget.isPip ? null : 'Background',
                            isActive: isBlurActive,
                            onTap: () => _showBackgroundMenu(context),
                            loadingOverlay: _bgIsLoading,
                          ),
                          if (widget.isDoctor) ...[
                            const SizedBox(width: 16),
                            _buildControlButton(
                              icon: Icons.person_add_alt_1,
                              label: widget.isPip ? null : 'Invite',
                              onTap: _showInviteDialog,
                            ),
                          ],
                        ] else ...[
                          SizedBox(
                              width: widget.isPip ? 8 : (isMobile ? 10 : 16)),
                          _buildControlButton(
                            icon: Icons.more_horiz,
                            onTap: _showMoreOptionsBottomSheet,
                            isMobile: isMobile,
                          ),
                        ],
                        SizedBox(
                            width: widget.isPip ? 8 : (isMobile ? 10 : 16)),
                        GestureDetector(
                          onTap: () async {
                            if (widget.isDoctor) {
                              try {
                                final payload =
                                    jsonEncode({'action': 'end_call'});
                                await _room.localParticipant?.publishData(
                                  utf8.encode(payload),
                                  reliable: true,
                                  topic: 'room_control',
                                );
                                // Give data channel a brief moment to transmit
                                await Future.delayed(
                                    const Duration(milliseconds: 300));
                              } catch (e) {
                                debugPrint("Error ending call: $e");
                              }
                            }
                            _exitRoom();
                          },
                          child: Container(
                            padding: EdgeInsets.symmetric(
                              horizontal:
                                  widget.isPip ? 12 : (isMobile ? 16 : 24),
                              vertical: widget.isPip ? 8 : (isMobile ? 10 : 12),
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE11D48),
                              borderRadius: BorderRadius.circular(
                                  widget.isPip ? 12 : (isMobile ? 16 : 25)),
                            ),
                            child: Text(
                              'End Call',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                fontSize:
                                    widget.isPip ? 10 : (isMobile ? 12 : 14),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Chat Overlay (Draggable on Desktop, Fixed bottom panel on Mobile)
              if (isChatOpen)
                isMobile
                    ? Positioned(
                        left: 16,
                        right: 16,
                        bottom: widget.isPip ? 60 : 76,
                        height: screenHeight * 0.52,
                        child: _buildChatOverlay(
                                isMobile: true,
                                screenWidth: screenWidth,
                                screenHeight: screenHeight)
                            .animate()
                            .slideY(begin: 0.2, duration: 200.ms)
                            .fadeIn(),
                      )
                    : Positioned(
                        left: _chatBoxX,
                        top: _chatBoxY,
                        child: _buildChatOverlay(
                                isMobile: false,
                                screenWidth: screenWidth,
                                screenHeight: screenHeight)
                            .animate()
                            .scaleXY(
                                begin: 0.9,
                                duration: 200.ms,
                                curve: Curves.easeOutBack)
                            .fadeIn(),
                      ),
            ],
          ),
        );
      },
    );
  }

  void _showMoreOptionsBottomSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'More Options',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Whiteboard
                    _buildSheetOption(
                      icon: Icons.gesture,
                      label: 'Whiteboard',
                      isActive: isWhiteboardOpen,
                      onTap: () {
                        Navigator.pop(context);
                        setState(() => isWhiteboardOpen = !isWhiteboardOpen);
                      },
                    ),
                    // Background
                    _buildSheetOption(
                      icon: isBlurActive ? Icons.image : Icons.image_outlined,
                      label: 'Background',
                      isActive: isBlurActive,
                      onTap: () {
                        Navigator.pop(context);
                        _showBackgroundMenu(context);
                      },
                    ),
                    if (widget.isDoctor)
                      _buildSheetOption(
                        icon: Icons.person_add_alt_1,
                        label: 'Invite',
                        onTap: () {
                          Navigator.pop(context);
                          _showInviteDialog();
                        },
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

  Widget _buildSheetOption({
    required IconData icon,
    required String label,
    bool isActive = false,
    required VoidCallback onTap,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          onTap: onTap,
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: isActive ? Colors.indigoAccent : const Color(0xFF334155),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
              color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    bool isDanger = false,
    bool isActive = false,
    String? label,
    int badgeCount = 0,
    required VoidCallback onTap,
    bool isMobile = false,
    bool loadingOverlay = false,
  }) {
    Color bgColor = const Color(0xFF334155); // Slate 700
    Color iconColor = Colors.white70;
    if (isDanger) {
      bgColor = const Color(0xFFE11D48).withOpacity(0.2); // Rose 600
      iconColor = const Color(0xFFE11D48);
    } else if (isActive) {
      bgColor = Colors.indigoAccent;
      iconColor = Colors.white;
    }

    final isCompact = widget.isPip || isMobile;

    final buttonWidget = AnimatedContainer(
      duration: 200.ms,
      height: isCompact ? 38 : 48,
      padding: EdgeInsets.symmetric(
          horizontal: (label != null && !isCompact) ? 16 : 0),
      width: (label == null || isCompact) ? (isCompact ? 38 : 48) : null,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(isCompact ? 10 : 24),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: iconColor, size: isCompact ? 18 : 20),
          if (label != null && !isCompact) ...[
            const SizedBox(width: 8),
            Text(label,
                style:
                    TextStyle(color: iconColor, fontWeight: FontWeight.bold)),
          ]
        ],
      ),
    );

    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (badgeCount > 0)
            Stack(
              clipBehavior: Clip.none,
              children: [
                buttonWidget,
                Positioned(
                  right: -4,
                  top: -4,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Color(0xFFE11D48),
                      shape: BoxShape.circle,
                    ),
                    constraints:
                        const BoxConstraints(minWidth: 16, minHeight: 16),
                    child: Center(
                      child: Text(
                        '$badgeCount',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            )
          else
            buttonWidget,
          if (loadingOverlay)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black45,
                  borderRadius: BorderRadius.circular(isCompact ? 10 : 24),
                ),
                child: const Center(
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white70,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildChatOverlay(
      {bool isMobile = false,
      required double screenWidth,
      required double screenHeight}) {
    return Container(
      width: isMobile ? double.infinity : _chatBoxW,
      height: isMobile ? double.infinity : _chatBoxH,
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 40)],
      ),
      child: Stack(
        children: [
          Column(
            children: [
              // Chat Messages List
              Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onPanUpdate: isMobile
                      ? null
                      : (details) {
                          setState(() {
                            _chatBoxX = (_chatBoxX + details.delta.dx)
                                .clamp(0.0, screenWidth - _chatBoxW);
                            _chatBoxY = (_chatBoxY + details.delta.dy)
                                .clamp(0.0, screenHeight - _chatBoxH);
                          });
                        },
                  child: Stack(
                    children: [
                      // Visual Drag Handle
                      if (!isMobile)
                        Align(
                          alignment: Alignment.topCenter,
                          child: Container(
                            margin: const EdgeInsets.only(top: 12),
                            width: 40,
                            height: 5,
                            decoration: BoxDecoration(
                                color: Colors.white24,
                                borderRadius: BorderRadius.circular(4)),
                          ),
                        ),
                      Padding(
                        padding:
                            EdgeInsets.fromLTRB(16, isMobile ? 16 : 32, 16, 0),
                        child: ListView.builder(
                          padding: const EdgeInsets.only(bottom: 16),
                          itemCount: _messages.length + 1,
                          itemBuilder: (context, index) {
                            if (index == 0) {
                              return const Padding(
                                padding: EdgeInsets.only(bottom: 16, top: 8),
                                child: Text(
                                    'Chat started. Messages are end-to-end\nencrypted.',
                                    style: TextStyle(
                                        color: Colors.white54,
                                        fontSize: 11,
                                        height: 1.5),
                                    textAlign: TextAlign.center),
                              );
                            }
                            final msg = _messages[index - 1];
                            return Align(
                              alignment: msg.isMe
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 10),
                                decoration: BoxDecoration(
                                  color: msg.isMe
                                      ? const Color(0xFF4F46E5)
                                      : const Color(0xFF334155),
                                  borderRadius: BorderRadius.only(
                                    topLeft: const Radius.circular(16),
                                    topRight: const Radius.circular(16),
                                    bottomLeft:
                                        Radius.circular(msg.isMe ? 16 : 4),
                                    bottomRight:
                                        Radius.circular(msg.isMe ? 4 : 16),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: msg.isMe
                                      ? CrossAxisAlignment.end
                                      : CrossAxisAlignment.start,
                                  children: [
                                    if (msg.isFile)
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.insert_drive_file,
                                              color: Colors.white70, size: 16),
                                          const SizedBox(width: 6),
                                          Flexible(
                                            child: Text(
                                              msg.fileName ?? msg.text,
                                              style: const TextStyle(
                                                  color: Colors.white,
                                                  fontSize: 13),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                      )
                                    else
                                      Text(msg.text,
                                          style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 13)),
                                    if (msg.isFile && !msg.isMe)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 6),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              'Saved for this call only',
                                              style: TextStyle(
                                                  color: Colors.white
                                                      .withOpacity(0.5),
                                                  fontSize: 10,
                                                  fontStyle: FontStyle.italic),
                                            ),
                                            const SizedBox(width: 8),
                                            GestureDetector(
                                              onTap: () =>
                                                  _openReceivedFile(msg),
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 3),
                                                decoration: BoxDecoration(
                                                  color:
                                                      const Color(0xFF6366F1),
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                ),
                                                child: const Text(
                                                  'Open',
                                                  style: TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 10,
                                                      fontWeight:
                                                          FontWeight.w600),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    const SizedBox(height: 4),
                                    Text(msg.time,
                                        style: TextStyle(
                                            color:
                                                Colors.white.withOpacity(0.5),
                                            fontSize: 9)),
                                  ],
                                ),
                              ).animate().fadeIn().slideY(begin: 0.2),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Input Area
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: _pickFile,
                      child: Container(
                        height: 44,
                        width: 44,
                        decoration: BoxDecoration(
                            color: const Color(0xFF334155),
                            borderRadius: BorderRadius.circular(8)),
                        child: const Icon(Icons.attach_file,
                            color: Colors.white70, size: 20),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        height: 44,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: TextField(
                          controller: _chatController,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 13),
                          decoration: const InputDecoration(
                            hintText: 'Type a message...',
                            hintStyle: TextStyle(color: Colors.white38),
                            border: InputBorder.none,
                          ),
                          onSubmitted: (_) => _sendMessage(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: _sendMessage,
                      child: Container(
                        height: 44,
                        width: 44,
                        decoration: BoxDecoration(
                            color: const Color(0xFF6366F1),
                            borderRadius: BorderRadius.circular(8)),
                        child: const Icon(Icons.send,
                            color: Colors.white, size: 18),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Close Button
          Positioned(
            top: 16,
            right: 16,
            child: GestureDetector(
              onTap: () => setState(() => isChatOpen = false),
              child: const Icon(Icons.close, color: Colors.white38, size: 20),
            ),
          ),

          // Resizable Handle
          if (!isMobile)
            Positioned(
              bottom: 0,
              right: 0,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onPanUpdate: (details) {
                  setState(() {
                    _chatBoxW = max(
                        250,
                        min(_chatBoxW + details.delta.dx,
                            600)); // Max width 600
                    _chatBoxH = max(
                        300,
                        min(_chatBoxH + details.delta.dy,
                            800)); // Max height 800
                  });
                },
                child: const MouseRegion(
                  cursor: SystemMouseCursors.resizeDownRight,
                  child: Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Icon(Icons.filter_list,
                        size: 16, color: Colors.white24), // Subtle handle icon
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSmartWaitingRoom() {
    double progress = _completedAppointments / _totalAppointments;

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
      ),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 480),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black45,
                  blurRadius: 30,
                  offset: Offset(0, 15),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Glowing Hourglass Icon
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.indigoAccent.withOpacity(0.1),
                    ),
                    child: const Icon(
                      Icons.hourglass_empty_rounded,
                      color: Colors.indigoAccent,
                      size: 32,
                    ).animate(onPlay: (c) => c.repeat(reverse: true)).rotate(
                          begin: 0,
                          end: 0.5,
                          duration: 1200.ms,
                          curve: Curves.easeInOut,
                        ),
                  ),
                ),
                const SizedBox(height: 24),

                const Center(
                  child: Text(
                    'Your consultation has started',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                const Center(
                  child: Text(
                    'Please remain on this screen. You will connect automatically.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Estimated Wait Time Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(16),
                    border:
                        Border.all(color: Colors.indigoAccent.withOpacity(0.2)),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'ESTIMATED WAIT TIME',
                        style: TextStyle(
                          color: Colors.indigoAccent,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '$_estimatedWaitMinutes Minutes',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Queue Progress Bar
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Today\'s Queue Progress',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '${(progress * 100).toInt()}% Completed',
                      style: const TextStyle(
                        color: Colors.indigoAccent,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: SizedBox(
                    height: 8,
                    child: LinearProgressIndicator(
                      value: progress,
                      backgroundColor: const Color(0xFF0F172A),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                          Colors.indigoAccent),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Completed: $_completedAppointments of $_totalAppointments appointments',
                      style:
                          const TextStyle(color: Colors.white38, fontSize: 11),
                    ),
                    Text(
                      _queuePosition == 1
                          ? 'You are next'
                          : '$_queuePosition patients ahead',
                      style: const TextStyle(
                        color: Colors.greenAccent,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                const Divider(color: Colors.white10),
                const SizedBox(height: 16),

                // Pulsing connecting status text
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Colors.greenAccent,
                        shape: BoxShape.circle,
                      ),
                    ).animate(onPlay: (c) => c.repeat()).scale(
                          begin: const Offset(1, 1),
                          end: const Offset(1.5, 1.5),
                          duration: 800.ms,
                        ),
                    const SizedBox(width: 8),
                    const Text(
                      'Waiting for doctor to connect...',
                      style: TextStyle(
                        color: Colors.white38,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
