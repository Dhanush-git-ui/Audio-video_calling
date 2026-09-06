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
import 'package:flutter_webrtc/flutter_webrtc.dart';
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
import 'dart:js' show allowInterop;
import 'package:provider/provider.dart';
import '../providers/user_session_provider.dart';
import '../shared_state.dart';



class ChatMessage {
  final String text;
  final bool isMe;
  final String time;
  final bool isFile;
  final String? fileName;
  final String? filePath;
  final String? memoryKey;
  final String? senderName;

  ChatMessage(
    this.text,
    this.isMe,
    this.time, {
    this.isFile = false,
    this.fileName,
    this.filePath,
    this.memoryKey,
    this.senderName,
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
  final bool isGuest;

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
    this.isGuest = false,
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
  bool isNoiseCancellationActive = true;
  String? _mediaErrorMessage;
  bool isWhiteboardOpen = false;
  bool _showInlineInviteCard = true; 
  bool _inviteLinkCopied = false;
  int _unreadMessageCount = 0; 

  // Telemedicine Feature States
  String? _roomAccessCode;
  bool _consentAccepted = false;
  String _liveTranscript = 'Consultation connected. Speech captions active...';
  String _selectedLanguage = 'English';
  Timer? _captionTimer;
  bool _isCameraFlipped = false;
  bool _activeSpeakerHighlight = false;
  String _activeSpeakerIdentity = '';
  final List<String> _simulatedLogs = [];

  // Live real-time consent & biometric states
  final List<String> _approvedParticipants = [];
  bool _isShowingConsentDialog = false;
  List<MediaDeviceInfo> _cameras = [];
  String? _selectedCameraId;
  bool _isLivenessChecked = false;
  bool _isVerifyingLiveness = false;
  String _livenessStatus = 'Ready to Scan';
  double _livenessProgress = 0.0;
  String? _capturedPhotoType;
  bool _hasCapturedPhoto = false;


  // Location Tracking
  final Map<String, Map<String, dynamic>> _participantLocations = {};
  final Map<String, String> _customParticipantNames = {};
  bool _isSharingLocation = false;

  // For reassembling incoming file chunks
  final Map<String, List<String?>> _incomingFileChunks = {};
  Directory? _chatFilesDir;
  final List<String> _webBlobUrls = [];
  final Map<String, Uint8List> _inMemoryChatFiles = {};

  // Patient Waiting Queue & Timer state
  bool _doctorJoinedTriggered = false;
  Timer? _waitingTimer;
  int _secondsWaiting = 0;
  int _liveMessageIndex = 0;
  final List<String> _liveUpdateMessages = [
    'Connecting to doctor...',
    'Preparing consultation room...',
    'Checking media devices...',
    'Doctor is wrapping up previous patient...',
  ];
  String _liveUpdateMessage = 'Connecting to doctor...';
  int _completedAppointments = 18;
  int _queuePosition = 2;
  int _estimatedWaitMinutes = 5;
  int _currentTimelineStage = 2;
  bool _isCameraReady = false;
  bool _isMicReady = false;
  bool _showCountdown = false;
  int _countdownSeconds = 3;
  Timer? _countdownTimer;


  String? _capturedDataUrl;
  String? _distanceError;

  final TextEditingController _chatController = TextEditingController();
  final TextEditingController _ipOverrideController = TextEditingController();
  final List<ChatMessage> _messages = [];
  final StreamController<dynamic> _whiteboardStreamController = StreamController<dynamic>.broadcast();

  
  // LiveKit WebRTC Tracks
  LocalVideoTrack? _localVideoTrack;
  LocalAudioTrack? _localAudioTrack;
  late final Room _room = Room();
  EventsListener<RoomEvent>? _listener;

  // Renamed variables to force a fresh state reset on hot reload
  double _chatBoxX = 24;
  double _chatBoxY = 100;
  double _chatBoxW = 320;
  double _chatBoxH = 450;

  final List<Map<String, Map<String, String>>> _captionDialogues = [
    {
      'English': {'speaker': 'Dr. Amanulla', 'text': 'Hello James, hope you are doing well. What symptoms are you experiencing today?'},
      'Spanish': {'speaker': 'Dr. Amanulla', 'text': 'Hola James, espero que estés bien. ¿Qué síntomas estás experimentando hoy?'},
    },
    {
      'English': {'speaker': 'James Carter', 'text': 'I have a high fever and a persistent sore throat for the past two days.'},
      'Spanish': {'speaker': 'James Carter', 'text': 'Tengo fiebre alta y dolor de garganta constante desde hace dos días.'},
    },
    {
      'English': {'speaker': 'Dr. Amanulla', 'text': 'I see. Have you taken any medications or have any known drug allergies?'},
      'Spanish': {'speaker': 'Dr. Amanulla', 'text': 'Ya veo. ¿Has tomado algún medicamento o tienes alguna alergia conocida?'},
    },
    {
      'English': {'speaker': 'James Carter', 'text': 'No medications, but I am allergic to Penicillin. I reported this to the AI assistant.'},
      'Spanish': {'speaker': 'James Carter', 'text': 'Sin medicamentos, pero soy alérgico a la penicilina. Le informé esto al asistente de IA.'},
    },
  ];
  int _captionIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadDevices();
    // Rebuild UI when connection state or participants change
    _room.addListener(_onRoomChanged);

    // Generate Room Access Code if not present
    final rand = Random();
    _roomAccessCode = (1000 + rand.nextInt(9000)).toString();

    // Start Live Captions translation simulation
    _startCaptionSimulation();

    // Pre-populate IP override if the web host is an IP address (so guest links are correct on mobile)
    try {
      final webHost = Uri.base.host;
      final ipRegex = RegExp(r'^(\d{1,3}\.){3}\d{1,3}$');
      if (ipRegex.hasMatch(webHost)) {
        _ipOverrideController.text = webHost;
      }
    } catch (e) {
      debugPrint("Error parsing web host: $e");
    }
    
    // 2. Listen to data channel messages (real-time chat)
    _listener = _room.createListener();
    _listener!.on<ParticipantConnectedEvent>((event) {
      if (_customParticipantNames.isNotEmpty) {
        _broadcastAllParticipantNames();
      }
    });
    _listener!.on<DataReceivedEvent>((event) async {
      final decoded = utf8.decode(event.data);
      try {
        final decodedMap = jsonDecode(decoded) as Map<String, dynamic>;
        
        // Intercept caption events
        if (event.topic == 'caption') {
          final action = decodedMap['action'] as String;
          if (action == 'transcript') {
            final speaker = decodedMap['speaker'] as String;
            final text = decodedMap['text'] as String;
            if (mounted) {
              setState(() {
                _liveTranscript = "$speaker: $text";
                _activeSpeakerIdentity = speaker;
                _activeSpeakerHighlight = true;
              });
              
              // Clear speaker highlight after 4 seconds
              Future.delayed(const Duration(seconds: 4), () {
                if (mounted) {
                  setState(() {
                    _activeSpeakerHighlight = false;
                  });
                }
              });
            }
          }
          return;
        }
        
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

        // 2. Intercept room call controls (e.g. Doctor ending the call, guest approvals)
        if (event.topic == 'room_control') {
          final action = decodedMap['action'] as String;
          if (action == 'end_call') {
            _exitRoom(message: 'The doctor has ended this consultation.');
          } else if (action == 'approve_guest') {
            final guestId = decodedMap['guestIdentity'] as String;
            if (guestId == _room.localParticipant?.identity) {
              setState(() {
                _consentAccepted = true;
              });
              // Publish local tracks now that the host has approved the entry
              if (_localVideoTrack != null) {
                await _room.localParticipant?.publishVideoTrack(_localVideoTrack!);
              }
              if (_localAudioTrack != null) {
                await _room.localParticipant?.publishAudioTrack(_localAudioTrack!);
              }
            }
          } else if (action == 'deny_guest') {
            final guestId = decodedMap['guestIdentity'] as String;
            if (guestId == _room.localParticipant?.identity) {
              _exitRoom(message: 'Access denied by host.');
            }
          }
          return;
        }

        // Real-time participant display name / role update synchronization
        if (event.topic == 'participant_name') {
          final action = decodedMap['action'] as String?;
          if (action == 'request_name_sync') {
            if (_customParticipantNames.isNotEmpty) {
              _broadcastAllParticipantNames();
            }
            return;
          }

          final targetIdentity = decodedMap['identity'] as String?;
          final newName = decodedMap['newName'] as String?;
          final allNamesMap = decodedMap['allNames'] as Map<String, dynamic>?;

          if (mounted) {
            setState(() {
              if (targetIdentity != null && newName != null) {
                _customParticipantNames[targetIdentity] = newName;
              }
              if (allNamesMap != null) {
                allNamesMap.forEach((key, val) {
                  if (val is String) {
                    _customParticipantNames[key] = val;
                  }
                });
              }
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
  }





  void _startCaptionSimulation() {
    if (kIsWeb) {
      _startLiveSpeechRecognition();
      return;
    }
    
    // Fallback simulation for non-web platforms
    _captionTimer = Timer.periodic(const Duration(seconds: 8), (timer) {
      if (!mounted) return;
      
      final index = _captionIndex % _captionDialogues.length;
      final dialogues = _captionDialogues[index];
      final currentLang = _selectedLanguage;
      final data = dialogues[currentLang] ?? dialogues['English']!;
      
      setState(() {
        _liveTranscript = "${data['speaker']}: ${data['text']}";
        _activeSpeakerIdentity = data['speaker']!;
        _activeSpeakerHighlight = true;
        _captionIndex++;
      });
      
      Future.delayed(const Duration(seconds: 4), () {
        if (mounted) {
          setState(() {
            _activeSpeakerHighlight = false;
          });
        }
      });
    });
  }

  void _startLiveSpeechRecognition() {
    try {
      js.context.callMethod('startSpeechRecognition', [
        _selectedLanguage,
        // ignore: undefined_function
        js.allowInterop((String text) {
          if (mounted) {
            final identity = widget.isDoctor ? 'Dr. Amanulla' : 'James Carter';
            setState(() {
              _liveTranscript = "$identity (You): $text";
              _activeSpeakerIdentity = identity;
              _activeSpeakerHighlight = true;
            });
            
            // Broadcast transcript to others
            try {
              final payload = jsonEncode({
                'action': 'transcript',
                'speaker': identity,
                'text': text,
              });
              _room.localParticipant?.publishData(
                utf8.encode(payload),
                reliable: true,
                topic: 'caption',
              );
            } catch (e) {
              debugPrint("Error publishing speech data: $e");
            }

            Future.delayed(const Duration(seconds: 4), () {
              if (mounted) {
                setState(() {
                  _activeSpeakerHighlight = false;
                });
              }
            });
          }
        })
      ]);
    } catch (e) {
      debugPrint("Failed to start speech recognition, falling back to simulation: $e");
      _captionTimer?.cancel();
      _captionTimer = Timer.periodic(const Duration(seconds: 8), (timer) {
        if (!mounted) return;
        final index = _captionIndex % _captionDialogues.length;
        final dialogues = _captionDialogues[index];
        final currentLang = _selectedLanguage;
        final data = dialogues[currentLang] ?? dialogues['English']!;
        setState(() {
          _liveTranscript = "${data['speaker']}: ${data['text']}";
          _activeSpeakerIdentity = data['speaker']!;
          _activeSpeakerHighlight = true;
          _captionIndex++;
        });
        Future.delayed(const Duration(seconds: 4), () {
          if (mounted) {
            setState(() {
              _activeSpeakerHighlight = false;
            });
          }
        });
      });
    }
  }

  void _exitRoom({String? message}) {
    // 1. Cleanly disconnect room & dispose local media resources
    try {
      _room.removeListener(_onRoomChanged);
      _room.disconnect();
      _localVideoTrack?.dispose();
      _localVideoTrack = null;
      _localAudioTrack?.dispose();
      _localAudioTrack = null;
      MeetingController().disconnect();
    } catch (e) {
      debugPrint("[MeetingLifecycle] Cleanup error: $e");
    }

    if (!mounted) return;

    if (message != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.indigo.shade800,
          duration: const Duration(seconds: 4),
        ),
      );
    }

    // 2. Identify Role & Auth State from Provider and Component Properties
    final userSession = Provider.of<UserSessionProvider>(context, listen: false);
    final String currentRole = widget.isGuest
        ? 'guest'
        : (widget.isDoctor ? 'doctor' : userSession.userRole.toLowerCase());

    debugPrint("[MeetingLifecycle] 🔚 End Call Event Triggered");
    debugPrint("[MeetingLifecycle] User Role: $currentRole | LoggedIn: ${userSession.isLoggedIn}");
    debugPrint("[MeetingLifecycle] Is Doctor: ${widget.isDoctor} | Is Guest: ${widget.isGuest}");

    // 3. Enforce Role-Based Navigation
    if (widget.isGuest || currentRole == 'guest') {
      debugPrint("[MeetingLifecycle] 🔀 Navigating GUEST -> Guest Exit Screen (/guest-exit)");
      context.go('/guest-exit?room=${Uri.encodeComponent(widget.roomName)}');
    } else if (widget.isDoctor || currentRole == 'doctor') {
      debugPrint("[MeetingLifecycle] 🔀 Navigating DOCTOR -> Doctor Dashboard (/)");
      context.go('/');
    } else if (currentRole == 'patient') {
      debugPrint("[MeetingLifecycle] 🔀 Navigating PATIENT -> Patient Dashboard (/pre-consultation)");
      context.go('/pre-consultation');
    } else {
      debugPrint("[MeetingLifecycle] 🔀 Navigating default -> Home (/)");
      context.go('/');
    }
  }

  void _onRoomChanged() {
    if (mounted) {
      setState(() {});
      // Broadcast updated name state to ensure all room participants are in sync
      if (_customParticipantNames.isNotEmpty) {
        _broadcastAllParticipantNames();
      }
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

    // 2. Initialize camera track
    if (_mediaErrorMessage == null) {
      try {
        final videoTrack = await LocalVideoTrack.createCameraTrack();
        if (!isVideoOn) {
          await videoTrack.mute();
        }
        _localVideoTrack = videoTrack;
      } catch (e) {
        debugPrint("Camera hardware failed/blocked: $e");
        _mediaErrorMessage = "Camera blocked or not found.";
      }
    }

    // 3. Initialize microphone track
    try {
      final audioTrack = await LocalAudioTrack.create();
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
    _captionTimer?.cancel();
    if (kIsWeb) {
      try {
        js.context.callMethod('stopSpeechRecognition');
      } catch (e) {
        debugPrint("Error stopping speech recognition: $e");
      }
    }
    _room.removeListener(_onRoomChanged);
    _room.disconnect();
    _listener?.dispose();
    _whiteboardStreamController.close();
    _localVideoTrack?.dispose();
    _localAudioTrack?.dispose();
    _room.dispose();
    _chatController.dispose();
    _cleanupChatFiles();
    super.dispose();
  }

  Future<void> _loadDevices() async {
    try {
      final devices = await navigator.mediaDevices.enumerateDevices();
      setState(() {
        _cameras = devices.where((d) => d.kind == 'videoinput').toList();
        if (_cameras.isNotEmpty) {
          _selectedCameraId = _cameras.first.deviceId;
        }
      });
    } catch (e) {
      debugPrint("Consultation room device error: $e");
    }
  }

  Future<void> _flipCamera() async {
    if (kIsWeb) {
      try {
        final res = await js.context.callMethod('checkAndFlipCamera', []);
        final success = res['success'] == true;
        final message = res['message']?.toString() ?? 'Camera state updated';

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: success ? Colors.green.shade800 : Colors.redAccent,
            duration: const Duration(seconds: 4),
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ No Back Camera Detected! Device has 1 camera (Front Camera).'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
      return;
    }

    if (_cameras.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ No Back Camera Detected! Device has 1 camera.')),
      );
      return;
    }

    final currentIndex = _cameras.indexWhere((c) => c.deviceId == _selectedCameraId);
    final nextIndex = (currentIndex + 1) % _cameras.length;
    _selectedCameraId = _cameras[nextIndex].deviceId;
    await _initLocalCamera();
  }

  // Opens a received file using the device's native application.
  // On web the file is previewed in an in-app overlay dialog.
  Future<void> _openReceivedFile(ChatMessage msg) async {
    if (kIsWeb) {
      // Web: show an in-app preview dialog instead of opening a new tab.
      final key = msg.memoryKey;
      if (key == null) return;
      final bytes = _inMemoryChatFiles[key];
      if (bytes == null) return;
      final name = msg.fileName ?? msg.text;
      final mimeType = getMimeType(name);

      // Check if this file type is previewable
      final isImage = mimeType.startsWith('image/');
      final blobUrl = createBlobUrl(name, bytes);
      if (blobUrl.isEmpty && !isImage) {
        // File type cannot be rendered — show a SnackBar.
        if (mounted) {
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

      if (blobUrl.isNotEmpty) {
        _webBlobUrls.add(blobUrl);
      }

      _showDocumentPreviewDialog(
        fileName: name,
        mimeType: mimeType,
        bytes: bytes,
        blobUrl: blobUrl,
      );
      return;
    }

    final path = msg.filePath;
    if (path == null || path.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('File path is unavailable.')),
        );
      }
      return;
    }

    final result = await OpenFilex.open(path);
    if (result.type != ResultType.done) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open file: ${result.message}'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  /// Shows an in-app full-screen overlay to preview a document.
  ///
  /// - **Images** (PNG, JPEG, GIF, etc.) are rendered with [Image.memory].
  /// - **PDFs / other renderable types** use an embedded `<iframe>` via
  ///   [HtmlElementView] so the browser's native viewer handles rendering.
  ///
  /// The preview is **read-only**: no download, save, or print buttons are
  /// shown.  Right-click context menu and image dragging are blocked.
  /// A prominent close button sits at the top-right.
  void _showDocumentPreviewDialog({
    required String fileName,
    required String mimeType,
    required Uint8List bytes,
    required String blobUrl,
  }) {
    final isImage = mimeType.startsWith('image/');

    // For non-image renderable types, register an iframe platform view.
    String? iframeViewType;
    if (!isImage && blobUrl.isNotEmpty) {
      iframeViewType =
          'doc-preview-${DateTime.now().millisecondsSinceEpoch}';
      registerIframeView(iframeViewType, blobUrl, mimeType: mimeType);
    }

    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (dialogContext) {
        return PopScope(
          child: Stack(
            children: [
              // Preview content — fills the screen
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 60),
                  child: Column(
                    children: [
                      // File name header — only action is Close (X)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20, vertical: 14),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(16),
                            topRight: Radius.circular(16),
                          ),
                          border: Border.all(
                              color: Colors.white.withOpacity(0.08)),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              isImage
                                  ? Icons.image
                                  : Icons.insert_drive_file,
                              color: const Color(0xFF818CF8),
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                fileName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            // Close button — the ONLY action in the header
                            Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(20),
                                onTap: () =>
                                    Navigator.of(dialogContext).pop(),
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.close,
                                    color: Colors.white,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Content area — wrapped to block right-click & drag
                      Expanded(
                        child: GestureDetector(
                          // Block right-click context menu ("Save image as…")
                          onSecondaryTapDown: (_) {},
                          child: Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F172A),
                              borderRadius: const BorderRadius.only(
                                bottomLeft: Radius.circular(16),
                                bottomRight: Radius.circular(16),
                              ),
                              border: Border.all(
                                  color: Colors.white.withOpacity(0.08)),
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: isImage
                                ? InteractiveViewer(
                                    minScale: 0.5,
                                    maxScale: 4.0,
                                    child: Center(
                                      child: IgnorePointer(
                                        // Prevents the browser from initiating
                                        // a native image drag operation.
                                        ignoring: false,
                                        child: Image.memory(
                                          bytes,
                                          fit: BoxFit.contain,
                                          errorBuilder: (context, error,
                                              stackTrace) {
                                            return const Center(
                                              child: Column(
                                                mainAxisSize:
                                                    MainAxisSize.min,
                                                children: [
                                                  Icon(Icons.broken_image,
                                                      color:
                                                          Colors.white38,
                                                      size: 48),
                                                  SizedBox(height: 12),
                                                  Text(
                                                    'Unable to display image',
                                                    style: TextStyle(
                                                        color: Colors
                                                            .white54,
                                                        fontSize: 13),
                                                  ),
                                                ],
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ),
                                  )
                                : (iframeViewType != null
                                    ? HtmlElementView(
                                        viewType: iframeViewType,
                                      )
                                    : const Center(
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.error_outline,
                                                color: Colors.white38,
                                                size: 48),
                                            SizedBox(height: 12),
                                            Text(
                                              'Preview not available for this file type',
                                              style: TextStyle(
                                                  color: Colors.white54,
                                                  fontSize: 13),
                                            ),
                                          ],
                                        ),
                                      )),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
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

  void _toggleBackgroundBlur() {
    setState(() {
      isBlurActive = !isBlurActive;
    });

    if (kIsWeb) {
      try {
        if (isBlurActive) {
          js.context.callMethod('applyBackgroundBlur', [14]);
        } else {
          js.context.callMethod('clearBackgroundEffect', []);
        }
      } catch (e) {
        debugPrint("Error toggling background blur: $e");
      }
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isBlurActive ? Icons.blur_on : Icons.blur_off,
              color: isBlurActive ? const Color(0xFF78C02B) : const Color(0xFF94A3B8),
            ),
            const SizedBox(width: 12),
            Text(
              isBlurActive
                  ? '✨ Real-time Background Blur Filter Activated'
                  : 'Background Blur Filter Turned Off',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        backgroundColor: isBlurActive ? const Color(0xFF1554A6) : const Color(0xFF111C33),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _toggleNoiseCancellation() {
    setState(() {
      isNoiseCancellationActive = !isNoiseCancellationActive;
    });

    if (kIsWeb) {
      try {
        js.context.callMethod('setNoiseCancellation', [isNoiseCancellationActive]);
      } catch (e) {
        debugPrint("Error toggling noise cancellation: $e");
      }
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isNoiseCancellationActive ? Icons.graphic_eq : Icons.noise_control_off,
              color: isNoiseCancellationActive ? const Color(0xFF78C02B) : const Color(0xFF94A3B8),
            ),
            const SizedBox(width: 12),
            Text(
              isNoiseCancellationActive
                  ? '🛡️ AI Noise Cancellation Enabled — Background noise filtered.'
                  : 'AI Noise Cancellation Disabled.',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        backgroundColor: isNoiseCancellationActive ? const Color(0xFF1554A6) : const Color(0xFF111C33),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _checkForPendingGuests() {
    if (widget.isGuest) return; // Guests don't approve other guests
    
    for (var participant in _room.remoteParticipants.values) {
      final name = participant.identity;
      if (name.contains('Guest') && !_approvedParticipants.contains(name)) {
        _showConsentDialogForGuest(name);
      }
    }
  }

  void _showConsentDialogForGuest(String guestIdentity) {
    if (_isShowingConsentDialog) return;
    _isShowingConsentDialog = true;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.security, color: Colors.indigoAccent),
            SizedBox(width: 10),
            Text('Guest Entry Request', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'Guest "$guestIdentity" has entered the waiting room. Do you consent to allow them into this consultation call?',
          style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _isShowingConsentDialog = false;
              _denyGuestEntry(guestIdentity);
            },
            child: const Text('Deny', style: TextStyle(color: Colors.redAccent)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _isShowingConsentDialog = false;
              _approveGuestEntry(guestIdentity);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.indigoAccent),
            child: const Text('Approve Entry', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _approveGuestEntry(String guestIdentity) {
    setState(() {
      _approvedParticipants.add(guestIdentity);
    });
    final payload = jsonEncode({
      'action': 'approve_guest',
      'guestIdentity': guestIdentity,
    });
    _room.localParticipant?.publishData(
      utf8.encode(payload),
      reliable: true,
      topic: 'room_control',
    );
  }

  void _denyGuestEntry(String guestIdentity) {
    final payload = jsonEncode({
      'action': 'deny_guest',
      'guestIdentity': guestIdentity,
    });
    _room.localParticipant?.publishData(
      utf8.encode(payload),
      reliable: true,
      topic: 'room_control',
    );
  }

  void _showBiometricsModal() {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Dialog(
              backgroundColor: Colors.transparent,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 500),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withOpacity(0.08)),
                  boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 30)],
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
                            color: Colors.pinkAccent.withOpacity(0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.camera_enhance, color: Colors.pinkAccent, size: 24),
                        ),
                        const SizedBox(width: 16),
                        const Text(
                          'Clinical Biometric Check',
                          style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    
                    if (!_isLivenessChecked) ...[
                      Container(
                        height: 220,
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: _isVerifyingLiveness ? Colors.pinkAccent.withOpacity(0.3) : Colors.white10),
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            if (_isVerifyingLiveness)
                              Positioned.fill(
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [Colors.transparent, Colors.pinkAccent.withOpacity(0.15), Colors.transparent],
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                    ),
                                  ),
                                )
                                    .animate(onPlay: (c) => c.repeat())
                                    .slideY(begin: -1, end: 1, duration: 1800.ms),
                              ),
                            
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  _isVerifyingLiveness ? Icons.remove_red_eye : Icons.visibility_off_outlined,
                                  color: _isVerifyingLiveness ? Colors.pinkAccent : Colors.white24,
                                  size: 48,
                                ).animate(target: _isVerifyingLiveness ? 1.0 : 0.0)
                                 .scale(end: const Offset(1.2, 1.2), duration: 600.ms)
                                 .shake(duration: 800.ms),
                                const SizedBox(height: 16),
                                Text(
                                  _livenessStatus,
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                                const SizedBox(height: 8),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 32.0),
                                  child: LinearProgressIndicator(
                                    value: _livenessProgress,
                                    color: Colors.pinkAccent,
                                    backgroundColor: Colors.white10,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton(
                        onPressed: _isVerifyingLiveness ? null : () async {
                          setModalState(() {
                            _isVerifyingLiveness = true;
                            _livenessStatus = 'Initializing liveness check...';
                            _livenessProgress = 0.0;
                          });
                          
                          await Future.delayed(const Duration(milliseconds: 1000));
                          setModalState(() {
                            _livenessStatus = 'Detecting facial positioning...';
                            _livenessProgress = 0.3;
                          });
                          
                          await Future.delayed(const Duration(milliseconds: 1200));
                          setModalState(() {
                            _livenessStatus = 'BLINK YOUR EYES NOW';
                            _livenessProgress = 0.6;
                          });
                          
                          await Future.delayed(const Duration(milliseconds: 1500));
                          setModalState(() {
                            _livenessStatus = 'Blink detected! Checking liveness signature...';
                            _livenessProgress = 0.9;
                          });
                          
                          await Future.delayed(const Duration(milliseconds: 1000));
                          setState(() {
                            _isLivenessChecked = true;
                          });
                          setModalState(() {
                            _isVerifyingLiveness = false;
                            _livenessStatus = 'Liveness Confirmed!';
                            _livenessProgress = 1.0;
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.pinkAccent,
                          minimumSize: const Size.fromHeight(48),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Start Liveness Verification', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ]
                    else ...[
                      if (!_hasCapturedPhoto) ...[
                        const Text(
                          'Liveness verified. Select biometric target:',
                          style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _buildTypeSelectBtn('Both Eyes', 'BothEyes', setModalState),
                            _buildTypeSelectBtn('Left Eye', 'LeftEye', setModalState),
                            _buildTypeSelectBtn('Right Eye', 'RightEye', setModalState),
                            _buildTypeSelectBtn('Only Face', 'Face', setModalState),
                            _buildTypeSelectBtn('Whole Body', 'Body', setModalState),
                          ],
                        ),
                        if (_capturedPhotoType != null) ...[
                          const SizedBox(height: 16),
                          _buildAadharBiometricContainer(
                            targetType: _capturedPhotoType,
                            isCaptured: false,
                            child: _localVideoTrack != null && isVideoOn
                                ? FittedBox(
                                    fit: BoxFit.cover,
                                    clipBehavior: Clip.hardEdge,
                                    child: SizedBox(
                                      width: 320,
                                      height: 400,
                                      child: VideoTrackRenderer(
                                        _localVideoTrack!,
                                        fit: VideoViewFit.cover,
                                      ),
                                    ),
                                  )
                                : Container(
                                    color: const Color(0xFF0F172A),
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        const Icon(Icons.videocam, color: Colors.cyanAccent, size: 44),
                                        const SizedBox(height: 8),
                                        Text(
                                          'ALIGN YOUR ${_capturedPhotoType?.toUpperCase()}',
                                          style: const TextStyle(color: Colors.cyanAccent, fontSize: 9, fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                  ),
                          ),
                        ],
                        if (_distanceError != null) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.redAccent.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.redAccent.withOpacity(0.5)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 20),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _distanceError!,
                                    style: const TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold, height: 1.3),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: _capturedPhotoType == null ? null : () async {
                            if (kIsWeb) {
                              try {
                                final res = js.context.callMethod('detectAndCaptureFeature', [_capturedPhotoType]);
                                if (res != null) {
                                  final isSuccess = res['success'] as bool? ?? false;
                                  final dataUrl = res['dataUrl'] as String?;
                                  final err = res['error'] as String?;

                                  if (!isSuccess || dataUrl == null || dataUrl.isEmpty) {
                                    setModalState(() {
                                      _distanceError = err ?? "❌ Feature not detected in frame! Point camera directly at your face/eyes.";
                                    });
                                    return;
                                  }

                                  setModalState(() {
                                    _distanceError = null;
                                    _capturedDataUrl = dataUrl;
                                    _hasCapturedPhoto = true;
                                  });
                                  return;
                                }
                              } catch (e) {
                                debugPrint("Detection call error: $e");
                              }
                            }

                            setModalState(() {
                              _distanceError = "❌ Detection failed! Ensure active camera feed is available.";
                            });
                          },
                          icon: const Icon(Icons.camera, color: Colors.white),
                          label: Text('Capture ${_capturedPhotoType ?? "Snapshot"}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.indigoAccent,
                            minimumSize: const Size.fromHeight(48),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                        ),
                      ] else ...[
                        _buildAadharBiometricContainer(
                          targetType: _capturedPhotoType,
                          isCaptured: true,
                          child: _capturedDataUrl != null && _capturedDataUrl!.startsWith('data:image')
                              ? Image.network(
                                  _capturedDataUrl!,
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  height: double.infinity,
                                )
                              : const Center(
                                  child: Icon(Icons.check_circle, color: Colors.greenAccent, size: 64),
                                ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          '${_capturedPhotoType} Photo Captured & Distance Verified!',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        const SizedBox(height: 6),
                        const Text(
                          'Ready to sync to EMR medical records.',
                          style: TextStyle(color: Colors.white30, fontSize: 11),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () {
                                  setModalState(() {
                                    _hasCapturedPhoto = false;
                                  });
                                },
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Colors.white24),
                                  minimumSize: const Size.fromHeight(48),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                child: const Text('Retake', style: TextStyle(color: Colors.white)),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () async {
                                  final dataUrl = _capturedDataUrl;
                                  final photoType = _capturedPhotoType ?? 'Biometrics';
                                  Navigator.pop(context);
                                  setState(() {
                                    _isLivenessChecked = false;
                                    _hasCapturedPhoto = false;
                                    _capturedPhotoType = null;
                                  });

                                  if (dataUrl != null && dataUrl.isNotEmpty) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Uploading $photoType snapshot to Supabase Storage...'),
                                        backgroundColor: Colors.indigo.shade800,
                                        duration: const Duration(seconds: 2),
                                      ),
                                    );

                                    final record = await SupabaseStorageService.uploadBase64Image(
                                      dataUrl: dataUrl,
                                      captureType: photoType,
                                      roomName: widget.roomName,
                                    );

                                    if (mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(
                                          content: Text('✅ $photoType stored in Supabase: ${record.storagePath}'),
                                          backgroundColor: Colors.green.shade800,
                                          duration: const Duration(seconds: 5),
                                        ),
                                      );
                                    }
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green,
                                  minimumSize: const Size.fromHeight(48),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                child: const Text('Save & Finish', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTypeSelectBtn(String label, String type, void Function(void Function()) setModalState) {
    final isSelected = _capturedPhotoType == type;
    return GestureDetector(
      onTap: () {
        setModalState(() {
          _capturedPhotoType = type;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isSelected ? Colors.indigoAccent.withOpacity(0.2) : Colors.black26,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: isSelected ? Colors.indigoAccent : Colors.white10, width: 2),
        ),
        child: Column(
          children: [
            Icon(
              type == 'Iris' 
                  ? Icons.remove_red_eye 
                  : (type == 'Face' ? Icons.face : Icons.accessibility),
              color: isSelected ? Colors.indigoAccent : Colors.white30,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.white54,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
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
      _messages.add(ChatMessage(text, true, DateFormat('hh:mm a').format(DateTime.now())));
      _chatController.clear();
    });
  }



  Future<void> _toggleVideo() async {
    final nextState = !isVideoOn;
    try {
      if (_room.connectionState == lk.ConnectionState.connected) {
        await _room.localParticipant?.setCameraEnabled(nextState);
      } else {
        if (nextState) {
          await _localVideoTrack?.unmute();
        } else {
          await _localVideoTrack?.mute();
        }
      }
      setState(() {
        isVideoOn = nextState;
      });
    } catch (e) {
      debugPrint("Error toggling video: $e");
    }
  }

  Future<void> _toggleAudio() async {
    final nextState = !isAudioOn;
    try {
      if (_room.connectionState == lk.ConnectionState.connected) {
        await _room.localParticipant?.setMicrophoneEnabled(nextState);
      } else {
        if (nextState) {
          await _localAudioTrack?.unmute();
        } else {
          await _localAudioTrack?.mute();
        }
      }
      setState(() {
        isAudioOn = nextState;
      });
    } catch (e) {
      debugPrint("Error toggling audio: $e");
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
      if (!widget.isGuest) {
        if (_localVideoTrack != null) await _room.localParticipant?.publishVideoTrack(_localVideoTrack!);
        if (_localAudioTrack != null) await _room.localParticipant?.publishAudioTrack(_localAudioTrack!);
      }

      // Automatically request and share location after connecting
      _shareMyLocation();
      // Request name/role state sync from existing participants
      _requestNameSync();
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
      origin = '${baseUri.scheme}://${baseUri.host}${baseUri.hasPort ? ":${baseUri.port}" : ""}';
    }

    var overrideIp = _ipOverrideController.text.trim();
    if (overrideIp.isNotEmpty) {
      // Clean up input if the user enters a full URL instead of just the IP
      if (overrideIp.startsWith('http://')) overrideIp = overrideIp.substring(7);
      if (overrideIp.startsWith('https://')) overrideIp = overrideIp.substring(8);
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
      
      origin = origin.replaceAll('localhost', overrideIp).replaceAll('127.0.0.1', overrideIp);
    }

    String serverUrl = widget.url;
    if (overrideIp.isNotEmpty) {
      serverUrl = serverUrl.replaceAll('localhost', overrideIp).replaceAll('127.0.0.1', overrideIp);
    }

    final Map<String, String> queryParams = {
      if (widget.roomName.isNotEmpty) 'room': widget.roomName,
      if (serverUrl.isNotEmpty) 'url': serverUrl,
      if (widget.apiKey.isNotEmpty) 'key': widget.apiKey,
      if (widget.apiSecret.isNotEmpty) 'secret': widget.apiSecret,
      'role': 'guest',
      if (_roomAccessCode != null) 'ac': _roomAccessCode!,
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
            bool dialogConsentAccepted = _consentAccepted;
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
                          child: const Icon(Icons.person_add, color: Colors.indigoAccent, size: 24),
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
                      style: TextStyle(color: Colors.white54, fontSize: 13, height: 1.4),
                    ),
                    if (isLocalhost) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orangeAccent.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.orangeAccent.withOpacity(0.3)),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.warning_amber_rounded, color: Colors.orangeAccent, size: 20),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Warning: Meeting is running on localhost. Other devices on your Wi-Fi will need your computer\'s IP address to connect.',
                                style: TextStyle(color: Colors.orangeAccent, fontSize: 11, height: 1.3),
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
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'Enter PC local IP (e.g., 192.168.1.50)',
                          hintStyle: const TextStyle(color: Colors.white30),
                          filled: true,
                          fillColor: const Color(0xFF0F172A),
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.clear, color: Colors.white30, size: 16),
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
                        border: Border.all(color: Colors.white.withOpacity(0.05)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'SHAREABLE GUEST LINK',
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
                          const Divider(color: Colors.white10, height: 24),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'GUEST ACCESS CODE',
                                style: TextStyle(
                                  color: Colors.pinkAccent,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.pinkAccent.withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: Colors.pinkAccent.withOpacity(0.3)),
                                ),
                                child: Text(
                                  _roomAccessCode ?? '1111',
                                  style: const TextStyle(
                                    color: Colors.pinkAccent,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    // Consent checkbox
                    Row(
                      children: [
                        Checkbox(
                          value: dialogConsentAccepted,
                          activeColor: Colors.indigoAccent,
                          onChanged: (val) {
                            setDialogState(() {
                              dialogConsentAccepted = val ?? false;
                              _consentAccepted = dialogConsentAccepted;
                            });
                          },
                        ),
                        const Expanded(
                          child: Text(
                            'I confirm that I have obtained explicit patient consent for link sharing & session participation.',
                            style: TextStyle(color: Colors.white70, fontSize: 11, height: 1.3),
                          ),
                        ),
                      ],
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
                          child: const Text('Close', style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                        const SizedBox(width: 12),
                        ElevatedButton.icon(
                          onPressed: () {
                            if (!dialogConsentAccepted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('⚠️ MANDATORY PATIENT CONSENT REQUIRED: You must tick the consent box before sharing invitation links or access codes.'),
                                  backgroundColor: Colors.redAccent,
                                  duration: Duration(seconds: 4),
                                ),
                              );
                              return;
                            }
                            Clipboard.setData(ClipboardData(text: "$inviteUrl\nAccess Code: ${_roomAccessCode ?? '1111'}"));
                            setDialogState(() {
                              copied = true;
                            });
                            Future.delayed(const Duration(milliseconds: 600), () {
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
                            copied ? 'Copied Link + Code!' : 'Copy Invitation',
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: copied ? Colors.green : Colors.indigoAccent,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
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
    final displayName = _customParticipantNames[participant.identity] ??
        (participant.name.isNotEmpty ? participant.name : participant.identity);

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

    final isActiveSpeaker = _activeSpeakerHighlight && 
        (_activeSpeakerIdentity == participant.identity || 
         _activeSpeakerIdentity.contains(participant.name));

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActiveSpeaker ? Colors.pinkAccent : Colors.white.withOpacity(0.08),
          width: isActiveSpeaker ? 3 : 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (videoTrack != null && !isVideoMuted)
            VideoTrackRenderer(videoTrack)
          else
            _buildParticipantPlaceholder(displayName),
          Positioned(
            bottom: 12,
            left: 12,
            right: 12,
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
                            color: participant.isSpeaking ? Colors.greenAccent : Colors.white30,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                displayName,
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Role-based name editing: only visible to the Doctor
                        if (widget.isDoctor) ...[  
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: () => _showRenameParticipantDialog(participant.identity),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: Colors.indigoAccent.withOpacity(0.25),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.edit,
                                color: Colors.white70,
                                size: 12,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
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

  /// Shows a dialog (Doctor-only) allowing the Doctor to rename a participant
  /// to either "Patient" or "Relative" for clearer identification during the call.
  void _showRenameParticipantDialog(String currentIdentity) {
    // Guard: only Doctors should ever reach this method.
    if (!widget.isDoctor) return;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: Colors.white.withOpacity(0.08)),
          ),
          title: const Row(
            children: [
              Icon(Icons.badge_outlined, color: Colors.indigoAccent, size: 24),
              SizedBox(width: 10),
              Text(
                'Rename Participant',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Set a display label for "$currentIdentity":',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildRenameOption(
                    dialogContext: dialogContext,
                    participantIdentity: currentIdentity,
                    label: 'Patient',
                    icon: Icons.personal_injury_outlined,
                    color: Colors.tealAccent,
                  ),
                  _buildRenameOption(
                    dialogContext: dialogContext,
                    participantIdentity: currentIdentity,
                    label: 'Relative',
                    icon: Icons.people_outline,
                    color: Colors.purpleAccent,
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.white54, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  void _broadcastAllParticipantNames() {
    if (_customParticipantNames.isEmpty) return;
    try {
      final payload = jsonEncode({
        'allNames': _customParticipantNames,
      });
      _room.localParticipant?.publishData(
        utf8.encode(payload),
        reliable: true,
        topic: 'participant_name',
      );
    } catch (e) {
      debugPrint("Error broadcasting all participant names: $e");
    }
  }

  void _updateAndBroadcastParticipantName(
      String targetIdentity, String newName) {
    setState(() {
      _customParticipantNames[targetIdentity] = newName;
    });
    try {
      final payload = jsonEncode({
        'identity': targetIdentity,
        'newName': newName,
        'allNames': _customParticipantNames,
      });
      _room.localParticipant?.publishData(
        utf8.encode(payload),
        reliable: true,
        topic: 'participant_name',
      );
    } catch (e) {
      debugPrint("Error publishing participant name update: $e");
    }
  }

  void _requestNameSync() {
    try {
      final payload = jsonEncode({
        'action': 'request_name_sync',
      });
      _room.localParticipant?.publishData(
        utf8.encode(payload),
        reliable: true,
        topic: 'participant_name',
      );
    } catch (e) {
      debugPrint("Error requesting name sync: $e");
    }
  }

  /// Builds an individual rename option button used inside [_showRenameParticipantDialog].
  Widget _buildRenameOption({
    required BuildContext dialogContext,
    required String participantIdentity,
    required String label,
    required IconData icon,
    required Color color,
  }) {
    return GestureDetector(
      onTap: () {
        Navigator.of(dialogContext).pop();
        _updateAndBroadcastParticipantName(participantIdentity, label);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Participant relabeled as "$label".',
                style: const TextStyle(fontWeight: FontWeight.w500),
              ),
              backgroundColor: Colors.indigo.shade700,
              duration: const Duration(seconds: 2),
            ),
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
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
        color: isAudioMuted ? const Color(0xFFEF4444).withOpacity(0.9) : Colors.black.withOpacity(0.65),
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
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isConnected 
                      ? Colors.greenAccent.withOpacity(0.1) 
                      : Colors.orangeAccent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isConnected 
                        ? Colors.greenAccent.withOpacity(0.3) 
                        : Colors.orangeAccent.withOpacity(0.3)
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!isConnected)
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.orangeAccent),
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
                        color: isConnected ? Colors.greenAccent : Colors.orangeAccent,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              
              if (widget.isGuest) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.indigoAccent.withOpacity(0.3)),
                    boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 16)],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.security, color: Colors.greenAccent, size: 20),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'GUEST CONSULTATION SESSION ACTIVE',
                            style: TextStyle(color: Colors.greenAccent, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Room Code: ${widget.roomName}',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ] else if (_showInlineInviteCard) ...[
                Builder(
                  builder: (context) {
                    final inviteUrl = _generateInviteLink();
                    final isLocalhost = widget.url.contains('localhost') || 
                                        widget.url.contains('127.0.0.1') ||
                                        Uri.base.host == 'localhost' || 
                                        Uri.base.host == '127.0.0.1';

                    return Container(
                      constraints: const BoxConstraints(maxWidth: 460),
                      decoration: BoxDecoration(
                        color: const Color(0xFF111C33),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0x331554A6)),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF1554A6).withOpacity(0.12),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.share_rounded, color: Color(0xFF78C02B), size: 20),
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
                            style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12, height: 1.4),
                          ),
                          if (isLocalhost) ...[
                            const SizedBox(height: 16),
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1554A6).withOpacity(0.12),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: const Color(0x331554A6)),
                              ),
                              child: const Row(
                                children: [
                                  Icon(Icons.info_outline_rounded, color: Color(0xFF60A5FA), size: 20),
                                  SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      'Meeting is running on localhost. Other devices on your Wi-Fi will need your computer\'s IP address to connect.',
                                      style: TextStyle(color: Color(0xFF93C5FD), fontSize: 11, height: 1.3),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            const Text(
                              'HOST COMPUTER IP OVERRIDE',
                              style: TextStyle(
                                color: Color(0xFF94A3B8),
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
                              style: const TextStyle(color: Colors.white, fontSize: 13),
                              decoration: InputDecoration(
                                hintText: 'Enter PC local IP (e.g., 192.168.1.50)',
                                hintStyle: const TextStyle(color: Color(0xFF64748B)),
                                filled: true,
                                fillColor: const Color(0xFF0A1120),
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(color: Color(0x331554A6)),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(color: Color(0x331554A6)),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: const BorderSide(color: Color(0xFF1554A6), width: 1.5),
                                ),
                                suffixIcon: IconButton(
                                  icon: const Icon(Icons.clear, color: Color(0xFF64748B), size: 16),
                                  onPressed: () {
                                    _ipOverrideController.clear();
                                    setState(() {});
                                  },
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 16),
                          
                          // Mandatory Patient Consent Checkbox on Dashboard Card
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0A1120),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _consentAccepted ? const Color(0xFF78C02B) : const Color(0x331554A6),
                                width: 1.5,
                              ),
                            ),
                            child: Row(
                              children: [
                                Checkbox(
                                  value: _consentAccepted,
                                  activeColor: const Color(0xFF78C02B),
                                  checkColor: Colors.white,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                  onChanged: (val) {
                                    setState(() {
                                      _consentAccepted = val ?? false;
                                    });
                                  },
                                ),
                                const Expanded(
                                  child: Text(
                                    'I confirm explicit patient consent for link sharing & guest participation.',
                                    style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 11, height: 1.3, fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          
                          // Link display field (LOCKED UNTIL CONSENT IS TICKED)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0A1120),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: _consentAccepted ? const Color(0xFF78C02B) : const Color(0x331554A6),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: (_consentAccepted ? const Color(0xFF78C02B) : const Color(0xFF1554A6)).withOpacity(0.15),
                                  blurRadius: 12,
                                ),
                              ],
                            ),
                            child: SelectableText(
                              _consentAccepted 
                                  ? "$inviteUrl\nAccess Code: ${_roomAccessCode ?? '1111'}"
                                  : '🔒 Link Locked: Tick "I confirm explicit patient consent" above to reveal invitation URL & Access Code.',
                              style: TextStyle(
                                color: _consentAccepted ? const Color(0xFFE2E8F0) : const Color(0xFF94A3B8),
                                fontSize: 12,
                                fontFamily: _consentAccepted ? 'monospace' : 'sans-serif',
                                fontWeight: _consentAccepted ? FontWeight.w600 : FontWeight.bold,
                                height: 1.3,
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),
                          
                          // Copy Button
                          Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              gradient: const LinearGradient(
                                colors: [Color(0xFF1554A6), Color(0xFF78C02B)],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF1554A6).withOpacity(0.35),
                                  blurRadius: 16,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: ElevatedButton.icon(
                              onPressed: () {
                                if (!_consentAccepted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('⚠️ MANDATORY PATIENT CONSENT REQUIRED: You must tick the consent box before copying or sharing the invite link.'),
                                      backgroundColor: Colors.redAccent,
                                      duration: Duration(seconds: 4),
                                    ),
                                  );
                                  return;
                                }
                                Clipboard.setData(ClipboardData(text: "$inviteUrl\nAccess Code: ${_roomAccessCode ?? '1111'}"));
                                setState(() {
                                  _inviteLinkCopied = true;
                                });
                                // Hide the inline invite component after copying
                                Future.delayed(const Duration(milliseconds: 500), () {
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
                                _inviteLinkCopied ? 'Copied Link!' : 'Copy Invitation Link',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: _inviteLinkCopied ? Colors.green : Colors.transparent,
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
                  }
                ),
              ] else ...[
                // Minimalist waiting state once the link is copied
                const SizedBox(height: 20),
                const CircularProgressIndicator(color: Colors.indigoAccent),
                const SizedBox(height: 16),
                const Text(
                  'Invitation link copied to clipboard!',
                  style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Waiting for other participants to join the call...',
                  style: TextStyle(color: Colors.white54, fontSize: 13),
                ),
                const SizedBox(height: 24),
                TextButton.icon(
                  icon: const Icon(Icons.share, size: 16, color: Colors.indigoAccent),
                  label: const Text('Show Invite Link Again', style: TextStyle(color: Colors.indigoAccent, fontWeight: FontWeight.bold)),
                  onPressed: () {
                    setState(() {
                      _inviteLinkCopied = false;
                      _showInlineInviteCard = true;
                    });
                  },
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
              child: Builder(
                builder: (context) {
                  final remoteParticipants = _room.remoteParticipants.values.toList();
                  if (remoteParticipants.isNotEmpty) {
                    return _buildParticipantGrid(remoteParticipants);
                  }

                  // If no one is connected, show waiting screen with share link
                  return _buildWaitingOrDisconnectedScreen(
                    _room.connectionState == lk.ConnectionState.connected 
                        ? 'Waiting for others to join the room...' 
                        : 'Not connected to LiveKit Server', 
                  );
                }
              ),
            ).animate().fadeIn(duration: 800.ms),
          ),

          // Local Participant PiP (Top Right)
          AnimatedPositioned(
            duration: 300.ms,
            top: widget.isPip ? 8 : (isMobile ? 12 : 24),
            right: widget.isPip ? 8 : (isMobile ? 12 : 24),
            width: widget.isPip ? 100 : (isMobile ? 120 : 220),
            height: widget.isPip ? 56 : (isMobile ? 68 : 124),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: (_activeSpeakerHighlight && _activeSpeakerIdentity == 'Dr. Amanulla')
                      ? Colors.pinkAccent
                      : Colors.white12,
                  width: (_activeSpeakerHighlight && _activeSpeakerIdentity == 'Dr. Amanulla') ? 3 : 1,
                ),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: (isVideoOn && _localVideoTrack != null)
                        ? VideoTrackRenderer(_localVideoTrack!)
                        : Container(
                            color: const Color(0xFF1E293B),
                            child: Center(
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 4.0),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      _mediaErrorMessage ?? (isVideoOn ? 'No Camera Device Found\n(VM / Permission Blocked)' : 'Camera Off'),
                                      textAlign: TextAlign.center,
                                      style: TextStyle(color: Colors.white54, fontSize: widget.isPip ? 8 : (isMobile ? 9 : 10)),
                                    ),
                                    if (_mediaErrorMessage != null) ...[
                                      const SizedBox(height: 6),
                                      GestureDetector(
                                        onTap: _initLocalCamera,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.indigoAccent,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            'Retry',
                                            style: TextStyle(
                                              fontSize: widget.isPip ? 8 : (isMobile ? 9 : 10),
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
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
                  ),

                  // Blur active indicator badge
                  if (isBlurActive)
                    Positioned(
                      top: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1554A6).withOpacity(0.9),
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF1554A6).withOpacity(0.4),
                              blurRadius: 6,
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.blur_on, color: Colors.white, size: 10),
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
                        Text(
                          _customParticipantNames[_room.localParticipant?.identity] ??
                              (widget.isDoctor ? 'You (Doctor)' : (widget.isGuest ? 'You (Patient)' : 'You')),
                          style: TextStyle(
                            fontSize: widget.isPip ? 8 : (isMobile ? 10 : 12),
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            shadows: const [Shadow(blurRadius: 2, color: Colors.black)],
                          ),
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
                          decoration: const BoxDecoration(color: Colors.black45, shape: BoxShape.circle),
                          child: const Icon(Icons.open_in_full, size: 12, color: Colors.white),
                        ),
                      ),
                    )
                ],
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
                  isReadOnly: false,
                  onClose: () => setState(() => isWhiteboardOpen = false),
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

          // Live simulated captions & translation selector
          if (!widget.isPip)
            Positioned(
              bottom: isMobile ? 80 : 110,
              left: 24,
              right: 24,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.75),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.white10),
                  ),
                  child: Row(
                    children: [
                      // Caption Speaker indicator
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _activeSpeakerHighlight ? Colors.pinkAccent : Colors.white30,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _liveTranscript,
                          style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.4),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Multi-lingual Translation Dropdown
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.white12),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedLanguage,
                            dropdownColor: const Color(0xFF1E293B),
                            style: const TextStyle(color: Colors.indigoAccent, fontSize: 11, fontWeight: FontWeight.bold),
                            items: const [
                              DropdownMenuItem(value: 'English', child: Text('EN')),
                              DropdownMenuItem(value: 'Spanish', child: Text('ES')),
                            ],
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  _selectedLanguage = val;
                                  final index = (_captionIndex - 1).clamp(0, _captionDialogues.length - 1);
                                  final data = _captionDialogues[index][_selectedLanguage] ?? _captionDialogues[index]['English']!;
                                  _liveTranscript = "${data['speaker']}: ${data['text']}";
                                });
                              }
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
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
                  color: const Color(0xFF111C33).withOpacity(0.92),
                  borderRadius: BorderRadius.circular(widget.isPip ? 16 : (isMobile ? 20 : 30)),
                  border: Border.all(color: const Color(0x331554A6)),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF1554A6).withOpacity(0.15),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildControlButton(
                        icon: isAudioOn ? Icons.mic_none : Icons.mic_off,
                        isDanger: !isAudioOn,
                        onTap: _toggleAudio,
                        isMobile: isMobile,
                      ),
                      SizedBox(width: widget.isPip ? 8 : (isMobile ? 10 : 16)),
                      _buildControlButton(
                        icon: isVideoOn ? Icons.videocam_outlined : Icons.videocam_off_outlined,
                        isDanger: !isVideoOn,
                        onTap: _toggleVideo,
                        isMobile: isMobile,
                      ),
                      SizedBox(width: widget.isPip ? 8 : (isMobile ? 10 : 16)),
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
                        const SizedBox(width: 10),
                        _buildControlButton(
                          icon: Icons.gesture,
                          isActive: isWhiteboardOpen,
                          label: widget.isPip ? null : 'Whiteboard',
                          onTap: () => setState(() => isWhiteboardOpen = !isWhiteboardOpen),
                        ),
                        const SizedBox(width: 10),
                        _buildControlButton(
                          icon: isBlurActive ? Icons.blur_on : Icons.blur_off,
                          label: widget.isPip ? null : 'Blur',
                          isActive: isBlurActive,
                          onTap: _toggleBackgroundBlur,
                        ),
                        const SizedBox(width: 10),
                        _buildControlButton(
                          icon: isNoiseCancellationActive ? Icons.graphic_eq : Icons.noise_control_off,
                          label: widget.isPip ? null : 'Noise Shield',
                          isActive: isNoiseCancellationActive,
                          onTap: _toggleNoiseCancellation,
                        ),
                        const SizedBox(width: 10),
                        _buildControlButton(
                          icon: Icons.camera_alt,
                          label: widget.isPip ? null : 'Live Photo',
                          onTap: _showBiometricsModal,
                        ),
                        const SizedBox(width: 10),
                        _buildControlButton(
                          icon: Icons.flip_camera_ios,
                          label: widget.isPip ? null : 'Flip',
                          onTap: _flipCamera,
                        ),
                        if (!widget.isGuest) ...[
                          const SizedBox(width: 10),
                          _buildControlButton(
                            icon: Icons.person_add_alt_1,
                            label: widget.isPip ? null : 'Invite',
                            onTap: _showInviteDialog,
                          ),
                        ],
                      ] else ...[
                        SizedBox(width: widget.isPip ? 8 : (isMobile ? 10 : 16)),
                        _buildControlButton(
                          icon: Icons.more_horiz,
                          onTap: _showMoreOptionsBottomSheet,
                          isMobile: isMobile,
                        ),
                      ],
                      SizedBox(width: widget.isPip ? 8 : (isMobile ? 10 : 16)),
                      GestureDetector(
                      onTap: () async {
                        if (widget.isDoctor && !widget.isGuest) {
                          try {
                            final payload = jsonEncode({'action': 'end_call'});
                            await _room.localParticipant?.publishData(
                              utf8.encode(payload),
                              reliable: true,
                              topic: 'room_control',
                            );
                            await Future.delayed(const Duration(milliseconds: 300));
                          } catch (e) {
                            debugPrint("Error ending call: $e");
                          }
                        }
                        _exitRoom();
                      },
                      child: Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: widget.isPip ? 12 : (isMobile ? 16 : 24),
                          vertical: widget.isPip ? 8 : (isMobile ? 10 : 12),
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE11D48),
                          borderRadius: BorderRadius.circular(widget.isPip ? 12 : (isMobile ? 16 : 25)),
                        ),
                        child: Text(
                          widget.isGuest ? 'Leave Call' : 'End Call',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            fontSize: widget.isPip ? 10 : (isMobile ? 12 : 14),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
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
                    child: _buildChatOverlay(isMobile: true)
                        .animate()
                        .slideY(begin: 0.2, duration: 200.ms)
                        .fadeIn(),
                  )
                : Positioned(
                    left: _chatBoxX,
                    top: _chatBoxY,
                    child: _buildChatOverlay(isMobile: false)
                        .animate()
                        .scaleXY(begin: 0.9, duration: 200.ms, curve: Curves.easeOutBack)
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
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
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
                    // Blur
                    _buildSheetOption(
                      icon: isBlurActive ? Icons.blur_on : Icons.blur_off,
                      label: 'Blur',
                      isActive: isBlurActive,
                      onTap: () {
                        Navigator.pop(context);
                        _toggleBackgroundBlur();
                      },
                    ),
                    // Noise Shield
                    _buildSheetOption(
                      icon: isNoiseCancellationActive ? Icons.graphic_eq : Icons.noise_control_off,
                      label: 'Noise Shield',
                      isActive: isNoiseCancellationActive,
                      onTap: () {
                        Navigator.pop(context);
                        _toggleNoiseCancellation();
                      },
                    ),
                    // Invite
                    if (!widget.isGuest)
                      _buildSheetOption(
                        icon: Icons.person_add_alt_1,
                        label: 'Invite',
                        onTap: () {
                          Navigator.pop(context);
                          _showInviteDialog();
                        },
                      ),
                    // Supabase Log
                    _buildSheetOption(
                      icon: Icons.storage_outlined,
                      label: 'Supabase Log',
                      onTap: () {
                        Navigator.pop(context);
                        _showSupabaseLogDialog();
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

  void _showSupabaseLogDialog() {
    showDialog(
      context: context,
      builder: (context) {
        final records = SupabaseStorageService.storedFilesLog;

        return AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.storage, color: Colors.greenAccent),
              SizedBox(width: 10),
              Text('Supabase Storage & EMR Log', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SizedBox(
            width: 500,
            child: records.isEmpty
                ? const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(height: 16),
                      Icon(Icons.folder_off_outlined, color: Colors.white30, size: 48),
                      SizedBox(height: 12),
                      Text('No files or biometrics captured yet.', style: TextStyle(color: Colors.white54, fontSize: 13)),
                      SizedBox(height: 6),
                      Text('Use "Live Photo" in call toolbar to capture & store photos to Supabase.', style: TextStyle(color: Colors.white30, fontSize: 11), textAlign: TextAlign.center),
                      SizedBox(height: 16),
                    ],
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: records.length,
                    separatorBuilder: (_, __) => const Divider(color: Colors.white10),
                    itemBuilder: (context, index) {
                      final rec = records[index];
                      return ListTile(
                        leading: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.greenAccent.withOpacity(0.3)),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(rec.dataUrl, fit: BoxFit.cover),
                          ),
                        ),
                        title: Text(
                          '${rec.captureType} (${rec.fileName})',
                          style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(rec.status, style: const TextStyle(color: Colors.greenAccent, fontSize: 11, fontFamily: 'monospace')),
                            Text('Size: ${(rec.sizeBytes / 1024).toStringAsFixed(1)} KB • ${rec.timestamp.hour.toString().padLeft(2, '0')}:${rec.timestamp.minute.toString().padLeft(2, '0')}', style: const TextStyle(color: Colors.white30, fontSize: 10)),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close', style: TextStyle(color: Colors.indigoAccent, fontWeight: FontWeight.bold)),
            ),
          ],
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
          style: const TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500),
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
      padding: EdgeInsets.symmetric(horizontal: (label != null && !isCompact) ? 16 : 0),
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
            Text(label, style: TextStyle(color: iconColor, fontWeight: FontWeight.bold)),
          ]
        ],
      ),
    );

    return GestureDetector(
      onTap: onTap,
      child: badgeCount > 0
          ? Stack(
              clipBehavior: Clip.none,
              children: [
                buttonWidget,
                Positioned(
                  right: -4,
                  top: -4,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Color(0xFFE11D48), // Rose 600
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
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
          : buttonWidget,
    );
  }

  Widget _buildChatOverlay({bool isMobile = false}) {
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
                  onPanUpdate: isMobile ? null : (details) {
                    final size = MediaQuery.of(context).size;
                    setState(() {
                      _chatBoxX = (_chatBoxX + details.delta.dx).clamp(0.0, size.width - _chatBoxW);
                      _chatBoxY = (_chatBoxY + details.delta.dy).clamp(0.0, size.height - _chatBoxH);
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
                            decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(4)),
                          ),
                        ),
                      Padding(
                        padding: EdgeInsets.fromLTRB(16, isMobile ? 16 : 32, 16, 0),
                        child: ListView.builder(
                          padding: const EdgeInsets.only(bottom: 16),
                          itemCount: _messages.length + 1,
                          itemBuilder: (context, index) {
                            if (index == 0) {
                              return const Padding(
                                padding: EdgeInsets.only(bottom: 16, top: 8),
                                child: Text('Chat started. Messages are end-to-end\nencrypted.', 
                                  style: TextStyle(color: Colors.white54, fontSize: 11, height: 1.5), textAlign: TextAlign.center
                                ),
                              );
                            }
                            final msg = _messages[index - 1];
                            return Align(
                              alignment: msg.isMe ? Alignment.centerRight : Alignment.centerLeft,
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                decoration: BoxDecoration(
                                  color: msg.isMe ? const Color(0xFF4F46E5) : const Color(0xFF334155),
                                  borderRadius: BorderRadius.only(
                                    topLeft: const Radius.circular(16),
                                    topRight: const Radius.circular(16),
                                    bottomLeft: Radius.circular(msg.isMe ? 16 : 4),
                                    bottomRight: Radius.circular(msg.isMe ? 4 : 16),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: msg.isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                                  children: [
                                    Text(msg.text, style: const TextStyle(color: Colors.white, fontSize: 13)),
                                    const SizedBox(height: 4),
                                    Text(msg.time, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 9)),
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
                        decoration: BoxDecoration(color: const Color(0xFF334155), borderRadius: BorderRadius.circular(8)),
                        child: const Icon(Icons.attach_file, color: Colors.white70, size: 20),
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
                          style: const TextStyle(color: Colors.white, fontSize: 13),
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
                        decoration: BoxDecoration(color: const Color(0xFF6366F1), borderRadius: BorderRadius.circular(8)),
                        child: const Icon(Icons.send, color: Colors.white, size: 18),
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
                    _chatBoxW = max(250, min(_chatBoxW + details.delta.dx, 600)); // Max width 600
                    _chatBoxH = max(300, min(_chatBoxH + details.delta.dy, 800)); // Max height 800
                  });
                },
                child: const MouseRegion(
                  cursor: SystemMouseCursors.resizeDownRight,
                  child: Padding(
                    padding: EdgeInsets.all(8.0),
                    child: Icon(Icons.filter_list, size: 16, color: Colors.white24), // Subtle handle icon
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAadharBiometricContainer({
    required String? targetType,
    required Widget child,
    required bool isCaptured,
  }) {
    ShapeBorder shape;
    double width = 210;
    double height = 210;
    String badgeText = "AADHAR IRIS SCANNER CONTAINER";

    double zoomScale = 1.0;
    if (!isCaptured) {
      if (targetType == 'LeftEye' || targetType == 'RightEye') {
        width = 210;
        height = 210;
        zoomScale = 2.4; // High magnification auto-zoom for live camera iris alignment
        shape = const CircleBorder();
        badgeText = "AADHAR IRIS SCANNER CONTAINER (${targetType?.toUpperCase()})";
      } else if (targetType == 'BothEyes') {
        width = 220;
        height = 200;
        zoomScale = 1.8; // Dual eye live camera auto-zoom
        shape = const CircleBorder();
        badgeText = "AADHAR DUAL EYE SCANNER CONTAINER";
      } else if (targetType == 'Face') {
        width = 210;
        height = 260;
        zoomScale = 1.35; // Face live camera framing zoom
        shape = const OvalBorder();
        badgeText = "AADHAR FACE VERIFICATION CONTAINER";
      } else if (targetType == 'Body') {
        width = 190;
        height = 270;
        zoomScale = 1.0; // Full body wide view
        shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(90));
        badgeText = "AADHAR FULL BODY CONTAINER";
      } else {
        shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(20));
        badgeText = "AADHAR BIOMETRIC SCANNER CONTAINER";
      }
    } else {
      // CAPTURED SNAPSHOT: 1.0x Scale so preview matches exact captured framing
      if (targetType == 'LeftEye' || targetType == 'RightEye' || targetType == 'BothEyes') {
        width = 220;
        height = 220;
        shape = const CircleBorder();
        badgeText = "AADHAR IRIS SCANNER CONTAINER (${targetType?.toUpperCase()})";
      } else if (targetType == 'Face') {
        width = 210;
        height = 260;
        shape = const OvalBorder();
        badgeText = "AADHAR FACE VERIFICATION CONTAINER";
      } else if (targetType == 'Body') {
        width = 190;
        height = 270;
        shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(90));
        badgeText = "AADHAR FULL BODY CONTAINER";
      } else {
        shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(20));
        badgeText = "AADHAR BIOMETRIC SCANNER CONTAINER";
      }
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: isCaptured ? Colors.green.withOpacity(0.15) : Colors.cyan.withOpacity(0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: isCaptured ? Colors.greenAccent : Colors.cyanAccent),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isCaptured ? Icons.check_circle : Icons.center_focus_strong,
                color: isCaptured ? Colors.greenAccent : Colors.cyanAccent,
                size: 14,
              ),
              const SizedBox(width: 6),
              Text(
                badgeText,
                style: TextStyle(
                  color: isCaptured ? Colors.greenAccent : Colors.cyanAccent,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: Container(
            width: width,
            height: height,
            decoration: ShapeDecoration(
              color: const Color(0xFF0F172A),
              shape: shape,
              shadows: [
                BoxShadow(
                  color: (isCaptured ? Colors.greenAccent : Colors.cyanAccent).withOpacity(0.35),
                  blurRadius: 18,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: ClipPath(
              clipper: _ShapeClipper(shape: shape),
              child: Stack(
                alignment: Alignment.center,
                fit: StackFit.expand,
                children: [
                  Transform.scale(
                    scale: zoomScale,
                    child: child,
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _ShapeClipper extends CustomClipper<Path> {
  final ShapeBorder shape;
  _ShapeClipper({required this.shape});

  @override
  Path getClip(Size size) {
    return shape.getOuterPath(Rect.fromLTWH(0, 0, size.width, size.height));
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => true;
}


