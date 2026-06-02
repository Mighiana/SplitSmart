import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../utils/theme_utils.dart';
import '../main.dart'; // for AppColors
import '../services/auth_service.dart';

class ContactUsScreen extends StatefulWidget {
  final String initialCategory;
  final String? initialMessage;

  const ContactUsScreen({
    super.key,
    this.initialCategory = 'Question',
    this.initialMessage,
  });

  @override
  State<ContactUsScreen> createState() => _ContactUsScreenState();
}

class _ContactUsScreenState extends State<ContactUsScreen> {
  final _emailCtrl = TextEditingController();
  final _msgCtrl = TextEditingController();
  bool _isSending = false;
  late String _category;

  static const _categories = [
    'Question',
    'Bug / issue',
    'Feature suggestion',
    'Account / sync',
    'Privacy',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    _category = _categories.contains(widget.initialCategory)
        ? widget.initialCategory
        : _categories.first;
    _emailCtrl.text = AuthService.instance.email ?? '';
    if (widget.initialMessage != null) {
      _msgCtrl.text = widget.initialMessage!;
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _msgCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    if (_isSending) return;
    HapticFeedback.mediumImpact();
    final email = _emailCtrl.text.trim();
    final msg = _msgCtrl.text.trim();
    if (email.isEmpty || msg.isEmpty) {
      _showToast('Please fill in both fields.');
      return;
    }
    if (!email.contains('@') || !email.contains('.')) {
      _showToast('Please enter a valid email address.');
      return;
    }

    setState(() => _isSending = true);
    try {
      final platform = Theme.of(context).platform.name;
      final packageInfo = await PackageInfo.fromPlatform();
      final auth = AuthService.instance;
      final uid = auth.uid;

      if (uid == null) {
        _showToast('Please sign in before sending a message.');
        return;
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('support_tickets')
          .add({
            'type': _category,
            'fromEmail': email,
            'message': msg,
            'uid': uid,
            'userName': auth.currentUser?.displayName,
            'appVersion': '${packageInfo.version}+${packageInfo.buildNumber}',
            'platform': platform,
            'createdAt': FieldValue.serverTimestamp(),
            'status': 'new',
            'source': 'settings_support',
          });
      if (!mounted) return;
      _showToast('Message sent! We\'ll get back to you soon.', isSuccess: true);
      _msgCtrl.clear();
    } on FirebaseException catch (e) {
      if (!mounted) return;
      debugPrint('[ContactUs] send failed: ${e.code} ${e.message}');
      _showToast('Failed to send message. Please try again.');
    } catch (e) {
      if (!mounted) return;
      debugPrint('[ContactUs] send failed: $e');
      _showToast('Failed to send message. Check your connection.');
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _showToast(String msg, {bool isSuccess = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            if (isSuccess) ...[
              const Icon(
                Icons.check_circle_outline,
                color: AppColors.green,
                size: 20,
              ),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: Text(
                msg,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: isSuccess ? Colors.white : TC.text(context),
                ),
              ),
            ),
          ],
        ),
        backgroundColor: isSuccess ? const Color(0xFF0d1f18) : TC.card(context),
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: isSuccess
              ? const BorderSide(color: AppColors.greenDim)
              : BorderSide.none,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TC.bg(context),
      appBar: AppBar(
        backgroundColor: TC.bg(context),
        elevation: 0,
        centerTitle: true,
        leading: GestureDetector(
          onTap: () {
            HapticFeedback.lightImpact();
            Navigator.pop(context);
          },
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: TC.card(context),
              shape: BoxShape.circle,
              border: Border.all(color: TC.border(context)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 16,
              color: TC.text(context),
            ),
          ),
        ),
        title: Text(
          'Contact Us',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: TC.text(context),
            letterSpacing: -0.2,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(22, 20, 22, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            const Text(
              'SUPPORT',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
                color: AppColors.green,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Get in touch',
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.w800,
                color: TC.text(context),
                height: 1.1,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Have a question or found an issue? Send us a message and we'll help you out.",
              style: TextStyle(
                fontSize: 14,
                color: TC.text2(context),
                height: 1.55,
              ),
            ),
            const SizedBox(height: 32),

            // Form Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: TC.card(context),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: TC.border(context)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 12,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Email field (without Row/Icon)
                  Text(
                    'Your email',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: TC.text(context),
                      letterSpacing: -0.1,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    style: TextStyle(fontSize: 14, color: TC.text(context)),
                    decoration: InputDecoration(
                      hintText: 'you@example.com',
                      hintStyle: TextStyle(color: TC.text3(context)),
                      filled: true,
                      fillColor: TC.bg(context),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 13,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: TC.border(context),
                          width: 1.5,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: AppColors.green,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  Text(
                    'Topic',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: TC.text(context),
                      letterSpacing: -0.1,
                    ),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    initialValue: _category,
                    dropdownColor: TC.card(context),
                    items: _categories
                        .map(
                          (category) => DropdownMenuItem(
                            value: category,
                            child: Text(category),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setState(() => _category = value);
                      }
                    },
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: TC.bg(context),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 13,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: TC.border(context),
                          width: 1.5,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: AppColors.green,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Message field
                  Text(
                    'Message',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: TC.text(context),
                      letterSpacing: -0.1,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    controller: _msgCtrl,
                    maxLines: 5,
                    style: TextStyle(fontSize: 14, color: TC.text(context)),
                    decoration: InputDecoration(
                      hintText: 'Write your question here...',
                      hintStyle: TextStyle(color: TC.text3(context)),
                      filled: true,
                      fillColor: TC.bg(context),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 13,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: TC.border(context),
                          width: 1.5,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: AppColors.green,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Reply hint
                  Row(
                    children: [
                      const Icon(
                        Icons.info_outline_rounded,
                        size: 16,
                        color: AppColors.green,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'We usually reply within 24-48 hours.',
                        style: TextStyle(
                          fontSize: 13,
                          color: TC.text2(context),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  // Send Button
                  GestureDetector(
                    onTap: _isSending ? null : _sendMessage,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: AppColors.green,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.green.withValues(alpha: 0.3),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: _isSending
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation(
                                  Colors.black,
                                ),
                              ),
                            )
                          : const Text(
                              'Send Message',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: Colors
                                    .black, // Dark text on bright green for contrast
                                letterSpacing: -0.1,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
