import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../providers/user_session_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneController = TextEditingController();
  final List<TextEditingController> _otpControllers = List.generate(4, (_) => TextEditingController());
  final List<FocusNode> _otpFocusNodes = List.generate(4, (_) => FocusNode());

  bool _otpSent = false;
  bool _isLoading = false;
  bool _isDoctor = true;

  @override
  void dispose() {
    _phoneController.dispose();
    for (var controller in _otpControllers) {
      controller.dispose();
    }
    for (var node in _otpFocusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _sendOtp() async {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty || phone.length < 10) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid phone number')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    // Simulate OTP network request
    await Future.delayed(const Duration(milliseconds: 1500));

    if (mounted) {
      setState(() {
        _isLoading = false;
        _otpSent = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Verification code sent! (Try: 1234)')),
      );
      // Auto focus first OTP field
      _otpFocusNodes[0].requestFocus();
    }
  }

  void _verifyOtp() async {
    final code = _otpControllers.map((c) => c.text).join();
    if (code.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter the 4-digit code')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    // Simulate verification
    await Future.delayed(const Duration(milliseconds: 1500));

    if (mounted) {
      setState(() {
        _isLoading = false;
      });

      if (code == '1234') {
        final name = _isDoctor ? 'Dr. Amanulla Belg' : 'James Carter';
        final role = _isDoctor ? 'Doctor' : 'Patient';
        Provider.of<UserSessionProvider>(context, listen: false).login(name, role);

        // Authenticated! Take them to lobby or pre-consultation depending on role
        if (_isDoctor) {
          context.go('/'); // Doctor lands in Setup Lobby
        } else {
          context.go('/pre-consultation'); // Patient lands in AI Pre-Consultation questionnaire
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Incorrect code. Try "1234"')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmall = screenWidth < 450;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF0F172A), Color(0xFF1E1E38)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Card(
                color: const Color(0xFF1E293B),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                elevation: 16,
                child: Padding(
                  padding: EdgeInsets.all(isSmall ? 20.0 : 32.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.spa, color: Colors.indigoAccent, size: 28),
                          const SizedBox(width: 8),
                          const Text(
                            'AuraCare',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ).animate().fadeIn().slideY(begin: -0.2),
                      const SizedBox(height: 12),
                      Text(
                        _otpSent ? 'Verify Identity' : 'Secure Login Portal',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.white70,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Step 1: Phone Login
                      if (!_otpSent) ...[
                        // Role selection
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'Account Type',
                              style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600),
                            ),
                            Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFF0F172A),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: const Color(0x3364748B)),
                              ),
                              padding: const EdgeInsets.all(3),
                              child: Row(
                                children: [
                                  _buildRoleTab('Doctor', _isDoctor, () => setState(() => _isDoctor = true)),
                                  _buildRoleTab('Patient', !_isDoctor, () => setState(() => _isDoctor = false)),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Quick Demo Login Pills
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: const Color(0x226366F1)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.flash_on, color: Color(0xFFF59E0B), size: 14),
                                  const SizedBox(width: 6),
                                  const Text(
                                    '1-Click Demo Profiles',
                                    style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: () {
                                        Provider.of<UserSessionProvider>(context, listen: false)
                                            .login('Dr. Amanulla Belg', 'Doctor');
                                        context.go('/');
                                      },
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(vertical: 8),
                                        side: const BorderSide(color: Color(0xFF6366F1)),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                      child: const Text('Dr. Belg (Doctor)', style: TextStyle(color: Color(0xFF818CF8), fontSize: 11, fontWeight: FontWeight.bold)),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: () {
                                        Provider.of<UserSessionProvider>(context, listen: false)
                                            .login('James Carter', 'Patient');
                                        context.go('/pre-consultation');
                                      },
                                      style: OutlinedButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(vertical: 8),
                                        side: const BorderSide(color: Color(0xFF06B6D4)),
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      ),
                                      child: const Text('James (Patient)', style: TextStyle(color: Color(0xFF22D3EE), fontSize: 11, fontWeight: FontWeight.bold)),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Phone Input
                        const Text(
                          'Phone Number',
                          style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8), fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          style: const TextStyle(color: Color(0xFFF8FAFC)),
                          decoration: InputDecoration(
                            prefixIcon: const Icon(Icons.phone_iphone, color: Color(0xFF64748B)),
                            hintText: 'Enter 10-digit phone number',
                            hintStyle: const TextStyle(color: Color(0xFF475569)),
                            filled: true,
                            fillColor: const Color(0xFF0F172A),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0x3364748B)),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: Color(0xFF6366F1), width: 1.5),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Action Button
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            gradient: const LinearGradient(
                              colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF6366F1).withOpacity(0.35),
                                blurRadius: 16,
                                offset: const Offset(0, 4),
                              )
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _sendOtp,
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size.fromHeight(48),
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                  )
                                : const Text(
                                    'Send Verification Code',
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 14),
                                  ),
                          ),
                        ),
                      ],

                      // Step 2: OTP Verification
                      if (_otpSent) ...[
                        const Text(
                          'We sent a 4-digit code to your phone. Please enter it below to confirm details.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white54, fontSize: 13, height: 1.4),
                        ),
                        const SizedBox(height: 24),

                        // Code fields row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: List.generate(4, (index) {
                            return SizedBox(
                              width: 56,
                              height: 56,
                              child: TextField(
                                controller: _otpControllers[index],
                                focusNode: _otpFocusNodes[index],
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.center,
                                style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                                decoration: InputDecoration(
                                  filled: true,
                                  fillColor: const Color(0xFF0F172A),
                                  counterText: '',
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide.none,
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(color: Colors.pinkAccent, width: 2),
                                  ),
                                ),
                                onChanged: (value) {
                                  if (value.isNotEmpty && index < 3) {
                                    _otpFocusNodes[index + 1].requestFocus();
                                  } else if (value.isEmpty && index > 0) {
                                    _otpFocusNodes[index - 1].requestFocus();
                                  }
                                  if (index == 3 && value.length == 1) {
                                    _verifyOtp(); // Auto-submit when last box is filled
                                  }
                                },
                              ),
                            );
                          }),
                        ),
                        const SizedBox(height: 32),

                        // Verify / Resend actions
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(14),
                            gradient: const LinearGradient(
                              colors: [Colors.pinkAccent, Colors.redAccent],
                            ),
                          ),
                          child: ElevatedButton(
                            onPressed: _isLoading ? null : _verifyOtp,
                            style: ElevatedButton.styleFrom(
                              minimumSize: const Size.fromHeight(52),
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                            child: _isLoading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                  )
                                : const Text(
                                    'Confirm Code',
                                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _otpSent = false;
                              for (var c in _otpControllers) {
                                c.clear();
                              }
                            });
                          },
                          child: const Text('Back to Login', style: TextStyle(color: Colors.indigoAccent, fontWeight: FontWeight.bold)),
                        )
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoleTab(String text, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.indigoAccent : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.white54,
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}
