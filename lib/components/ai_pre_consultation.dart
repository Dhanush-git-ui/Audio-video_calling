import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';

class PreConsultationMessage {
  final String text;
  final bool isAi;
  PreConsultationMessage(this.text, this.isAi);
}

class AiPreConsultation extends StatefulWidget {
  const AiPreConsultation({super.key});

  @override
  State<AiPreConsultation> createState() => _AiPreConsultationState();
}

class _AiPreConsultationState extends State<AiPreConsultation> {
  final List<PreConsultationMessage> _messages = [];
  final _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  final List<String> _questions = [
    "What symptoms are you experiencing today?",
    "How long have you had these symptoms?",
    "Are you currently taking any prescription medications?",
    "Do you have any known drug or environmental allergies?",
    "Is there any previous medical history (like surgery, chronic illnesses) you want to share?",
  ];

  final List<String> _collectedAnswers = [];
  int _currentQuestionIndex = 0;
  bool _isTyping = false;
  bool _isFinished = false;

  @override
  void initState() {
    super.initState();
    _startConversation();
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _startConversation() async {
    setState(() => _isTyping = true);
    await Future.delayed(const Duration(milliseconds: 1000));
    if (mounted) {
      setState(() {
        _isTyping = false;
        _messages.add(PreConsultationMessage(
          "Hello! I am AuraCare's AI Pre-Consultation Assistant. I will collect details about your symptoms to share with your doctor before they join. Let's begin.",
          true,
        ));
      });
    }
    
    await Future.delayed(const Duration(milliseconds: 800));
    _askNextQuestion();
  }

  void _askNextQuestion() async {
    if (_currentQuestionIndex < _questions.length) {
      if (mounted) {
        setState(() => _isTyping = true);
      }
      await Future.delayed(const Duration(milliseconds: 1200));
      if (mounted) {
        setState(() {
          _isTyping = false;
          _messages.add(PreConsultationMessage(_questions[_currentQuestionIndex], true));
        });
        _scrollToBottom();
      }
    } else {
      // Completed all questions
      setState(() => _isTyping = true);
      await Future.delayed(const Duration(milliseconds: 1500));
      if (mounted) {
        setState(() {
          _isTyping = false;
          _isFinished = true;
          _messages.add(PreConsultationMessage(
            "Thank you! I have successfully generated a summary of your symptoms and drafted notes for the doctor. You can now enter the Waiting Room.",
            true,
          ));
        });
        _scrollToBottom();
      }
    }
  }

  void _sendMessage() {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add(PreConsultationMessage(text, false));
      _collectedAnswers.add(text);
      _inputController.clear();
      _currentQuestionIndex++;
    });
    
    _scrollToBottom();
    _askNextQuestion();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 800;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F172A), Color(0xFF1E1E38)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 900),
              child: isDesktop
                  ? Row(
                      children: [
                        Expanded(flex: 5, child: _buildChatInterface()),
                        const VerticalDivider(color: Colors.white10, width: 1),
                        Expanded(flex: 4, child: _buildSummaryPane()),
                      ],
                    )
                  : Column(
                      children: [
                        Expanded(child: _buildChatInterface()),
                        if (_isFinished) _buildSummaryPaneMobile(),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChatInterface() {
    return Column(
      children: [
        // AI Chat Header
        Container(
          padding: const EdgeInsets.all(20),
          decoration: const BoxDecoration(
            color: Color(0xFF161E2E),
            border: Border(bottom: BorderSide(color: Colors.white12)),
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.pinkAccent.withOpacity(0.15),
                child: const Icon(Icons.psychology, color: Colors.pinkAccent),
              ),
              const SizedBox(width: 14),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AI Consultation Assistant',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  SizedBox(height: 2),
                  Text('Pre-consultation clinical check', style: TextStyle(color: Colors.white54, fontSize: 11)),
                ],
              ),
            ],
          ),
        ),

        // Chat Log
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(20),
            itemCount: _messages.length + (_isTyping ? 1 : 0),
            itemBuilder: (context, index) {
              if (index == _messages.length && _isTyping) {
                return _buildTypingIndicator();
              }
              final msg = _messages[index];
              return _buildChatBubble(msg);
            },
          ),
        ),

        // Text input field
        if (!_isFinished)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: const BoxDecoration(
              color: Color(0xFF0F172A),
              border: Border(top: BorderSide(color: Color(0x2264748B))),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Quick Suggestion Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildQuickChip('Fever & Cough'),
                      const SizedBox(width: 8),
                      _buildQuickChip('Mild Headache'),
                      const SizedBox(width: 8),
                      _buildQuickChip('2-3 Days'),
                      const SizedBox(width: 8),
                      _buildQuickChip('No medications'),
                      const SizedBox(width: 8),
                      _buildQuickChip('No known allergies'),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _inputController,
                        style: const TextStyle(color: Color(0xFFF8FAFC)),
                        decoration: InputDecoration(
                          hintText: 'Type your response or select a chip...',
                          hintStyle: const TextStyle(color: Color(0xFF475569)),
                          filled: true,
                          fillColor: const Color(0xFF1E293B),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0x2264748B)),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFF6366F1), width: 1.5),
                          ),
                        ),
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF6366F1).withOpacity(0.4),
                            blurRadius: 12,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
                        onPressed: _sendMessage,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          )
        else
          Container(
            padding: const EdgeInsets.all(20),
            color: const Color(0xFF1E293B),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    // Send to standard waiting room with the room state preset
                    context.go('/?room=pre-consult-lobby');
                  },
                  icon: const Icon(Icons.meeting_room, color: Colors.white),
                  label: const Text('Enter Consultation Lobby', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.pinkAccent,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildChatBubble(PreConsultationMessage message) {
    return Align(
      alignment: message.isAi ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.7,
        ),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: message.isAi ? const Color(0xFF1E293B) : Colors.indigoAccent,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(message.isAi ? 0 : 16),
            bottomRight: Radius.circular(message.isAi ? 16 : 0),
          ),
          border: message.isAi ? Border.all(color: Colors.white.withOpacity(0.05)) : null,
        ),
        child: Text(
          message.text,
          style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.4),
        ),
      ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.1),
    );
  }

  Widget _buildTypingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildDot(0),
            _buildDot(150),
            _buildDot(300),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickChip(String label) {
    return GestureDetector(
      onTap: () {
        _inputController.text = label;
        _sendMessage();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0x336366F1)),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Color(0xFFC7D2FE),
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildDot(int delayMs) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      width: 6,
      height: 6,
      decoration: const BoxDecoration(
        color: Colors.white54,
        shape: BoxShape.circle,
      ),
    )
        .animate(onPlay: (controller) => controller.repeat(reverse: true))
        .scale(end: const Offset(1.5, 1.5), duration: 600.ms, delay: delayMs.ms);
  }

  Widget _buildSummaryPane() {
    return Container(
      color: const Color(0xFF0F172A),
      padding: const EdgeInsets.all(28),
      child: _buildSummaryContent(),
    );
  }

  Widget _buildSummaryPaneMobile() {
    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        border: Border(top: BorderSide(color: Colors.white12)),
      ),
      padding: const EdgeInsets.all(20),
      child: ExpansionTile(
        title: const Text('Clinical Pre-Consultation Summary', style: TextStyle(color: Colors.pinkAccent, fontWeight: FontWeight.bold)),
        children: [_buildSummaryContent()],
      ),
    );
  }

  Widget _buildSummaryContent() {
    if (!_isFinished) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.assignment_outlined, color: Colors.white24, size: 48),
            const SizedBox(height: 16),
            const Text(
              'Awaiting Completion',
              style: TextStyle(color: Colors.white30, fontSize: 14),
            ),
            const SizedBox(height: 8),
            const Text(
              'The AI summary will update live as you answer the assistant\'s checks.',
              style: TextStyle(color: Colors.white24, fontSize: 11),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    final symptoms = _collectedAnswers.isNotEmpty ? _collectedAnswers[0] : 'N/A';
    final duration = _collectedAnswers.length > 1 ? _collectedAnswers[1] : 'N/A';
    final medications = _collectedAnswers.length > 2 ? _collectedAnswers[2] : 'N/A';
    final allergies = _collectedAnswers.length > 3 ? _collectedAnswers[3] : 'N/A';
    final history = _collectedAnswers.length > 4 ? _collectedAnswers[4] : 'N/A';

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('CLINICAL SUMMARY', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1.2)),
          const SizedBox(height: 24),
          
          _buildSummaryItem('Reported Symptoms', symptoms, Colors.pinkAccent),
          _buildSummaryItem('Onset & Duration', duration, Colors.indigoAccent),
          _buildSummaryItem('Current Medications', medications, Colors.greenAccent),
          _buildSummaryItem('Allergies Profile', allergies, Colors.redAccent),
          _buildSummaryItem('Medical History', history, Colors.amber),

          const Divider(color: Colors.white12, height: 32),
          
          // Doctor Prompts
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.indigoAccent.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.indigoAccent.withOpacity(0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.quiz, color: Colors.indigoAccent, size: 18),
                    SizedBox(width: 8),
                    Text('Recommended Questions for Doctor', style: TextStyle(color: Colors.indigoAccent, fontWeight: FontWeight.bold, fontSize: 13)),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  "1. Could my symptoms related to '$symptoms' be linked to prior history?\n2. Do current medications interact with proposed therapeutics?",
                  style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
                ),
              ],
            ),
          )
        ],
      ).animate().fadeIn(duration: 500.ms),
    );
  }

  Widget _buildSummaryItem(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.3)),
        ],
      ),
    );
  }
}
