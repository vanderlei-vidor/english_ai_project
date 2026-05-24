import 'package:flutter/material.dart';
import '../../core/api_client.dart';
import 'package:confetti/confetti.dart';
import 'package:audioplayers/audioplayers.dart';
import '../ranking/ranking_screen.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:flutter_tts/flutter_tts.dart';
import '../../widgets/voice_orb.dart';

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

  @override
  void initState() {
    super.initState();

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

    awaitTts();
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
    print("START LISTENING");

    FocusScope.of(context).unfocus();

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
        print("ERROR: $error");
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
        localeId: "en_US",
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

  Future<void> stopListening() async {
    await _speech.stop();

    setState(() {
      isListening = false;
      voiceState = "idle";
    });
  }

  Future<void> initTts() async {
    _tts = FlutterTts();

    await _tts.awaitSpeakCompletion(true);

    await _tts.setSharedInstance(true);

    await _tts.setLanguage("en-US");

    await _tts.setSpeechRate(0.45);

    await _tts.setPitch(1.0);

    await _tts.setVoice({"name": "en-us-x-tpf-local", "locale": "en-US"});

    _tts.setCompletionHandler(() async {
      setState(() {
        voiceState = "idle";
      });

      if (voiceModeEnabled) {
        await startListening();
      }
    });
  }

  Future<void> sendMessage() async {
    final userText = _controller.text;
    if (userText.isEmpty) return;

    setState(() {
      messages.add({"sender": "user", "text": userText});
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,

        duration: const Duration(milliseconds: 400),

        curve: Curves.easeOut,
      );
    });
    setState(() {
      voiceState = "thinking";
    });

    final result = await ApiClient.post("/chat", {
      "user_id": "ad32edbf-b496-4e9a-9907-f52aba6a518d",
      "message": userText,
    });

    final aiReply = result["ai_response"]["conversation_reply"] ?? "";
    setState(() {
      voiceState = "speaking";
    });
    await _tts.speak(aiReply);

    _controller.clear();

    String oldLeague = league;

    setState(() {
      messages.add({
        "sender": "ai",
        "text": aiReply,

        "correction": result["ai_response"]["correction"] ?? "",
        "explanation": result["ai_response"]["explanation_pt"] ?? "",
        "example": result["ai_response"]["example"] ?? "",
        "exercise": result["ai_response"]["exercise"] ?? "",
      });

      earnedXp = result["xp"]["earned"];
      totalXp = result["xp"]["total"];
      progressPercent = result["xp"]["level"]["progress_percentage"];

      league = result["xp"]["level"]["name"];
    });

    Future.delayed(const Duration(milliseconds: 100), () {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });

    // 🎉 XP animation
    if (earnedXp > 0) {
      setState(() => showXp = true);
      _xpController.forward(from: 0);

      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) setState(() => showXp = false);
      });
    }

    // 🏆 Badge
    if (result["badges_earned"] != null && result["badges_earned"].isNotEmpty) {
      newBadgeTitle = result["badges_earned"][0]["title"];
      setState(() => showBadge = true);

      _confettiController.play();
      await _audioPlayer.play(AssetSource('sounds/victory.mp3'));

      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) setState(() => showBadge = false);
      });
    }

    // 🚀 League Up
    if (oldLeague != league) {
      triggerLeagueUpAnimation();
    }
  }

  Widget buildMessage(Map<String, dynamic> message) {
    final isUser = message["sender"] == "user";

    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,

      child: Column(
        crossAxisAlignment: isUser
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,

        children: [
          // 💬 BOLHA CHAT
          Container(
            margin: const EdgeInsets.symmetric(vertical: 6),
            padding: const EdgeInsets.all(12),
            constraints: const BoxConstraints(maxWidth: 280),

            decoration: BoxDecoration(
              color: isUser ? Colors.blue : Colors.grey.shade300,

              borderRadius: BorderRadius.circular(16),
            ),

            child: Text(
              message["text"] ?? "",

              style: TextStyle(color: isUser ? Colors.white : Colors.black87),
            ),
          ),

          // ✨ FEEDBACK CARD
          if (!isUser) buildFeedbackCard(message),
        ],
      ),
    );
  }

  Widget buildFeedbackCard(Map<String, dynamic> message) {
    final correction = message["correction"] ?? "";

    if (correction.isEmpty) {
      return const SizedBox();
    }

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.deepPurple.shade900,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.greenAccent, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.greenAccent.withOpacity(0.25),
            blurRadius: 12,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "✨ Grammar Feedback",
            style: TextStyle(
              color: Colors.greenAccent,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),

          const SizedBox(height: 14),

          Text(
            "✅ Correction:\n${message["correction"]}",
            style: const TextStyle(color: Colors.white),
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
            style: const TextStyle(color: Colors.amber),
          ),
        ],
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
                    soundLevel: soundLevel,),
                ),
              ),
              // 💬 CHAT AREA
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
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
}
