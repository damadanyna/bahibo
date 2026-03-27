import 'package:flutter/material.dart';

class SellerChatPage extends StatefulWidget {
  const SellerChatPage({super.key});

  @override
  State<SellerChatPage> createState() => _SellerChatPageState();
}

class _SellerChatPageState extends State<SellerChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<_ChatMessage> _messages = [
    const _ChatMessage(
      message: 'Bonjour, le Samsung S20 est-il toujours disponible ?',
      time: '13:00',
      isMine: false,
    ),
    const _ChatMessage(
      message: 'Oui, il est toujours disponible. Interesse ?',
      time: '15:00',
      isMine: true,
    ),
    const _ChatMessage(
      message: 'Oui, je souhaite l\'acheter.',
      time: '15:00',
      isMine: false,
    ),
  ];

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    final now = TimeOfDay.now();
    final formattedTime =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';

    setState(() {
      _messages.add(
        _ChatMessage(message: text, time: formattedTime, isMine: true),
      );
    });

    _messageController.clear();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 80,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;
    final background = isDark
        ? const Color(0xFF0F1412)
        : const Color(0xFFF3F5F7);
    final panel = isDark ? const Color(0xFF171C1A) : Colors.white;
    const avatarUrl =
        'https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=200';

    return Scaffold(
      backgroundColor: background,
      body: SafeArea(
        child: Container(
          margin: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(26),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.22 : 0.12),
                blurRadius: 28,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(26),
            child: Column(
              children: [
                Container(
                  color: primary,
                  padding: const EdgeInsets.fromLTRB(5, 12, 5, 14),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.arrow_back, color: Colors.white),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text(
                              'Chat avec John',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Vendeur certifie',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      CircleAvatar(
                        radius: 18,
                        backgroundImage: const NetworkImage(avatarUrl),
                        backgroundColor: Colors.white,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.separated(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(5, 10, 5, 8),
                    itemCount: _messages.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 14),
                    itemBuilder: (context, index) {
                      final chat = _messages[index];
                      return _ChatBubble(
                        message: chat.message,
                        time: chat.time,
                        isMine: chat.isMine,
                        primaryColor: primary,
                        panelColor: panel,
                        isDark: isDark,
                      );
                    },
                  ),
                ),
                Container(
                  color: panel,
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF222826)
                                : Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isDark
                                  ? Colors.white10
                                  : const Color(0xFFE2E6EA),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: _messageController,
                                  textInputAction: TextInputAction.send,
                                  onSubmitted: (_) => _sendMessage(),
                                  decoration: InputDecoration(
                                    hintText: 'Ecrire un message...',
                                    hintStyle: TextStyle(
                                      color: isDark
                                          ? Colors.white54
                                          : const Color(0xFF8A96A3),
                                    ),
                                    border: InputBorder.none,
                                  ),
                                ),
                              ),
                              Icon(
                                Icons.add_photo_alternate_outlined,
                                color: isDark
                                    ? Colors.white54
                                    : const Color(0xFF7B8794),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: _sendMessage,
                        child: Container(
                          width: 52,
                          height: 52,
                          decoration: BoxDecoration(
                            color: primary,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: primary.withOpacity(0.28),
                                blurRadius: 18,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.send_rounded,
                            color: Colors.white,
                            size: 24,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ChatMessage {
  final String message;
  final String time;
  final bool isMine;

  const _ChatMessage({
    required this.message,
    required this.time,
    required this.isMine,
  });
}

class _ChatBubble extends StatelessWidget {
  final String message;
  final String time;
  final bool isMine;
  final Color primaryColor;
  final Color panelColor;
  final bool isDark;

  const _ChatBubble({
    required this.message,
    required this.time,
    required this.isMine,
    required this.primaryColor,
    required this.panelColor,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    final bubbleColor = isMine ? primaryColor : panelColor;
    final textColor = isMine
        ? Colors.white
        : (isDark ? Colors.white : const Color(0xFF2F3A45));
    final timeColor = isMine
        ? Colors.white70
        : (isDark ? Colors.white54 : const Color(0xFF8A96A3));

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 270),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
          decoration: BoxDecoration(
            color: bubbleColor,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(isMine ? 16 : 4),
              bottomRight: Radius.circular(isMine ? 4 : 16),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.18 : 0.06),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                message,
                style: TextStyle(
                  color: textColor,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  time,
                  style: TextStyle(
                    color: timeColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
