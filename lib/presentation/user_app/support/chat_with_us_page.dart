import 'dart:async';
import 'package:flutter/material.dart';
import '../../../core/widgets/app_theme.dart';
import '../../../core/widgets/themed_top_header.dart';

class ChatWithUsPage extends StatefulWidget {
  const ChatWithUsPage({super.key});

  @override
  State<ChatWithUsPage> createState() => _ChatWithUsPageState();
}

class _ChatWithUsPageState extends State<ChatWithUsPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, dynamic>> _messages = [];
  bool _isTyping = false;

  final List<String> _suggestedTopics = [
    'Ticket Booking Issue',
    'Cancel / Refund ticket',
    'Edit Profile Profile',
    'Incorrect Place Info',
    'Payment Problem',
  ];

  @override
  void initState() {
    super.initState();
    // Insert initial support agent greetings
    _messages.add({
      'isUser': false,
      'text': 'Hello! Thanks for reaching out to HAYY support team. 👋',
      'time': DateTime.now(),
    });
    _messages.add({
      'isUser': false,
      'text': 'How can we help you today? Please choose a topic below or type your question.',
      'time': DateTime.now(),
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
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

  void _sendMessage(String text) {
    if (text.trim().isEmpty) return;

    setState(() {
      _messages.add({
        'isUser': true,
        'text': text.trim(),
        'time': DateTime.now(),
      });
      _isTyping = true;
    });

    _messageController.clear();
    _scrollToBottom();

    // Simulate Agent response
    Timer(const Duration(milliseconds: 1500), () {
      if (!mounted) return;
      
      String response = '';
      final lower = text.toLowerCase();
      if (lower.contains('booking') || lower.contains('ticket')) {
        response = 'Sure! I can help you with your booking. Please share your ticket ID or email registered with the booking so I can look up the details.';
      } else if (lower.contains('refund') || lower.contains('cancel')) {
        response = 'Refund requests are processed within 3-5 business days. Please write down the details of the booking and our billing agent will review it immediately.';
      } else if (lower.contains('payment')) {
        response = 'If your payment failed but the amount was deducted, it will be automatically refunded by your bank within 24 hours. Please double check with your bank issuer.';
      } else {
        response = 'Thank you for explaining this. I have opened a support ticket for you. Our agent will review this issue and reply back within a few minutes.';
      }

      setState(() {
        _isTyping = false;
        _messages.add({
          'isUser': false,
          'text': response,
          'time': DateTime.now(),
        });
      });
      _scrollToBottom();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Column(
        children: [
          // ── Header with agent info ─────────────────────────────────────────
          ThemedTopHeader(
            title: 'Live Chat',
            showBackButton: true,
            onBackPressed: () => Navigator.maybePop(context),
            trailing: Container(
              margin: const EdgeInsets.only(right: 16),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF2E7D50).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(99),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 3.0,
                    backgroundColor: Color(0xFF2E7D50),
                  ),
                  SizedBox(width: 5),
                  Text(
                    'Online',
                    style: TextStyle(
                      color: Color(0xFF2E7D50),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Chat Messages list ─────────────────────────────────────────────
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              physics: const BouncingScrollPhysics(),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                return _ChatBubble(
                  isUser: msg['isUser'] as bool,
                  text: msg['text'] as String,
                  time: msg['time'] as DateTime,
                );
              },
            ),
          ),

          // ── Typing indicator ───────────────────────────────────────────────
          if (_isTyping)
            Padding(
              padding: const EdgeInsets.only(left: 20, bottom: 8),
              child: Row(
                children: [
                  Text(
                    'Support Agent is typing...',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),

          // ── Quick suggestions chips ────────────────────────────────────────
          if (_messages.length <= 2) _buildSuggestions(),

          // ── Input area ─────────────────────────────────────────────────────
          _buildInputBar(),
        ],
      ),
    );
  }

  Widget _buildSuggestions() {
    return Container(
      height: 38,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _suggestedTopics.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          return ActionChip(
            label: Text(_suggestedTopics[i]),
            onPressed: () => _sendMessage(_suggestedTopics[i]),
            backgroundColor: Colors.white,
            labelStyle: const TextStyle(
              color: Color(0xFFFF641A),
              fontWeight: FontWeight.w600,
              fontSize: 12.5,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(999),
              side: const BorderSide(color: Color(0xFFFFE0D0)),
            ),
          );
        },
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 10,
        bottom: 10 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F5F9),
                borderRadius: BorderRadius.circular(24),
              ),
              child: TextField(
                controller: _messageController,
                decoration: InputDecoration(
                  hintText: 'Type a message...',
                  hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                  border: InputBorder.none,
                ),
                onSubmitted: _sendMessage,
              ),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: () => _sendMessage(_messageController.text),
            child: Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: Color(0xFFFF641A),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.send_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final bool isUser;
  final String text;
  final DateTime time;

  const _ChatBubble({
    required this.isUser,
    required this.text,
    required this.time,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isUser ? const Color(0xFFFF641A) : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isUser ? 16 : 4),
            bottomRight: Radius.circular(isUser ? 4 : 16),
          ),
          boxShadow: const [
            BoxShadow(
              color: Color(0x05000000),
              blurRadius: 6,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              text,
              style: TextStyle(
                color: isUser ? Colors.white : const Color(0xFF333333),
                fontSize: 13.5,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
                  style: TextStyle(
                    color: isUser ? Colors.white60 : Colors.grey.shade400,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
