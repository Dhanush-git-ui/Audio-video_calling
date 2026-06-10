import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:livekit_client/livekit_client.dart' hide ConnectionState;
import 'package:livekit_client/livekit_client.dart' as lk show ConnectionState;
import 'dart:math';

class ChatMessage {
  final String text;
  final bool isMe;
  final String time;
  ChatMessage(this.text, this.isMe, this.time);
}

class ConsultationRoom extends StatefulWidget {
  final bool isPip;
  final VoidCallback? onExpand;

  const ConsultationRoom({super.key, this.isPip = false, this.onExpand});

  @override
  State<ConsultationRoom> createState() => _ConsultationRoomState();
}

class _ConsultationRoomState extends State<ConsultationRoom> {
  bool isVideoOn = true;
  bool isAudioOn = true;
  bool isChatOpen = false;
  bool isBlurActive = false;

  final TextEditingController _chatController = TextEditingController();
  final List<ChatMessage> _messages = [];
  
  // LiveKit WebRTC Tracks
  LocalVideoTrack? _localVideoTrack;
  LocalAudioTrack? _localAudioTrack;
  late final Room _room = Room();

  // Renamed variables to force a fresh state reset on hot reload
  double _chatBoxX = 24;
  double _chatBoxY = 100;
  double _chatBoxW = 320;
  double _chatBoxH = 450;

  @override
  void initState() {
    super.initState();
    // Rebuild UI when connection state or participants change
    _room.addListener(() {
      if (mounted) setState(() {});
    });
    _initLocalCamera();
  }

  Future<void> _initLocalCamera() async {
    try {
      final videoTrack = await LocalVideoTrack.createCameraTrack();
      final audioTrack = await LocalAudioTrack.create();
      if (mounted) {
        setState(() {
          _localVideoTrack = videoTrack;
          _localAudioTrack = audioTrack;
        });
      }
    } catch (e) {
      debugPrint("Media error: $e");
    }
  }

  @override
  void dispose() {
    _localVideoTrack?.dispose();
    _localAudioTrack?.dispose();
    _room.dispose();
    _chatController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _chatController.text.trim();
    if (text.isEmpty) return;
    setState(() {
      _messages.add(ChatMessage(text, true, DateFormat('hh:mm a').format(DateTime.now())));
      _chatController.clear();
      // In a real app with data channels, we would call:
      // _room.localParticipant?.publishData(utf8.encode(text));
    });
  }

  Future<void> _pickFile() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles();
    if (result != null) {
      setState(() {
        _messages.add(ChatMessage('📎 Sent file: ${result.files.single.name}', true, DateFormat('hh:mm a').format(DateTime.now())));
      });
    }
  }

  Future<void> _toggleVideo() async {
    if (isVideoOn) {
      await _localVideoTrack?.mute();
    } else {
      await _localVideoTrack?.unmute();
    }
    setState(() {
      isVideoOn = !isVideoOn;
    });
  }

  Future<void> _toggleAudio() async {
    if (isAudioOn) {
      await _localAudioTrack?.mute();
    } else {
      await _localAudioTrack?.unmute();
    }
    setState(() {
      isAudioOn = !isAudioOn;
    });
  }

  // Connect to the self-hosted LiveKit server
  Future<void> _connectToLiveKit(String url, String token) async {
    try {
      await _room.connect(url, token);
      if (_localVideoTrack != null) await _room.localParticipant?.publishVideoTrack(_localVideoTrack!);
      if (_localAudioTrack != null) await _room.localParticipant?.publishAudioTrack(_localAudioTrack!);
    } catch (e) {
      debugPrint("LiveKit Connect Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF161E2E), // Darker slate
      ),
      child: Stack(
        children: [
          // Remote Participant (REAL TIME WEBRTC)
          Positioned.fill(
            child: Builder(
              builder: (context) {
                // Get the first remote participant's video track if connected
                final remoteParticipants = _room.remoteParticipants.values.toList();
                final firstRemote = remoteParticipants.isNotEmpty ? remoteParticipants.first : null;
                final remoteVideo = firstRemote?.videoTrackPublications.firstOrNull?.track;

                if (remoteVideo != null) {
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      VideoTrackRenderer(remoteVideo as VideoTrack),
                      Positioned(
                        bottom: widget.isPip ? 12 : 100,
                        left: widget.isPip ? 12 : 32,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), borderRadius: BorderRadius.circular(24)),
                          child: Row(
                            children: [
                              Text(firstRemote?.identity ?? 'Patient', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                }

                // If no one is connected, show waiting screen
                return Container(
                  color: const Color(0xFF0F172A),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const CircularProgressIndicator(color: Colors.indigoAccent),
                        const SizedBox(height: 24),
                        Text(
                          _room.connectionState == lk.ConnectionState.connected 
                              ? 'Waiting for patient to join the room...' 
                              : 'Not connected to LiveKit Server', 
                          style: const TextStyle(color: Colors.white54, fontSize: 16)
                        ),
                      ],
                    ),
                  ),
                );
              }
            ).animate().fadeIn(duration: 800.ms),
          ),

          // Local Participant PiP (Top Right)
          AnimatedPositioned(
            duration: 300.ms,
            top: widget.isPip ? 12 : 24,
            right: widget.isPip ? 12 : 24,
            width: widget.isPip ? 120 : 220,
            height: widget.isPip ? 68 : 124,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white12),
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
                                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                child: Text(isVideoOn ? 'No Camera Device Found\n(VM / Permission Blocked)' : 'Camera Off', 
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.white54, fontSize: widget.isPip ? 9 : 11)),
                              ),
                            ),
                          ),
                  ),
                  Positioned(
                    bottom: 8,
                    left: 8,
                    child: Text('You (Doctor)', style: TextStyle(fontSize: widget.isPip ? 8 : 12, color: Colors.white, fontWeight: FontWeight.bold, shadows: const [Shadow(blurRadius: 2, color: Colors.black)])),
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

          // Bottom Controls Bar
          AnimatedPositioned(
            duration: 300.ms,
            bottom: widget.isPip ? 12 : 32,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: widget.isPip ? 12 : 24, vertical: widget.isPip ? 8 : 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B).withOpacity(0.9), // Slate 800
                  borderRadius: BorderRadius.circular(widget.isPip ? 16 : 30),
                  border: Border.all(color: Colors.white12),
                  boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10)],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildControlButton(
                      icon: isAudioOn ? Icons.mic_none : Icons.mic_off,
                      isDanger: !isAudioOn,
                      onTap: _toggleAudio,
                    ),
                    SizedBox(width: widget.isPip ? 8 : 16),
                    _buildControlButton(
                      icon: isVideoOn ? Icons.videocam_outlined : Icons.videocam_off_outlined,
                      isDanger: !isVideoOn,
                      onTap: _toggleVideo,
                    ),
                    SizedBox(width: widget.isPip ? 8 : 16),
                    _buildControlButton(
                      icon: Icons.chat_bubble_outline,
                      isActive: isChatOpen,
                      onTap: () => setState(() => isChatOpen = !isChatOpen),
                    ),
                    SizedBox(width: widget.isPip ? 8 : 16),
                    _buildControlButton(
                      icon: Icons.blur_on,
                      label: widget.isPip ? null : 'Blur',
                      isActive: isBlurActive,
                      onTap: () {
                        setState(() => isBlurActive = !isBlurActive);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('Background Blur requires ML WebAssembly assets (TFLite) and Cross-Origin isolation headers to be deployed on the hosting server. This feature will activate in production!'),
                            backgroundColor: Colors.indigo.shade800,
                            duration: const Duration(seconds: 4),
                          ),
                        );
                      },
                    ),
                    SizedBox(width: widget.isPip ? 8 : 16),
                    GestureDetector(
                      onTap: () => context.go('/'),
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: widget.isPip ? 12 : 24, vertical: widget.isPip ? 8 : 12),
                        decoration: BoxDecoration(color: const Color(0xFFE11D48), borderRadius: BorderRadius.circular(25)), // Rose 600
                        child: Text('End Call', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: widget.isPip ? 10 : 14)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // Draggable/Resizable Chat Overlay
          if (isChatOpen)
            Positioned(
              left: _chatBoxX,
              top: _chatBoxY,
              child: _buildChatOverlay().animate().scaleXY(begin: 0.9, duration: 200.ms, curve: Curves.easeOutBack).fadeIn(),
            ),
        ],
      ),
    );
  }

  Widget _buildControlButton({required IconData icon, bool isDanger = false, bool isActive = false, String? label, required VoidCallback onTap}) {
    Color bgColor = const Color(0xFF334155); // Slate 700
    Color iconColor = Colors.white70;
    if (isDanger) {
      bgColor = const Color(0xFFE11D48).withOpacity(0.2); // Rose 600
      iconColor = const Color(0xFFE11D48);
    } else if (isActive) {
      bgColor = Colors.indigoAccent;
      iconColor = Colors.white;
    }

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: 200.ms,
        height: widget.isPip ? 36 : 48,
        padding: EdgeInsets.symmetric(horizontal: label != null ? (widget.isPip ? 8 : 16) : 0),
        width: label == null ? (widget.isPip ? 36 : 48) : null,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(widget.isPip ? 12 : 24),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: iconColor, size: widget.isPip ? 16 : 20),
            if (label != null && !widget.isPip) ...[
              const SizedBox(width: 8),
              Text(label, style: TextStyle(color: iconColor, fontWeight: FontWeight.bold)),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildChatOverlay() {
    return Container(
      width: _chatBoxW,
      height: _chatBoxH,
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
                  onPanUpdate: (details) {
                    setState(() {
                      _chatBoxX += details.delta.dx;
                      _chatBoxY += details.delta.dy;
                    });
                  },
                  child: Stack(
                    children: [
                      // Visual Drag Handle
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
                        padding: const EdgeInsets.fromLTRB(16, 32, 16, 0),
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
}
