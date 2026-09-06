import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

class ClinicalPanel extends StatefulWidget {
  const ClinicalPanel({super.key});

  @override
  State<ClinicalPanel> createState() => _ClinicalPanelState();
}

class _ClinicalPanelState extends State<ClinicalPanel> {
  int activeTabIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0A1120), // CallHealth Deep Navy
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header / Patient Info
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFF111C33), // CallHealth Slate Navy
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0x331554A6)),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF1554A6).withOpacity(0.08),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1554A6), Color(0xFF0D47A1)],
                      ),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF1554A6).withOpacity(0.4),
                          blurRadius: 10,
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: const Text('JC', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16)),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          spacing: 12,
                          runSpacing: 4,
                          children: [
                            const Text('James Carter', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFFF8FAFC), letterSpacing: -0.2)),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: const Color(0xFF1554A6).withOpacity(0.2),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: const Color(0x331554A6)),
                              ),
                              child: const Text('P-20240125-001', style: TextStyle(color: Color(0xFF93C5FD), fontSize: 10, fontWeight: FontWeight.w600)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Text('Pain near left chest, Pelvic salinity', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12)),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _buildTag('28 Yrs - Male'),
                            _buildTag('O+ve', color: const Color(0xFF78C02B).withOpacity(0.15), textColor: const Color(0xFF78C02B)),
                            _buildTag('Cardiology', color: const Color(0xFF1554A6).withOpacity(0.18), textColor: const Color(0xFF93C5FD)),
                            _buildTag('25 Jan 2025, 07:00 AM'),
                            _buildTag('Online Consultation', color: const Color(0xFF78C02B).withOpacity(0.15), textColor: const Color(0xFF78C02B)),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Tabs
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: Color(0x221554A6))),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  'Vitals', 'Complaint', 'Diagnosis', 'Medications', 'Investigation', 'Follow Up', 'Invoice'
                ].asMap().entries.map((entry) {
                  final idx = entry.key;
                  final title = entry.value;
                  final isActive = idx == activeTabIndex;
                  return GestureDetector(
                    onTap: () => setState(() => activeTabIndex = idx),
                    child: Container(
                      margin: const EdgeInsets.only(right: 32),
                      padding: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(color: isActive ? const Color(0xFF78C02B) : Colors.transparent, width: 3),
                        ),
                      ),
                      child: Text(
                        title,
                        style: TextStyle(
                          color: isActive ? const Color(0xFF78C02B) : const Color(0xFF94A3B8),
                          fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ),

          // Content
          Expanded(
            child: _buildTabContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildTag(String text, {Color? color, Color? textColor}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color ?? const Color(0xFF162544),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0x331554A6)),
      ),
      child: Text(text, style: TextStyle(color: textColor ?? const Color(0xFFCBD5E1), fontSize: 10, fontWeight: FontWeight.w600)),
    );
  }

  Widget _buildVitalsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('VITALS & BIOMETRICS', style: TextStyle(color: Color(0xFFF8FAFC), fontWeight: FontWeight.w800, fontSize: 15, letterSpacing: 1.0))
              .animate().fadeIn().slideX(begin: -0.1),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (context, constraints) {
              int crossAxisCount = 1;
              double childAspectRatio = 2.2;
              double valueFontSize = 30.0;
              
              if (constraints.maxWidth > 1100) {
                crossAxisCount = 6;
                childAspectRatio = 1.0;
                valueFontSize = 46.0;
              } else if (constraints.maxWidth > 800) {
                crossAxisCount = 3;
                childAspectRatio = 1.6;
              } else if (constraints.maxWidth > 500) {
                crossAxisCount = 2;
                childAspectRatio = 1.35;
              } else if (constraints.maxWidth > 300) {
                crossAxisCount = 2;
                childAspectRatio = 1.15;
              }
              
              return GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: crossAxisCount,
                childAspectRatio: childAspectRatio,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                children: [
                  VitalCard(title: 'BLOOD\nPRESSURE', value: '120/80', unit: 'mmHg', colors: const [Color(0xFF1554A6), Color(0xFF2563EB)], valueFontSize: valueFontSize),
                  VitalCard(title: 'HEART RATE', value: '72', unit: 'bpm', colors: const [Color(0xFF78C02B), Color(0xFF4ADE80)], valueFontSize: valueFontSize),
                  VitalCard(title: 'TEMPERATURE', value: '98.6', unit: '°F', colors: const [Color(0xFF1554A6), Color(0xFF38BDF8)], valueFontSize: valueFontSize),
                  VitalCard(title: 'SPO2', value: '98', unit: '%', colors: const [Color(0xFF78C02B), Color(0xFF22C55E)], valueFontSize: valueFontSize),
                  VitalCard(title: 'RESP. RATE', value: '18', unit: 'br/min', colors: const [Color(0xFF1554A6), Color(0xFF60A5FA)], valueFontSize: valueFontSize),
                  VitalCard(title: 'WEIGHT', value: '74', unit: 'kg', colors: const [Color(0xFF78C02B), Color(0xFF84CC16)], valueFontSize: valueFontSize),
                ],
              );
            }
          ),
          const SizedBox(height: 24),
          const Divider(color: Color(0x221554A6)),
          const SizedBox(height: 24),
          const Text('AI EMOTION & SENTIMENT ANALYSIS', style: TextStyle(color: Color(0xFFF8FAFC), fontWeight: FontWeight.w800, fontSize: 13, letterSpacing: 1.0)),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: const Color(0xFF111C33),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0x3378C02B)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.psychology, color: Color(0xFF78C02B), size: 20),
                          SizedBox(width: 8),
                          Text('Emotion Tracker', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF78C02B).withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0x3378C02B)),
                        ),
                        child: const Text('CALM / STABLE', style: TextStyle(color: Color(0xFF78C02B), fontSize: 10, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Patient Tone: Expressing concern about chest discomfort, mild anxiety. Speech pattern is coherent and logical.',
                  style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 20),
                const Text('SENTIMENT ANALYSIS BREAKDOWN', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5)),
                const SizedBox(height: 12),
                _buildSentimentBar('Normal / Calm Tone', 0.85, const Color(0xFF78C02B)),
                const SizedBox(height: 8),
                _buildSentimentBar('Mild Anxiety', 0.12, const Color(0xFF2563EB)),
                const SizedBox(height: 8),
                _buildSentimentBar('Pain / Discomfort Indicator', 0.03, const Color(0xFFE11D48)),
              ],
            ),
          ).animate().fadeIn().slideY(begin: 0.1),
        ],
      ),
    );
  }

  Widget _buildSentimentBar(String label, double value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11)),
            Text('${(value * 100).toStringAsFixed(0)}%', style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: value,
            backgroundColor: Colors.white10,
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 6,
          ),
        ),
      ],
    );
  }

  Widget _buildTabContent() {
    switch (activeTabIndex) {
      case 0:
        return _buildVitalsTab();
      case 1:
        return _buildComplaintTab();
      case 2:
        return _buildDiagnosisTab();
      case 3:
        return _buildMedicationsTab();
      case 4:
        return _buildInvestigationTab();
      case 5:
        return _buildFollowUpTab();
      case 6:
        return _buildInvoiceTab();
      default:
        return const Center(child: Text('Data Unavailable', style: TextStyle(color: Colors.white54)));
    }
  }

  Widget _buildComplaintTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('CHIEF COMPLAINTS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1.2)),
          const SizedBox(height: 16),
          _buildComplaintItem('Chest Pain', 'Severe tightness in the left thoracic region, radiation to left shoulder, onset 3 hours ago.'),
          _buildComplaintItem('Shortness of Breath', 'Dyspnea reported during mild exertion or walking up stairs.'),
          _buildComplaintItem('Dizziness', 'Mild lightheadedness experienced during episodes of chest tightness.'),
        ],
      ),
    );
  }

  Widget _buildComplaintItem(String symptom, String desc) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(symptom, style: const TextStyle(color: Colors.pinkAccent, fontSize: 14, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Text(desc, style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.4)),
        ],
      ),
    );
  }

  Widget _buildDiagnosisTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('CLINICAL DIAGNOSIS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1.2)),
          const SizedBox(height: 16),
          _buildDiagnosisItem('I20.9', 'Angina Pectoris, Unspecified', 'Primary', 'Stable angina pectoris provoked by physical exertion or acute stress.'),
          _buildDiagnosisItem('I10', 'Essential (Primary) Hypertension', 'Secondary', 'Long-standing blood pressure elevation, currently managed on pharmacotherapy.'),
        ],
      ),
    );
  }

  Widget _buildDiagnosisItem(String code, String desc, String type, String notes) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(code, style: const TextStyle(color: Colors.indigoAccent, fontSize: 15, fontWeight: FontWeight.bold)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: type == 'Primary' ? Colors.redAccent.withOpacity(0.2) : Colors.white10, borderRadius: BorderRadius.circular(4)),
                child: Text(type, style: TextStyle(color: type == 'Primary' ? Colors.redAccent : Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(desc, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(notes, style: const TextStyle(color: Colors.white54, fontSize: 12, height: 1.3)),
        ],
      ),
    );
  }

  Widget _buildMedicationsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('PRESCRIPTION LOG', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1.2)),
          const SizedBox(height: 16),
          _buildMedicationItem('Aspirin 81 mg', 'Oral Tablet', '1 Tablet Daily (Morning)', 'Take with food.', '30 Days'),
          _buildMedicationItem('Atorvastatin 20 mg', 'Oral Tablet', '1 Tablet Daily (Night)', 'Avoid grapefruit juice.', '90 Days'),
          _buildMedicationItem('Nitroglycerin 0.4 mg', 'Sublingual Tablet', '1 Tablet q5m prn', 'For acute chest pain. Max 3 doses.', 'As Needed'),
        ],
      ),
    );
  }

  Widget _buildMedicationItem(String name, String route, String freq, String inst, String dur) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(name, style: const TextStyle(color: Colors.greenAccent, fontSize: 14, fontWeight: FontWeight.bold)),
              Text(dur, style: const TextStyle(color: Colors.white38, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 8),
          Text('Route: $route  |  Frequency: $freq', style: const TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 6),
          Text('Instructions: $inst', style: const TextStyle(color: Colors.white54, fontSize: 12, fontStyle: FontStyle.italic)),
        ],
      ),
    );
  }

  Widget _buildInvestigationTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('ORDERED INVESTIGATIONS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1.2)),
          const SizedBox(height: 16),
          _buildInvestigationItem('12-Lead ECG', 'Cardiology Lab', 'Urgent', 'To evaluate ST-segment transitions during chest pain episodes.'),
          _buildInvestigationItem('Lipid Profile', 'Biochemistry Lab', 'Routine', 'Fasting lipid panel to assess cardiovascular risk profile.'),
          _buildInvestigationItem('Serum Troponin I', 'Emergency Lab', 'Stat', 'To rule out myocardial injury / infarction.'),
          const SizedBox(height: 24),
          const Divider(color: Colors.white12),
          const SizedBox(height: 24),
          const Text('DIGITAL CONSULTATION ATTACHMENTS', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14, letterSpacing: 1.2)),
          const SizedBox(height: 16),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.4,
            children: [
              _buildDigitalImageCard('Whiteboard Sketch Snapshot', 'Captured on 25 Jan 2025, 07:12 AM', Icons.gesture, Colors.indigoAccent),
              _buildDigitalImageCard('Symptom Site / Clinical Capture', 'Captured on 25 Jan 2025, 07:15 AM', Icons.camera_alt, Colors.pinkAccent),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDigitalImageCard(String title, String subtitle, IconData icon, Color color) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white12),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            Positioned.fill(
              child: Container(
                color: color.withOpacity(0.05),
                child: Center(
                  child: Icon(icon, size: 48, color: color.withOpacity(0.3)),
                ),
              ),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: const EdgeInsets.all(12),
                color: Colors.black.withOpacity(0.7),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(title, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 10)),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInvestigationItem(String test, String dept, String priority, String purpose) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(test, style: const TextStyle(color: Colors.orangeAccent, fontSize: 14, fontWeight: FontWeight.bold)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: priority == 'Stat' ? Colors.redAccent.withOpacity(0.2) : Colors.white10, borderRadius: BorderRadius.circular(4)),
                child: Text(priority, style: TextStyle(color: priority == 'Stat' ? Colors.redAccent : Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text('Dept: $dept', style: const TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 6),
          Text('Purpose: $purpose', style: const TextStyle(color: Colors.white54, fontSize: 12, height: 1.3)),
        ],
      ),
    );
  }

  Widget _buildFollowUpTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('FOLLOW-UP SCHEDULE', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1.2)),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white12)),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.calendar_today, color: Colors.indigoAccent, size: 18),
                    SizedBox(width: 10),
                    Text('Next Visit: 08 Feb 2025, 10:00 AM', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14)),
                  ],
                ),
                SizedBox(height: 12),
                Text('Instructions:', style: TextStyle(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 12)),
                SizedBox(height: 6),
                Text('1. Bring latest ECG printout and blood lipid test reports.\n2. Please log blood pressure measurements twice daily.\n3. Return immediately to ER if chest pain occurs and does not subside after 1 dose of sublingual nitroglycerin.',
                  style: TextStyle(color: Colors.white54, fontSize: 12, height: 1.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInvoiceTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('BILLING OVERVIEW', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 1.2)),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: const Color(0xFF1E293B), borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.white12)),
            child: Column(
              children: [
                _buildInvoiceRow('Consultation Fee', '\$120.00'),
                _buildInvoiceRow('Telemedicine Surcharge', '\$15.00'),
                _buildInvoiceRow('Digital Charting Surcharge', '\$15.00'),
                const Divider(color: Colors.white24, height: 24),
                _buildInvoiceRow('Total Amount', '\$150.00', isTotal: true),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Status', style: TextStyle(color: Colors.white60, fontSize: 13)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: Colors.greenAccent.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                      child: const Text('PAID VIA INS', style: TextStyle(color: Colors.greenAccent, fontSize: 11, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInvoiceRow(String item, String price, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(item, style: TextStyle(color: isTotal ? Colors.white : Colors.white70, fontWeight: isTotal ? FontWeight.bold : FontWeight.normal, fontSize: isTotal ? 15 : 13)),
          Text(price, style: TextStyle(color: isTotal ? Colors.indigoAccent : Colors.white, fontWeight: isTotal ? FontWeight.bold : FontWeight.normal, fontSize: isTotal ? 16 : 13)),
        ],
      ),
    );
  }
}

class VitalCard extends StatefulWidget {
  final String title;
  final String value;
  final String unit;
  final List<Color> colors;
  final double valueFontSize;

  const VitalCard({
    super.key,
    required this.title,
    required this.value,
    required this.unit,
    required this.colors,
    this.valueFontSize = 34.0,
  });

  @override
  State<VitalCard> createState() => _VitalCardState();
}

class _VitalCardState extends State<VitalCard> {
  bool isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => isHovered = true),
      onExit: (_) => setState(() => isHovered = false),
      child: AnimatedContainer(
        duration: 300.ms,
        curve: Curves.easeOutCubic,
        transform: Matrix4.identity()..scale(isHovered ? 1.02 : 1.0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: isHovered ? widget.colors.first.withOpacity(0.2) : Colors.black26, 
              blurRadius: isHovered ? 20 : 10, 
              offset: const Offset(0, 4)
            )
          ],
        ),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFF111C33),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0x221554A6)),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              children: [
                // Top Glowing Edge
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: 4,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: widget.colors),
                      boxShadow: [
                        BoxShadow(
                          color: widget.colors.first.withOpacity(0.6),
                          blurRadius: 16,
                          spreadRadius: 2,
                          offset: const Offset(0, 4),
                        )
                      ]
                    ),
                  ),
                ),
                // Card Content
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(widget.title, style: const TextStyle(color: Colors.white60, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 0.5, height: 1.2)),
                          ),
                          const SizedBox(width: 4),
                          Text(widget.unit, style: const TextStyle(color: Colors.white60, fontSize: 10, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      Text(widget.value, style: TextStyle(color: Colors.white, fontSize: widget.valueFontSize - 4, fontWeight: FontWeight.w900, height: 1.0))
                        .animate(target: isHovered ? 1 : 0)
                        .shimmer(duration: 1.seconds, color: Colors.white38),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ).animate().fadeIn(duration: 600.ms).slideY(begin: 0.1),
    );
  }
}
