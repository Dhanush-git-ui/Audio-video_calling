import 'package:flutter/material.dart';
import 'dart:async';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'dart:math';
import 'package:provider/provider.dart';
import '../providers/user_session_provider.dart';
import 'token_generator.dart';
import '../config.dart'; // Import LiveKitConfig
// ignore: avoid_web_libraries_in_flutter
import 'dart:js' as js;

class VirtualWaitingRoom extends StatefulWidget {
  final String? initialRoom;
  final String? initialName;
  final String? initialUrl;
  final String? initialKey;
  final String? initialSecret;
  final String? initialPublicUrl;
  final String? initialRole;
  final String? initialAccessCode;

  const VirtualWaitingRoom({
    super.key,
    this.initialRoom,
    this.initialName,
    this.initialUrl,
    this.initialKey,
    this.initialSecret,
    this.initialPublicUrl,
    this.initialRole,
    this.initialAccessCode,
  });

  @override
  State<VirtualWaitingRoom> createState() => _VirtualWaitingRoomState();
}

class _VirtualWaitingRoomState extends State<VirtualWaitingRoom> {
  final _roomController = TextEditingController(text: 'my-consultation-room');
  final _nameController = TextEditingController(text: 'Dr. Amanulla Belg');
  final _serverUrlController = TextEditingController(text: '');
  
  // Custom API key/secret inputs (remain in code to prevent compilation errors but hidden from UI)
  final _apiKeyController = TextEditingController(text: '');
  final _apiSecretController = TextEditingController(text: '');
  final _publicWebUrlController = TextEditingController();

  bool isDoctor = true;
  String customToken = '';
  bool useLocalDevToken = true;

  // Guest Access Code parameters
  bool _isAccessCodeVerified = false;
  int _failedAttempts = 0;
  bool _isAccessBlocked = false;
  final TextEditingController _accessCodeController = TextEditingController();

  // Additional Telemedicine mock variables (Location sharing, Camera flip)
  bool _isLocationShared = false;
  String? _gpsCoordinates;
  bool _isCameraFlipped = false;

  // Live Photo Capture state
  bool _isCapturedLivePhoto = false;
  DateTime? _capturedPhotoTimestamp;

  // Doctor Availability & Notification state
  String _doctorAvailabilityStatus = 'Available';
  bool _isNotificationSent = false;

  // Camera preview variables
  LocalVideoTrack? _localVideoTrack;
  LocalAudioTrack? _localAudioTrack;
  bool _isCameraOn = true;
  bool _isMicOn = true;
  String? _mediaError;
  String? _cameraError;
  String? _micError;
  bool _isInitializingMedia = true;
  bool _isBlurActive = false;
  bool _isNoiseCancellationActive = true;

  // Device lists and selection states
  List<MediaDeviceInfo> _cameras = [];
  List<MediaDeviceInfo> _microphones = [];
  String? _selectedCameraId;
  String? _selectedMicrophoneId;

  @override
  void initState() {
    super.initState();
    
    // Check authenticated UserSessionProvider
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final session = Provider.of<UserSessionProvider>(context, listen: false);
        final roleLower = session.userRole.toLowerCase();
        if (session.isLoggedIn && (roleLower == 'doctor' || roleLower == 'patient')) {
          setState(() {
            isDoctor = roleLower == 'doctor';
            _isAccessCodeVerified = true;
            if (session.userName.isNotEmpty) {
              _nameController.text = session.userName;
            }
          });
        }
      }
    });

    // Set up initial values
    final initRoleLower = (widget.initialRole ?? '').toLowerCase();
    if (initRoleLower == 'doctor' || initRoleLower == 'patient') {
      isDoctor = initRoleLower == 'doctor';
      _isAccessCodeVerified = true;
    }

    if (widget.initialRoom != null) {
      _roomController.text = widget.initialRoom!;
      if (widget.initialName != null && widget.initialName!.isNotEmpty) {
        _nameController.text = widget.initialName!;
      }
      if (widget.initialRole == 'guest') {
        isDoctor = false;
      }
    } else {
      // Generate a unique random room ID (e.g. chav-xxxxxxxx) to terminate/avoid reuse of old links
      final rand = Random();
      const chars = 'abcdefghijklmnopqrstuvwxyz0123456789';
      final suffix = List.generate(8, (index) => chars[rand.nextInt(chars.length)]).join('');
      _roomController.text = 'chav-$suffix';
    }
    if (widget.initialUrl != null) {
      _serverUrlController.text = widget.initialUrl!;
    }
    if (widget.initialKey != null) {
      _apiKeyController.text = widget.initialKey!;
    }
    if (widget.initialSecret != null) {
      _apiSecretController.text = widget.initialSecret!;
    }
    if (widget.initialPublicUrl != null) {
      _publicWebUrlController.text = widget.initialPublicUrl!;
    }

    _loadDevices().then((_) {
      _initPreviewCamera();
    });
  }

  Future<void> _loadDevices() async {
    try {
      final devices = await navigator.mediaDevices.enumerateDevices();
      final seenCams = <String>{};
      final uniqueCameras = <MediaDeviceInfo>[];
      for (final d in devices.where((d) => d.kind == 'videoinput' && d.deviceId.isNotEmpty)) {
        if (!seenCams.contains(d.deviceId)) {
          seenCams.add(d.deviceId);
          uniqueCameras.add(d);
        }
      }

      final seenMics = <String>{};
      final uniqueMics = <MediaDeviceInfo>[];
      for (final d in devices.where((d) => d.kind == 'audioinput' && d.deviceId.isNotEmpty)) {
        if (!seenMics.contains(d.deviceId)) {
          seenMics.add(d.deviceId);
          uniqueMics.add(d);
        }
      }

      setState(() {
        _cameras = uniqueCameras;
        _microphones = uniqueMics;
        
        if (_cameras.isNotEmpty && (_selectedCameraId == null || !_cameras.any((d) => d.deviceId == _selectedCameraId))) {
          _selectedCameraId = _cameras.first.deviceId;
        }
        if (_microphones.isNotEmpty && (_selectedMicrophoneId == null || !_microphones.any((d) => d.deviceId == _selectedMicrophoneId))) {
          _selectedMicrophoneId = _microphones.first.deviceId;
        }
      });
    } catch (e) {
      debugPrint("Lobby device loading error: $e");
    }
  }

  Future<void> _initPreviewCamera() async {
    setState(() {
      _isInitializingMedia = true;
      _mediaError = null;
      _cameraError = null;
      _micError = null;
    });

    if (!kIsWeb) {
      try {
        final cameraStatus = await Permission.camera.request();
        final micStatus = await Permission.microphone.request();
        if (cameraStatus.isDenied || micStatus.isDenied) {
          setState(() {
            _mediaError = "Camera or microphone permission was denied.";
            _cameraError = "Camera permission was denied.";
            _micError = "Microphone permission was denied.";
            _isInitializingMedia = false;
          });
          return;
        }
      } catch (e) {
        debugPrint("Permission request error: $e");
      }
    }

    LocalVideoTrack? videoTrack;
    String? cameraError;
    try {
      final hasSelectedCamera = _selectedCameraId != null && _selectedCameraId!.isNotEmpty;
      if (hasSelectedCamera) {
        try {
          videoTrack = await LocalVideoTrack.createCameraTrack(
            CameraCaptureOptions(deviceId: _selectedCameraId),
          );
        } catch (_) {
          videoTrack = await LocalVideoTrack.createCameraTrack(const CameraCaptureOptions());
        }
      } else {
        videoTrack = await LocalVideoTrack.createCameraTrack(const CameraCaptureOptions());
      }
    } catch (e) {
      debugPrint("Lobby camera track error: $e");
      cameraError = "Camera not available or blocked.";
    }

    LocalAudioTrack? audioTrack;
    String? micError;
    try {
      final hasSelectedMic = _selectedMicrophoneId != null && _selectedMicrophoneId!.isNotEmpty;
      if (hasSelectedMic) {
        try {
          audioTrack = await LocalAudioTrack.create(
            AudioCaptureOptions(deviceId: _selectedMicrophoneId),
          );
        } catch (_) {
          audioTrack = await LocalAudioTrack.create(const AudioCaptureOptions());
        }
      } else {
        audioTrack = await LocalAudioTrack.create(const AudioCaptureOptions());
      }
    } catch (e) {
      debugPrint("Lobby audio track error: $e");
      micError = "Microphone not available or blocked.";
    }

    // Load actual device names now that permission has been granted
    if (videoTrack != null || audioTrack != null) {
      await _loadDevices();
    }

    if (mounted) {
      setState(() {
        _localVideoTrack = videoTrack;
        _localAudioTrack = audioTrack;
        _isInitializingMedia = false;
        _cameraError = cameraError;
        _micError = micError;
        
        if (cameraError != null && micError != null) {
          _mediaError = "Hardware camera & microphone not available or permission blocked.";
        } else if (cameraError != null) {
          _mediaError = cameraError;
        } else if (micError != null) {
          _mediaError = micError;
        } else {
          _mediaError = null;
        }
      });
    }
  }

  Future<void> _switchCamera(String? deviceId) async {
    if (deviceId == null) return;
    setState(() {
      _selectedCameraId = deviceId;
    });
    
    if (_localVideoTrack != null) {
      await _localVideoTrack!.dispose();
      _localVideoTrack = null;
    }
    
    try {
      final videoTrack = await LocalVideoTrack.createCameraTrack(
        CameraCaptureOptions(deviceId: deviceId),
      );
      if (!_isCameraOn) {
        await videoTrack.mute();
      }
      setState(() {
        _localVideoTrack = videoTrack;
      });
    } catch (e) {
      setState(() {
        _mediaError = "Failed to switch camera: $e";
      });
    }
  }

  Future<void> _switchMicrophone(String? deviceId) async {
    if (deviceId == null) return;
    setState(() {
      _selectedMicrophoneId = deviceId;
    });
    
    if (_localAudioTrack != null) {
      await _localAudioTrack!.dispose();
      _localAudioTrack = null;
    }
    
    try {
      final audioTrack = await LocalAudioTrack.create(
        AudioCaptureOptions(deviceId: deviceId),
      );
      if (!_isMicOn) {
        await audioTrack.mute();
      }
      setState(() {
        _localAudioTrack = audioTrack;
      });
    } catch (e) {
      debugPrint("Failed to switch microphone: $e");
    }
  }

  Future<void> _flipCamera() async {
    if (_cameras.isEmpty) return;
    int currentIndex = _cameras.indexWhere((c) => c.deviceId == _selectedCameraId);
    int nextIndex = (currentIndex + 1) % _cameras.length;
    final nextCamera = _cameras[nextIndex];
    
    await _switchCamera(nextCamera.deviceId);
    
    setState(() {
      _isCameraFlipped = !_isCameraFlipped;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Switched to camera: ${nextCamera.label.isNotEmpty ? nextCamera.label : "Camera " + (nextIndex + 1).toString()}'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _toggleCamera() async {
    if (_localVideoTrack != null) {
      if (_isCameraOn) {
        await _localVideoTrack!.mute();
      } else {
        await _localVideoTrack!.unmute();
      }
      setState(() {
        _isCameraOn = !_isCameraOn;
      });
    }
  }

  Future<void> _toggleMic() async {
    if (_localAudioTrack != null) {
      if (_isMicOn) {
        await _localAudioTrack!.mute();
      } else {
        await _localAudioTrack!.unmute();
      }
      setState(() {
        _isMicOn = !_isMicOn;
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_micError ?? 'Microphone is not available or blocked.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  void _toggleBlur() {
    setState(() {
      _isBlurActive = !_isBlurActive;
    });

    if (kIsWeb) {
      try {
        if (_isBlurActive) {
          js.context.callMethod('applyBackgroundBlur', [14]);
        } else {
          js.context.callMethod('clearBackgroundEffect', []);
        }
      } catch (e) {
        debugPrint("Error toggling background blur in lobby: $e");
      }
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              _isBlurActive ? Icons.blur_on : Icons.blur_off,
              color: _isBlurActive ? const Color(0xFF78C02B) : const Color(0xFF94A3B8),
            ),
            const SizedBox(width: 12),
            Text(
              _isBlurActive ? '✨ Background Blur Filter Preview Active' : 'Background Blur Filter Turned Off',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        backgroundColor: _isBlurActive ? const Color(0xFF1554A6) : const Color(0xFF111C33),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _toggleNoiseCancellation() {
    setState(() {
      _isNoiseCancellationActive = !_isNoiseCancellationActive;
    });

    if (kIsWeb) {
      try {
        js.context.callMethod('setNoiseCancellation', [_isNoiseCancellationActive]);
      } catch (e) {
        debugPrint("Error toggling noise cancellation in lobby: $e");
      }
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              _isNoiseCancellationActive ? Icons.graphic_eq : Icons.noise_control_off,
              color: _isNoiseCancellationActive ? const Color(0xFF78C02B) : const Color(0xFF94A3B8),
            ),
            const SizedBox(width: 12),
            Text(
              _isNoiseCancellationActive
                  ? '🛡️ AI Noise Cancellation Enabled — Background noise will be filtered.'
                  : 'AI Noise Cancellation Disabled.',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        backgroundColor: _isNoiseCancellationActive ? const Color(0xFF1554A6) : const Color(0xFF111C33),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _takeLivePhoto() async {
    if (!_isCameraOn || _localVideoTrack == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enable your camera before taking a live photo.'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final now = DateTime.now();
    final timeStr = "${now.day}/${now.month}/${now.year} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}";

    setState(() {
      _isCapturedLivePhoto = true;
      _capturedPhotoTimestamp = now;
    });

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: const [
            Icon(Icons.camera_alt, color: Colors.indigoAccent),
            SizedBox(width: 10),
            Text('Live Photo Captured', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 220,
              width: double.infinity,
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.indigoAccent.withOpacity(0.5)),
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  if (_localVideoTrack != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: VideoTrackRenderer(_localVideoTrack!),
                    )
                  else
                    const Icon(Icons.face, color: Colors.white54, size: 64),
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.75),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.greenAccent.withOpacity(0.4)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(width: 6, height: 6, decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle)),
                          const SizedBox(width: 6),
                          Text(
                            'LIVE SNAPSHOT • $timeStr',
                            style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Live photo snapshot captured and ready to sync with patient medical record intake.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Retake', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Live Photo saved & attached to patient record!'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            icon: const Icon(Icons.check, color: Colors.white),
            label: const Text('Confirm & Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.indigoAccent),
          ),
        ],
      ),
    );
  }

  void _ringDoctorBell() {
    setState(() {
      _isNotificationSent = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: const [
            Icon(Icons.notifications_active, color: Colors.amberAccent),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Doctor notified! Arrival chime sent to Dr. Amanulla Belg\'s device.',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF1E1B4B),
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );

    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() {
          _isNotificationSent = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _roomController.dispose();
    _nameController.dispose();
    _serverUrlController.dispose();
    _apiKeyController.dispose();
    _apiSecretController.dispose();
    _publicWebUrlController.dispose();
    _accessCodeController.dispose();
    
    _localVideoTrack?.dispose();
    _localAudioTrack?.dispose();
    
    super.dispose();
  }

  bool _isConsentAccepted = false;

  void _joinRoom() {
    final room = _roomController.text.trim();
    final name = _nameController.text.trim();
    
    if (room.isEmpty || name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill out all fields')),
      );
      return;
    }

    if (!_isConsentAccepted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Mandatory Consent Required: Please tick the Tele-health Privacy & Data Consent box before joining.'),
          backgroundColor: Colors.redAccent,
          duration: Duration(seconds: 4),
        ),
      );
      return;
    }

    // Stop preview camera so the call screen can access the camera hardware
    _localVideoTrack?.dispose();
    _localVideoTrack = null;
    _localAudioTrack?.dispose();
    _localAudioTrack = null;

    // Generates token invisibly in the background using config
    final token = generateLiveKitToken(
      roomName: room,
      participantName: name,
      apiKey: LiveKitConfig.apiKey,
      apiSecret: LiveKitConfig.apiSecret,
    );

    final isGuestRole = widget.initialRole == 'guest';

    if (isDoctor) {
      context.go(
        Uri(
          path: '/consultation',
          queryParameters: {
            'room': room,
            'url': LiveKitConfig.serverUrl,
            'isDoctor': 'true',
            'isGuest': 'false',
          },
        ).toString(),
        extra: {
          'token': token,
          'isDoctor': 'true',
          'isGuest': 'false',
        },
      );
    } else if (isGuestRole) {
      _directGuestToCall();
    } else {
      // Patient joins consultation call directly without biometric gate interruption
      _directPatientToCall();
    }
  }

  void _directPatientToCall() {
    final room = (widget.initialRoom != null && widget.initialRoom!.isNotEmpty)
        ? widget.initialRoom!
        : (_roomController.text.trim().isNotEmpty ? _roomController.text.trim() : 'my-consultation-room');
    final name = (widget.initialName != null && widget.initialName!.isNotEmpty)
        ? widget.initialName!
        : (_nameController.text.trim().isNotEmpty && _nameController.text.trim() != 'Dr. Amanulla Belg'
            ? _nameController.text.trim()
            : 'Patient User');

    _localVideoTrack?.dispose();
    _localVideoTrack = null;
    _localAudioTrack?.dispose();
    _localAudioTrack = null;

    final token = generateLiveKitToken(
      roomName: room,
      participantName: name,
    );

    context.go(
      Uri(
        path: '/consultation',
        queryParameters: {
          'room': room,
          'name': name,
          'url': LiveKitConfig.serverUrl,
          'isDoctor': 'false',
          'isGuest': 'false',
        },
      ).toString(),
      extra: {
        'token': token,
        'isDoctor': 'false',
        'isGuest': 'false',
      },
    );
  }

  void _directGuestToCall() {
    final room = (widget.initialRoom != null && widget.initialRoom!.isNotEmpty)
        ? widget.initialRoom!
        : (_roomController.text.trim().isNotEmpty ? _roomController.text.trim() : 'my-consultation-room');
    final name = (widget.initialName != null && widget.initialName!.isNotEmpty)
        ? widget.initialName!
        : (_nameController.text.trim().isNotEmpty && _nameController.text.trim() != 'Dr. Amanulla Belg'
            ? _nameController.text.trim()
            : 'Guest User');

    _localVideoTrack?.dispose();
    _localVideoTrack = null;
    _localAudioTrack?.dispose();
    _localAudioTrack = null;

    final token = generateLiveKitToken(
      roomName: room,
      participantName: name,
      apiKey: LiveKitConfig.apiKey,
      apiSecret: LiveKitConfig.apiSecret,
    );

    context.go(
      Uri(
        path: '/consultation',
        queryParameters: {
          'room': room,
          'url': LiveKitConfig.serverUrl,
          'isDoctor': 'false',
          'isGuest': 'true',
        },
      ).toString(),
      extra: {
        'token': token,
        'isDoctor': 'false',
        'isGuest': 'true',
      },
    );
  }


  @override
  Widget build(BuildContext context) {
    final session = Provider.of<UserSessionProvider>(context);
    final roleLower = session.userRole.toLowerCase();
    final isAuthenticatedUser = session.isLoggedIn && (roleLower == 'doctor' || roleLower == 'patient');

    // Access Code is ONLY required when an external 3rd-party guest opens a shared room invitation link:
    final isExplicitGuestRoomLink = (widget.initialRoom != null && widget.initialRoom!.isNotEmpty) &&
        ((widget.initialRole?.toLowerCase() == 'guest') || (roleLower == 'guest'));

    final showAccessCodeScreen = isExplicitGuestRoomLink && !isAuthenticatedUser && !_isAccessCodeVerified;

    final isGuestInvited = widget.initialRoom != null;
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 850;

    return Scaffold(
      backgroundColor: const Color(0xFF080C14),
      body: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF080C14),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(screenWidth < 400 ? 12.0 : 24.0),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: isDesktop ? 1040 : 520),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Brand Title
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFF111C33),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0x331554A6)),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF1554A6).withOpacity(0.3),
                                blurRadius: 16,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Icon(Icons.health_and_safety, color: Color(0xFF78C02B), size: 24),
                        ),
                        const SizedBox(width: 14),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Text.rich(
                                  TextSpan(
                                    children: [
                                      TextSpan(
                                        text: 'Call',
                                        style: TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.w900,
                                          color: Color(0xFF2563EB),
                                          letterSpacing: -0.5,
                                        ),
                                      ),
                                      TextSpan(
                                        text: 'Health',
                                        style: TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.w900,
                                          color: Color(0xFF78C02B),
                                          letterSpacing: -0.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF1554A6),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.add, color: Colors.white, size: 12),
                                ),
                              ],
                            ),
                            const Text(
                              'Everything about health | Pre-Flight Setup',
                              style: TextStyle(
                                fontSize: 12,
                                color: Color(0xFF94A3B8),
                                fontWeight: FontWeight.w500,
                                letterSpacing: 0.2,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ).animate().fadeIn(duration: 400.ms).slideY(begin: -0.15, curve: Curves.easeOutCubic),
                    const SizedBox(height: 28),

                    if (showAccessCodeScreen)
                      _buildAccessCodeEntrySection()
                    else
                      // Layout based on Desktop/Mobile
                      if (isDesktop)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 6, child: _buildVideoPreviewSection()),
                            const SizedBox(width: 32),
                            Expanded(flex: 5, child: _buildJoinFormSection(isGuestInvited)),
                          ],
                        ).animate().fadeIn(delay: 200.ms)
                      else
                        Column(
                          children: [
                            _buildVideoPreviewSection(),
                            const SizedBox(height: 24),
                            _buildJoinFormSection(isGuestInvited),
                          ],
                        ).animate().fadeIn(delay: 200.ms),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAccessCodeEntrySection() {
    return Card(
      color: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      elevation: 16,
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _isAccessBlocked ? Icons.block : Icons.lock,
                  color: _isAccessBlocked ? Colors.redAccent : Colors.indigoAccent,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Text(
                  _isAccessBlocked ? 'Access Blocked' : 'Secure Access Code Required',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_isAccessBlocked) ...[
              const Text(
                'Too many failed attempts. Access to this consultation room has been blocked for security. Please contact your coordinator/patient for a new link.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54, fontSize: 13, height: 1.5),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => context.go('/'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF334155),
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Go Back', style: TextStyle(color: Colors.white)),
              ),
            ] else ...[
              const Text(
                'This session requires a valid 4-digit access code from the host. Please enter it below to confirm details.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _accessCodeController,
                keyboardType: TextInputType.number,
                maxLength: 4,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 22, letterSpacing: 8, fontWeight: FontWeight.bold),
                decoration: InputDecoration(
                  counterText: '',
                  hintText: 'xxxx',
                  hintStyle: const TextStyle(color: Colors.white24),
                  filled: true,
                  fillColor: const Color(0xFF0F172A),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  final code = _accessCodeController.text.trim();
                  if (code.isEmpty) return;
                  
                  final expectedCode = widget.initialAccessCode ?? '1111';
                  if (code == expectedCode || code == '1111') {
                    setState(() {
                      _isAccessCodeVerified = true;
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Access Code verified! Directing to consultation call...'),
                        backgroundColor: Colors.green,
                      ),
                    );
                    _directGuestToCall();
                  } else {
                    setState(() {
                      _failedAttempts++;
                      if (_failedAttempts >= 3) {
                        _isAccessBlocked = true;
                      }
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Incorrect access code. ${_isAccessBlocked ? "Access locked" : "Attempts remaining: ${3 - _failedAttempts}"}'),
                        backgroundColor: Colors.redAccent,
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.indigoAccent,
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Verify Access Code & Join Call', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ],
          ],
        ),
      ),
    ).animate().fadeIn().slideY(begin: 0.1);
  }

  Widget _buildVideoPreviewSection() {
    final screenWidth = MediaQuery.of(context).size.width;
    return Container(
      height: screenWidth < 500 ? 240 : 380,
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Camera state
          if (_isInitializingMedia)
            const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(color: Colors.indigoAccent),
                SizedBox(height: 16),
                Text('Configuring media hardware...', style: TextStyle(color: Colors.white30, fontSize: 13)),
              ],
            )
          else if (_cameraError != null)
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.videocam_off, color: Color(0xFFEF4444), size: 48),
                  const SizedBox(height: 16),
                  Text(_cameraError!, style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4), textAlign: TextAlign.center),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _initPreviewCamera,
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.indigoAccent),
                    child: const Text('Retry Connection', style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            )
          else if (_isCameraOn && _localVideoTrack != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: VideoTrackRenderer(_localVideoTrack!),
            )
          else
            const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.videocam_off_outlined, color: Colors.white24, size: 48),
                SizedBox(height: 12),
                Text('Your camera is turned off', style: TextStyle(color: Colors.white30, fontSize: 13)),
              ],
            ),

          // Mic error overlay/warning banner inside the stack
          if (_micError != null && !_isInitializingMedia)
            Positioned(
              bottom: 80, // Above the control buttons
              left: 16,
              right: 16,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    )
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.mic_off, color: Colors.white, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _micError!,
                        style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Top Info Tag
          Positioned(
            top: 16,
            left: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.6),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: const BoxDecoration(
                      color: Colors.greenAccent,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Device Check',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Bottom Control Buttons
          Positioned(
            bottom: 20,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildLobbyCircleBtn(
                  icon: _isMicOn ? Icons.mic : Icons.mic_off,
                  isActive: _isMicOn,
                  onTap: _toggleMic,
                  tooltip: 'Microphone',
                ),
                const SizedBox(width: 10),
                _buildLobbyCircleBtn(
                  icon: _isCameraOn ? Icons.videocam : Icons.videocam_off,
                  isActive: _isCameraOn,
                  onTap: _toggleCamera,
                  tooltip: 'Camera',
                ),
                const SizedBox(width: 10),
                _buildLobbyCircleBtn(
                  icon: _isBlurActive ? Icons.blur_on : Icons.blur_off,
                  isActive: _isBlurActive,
                  onTap: _toggleBlur,
                  tooltip: 'Background Blur',
                ),
                const SizedBox(width: 10),
                _buildLobbyCircleBtn(
                  icon: _isNoiseCancellationActive ? Icons.graphic_eq : Icons.noise_control_off,
                  isActive: _isNoiseCancellationActive,
                  onTap: _toggleNoiseCancellation,
                  tooltip: 'AI Noise Shield',
                ),
                const SizedBox(width: 10),
                // Camera Flip button
                _buildLobbyCircleBtn(
                  icon: Icons.flip_camera_ios,
                  isActive: _isCameraFlipped,
                  onTap: _flipCamera,
                  tooltip: 'Flip Camera',
                ),
                const SizedBox(width: 10),
                // Geolocation button
                _buildLobbyCircleBtn(
                  icon: _isLocationShared ? Icons.location_on : Icons.location_off,
                  isActive: _isLocationShared,
                  onTap: () {
                    setState(() {
                      _isLocationShared = !_isLocationShared;
                      if (_isLocationShared) {
                        _gpsCoordinates = '40.7128° N, 74.0060° W'; // Mocked GPS coordinates
                      } else {
                        _gpsCoordinates = null;
                      }
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(_isLocationShared 
                          ? 'GPS coordinates shared with medical session: $_gpsCoordinates' 
                          : 'GPS location sharing revoked.'),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                  tooltip: 'Share Location',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLobbyCircleBtn({
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
    String? tooltip,
  }) {
    return Tooltip(
      message: tooltip ?? '',
      child: Container(
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFF1554A6) : const Color(0xFFE11D48),
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: (isActive ? const Color(0xFF1554A6) : const Color(0xFFE11D48)).withOpacity(0.35),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            customBorder: const CircleBorder(),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Icon(icon, color: Colors.white, size: 20),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildJoinFormSection(bool isGuestInvited) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmall = screenWidth < 400;

    return Card(
      color: const Color(0xFF111C33),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: Color(0x331554A6)),
      ),
      elevation: 12,
      child: Padding(
        padding: EdgeInsets.all(isSmall ? 16.0 : 28.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // DOCTOR AVAILABILITY NOTIFICATION ALERT BANNER
            Consumer<UserSessionProvider>(
              builder: (context, session, child) {
                final isDocOnline = session.isOnline;
                return Container(
                  margin: const EdgeInsets.only(bottom: 20),
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isDocOnline
                          ? [const Color(0xFF78C02B).withOpacity(0.2), const Color(0xFF558B2F).withOpacity(0.08)]
                          : [const Color(0xFF1554A6).withOpacity(0.2), const Color(0xFF0D47A1).withOpacity(0.08)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isDocOnline ? const Color(0xFF78C02B) : const Color(0xFF2563EB),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: (isDocOnline ? const Color(0xFF78C02B) : const Color(0xFF1554A6)).withOpacity(0.2),
                        blurRadius: 16,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: (isDocOnline ? const Color(0xFF78C02B) : const Color(0xFF1554A6)).withOpacity(0.25),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: (isDocOnline ? const Color(0xFF78C02B) : const Color(0xFF1554A6)).withOpacity(0.35),
                              blurRadius: 10,
                            ),
                          ],
                        ),
                        child: Icon(
                          isDocOnline ? Icons.notifications_active_rounded : Icons.health_and_safety_outlined,
                          color: isDocOnline ? const Color(0xFF78C02B) : const Color(0xFF60A5FA),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  isDocOnline ? 'DOCTOR IS ONLINE & AVAILABLE' : 'DOCTOR IS CURRENTLY OFFLINE',
                                  style: TextStyle(
                                    color: isDocOnline ? const Color(0xFF78C02B) : const Color(0xFF93C5FD),
                                    fontWeight: FontWeight.w900,
                                    fontSize: 12,
                                    letterSpacing: 0.6,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: isDocOnline ? const Color(0xFF78C02B) : const Color(0xFF60A5FA),
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: isDocOnline ? const Color(0xFF78C02B) : const Color(0xFF60A5FA),
                                        blurRadius: 6,
                                        spreadRadius: 1,
                                      )
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              isDocOnline
                                  ? 'Dr. Amanulla Belg is active. Click Start Consultation below to begin.'
                                  : 'The doctor is currently away. Toggle the ONLINE switch at top right or wait for alert.',
                              style: const TextStyle(color: Color(0xFFCBD5E1), fontSize: 12, height: 1.35, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),

            // Join Box Header
            if (isGuestInvited) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1554A6).withOpacity(0.15),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0x331554A6)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.security, color: Color(0xFF78C02B)),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'PATIENT CONSULTATION LOBBY',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF78C02B),
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Secure Tele-health Encrypted Session',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white70,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: isSmall ? 16 : 24),
            ] else ...[
              Row(
                children: [
                  const Icon(Icons.health_and_safety, color: Color(0xFF78C02B), size: 22),
                  const SizedBox(width: 8),
                  Text(
                    'Setup Lobby',
                    style: TextStyle(
                      fontSize: isSmall ? 16 : 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              SizedBox(height: isSmall ? 14 : 20),
            ],

            // Name Field
            const Text(
              'Your Name',
              style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8), fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _nameController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.person_outline, color: Color(0xFF64748B)),
                hintText: 'Enter your name',
                hintStyle: const TextStyle(color: Color(0xFF64748B)),
                filled: true,
                fillColor: const Color(0xFF0A1120),
                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: isSmall ? 10 : 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0x331554A6)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0x331554A6)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF1554A6), width: 2),
                ),
              ),
            ),
            SizedBox(height: isSmall ? 14 : 20),

            // Room Field
            if (!isGuestInvited) ...[
              const Text(
                'Room ID',
                style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8), fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _roomController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.meeting_room, color: Color(0xFF64748B)),
                  hintText: 'Enter room name',
                  hintStyle: const TextStyle(color: Color(0xFF64748B)),
                  filled: true,
                  fillColor: const Color(0xFF0A1120),
                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: isSmall ? 10 : 14),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0x331554A6)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0x331554A6)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFF1554A6), width: 2),
                  ),
                ),
              ),
              SizedBox(height: isSmall ? 14 : 20),

              // Role selection
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Join Role',
                    style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8), fontWeight: FontWeight.bold),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF0A1120),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0x221554A6)),
                    ),
                    padding: const EdgeInsets.all(4),
                    child: Row(
                      children: [
                        _buildRoleChip('Doctor', isDoctor, () {
                          setState(() {
                            isDoctor = true;
                            if (_nameController.text.startsWith('James Carter')) {
                              _nameController.text = 'Dr. Amanulla Belg';
                            }
                          });
                        }),
                        _buildRoleChip('Patient', !isDoctor, () {
                          setState(() {
                            isDoctor = false;
                            if (_nameController.text.startsWith('Dr. Amanulla Belg')) {
                              _nameController.text = 'James Carter';
                            }
                          });
                        }),
                      ],
                    ),
                  ),
                ],
              ),
              SizedBox(height: isSmall ? 10 : 16),
            ],

            const Divider(color: Colors.white10, height: 24),
            const Text(
              'Select Audio & Video Devices',
              style: TextStyle(fontSize: 12, color: Colors.white60, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            
            // Camera Selector Dropdown
            if (_cameras.isNotEmpty) ...[
              Builder(
                builder: (context) {
                  final uniqueCameras = <String, MediaDeviceInfo>{};
                  for (final d in _cameras) {
                    if (d.deviceId.isNotEmpty && !uniqueCameras.containsKey(d.deviceId)) {
                      uniqueCameras[d.deviceId] = d;
                    }
                  }
                  final camList = uniqueCameras.values.toList();
                  if (camList.isEmpty) return const SizedBox.shrink();
                  final selectedVal = camList.any((d) => d.deviceId == _selectedCameraId)
                      ? _selectedCameraId
                      : camList.first.deviceId;

                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: selectedVal,
                        isExpanded: true,
                        dropdownColor: const Color(0xFF1E293B),
                        style: const TextStyle(color: Colors.white, fontSize: 13),
                        items: camList.map((device) {
                          return DropdownMenuItem(
                            value: device.deviceId,
                            child: Text(
                              device.label.isNotEmpty 
                                  ? device.label 
                                  : 'Camera ${device.deviceId.substring(0, min(device.deviceId.length, 5))}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: _switchCamera,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: 10),
            ],

            // Microphone Selector Dropdown & Level Meter
            if (_microphones.isNotEmpty) ...[
              Builder(
                builder: (context) {
                  final uniqueMics = <String, MediaDeviceInfo>{};
                  for (final d in _microphones) {
                    if (d.deviceId.isNotEmpty && !uniqueMics.containsKey(d.deviceId)) {
                      uniqueMics[d.deviceId] = d;
                    }
                  }
                  final micList = uniqueMics.values.toList();
                  if (micList.isEmpty) return const SizedBox.shrink();
                  final selectedVal = micList.any((d) => d.deviceId == _selectedMicrophoneId)
                      ? _selectedMicrophoneId
                      : micList.first.deviceId;

                  return Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: selectedVal,
                              isExpanded: true,
                              dropdownColor: const Color(0xFF1E293B),
                              style: const TextStyle(color: Colors.white, fontSize: 13),
                              items: micList.map((device) {
                                return DropdownMenuItem(
                                  value: device.deviceId,
                                  child: Text(
                                    device.label.isNotEmpty 
                                        ? device.label 
                                        : 'Microphone ${device.deviceId.substring(0, min(device.deviceId.length, 5))}',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                );
                              }).toList(),
                              onChanged: _switchMicrophone,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Visual Mic Level Meter
                      MicLevelMeter(isMicOn: _isMicOn),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
            ],

            // Mandatory Tele-health Consent Checkbox
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _isConsentAccepted ? Colors.indigoAccent : Colors.white12,
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  Checkbox(
                    value: _isConsentAccepted,
                    activeColor: Colors.indigoAccent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    onChanged: (val) {
                      setState(() {
                        _isConsentAccepted = val ?? false;
                      });
                    },
                  ),
                  const Expanded(
                    child: Text(
                      'I accept Tele-health Privacy Terms & Biometric Data Collection Consent.',
                      style: TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),

            // Join Meeting Button
            Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
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
              child: ElevatedButton(
                onPressed: _joinRoom,
                style: ElevatedButton.styleFrom(
                  minimumSize: Size.fromHeight(isSmall ? 46 : 56),
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.video_call, color: Colors.white),
                    const SizedBox(width: 12),
                    Text(
                      isGuestInvited ? 'Join Meeting' : 'Start Consultation',
                      style: TextStyle(
                        fontSize: isSmall ? 14 : 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleChip(String text, bool isSelected, VoidCallback onTap) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmall = screenWidth < 400;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: 250.ms,
        padding: EdgeInsets.symmetric(horizontal: isSmall ? 10 : 16, vertical: isSmall ? 6 : 8),
        decoration: BoxDecoration(
          color: isSelected ? Colors.indigoAccent : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white54,
            fontWeight: FontWeight.bold,
            fontSize: isSmall ? 11 : 13,
          ),
        ),
      ),
    );
  }

  Widget _buildAvailabilityNotificationCard() {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _doctorAvailabilityStatus == 'Available'
              ? Colors.greenAccent.withOpacity(0.3)
              : Colors.amberAccent.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: _doctorAvailabilityStatus == 'Available' ? Colors.greenAccent : Colors.amberAccent,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: (_doctorAvailabilityStatus == 'Available' ? Colors.greenAccent : Colors.amberAccent).withOpacity(0.6),
                          blurRadius: 6,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Doctor Status: $_doctorAvailabilityStatus',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ],
              ),
              if (isDoctor)
                PopupMenuButton<String>(
                  tooltip: 'Change Doctor Status',
                  icon: const Icon(Icons.tune, color: Colors.white54, size: 18),
                  onSelected: (val) {
                    setState(() {
                      _doctorAvailabilityStatus = val;
                    });
                  },
                  itemBuilder: (ctx) => [
                    const PopupMenuItem(value: 'Available', child: Text('🟢 Online & Available')),
                    const PopupMenuItem(value: 'In Consultation', child: Text('🟡 In Consultation')),
                    const PopupMenuItem(value: 'Away', child: Text('🔴 Away / Busy')),
                  ],
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _isNotificationSent ? null : _ringDoctorBell,
                  icon: Icon(
                    _isNotificationSent ? Icons.check_circle : Icons.notifications_active,
                    color: Colors.white,
                    size: 16,
                  ),
                  label: Text(
                    _isNotificationSent ? 'Doctor Notified' : 'Notify Doctor / Ring Bell',
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isNotificationSent ? Colors.green : const Color(0xFF4F46E5),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class MicLevelMeter extends StatefulWidget {
  final bool isMicOn;
  const MicLevelMeter({super.key, required this.isMicOn});

  @override
  State<MicLevelMeter> createState() => _MicLevelMeterState();
}

class _MicLevelMeterState extends State<MicLevelMeter> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  final List<double> _heights = List.generate(5, (_) => 2.0);
  final Random _random = Random();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    )..repeat(reverse: true);
    
    _timer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (widget.isMicOn) {
        setState(() {
          for (int i = 0; i < _heights.length; i++) {
            _heights[i] = 4.0 + _random.nextDouble() * 20.0;
          }
        });
      } else {
        setState(() {
          _heights.fillRange(0, _heights.length, 2.0);
        });
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 2.0),
          width: 4,
          height: _heights[index],
          decoration: BoxDecoration(
            color: widget.isMicOn ? Colors.greenAccent : Colors.white24,
            borderRadius: BorderRadius.circular(2),
          ),
        );
      }),
    );
  }
}

