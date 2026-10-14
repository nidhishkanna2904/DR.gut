import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/diet_plan.dart';
import '../services/api_service.dart';
import '../theme.dart';

class DietBotScreen extends StatefulWidget {
  final DietPlan plan;

  const DietBotScreen({super.key, required this.plan});

  @override
  State<DietBotScreen> createState() => _DietBotScreenState();
}

class _DietBotScreenState extends State<DietBotScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _isTyping = false;
  late AnimationController _dotController;

  // Quick suggestion prompts
  static const List<String> _quickPrompts = [
    '🔄 Suggest a meal swap for Day 3',
    '💊 What should I eat to fix my deficiency?',
    '🥗 Can I eat less carbs in this plan?',
    '🛒 What groceries should I buy this week?',
    '⚡ I feel tired — what foods help?',
    '🌙 Is my dinner healthy enough?',
  ];

  @override
  void initState() {
    super.initState();
    _dotController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();

    // Welcome message
    _messages.add(ChatMessage(
      text: "Hi! 👋 I'm Dr. Gut, your personal nutrition assistant.\n\n"
          "I've reviewed your diet plan and I'm here to help you:\n"
          "• Understand your meal choices\n"
          "• Suggest swaps if you dislike something\n"
          "• Answer any nutrition questions\n"
          "• Help you improve the plan\n\n"
          "What would you like to know?",
      isUser: false,
      timestamp: DateTime.now(),
    ));
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    _dotController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 350),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _isTyping) return;

    _controller.clear();

    setState(() {
      _messages.add(ChatMessage(
        text: trimmed,
        isUser: true,
        timestamp: DateTime.now(),
      ));
      _isTyping = true;
    });
    _scrollToBottom();

    try {
      final reply = await ApiService.sendDietChatMessage(
        message: trimmed,
        plan: widget.plan,
      );
      if (!mounted) return;
      setState(() {
        _isTyping = false;
        _messages.add(ChatMessage(
          text: reply,
          isUser: false,
          timestamp: DateTime.now(),
        ));
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isTyping = false;
        _messages.add(ChatMessage(
          text:
              "⚠️ I couldn't connect right now. Please check your connection and try again.",
          isUser: false,
          timestamp: DateTime.now(),
        ));
      });
    }
    _scrollToBottom();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: DrGutColors.background,
      appBar: AppBar(
        backgroundColor: DrGutColors.primary,
        foregroundColor: DrGutColors.onPrimary,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: DrGutColors.accent.withValues(alpha: 0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.smart_toy_outlined,
                  color: DrGutColors.accent, size: 20),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Dr. Gut Assistant',
                  style: t.titleSmall?.copyWith(
                    color: DrGutColors.onPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'AI Nutrition Coach',
                  style: t.bodySmall?.copyWith(
                    color: DrGutColors.accent.withValues(alpha: 0.8),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep_outlined),
            tooltip: 'Clear chat',
            onPressed: () {
              setState(() {
                _messages.clear();
                _messages.add(ChatMessage(
                  text:
                      "Chat cleared! Ask me anything about your diet plan. 🌱",
                  isUser: false,
                  timestamp: DateTime.now(),
                ));
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Chat messages ────────────────────────────────────────────────
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              itemCount: _messages.length + (_isTyping ? 1 : 0),
              itemBuilder: (context, index) {
                if (_isTyping && index == _messages.length) {
                  return _TypingIndicator(dotController: _dotController);
                }
                final msg = _messages[index];
                return _MessageBubble(message: msg);
              },
            ),
          ),

          // ── Quick prompt chips ───────────────────────────────────────────
          if (_messages.length <= 2)
            SizedBox(
              height: 46,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                itemCount: _quickPrompts.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  return _QuickChip(
                    label: _quickPrompts[i],
                    onTap: () => _sendMessage(_quickPrompts[i]),
                  );
                },
              ),
            ),

          // ── Input row ────────────────────────────────────────────────────
          Container(
            decoration: BoxDecoration(
              color: DrGutColors.surface,
              border:
                  const Border(top: BorderSide(color: DrGutColors.divider)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 12,
                  offset: const Offset(0, -3),
                ),
              ],
            ),
            padding: EdgeInsets.fromLTRB(
              16,
              10,
              12,
              10 + MediaQuery.of(context).viewInsets.bottom,
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    textCapitalization: TextCapitalization.sentences,
                    maxLines: 4,
                    minLines: 1,
                    style: t.bodyMedium
                        ?.copyWith(color: DrGutColors.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Ask about your diet plan…',
                      hintStyle:
                          t.bodyMedium?.copyWith(color: DrGutColors.textMuted),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(22),
                        borderSide: const BorderSide(
                            color: DrGutColors.surfaceBorder),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(22),
                        borderSide: const BorderSide(
                            color: DrGutColors.surfaceBorder),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(22),
                        borderSide: const BorderSide(
                            color: DrGutColors.primary, width: 1.5),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 18, vertical: 12),
                      filled: true,
                      fillColor: DrGutColors.background,
                    ),
                    onSubmitted: _isTyping ? null : _sendMessage,
                  ),
                ),
                const SizedBox(width: 8),
                _SendButton(
                  isTyping: _isTyping,
                  onTap: () => _sendMessage(_controller.text),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Message bubble ─────────────────────────────────────────────────────────────
class _MessageBubble extends StatelessWidget {
  final ChatMessage message;

  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final isUser = message.isUser;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            Container(
              width: 30,
              height: 30,
              decoration: const BoxDecoration(
                color: DrGutColors.primary,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.smart_toy_outlined,
                  color: DrGutColors.accent, size: 16),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.78,
              ),
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: isUser ? DrGutColors.primary : DrGutColors.surface,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isUser ? 18 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 18),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
                border: isUser
                    ? null
                    : Border.all(color: DrGutColors.surfaceBorder),
              ),
              child: Text(
                message.text,
                style: t.bodyMedium?.copyWith(
                  color: isUser
                      ? DrGutColors.onPrimary
                      : DrGutColors.textPrimary,
                  height: 1.5,
                ),
              ),
            ),
          ),
          if (isUser) const SizedBox(width: 8),
        ],
      ),
    );
  }
}

// ── Typing indicator ───────────────────────────────────────────────────────────
class _TypingIndicator extends StatelessWidget {
  final AnimationController dotController;

  const _TypingIndicator({required this.dotController});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            width: 30,
            height: 30,
            decoration: const BoxDecoration(
              color: DrGutColors.primary,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.smart_toy_outlined,
                color: DrGutColors.accent, size: 16),
          ),
          const SizedBox(width: 8),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color: DrGutColors.surface,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
                bottomRight: Radius.circular(18),
                bottomLeft: Radius.circular(4),
              ),
              border: Border.all(color: DrGutColors.surfaceBorder),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: AnimatedBuilder(
              animation: dotController,
              builder: (context, _) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(3, (i) {
                    final phase = (dotController.value * 3 - i).clamp(0.0, 1.0);
                    final opacity =
                        (1.0 - (phase - 0.5).abs() * 2).clamp(0.2, 1.0);
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: Opacity(
                        opacity: opacity,
                        child: Container(
                          width: 7,
                          height: 7,
                          decoration: const BoxDecoration(
                            color: DrGutColors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    );
                  }),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ── Quick chip ─────────────────────────────────────────────────────────────────
class _QuickChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _QuickChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: DrGutColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: DrGutColors.surfaceBorder),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: DrGutColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
        ),
      ),
    );
  }
}

// ── Send button ────────────────────────────────────────────────────────────────
class _SendButton extends StatelessWidget {
  final bool isTyping;
  final VoidCallback onTap;

  const _SendButton({required this.isTyping, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isTyping ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: isTyping ? DrGutColors.textMuted : DrGutColors.primary,
          shape: BoxShape.circle,
          boxShadow: isTyping
              ? null
              : [
                  BoxShadow(
                    color: DrGutColors.primary.withValues(alpha: 0.35),
                    blurRadius: 10,
                    offset: const Offset(0, 3),
                  ),
                ],
        ),
        child: isTyping
            ? const Padding(
                padding: EdgeInsets.all(12),
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Icons.send_rounded,
                color: DrGutColors.accent, size: 20),
      ),
    );
  }
}
