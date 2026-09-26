import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../viewmodel/trip_optimizer_cubit.dart';
import '../viewmodel/trip_optimizer_state.dart';
import 'itinerary_view.dart';

class AiChatView extends StatefulWidget {
  const AiChatView({super.key});

  @override
  State<AiChatView> createState() => _AiChatViewState();
}

class _AiChatViewState extends State<AiChatView> {
  final TextEditingController _messageController = TextEditingController();
  final List<Map<String, dynamic>> _messages = [];
  final ScrollController _scrollController = ScrollController();
  late final FocusNode _focusNode; // FocusNode'u burada late ile tanımlıyoruz

  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();

    // Odak noktasını başlatıyor ve tuş vuruşlarını doğrudan burada dinliyoruz
    _focusNode = FocusNode(
      onKeyEvent: (node, event) {
        if (event is KeyDownEvent) {
          // Eğer basılan tuş Enter (veya Numpad Enter) ise
          if (event.logicalKey == LogicalKeyboardKey.enter ||
              event.logicalKey == LogicalKeyboardKey.numpadEnter) {

            // Eğer Shift'e de basılıyorsa, olay işlenmedi (Unhandled) de ki
            // Flutter TextField kendi bildiğini okuyup alt satıra geçsin.
            if (HardwareKeyboard.instance.isShiftPressed) {
              return KeyEventResult.ignored;
            } else {
              // Sadece Enter'a basıldıysa mesajı yolla
              _sendMessage();
              // Olayı biz işledik (Handled), TextField kendi başına alt satıra geçmesin
              return KeyEventResult.handled;
            }
          }
        }
        return KeyEventResult.ignored;
      },
    );

    _messages.add({
      "isUser": false,
      "text": "Merhaba! Ben senin akıllı seyahat asistanınım. Nereye, kaç günlüğüne ve nasıl bir bütçeyle gitmek istersin? Bana hayalindeki rotayı anlat."
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _sendMessage() {
    // Odaktan çıkmadan yazıyı alıyoruz
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    setState(() {
      _messages.add({"isUser": true, "text": text});
      _isProcessing = true;
    });

    _messageController.clear();
    _scrollToBottom();

    // Odağı TextField'da tutmak için küçük bir bekleme ekliyoruz
    FocusScope.of(context).requestFocus(_focusNode);

    // Tekil akışı tetikliyoruz
    context.read<TripOptimizerCubit>().generateRouteFromAIFlow(text);
  }

  void _scrollToBottom() {
    Future.delayed(const Duration(milliseconds: 100), () {
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
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_awesome, color: Colors.amberAccent),
            SizedBox(width: 8),
            Text('AI Rota Asistanı', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        backgroundColor: const Color(0xFF1E293B),
        centerTitle: true,
        elevation: 0,
      ),
      body: BlocConsumer<TripOptimizerCubit, TripOptimizerState>(
        listener: (context, state) {
          if (state is TripOptimizerError && _isProcessing) {
            setState(() {
              _isProcessing = false;
              _messages.add({
                "isUser": false,
                // Hatayı daha kullanıcı dostu gösterelim
                "text": state.message.contains("404") || state.message.contains("bad response")
                    ? "Üzgünüm, şu an sadece gezi planlaması üzerine konuşabiliyorum. Bana gitmek istediğin yeri söyler misin?"
                    : "Üzgünüm, bir hata oluştu: ${state.message}"
              });
            });
            _scrollToBottom();
          }
          // Sadece rota başarıyla oluştuğunda ve biz işlemdeysek ekranı aç
          else if (state is RouteOptimized && _isProcessing) {
            setState(() {
              _isProcessing = false;
            });

            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => ItineraryView(
                  itinerary: state.itinerary,
                ),
              ),
            );
          }
        },
        builder: (context, state) {
          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: _messages.length,
                  itemBuilder: (context, index) {
                    final msg = _messages[index];
                    final isUser = msg["isUser"] as bool;

                    return Align(
                      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.75,
                        ),
                        decoration: BoxDecoration(
                          color: isUser ? Colors.blueAccent : const Color(0xFF1E293B),
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(20),
                            topRight: const Radius.circular(20),
                            bottomLeft: Radius.circular(isUser ? 20 : 0),
                            bottomRight: Radius.circular(isUser ? 0 : 20),
                          ),
                          border: isUser ? null : Border.all(color: Colors.blueAccent.withOpacity(0.3)),
                        ),
                        child: Text(
                          msg["text"],
                          style: const TextStyle(color: Colors.white, fontSize: 15),
                        ),
                      ),
                    );
                  },
                ),
              ),

              if (_isProcessing)
                const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.amberAccent)),
                      SizedBox(width: 12),
                      Text("Yapay Zeka planlıyor...", style: TextStyle(color: Colors.white54, fontStyle: FontStyle.italic)),
                    ],
                  ),
                ),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(
                  color: Color(0xFF1E293B),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: SafeArea(
                  child: Row(
                    children: [
                      Expanded(
                        // RawKeyboardListener'ı kaldırdık, FocusNode kendi işini yapacak
                        child: TextField(
                          controller: _messageController,
                          focusNode: _focusNode,
                          style: const TextStyle(color: Colors.white),
                          maxLines: 4,
                          minLines: 1,
                          // textInputAction'ı newline yaptık ki mobilde normal enter tuşu görünsün
                          // ve donanım klavyesindeki müdahalemizi engellemesin
                          textInputAction: TextInputAction.newline,
                          enabled: !_isProcessing,
                          decoration: InputDecoration(
                            hintText: 'Örn: 2 günlük ucuz bir Konya turu çiz...',
                            hintStyle: TextStyle(color: Colors.grey.shade500),
                            filled: true,
                            fillColor: const Color(0xFF0F172A),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(24),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: _isProcessing ? null : _sendMessage,
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: _isProcessing ? Colors.grey.shade600 : Colors.blueAccent,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.send_rounded, color: Colors.white, size: 24),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}