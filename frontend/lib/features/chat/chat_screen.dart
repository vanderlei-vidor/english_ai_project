import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import 'package:confetti/confetti.dart';
import 'package:audioplayers/audioplayers.dart';
import '../ranking/ranking_screen.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import '../../widgets/voice_orb.dart';
import '../../widgets/starfield_background.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with TickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  List<Map<String, dynamic>> messages = [];

  int totalXp = 0;
  int earnedXp = 0;
  int progressPercent = 0;
  String league = "Bronze";

  late AnimationController _xpController;
  late Animation<double> _xpAnimation;
  bool showXp = false;

  late ConfettiController _confettiController;
  String newBadgeTitle = "";
  bool showBadge = false;

  final AudioPlayer _audioPlayer = AudioPlayer();

  bool showLeagueUp = false;
  String newLeagueName = "";

  late AnimationController _leagueController;
  late Animation<double> _leagueScale;

  late stt.SpeechToText _speech;
  late FlutterTts _tts;

  bool isListening = false;
  String voiceState = "idle";

  final ScrollController _scrollController = ScrollController();

  double soundLevel = 0;

  bool isThinking = false;

  String streamingText = "";

  bool isStreaming = false;

  double aiSoundLevel = 0;

  @override
  void initState() {
    super.initState();

    Timer.periodic(const Duration(milliseconds: 500), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (isThinking) {
        setState(() {
          thinkingDots++;

          if (thinkingDots > 3) {
            thinkingDots = 1;
          }
        });
      }
    });

    _confettiController = ConfettiController(
      duration: const Duration(seconds: 2),
    );

    _xpController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _xpAnimation = CurvedAnimation(
      parent: _xpController,
      curve: Curves.elasticOut,
    );

    _leagueController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );

    _leagueScale = Tween<double>(begin: 0.5, end: 1.2).animate(
      CurvedAnimation(parent: _leagueController, curve: Curves.elasticOut),
    );

    _speech = stt.SpeechToText();

    initTts();
  }

  @override
  void dispose() {
    _speech.stop();
    _tts.stop();

    _xpController.dispose();
    _leagueController.dispose();
    _confettiController.dispose();
    _audioPlayer.dispose();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  bool voiceModeEnabled = true;

  Future<void> awaitTts() async {
    await _tts.setLanguage("en-US");
    await _tts.setSpeechRate(0.45);
  }

  Future<void> startListening() async {
    FocusScope.of(context).unfocus();

    await _speech.stop();

    await Future.delayed(const Duration(milliseconds: 300));

    print("START LISTENING");

    bool available = await _speech.initialize(
      onStatus: (status) async {
        print("STATUS: $status");

        if (status == "done") {
          setState(() {
            isListening = false;
          });

          if (_controller.text.isNotEmpty) {
            await sendMessage();

            _controller.clear();
          }
        }
      },
      onError: (error) {
        print("ERROR: ${error.errorMsg}");

        setState(() {
          isListening = false;
          voiceState = "idle";
        });
      },
    );

    print("AVAILABLE: $available");

    if (available) {
      setState(() {
        isListening = true;
      });
      setState(() {
        voiceState = "listening";
      });

      await _speech.listen(
        localeId: "en-US",
        partialResults: true,
        onSoundLevelChange: (level) {
          setState(() {
            soundLevel = level;
          });
        },
        onResult: (result) {
          print("WORDS: ${result.recognizedWords}");

          setState(() {
            _controller.text = result.recognizedWords;
          });
        },
      );
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        // Pequeno delay para garantir que o ListView calculou o tamanho da animação
        Future.delayed(const Duration(milliseconds: 100), () {
          if (_scrollController.hasClients) {
            _scrollController.animateTo(
              _scrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeOut,
            );
          }
        });
      }
    });
  }

  void _scrollStreaming() {
    if (!_scrollController.hasClients) return;

    _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
  }

  Future<void> stopListening() async {
    await _speech.stop();

    setState(() {
      isListening = false;
      voiceState = "idle";
    });
  }

  Future<void> initTts() async {
    _tts = FlutterTts();

    // Configurações de áudio para garantir que saia no alto-falante
    await _tts.setIosAudioCategory(IosTextToSpeechAudioCategory.playback, [
      IosTextToSpeechAudioCategoryOptions.allowBluetooth,
      IosTextToSpeechAudioCategoryOptions.allowBluetoothA2DP,
      IosTextToSpeechAudioCategoryOptions.mixWithOthers,
    ], IosTextToSpeechAudioMode.voicePrompt);

    await _tts.setLanguage("en-US");
    await _tts.setSpeechRate(0.45);
    await _tts.setPitch(1.0);
    await _tts.setVolume(1.0); // Garante volume no máximo do app

    // O pulo do gato: desative o awaitSpeakCompletion para teste
    await _tts.awaitSpeakCompletion(true);

    _tts.setCompletionHandler(() async {
      if (!mounted) return;

      setState(() {
        voiceState = "idle";
      });

      if (voiceModeEnabled) {
        await Future.delayed(const Duration(milliseconds: 1200));

        if (mounted) {
          startListening();
        }
      }
    });

    // Handler de erro para você ver no console se algo falhar
    _tts.setErrorHandler((msg) {
      print("Erro no TTS: $msg");
      setState(() => voiceState = "idle");
    });
  }

  Future<void> sendMessage() async {
    final userText = _controller.text;
    if (userText.isEmpty) return;

    setState(() {
      messages.add({"sender": "user", "text": userText});
      isThinking = true;
      voiceState = "thinking";
    });

    _scrollToBottom();
    _controller.clear();

    try {
      final result = await ApiClient.post("/chat", {
        "user_id": "ad32edbf-b496-4e9a-9907-f52aba6a518d",
        "message": userText,
      });

      if (result == null || result["ai_response"] == null) {
        throw Exception("Resposta inválida do servidor");
      }

      final aiReply = result["ai_response"]["conversation_reply"] ?? "";
      String oldLeague = league;

      setState(() {
        isThinking = false;
        // showFeedback = false;
        voiceState = "speaking";
      });

      // 🔥 CORREÇÃO: Chame o streamResponse APENAS UMA VEZ aqui
      await streamResponse(aiReply);

      setState(() {
        messages.add({
          "sender": "ai",
          "text": aiReply,
          "showFeedback": false,
          "correction": result["ai_response"]["correction"] ?? "",
          "explanation": result["ai_response"]["explanation_pt"] ?? "",
          "example": result["ai_response"]["example"] ?? "",
          "exercise": result["ai_response"]["exercise"] ?? "",
        });

        // 🔥 PROTEÇÃO TOTAL CONTRA ERRO DE INT/DOUBLE
        earnedXp =
            int.tryParse(result["xp"]?["earned"]?.toString() ?? "0") ?? 0;
        totalXp = int.tryParse(result["xp"]?["total"]?.toString() ?? "0") ?? 0;

        // Use .toInt() para converter o valor, em vez de "as int"
        progressPercent =
            (double.tryParse(
                      result["xp"]?["level"]?["progress_percentage"]
                              ?.toString() ??
                          "0",
                    ) ??
                    0.0)
                .toInt();

        league = result["xp"]?["level"]?["name"] ?? "Bronze";
      });

      // Feedback visual/sonoro após o streaming
      Future.delayed(const Duration(milliseconds: 500), () async {
        if (!mounted) return;

        setState(() {
          messages.last["showFeedback"] = true;
        });

        await Future.delayed(const Duration(milliseconds: 50));

        // 🔥 SCROLL DO FEEDBACK
        _scrollToBottom();

        if ((result["ai_response"]["correction"] ?? "").isNotEmpty) {
          await _audioPlayer.play(AssetSource('sounds/holographic_ping.mp3'));
        }
      });

      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

      // --- Lógica do TTS ---
      String textToSpeak = aiReply.replaceAll(RegExp(r'[*_#]'), '');
      await _tts.stop();
      await _tts.setLanguage("en-US");
      await _tts.setSpeechRate(0.45);

      if (textToSpeak.isNotEmpty) {
        await _tts.speak(textToSpeak);
      }

      // --- Gamificação ---
      if (earnedXp > 0) {
        setState(() => showXp = true);
        _xpController.forward(from: 0);
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) setState(() => showXp = false);
        });
      }

      if (result["badges_earned"] != null &&
          (result["badges_earned"] as List).isNotEmpty) {
        setState(() {
          newBadgeTitle = result["badges_earned"][0]["title"] ?? "";
          showBadge = true;
        });
        _confettiController.play();
        _audioPlayer.play(AssetSource('sounds/victory.mp3'));
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) setState(() => showBadge = false);
        });
      }

      if (oldLeague != league) {
        triggerLeagueUpAnimation();
      }
    } catch (e) {
      print("Erro no envio: $e");
      setState(() {
        isThinking = false;
        voiceState = "idle";
        messages.add({
          "sender": "ai",
          "text":
              "Sorry, I'm having trouble connecting. Please check your internet. 📡",
        });
      });
    }
  }

  Widget buildMessage(Map<String, dynamic> message) {
    final isUser = message["sender"] == "user";

    // O TweenAnimationBuilder envolve todo o conteúdo para animar a entrada
    return TweenAnimationBuilder(
      duration: const Duration(
        milliseconds: 600,
      ), // Um pouco mais lento fica mais elegante
      tween: Tween<double>(begin: 0, end: 1),
      curve: Curves.easeOutCubic,
      builder: (context, double value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(
              isUser ? 40 * (1 - value) : -40 * (1 - value),

              20 * (1 - value),
            ),
            child: Transform.scale(
              scale: 0.96 + (value * 0.04),
              // Desliza 30 pixels para cima
              child: child,
            ),
          ),
        );
      },
      child: Align(
        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: Column(
          crossAxisAlignment: isUser
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            // 💬 BOLHA CHAT COM GLASSMORPHISM
            Container(
              margin: const EdgeInsets.symmetric(vertical: 6),
              constraints: const BoxConstraints(maxWidth: 280),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(22),
                clipBehavior: Clip.antiAlias,
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(22),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,

                        colors: isUser
                            ? [
                                Colors.cyanAccent.withOpacity(0.22),

                                Colors.blueAccent.withOpacity(0.12),

                                Colors.white.withOpacity(0.03),
                              ]
                            : [
                                Colors.deepPurpleAccent.withOpacity(0.18),

                                Colors.purpleAccent.withOpacity(0.08),

                                Colors.white.withOpacity(0.03),
                              ],
                      ),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.18),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: isUser
                              ? Colors.cyanAccent.withOpacity(0.16)
                              : Colors.deepPurpleAccent.withOpacity(0.18),

                          blurRadius: 28,
                          spreadRadius: 2,
                          offset: const Offset(0, 10),
                        ),

                        BoxShadow(
                          color: Colors.black.withOpacity(0.25),

                          blurRadius: 25,
                          offset: const Offset(0, 12),
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        // 🌌 INNER LIGHT
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,

                          child: Container(
                            height: 16,

                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(22),
                                topRight: Radius.circular(22),
                              ),

                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,

                                colors: [
                                  Colors.white.withOpacity(0.035),

                                  Colors.transparent,
                                ],
                              ),
                            ),
                          ),
                        ),

                        // 💬 MESSAGE TEXT
                        Text(
                          message["text"] ?? "",

                          style: TextStyle(
                            color: isUser
                                ? Colors.white
                                : Colors.white.withOpacity(0.9),

                            fontSize: 15,
                            height: 1.4,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // ✨ FEEDBACK CARD
            if (!isUser) buildFeedbackCard(message),
          ],
        ),
      ),
    );
  }

  Widget buildFeedbackCard(Map<String, dynamic> message) {
    final correction = message["correction"] ?? "";

    if (correction.isEmpty) {
      return const SizedBox();
    }

    if (!(message["showFeedback"] ?? false)) {
      return const SizedBox();
    }

    return TweenAnimationBuilder(
      duration: const Duration(milliseconds: 1200),
      tween: Tween<double>(begin: 0, end: 1),
      curve: Curves.easeOutExpo,
      builder: (context, double value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 40 * (1 - value)), // Sobe de 40 para 0
            child: Transform.scale(
              scale: 0.92 + (value * 0.08), // Aumenta de 0.92 para 1.0
              child: child,
            ),
          ),
        );
      },
      // 🔥 O SEU CARD ENTRA AQUI COMO CHILD:
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            margin: const EdgeInsets.only(top: 10),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,

                colors: [
                  Colors.white.withOpacity(0.12),

                  Colors.deepPurpleAccent.withOpacity(0.08),

                  Colors.cyanAccent.withOpacity(0.03),
                ],
              ),
              border: Border.all(
                color: Colors.white.withOpacity(0.18),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.25),
                  blurRadius: 35,
                  spreadRadius: 3,
                  offset: const Offset(0, 10),
                ),
                BoxShadow(
                  color: Colors.deepPurpleAccent.withOpacity(0.18),
                  blurRadius: 18,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "🌌 AI Feedback",
                  style: TextStyle(
                    color: Colors.greenAccent,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,

                    shadows: [
                      Shadow(color: Colors.greenAccent, blurRadius: 14),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  "✅ Correction:\n${message["correction"]}",
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  "📘 Explanation:\n${message["explanation"]}",
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 10),
                Text(
                  "💡 Example:\n${message["example"]}",
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 10),
                Text(
                  "🧠 Exercise:\n${message["exercise"]}",
                  style: const TextStyle(
                    color: Colors.amber,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  int thinkingDots = 1;

  Widget buildThinkingIndicator() {
    return Align(
      alignment: Alignment.centerLeft,

      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),

        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),

        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),

          gradient: LinearGradient(
            colors: [
              Colors.deepPurpleAccent.withOpacity(0.22),
              Colors.blueGrey.withOpacity(0.12),
            ],
          ),

          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),

        child: Row(
          mainAxisSize: MainAxisSize.min,

          children: [
            const Text(
              "AI is thinking",
              style: TextStyle(color: Colors.white70),
            ),

            const SizedBox(width: 12),

            SizedBox(
              width: 40,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),

                transitionBuilder: (child, animation) {
                  return FadeTransition(opacity: animation, child: child);
                },

                child: Text(
                  "." * thinkingDots,

                  key: ValueKey(thinkingDots),

                  style: const TextStyle(color: Colors.white, fontSize: 22),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildStreamingMessage() {
    return Align(
      alignment: Alignment.centerLeft,

      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),

        padding: const EdgeInsets.all(14),

        constraints: const BoxConstraints(maxWidth: 280),

        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),

          gradient: LinearGradient(
            colors: [
              Colors.deepPurpleAccent.withOpacity(0.22),
              Colors.blueGrey.withOpacity(0.15),
            ],
          ),

          border: Border.all(color: Colors.white.withOpacity(0.1)),

          boxShadow: [
            BoxShadow(
              color: Colors.deepPurpleAccent.withOpacity(0.18),

              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),

        child: Text(
          streamingText,

          style: const TextStyle(color: Colors.white, fontSize: 15),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("English AI"),
        backgroundColor: const Color(0xFF020617),
        actions: [
          IconButton(
            icon: const Icon(Icons.emoji_events),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const RankingScreen()),
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          // 🌌 CAMADA 0: O FUNDO DE ESTRELAS/PARTÍCULAS
          const Positioned.fill(child: StarfieldBackground()),

          Column(
            children: [
              // 🔥 HEADER PREMIUM
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(color: Color(0xFF0F172A)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          "🔥 Liga: $league",
                          style: const TextStyle(color: Colors.white),
                        ),
                        Text(
                          "⭐ XP: $totalXp",
                          style: const TextStyle(color: Colors.white),
                        ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    LinearProgressIndicator(
                      value: progressPercent / 100,
                      backgroundColor: Colors.grey.shade800,
                      color: Colors.greenAccent,
                      minHeight: 8,
                    ),

                    const SizedBox(height: 6),

                    Text(
                      "Progresso: $progressPercent%",
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  child: VoiceOrb(
                    state: voiceState,
                    soundLevel: voiceState == "speaking"
                        ? aiSoundLevel
                        : soundLevel,
                  ),
                ),
              ),
              // 💬 CHAT AREA
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount:
                      messages.length +
                      (isThinking ? 1 : 0) +
                      (isStreaming ? 1 : 0),
                  physics:
                      const BouncingScrollPhysics(), // Melhora a sensação de scroll

                  itemBuilder: (context, index) {
                    if (index < messages.length) {
                      return buildMessage(messages[index]);
                    }

                    if (isThinking && index == messages.length) {
                      return buildThinkingIndicator();
                    }

                    if (isStreaming) {
                      return buildStreamingMessage();
                    }

                    return const SizedBox();

                    return buildMessage(messages[index]);
                  },
                ),
              ),

              // ✍ INPUT
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey.shade900,
                  border: const Border(top: BorderSide(color: Colors.white12)),
                ),
                child: Row(
                  children: [
                    // 🎤 MICROFONE
                    Container(
                      decoration: BoxDecoration(
                        color: isListening
                            ? Colors.redAccent
                            : Colors.blueAccent,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: Icon(
                          isListening ? Icons.mic : Icons.mic_none,
                          color: Colors.white,
                        ),
                        onPressed: () {
                          if (isListening) {
                            stopListening();
                          } else {
                            startListening();
                          }
                        },
                      ),
                    ),

                    const SizedBox(width: 10),

                    // ✍ INPUT
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: TextField(
                          controller: _controller,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            hintText: "Type or speak...",
                            hintStyle: TextStyle(color: Colors.white54),
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 10),

                    // 🚀 BOTÃO ENVIAR
                    Container(
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.send, color: Colors.white),
                        onPressed: sendMessage,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              shouldLoop: false,
              numberOfParticles: 30,
              maxBlastForce: 20,
              minBlastForce: 8,
            ),
          ),

          // 🎉 OVERLAY XP
          if (showXp)
            Center(
              child: ScaleTransition(
                scale: _xpAnimation,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 40,
                    vertical: 20,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    "🎉 +$earnedXp XP",
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.greenAccent,
                    ),
                  ),
                ),
              ),
            ),

          if (showBadge)
            Center(
              child: Container(
                padding: const EdgeInsets.all(24),
                margin: const EdgeInsets.symmetric(horizontal: 40),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      "🏆 Novo Badge!",
                      style: TextStyle(
                        color: Colors.amber,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      newBadgeTitle,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 18),
                    ),
                  ],
                ),
              ),
            ),
          if (showLeagueUp)
            Container(
              color: Colors.black.withOpacity(0.85),
              child: Center(
                child: ScaleTransition(
                  scale: _leagueScale,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.emoji_events,
                        color: Colors.amber,
                        size: 80,
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        "LEAGUE PROMOTION!",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        newLeagueName,
                        style: const TextStyle(
                          color: Colors.greenAccent,
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
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

  void triggerLeagueUpAnimation() async {
    newLeagueName = league;

    setState(() {
      showLeagueUp = true;
    });

    _leagueController.forward(from: 0);

    await _audioPlayer.play(AssetSource('sounds/victory.mp3'));

    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        setState(() {
          showLeagueUp = false;
        });
      }
    });
  }

  Future<void> _setupAudioAndTts() async {
    await initTts(); // Primeiro inicializa e configura os handlers
    await _tts.setLanguage("en-US");
    await _tts.setSpeechRate(0.45);
  }

  Future<void> streamResponse(String text) async {
    setState(() {
      isThinking = false; // Garante que o loading pare
      isStreaming = true;
      streamingText = "";
    });

    final words = text.split(" ");
    for (final word in words) {
      if (!mounted) return; // Segurança caso o usuário saia da tela

      setState(() {
        streamingText += "$word ";
        aiSoundLevel = 10 + Random().nextDouble() * 25;
      });

      int delay = 110;

      if (word.contains(".") || word.contains("!") || word.contains("?")) {
        delay = 320;
      } else if (word.contains(",")) {
        delay = 180;
      }

      await Future.delayed(Duration(milliseconds: delay));
      _scrollStreaming();
    }

    // Não resetamos o isStreaming aqui imediatamente para evitar o "flicker" (piscada)
    // Deixamos o sendMessage cuidar da transição final.
    setState(() {
      isStreaming = false;
    });
    aiSoundLevel = 0;
  }
}
