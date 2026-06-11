import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class ChatBotScreen extends StatefulWidget {
  final String? initialMessage;
  final VoidCallback? onBackHome;

  const ChatBotScreen({super.key, this.initialMessage, this.onBackHome});

  @override
  State<ChatBotScreen> createState() => _ChatBotScreenState();
}

class _ChatBotScreenState extends State<ChatBotScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  late List<Map<String, dynamic>> _messages;

  bool _isLoading = false;

  static const String _geminiApiKey = '_여기에 api키를 입력하세요_';

  @override
  void initState() {
    super.initState();

    _messages = [
      {
        'text': '안녕하세요. 무엇이든 편하게 물어보세요.',
        'isMe': false,
      },
    ];

    if (widget.initialMessage != null &&
        widget.initialMessage!.trim().isNotEmpty) {
      _messages.add({'text': widget.initialMessage!, 'isMe': true});

      Future.delayed(Duration.zero, () {
        _sendInitialMessage(widget.initialMessage!);
      });
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _handleBack() {
    if (widget.onBackHome != null) {
      widget.onBackHome!();
    } else if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
  }

  Future<String> _getGeminiResponse(String message) async {
    try {
      final url = Uri.parse(
        'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent',
      );

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'x-goog-api-key': _geminiApiKey,
        },
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {
                  'text': '너는 친절한 한국어 AI assistant다.\n'
                      '사용자의 질문에 자연스럽고 정확하게 답변해라.\n'
                      '불필요하게 형식을 강제하지 말고, 일반적인 AI 챗봇처럼 대화해라.\n'
                      '사용자가 스미싱, 피싱, 의심 문자, 링크 클릭, 개인정보 입력, 금전 피해에 대해 물어볼 때만 '
                      '안전 조치와 신고 방법을 함께 안내해라.\n\n'
                      '사용자 질문:\n$message',
                }
              ],
            }
          ],
          'generationConfig': {
            'temperature': 0.7,
            'maxOutputTokens': 1000,
          },
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));

        final text = data['candidates']?[0]?['content']?['parts']?[0]?['text'];

        if (text != null && text.toString().trim().isNotEmpty) {
          return text.toString().trim();
        }

        return '답변이 비어 있어요. 다시 입력해주세요.';
      } else {
        return 'Gemini API 오류가 발생했어요.\n'
            '상태 코드: ${response.statusCode}\n'
            '응답 내용: ${response.body}';
      }
    } catch (e) {
      return '네트워크 오류가 발생했어요.\n$e';
    }
  }

  Future<void> _sendInitialMessage(String text) async {
    setState(() {
      _isLoading = true;
    });

    final aiReply = await _getGeminiResponse(text);

    setState(() {
      _messages.add({'text': aiReply, 'isMe': false});
      _isLoading = false;
    });

    _scrollToBottom();
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty || _isLoading) return;

    final String text = _messageController.text.trim();

    setState(() {
      _messages.add({'text': text, 'isMe': true});
      _messageController.clear();
      _isLoading = true;
    });

    _scrollToBottom();

    final String aiReply = await _getGeminiResponse(text);

    setState(() {
      _messages.add({'text': aiReply, 'isMe': false});
      _isLoading = false;
    });

    _scrollToBottom();
  }

  void _addQuickMessage(String text) {
    if (_isLoading) return;
    _messageController.text = text;
    _sendMessage();
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
      if (!_scrollController.hasClients) return;

      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 120,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  Widget _buildQuickAction(String label, IconData icon) {
    return InkWell(
      onTap: () => _addQuickMessage(label),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFFEAF4FF),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFB9D8FF)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: const Color(0xFF1565C0)),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: Color(0xFF1565C0),
                fontWeight: FontWeight.w600,
                fontSize: 13.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> msg) {
    final bool isMe = msg['isMe'] as bool;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMe) ...[
            Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                color: Color(0xFF1565C0),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.smart_toy_rounded,
                color: Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.72,
              ),
              decoration: BoxDecoration(
                color: isMe ? const Color(0xFF1976D2) : Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isMe ? 18 : 6),
                  bottomRight: Radius.circular(isMe ? 6 : 18),
                ),
                border:
                    isMe ? null : Border.all(color: const Color(0xFFD9E6F5)),
                boxShadow: [
                  BoxShadow(
	                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Text(
                msg['text'] as String,
                style: TextStyle(
                  fontSize: 15.5,
                  height: 1.55,
                  color: isMe ? Colors.white : const Color(0xFF1F2937),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingBubble() {
    return Align(
      alignment: Alignment.centerLeft,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: const BoxDecoration(
              color: Color(0xFF1565C0),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.smart_toy_rounded,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFD9E6F5)),
            ),
            child: const Text(
              '답변을 생성하고 있어요...',
              style: TextStyle(
                fontSize: 15,
                color: Color(0xFF64748B),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          _handleBack();
        }
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFF4F8FC),
        appBar: AppBar(
          elevation: 0,
          backgroundColor: const Color(0xFFF4F8FC),
          foregroundColor: Colors.black,
          centerTitle: true,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded),
            onPressed: _handleBack,
          ),
          title: const Text(
            'AI 챗봇',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        resizeToAvoidBottomInset: true,
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1565C0), Color(0xFF1E88E5)],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 22,
                      backgroundColor: Colors.white24,
                      child: Icon(
                        Icons.smart_toy_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'AI 상담 활성화',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w800,
                              fontSize: 17,
                            ),
                          ),
                          SizedBox(height: 6),
                          Text(
                            'AI가 상담을 도와드립니다.',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 13.5,
                              height: 1.45,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                itemCount: _messages.length + (_isLoading ? 1 : 0),
                itemBuilder: (context, index) {
                  if (_isLoading && index == _messages.length) {
                    return _buildLoadingBubble();
                  }
                  return _buildMessageBubble(_messages[index]);
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildQuickAction('의심 문자 확인해줘', Icons.sms_outlined),
                    _buildQuickAction('링크를 눌렀어요', Icons.link_off),
                    _buildQuickAction('신고 방법 알려줘', Icons.campaign_outlined),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: const Color(0xFFD6E0EA)),
                        ),
                        child: TextField(
                          controller: _messageController,
                          enabled: !_isLoading,
                          style: const TextStyle(
                            fontSize: 15.5,
                            color: Color(0xFF0F172A),
                          ),
                          minLines: 1,
                          maxLines: 4,
                          decoration: const InputDecoration(
                            hintText: '무엇이든 물어보세요',
                            hintStyle: TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 14.5,
                            ),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                          ),
                          onSubmitted: (_) => _sendMessage(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF1565C0), Color(0xFF1E88E5)],
                        ),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: IconButton(
                        icon: const Icon(
                          Icons.send_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                        onPressed: _isLoading ? null : _sendMessage,
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
}
