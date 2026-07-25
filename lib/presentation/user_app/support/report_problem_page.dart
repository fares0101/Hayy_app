import 'package:flutter/material.dart';
import '../../../core/widgets/app_theme.dart';
import '../../../core/widgets/themed_top_header.dart';

class ReportProblemPage extends StatefulWidget {
  const ReportProblemPage({super.key});

  @override
  State<ReportProblemPage> createState() => _ReportProblemPageState();
}

class _ReportProblemPageState extends State<ReportProblemPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _descriptionController = TextEditingController();
  int _selectedCategoryIndex = 0;
  bool _isSubmitting = false;
  bool _hasAttachment = false;

  final List<Map<String, dynamic>> _problemCategories = [
    {
      'title': 'App Glitch / Crash',
      'icon': Icons.bug_report_outlined,
    },
    {
      'title': 'Incorrect Place Info',
      'icon': Icons.location_off_outlined,
    },
    {
      'title': 'Booking / Ticket Error',
      'icon': Icons.confirmation_number_outlined,
    },
    {
      'title': 'Other Issue',
      'icon': Icons.help_outline_rounded,
    },
  ];

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  void _submitReport() {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;
      setState(() => _isSubmitting = false);

      _descriptionController.clear();
      setState(() => _hasAttachment = false);

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Color(0xFF2E7D50), size: 28),
              SizedBox(width: 8),
              Text('Report Received'),
            ],
          ),
          content: const Text(
            'Thank you for reporting this problem. Our engineering team has received your report and will investigate it immediately.',
            style: TextStyle(fontSize: 14, color: Color(0xFF555555)),
          ),
          actions: [
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFFF641A),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.maybePop(context);
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Column(
        children: [
          ThemedTopHeader(
            title: 'Report a Problem',
            showBackButton: true,
            onBackPressed: () => Navigator.maybePop(context),
          ),
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Category selector ──────────────────────────────────
                    const Text(
                      'What kind of problem are you experiencing?',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                    const SizedBox(height: 12),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        childAspectRatio: 2.3,
                        crossAxisSpacing: 10,
                        mainAxisSpacing: 10,
                      ),
                      itemCount: _problemCategories.length,
                      itemBuilder: (context, i) {
                        final isSelected = i == _selectedCategoryIndex;
                        final cat = _problemCategories[i];
                        return GestureDetector(
                          onTap: () => setState(() => _selectedCategoryIndex = i),
                          child: Depth3DCard(
                            borderRadius: 14,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? const Color(0xFFFFF0E8)
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isSelected
                                      ? const Color(0xFFFF641A)
                                      : Colors.transparent,
                                  width: 1.5,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    cat['icon'] as IconData,
                                    color: isSelected
                                        ? const Color(0xFFFF641A)
                                        : const Color(0xFF777777),
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      cat['title'] as String,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: isSelected
                                            ? FontWeight.w700
                                            : FontWeight.w500,
                                        color: isSelected
                                            ? const Color(0xFFFF641A)
                                            : const Color(0xFF333333),
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

                    // ── Details textfield ──────────────────────────────────
                    const Text(
                      'Describe the Problem',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _descriptionController,
                      maxLines: 5,
                      validator: (val) => val == null || val.trim().isEmpty
                          ? 'Please describe the issue you encountered'
                          : null,
                      decoration: InputDecoration(
                        hintText: 'Please provide step by step details on what happened...',
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide.none,
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: Color(0xFFFF641A), width: 1.5),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ── Attachment Picker Simulation ─────────────────────────
                    const Text(
                      'Add Screenshot (Optional)',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1A1A1A),
                      ),
                    ),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: () => setState(() => _hasAttachment = !_hasAttachment),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: _hasAttachment
                                ? const Color(0xFF2E7D50)
                                : Colors.grey.shade300,
                            style: BorderStyle.solid,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              _hasAttachment ? Icons.check_circle_rounded : Icons.add_a_photo_outlined,
                              color: _hasAttachment ? const Color(0xFF2E7D50) : const Color(0xFFFF641A),
                              size: 22,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              _hasAttachment
                                  ? 'Screenshot attached (screenshot_1.jpg)'
                                  : 'Tap to select screenshot from gallery',
                              style: TextStyle(
                                fontSize: 13,
                                color: _hasAttachment ? const Color(0xFF2E7D50) : Colors.grey.shade600,
                                fontWeight: _hasAttachment ? FontWeight.w600 : FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // ── Submit Button ──────────────────────────────────────
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: _isSubmitting ? null : _submitReport,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFFFF641A),
                          minimumSize: const Size.fromHeight(52),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(999),
                          ),
                          elevation: 6,
                          shadowColor: const Color(0x33FF641A),
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.5,
                                ),
                              )
                            : const Text(
                                'Submit Report',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
