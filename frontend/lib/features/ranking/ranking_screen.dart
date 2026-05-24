import 'package:flutter/material.dart';
import 'ranking_service.dart';

class RankingScreen extends StatefulWidget {
  const RankingScreen({super.key});

  @override
  State<RankingScreen> createState() => _RankingScreenState();
}

class _RankingScreenState extends State<RankingScreen>
    with TickerProviderStateMixin {
  List ranking = [];
  bool loading = true;
  late AnimationController _podiumController;
  late Animation<Offset> _podiumSlide;

  late AnimationController _glowController;
  late Animation<double> _glowAnimation;

  late AnimationController _crownController;
  late Animation<double> _crownFloat;

  final String currentUserId = "ad32edbf-b496-4e9a-9907-f52aba6a518d";

  @override
  void initState() {
    super.initState();

    _crownController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    );

    _crownFloat = Tween<double>(begin: -6, end: 6).animate(
      CurvedAnimation(parent: _crownController, curve: Curves.easeInOut),
    );

    _crownController.repeat(reverse: true);

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _glowAnimation = Tween<double>(begin: 6, end: 18).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );

    _podiumController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _podiumSlide = Tween<Offset>(begin: const Offset(0, 1.5), end: Offset.zero)
        .animate(
          CurvedAnimation(parent: _podiumController, curve: Curves.elasticOut),
        );

    loadRanking(); // ⬅ AGORA sim depois de criar controller
  }

  Future<void> loadRanking() async {
    final result = await RankingService.getWeeklyRanking();

    setState(() {
      ranking = result["ranking"];

      loading = false;
      _podiumController.forward();
    });
  }

  Widget buildMedal(int position) {
    if (position == 1) {
      return const Text("🥇", style: TextStyle(fontSize: 22));
    }
    if (position == 2) {
      return const Text("🥈", style: TextStyle(fontSize: 22));
    }
    if (position == 3) {
      return const Text("🥉", style: TextStyle(fontSize: 22));
    }
    return Text(
      "$position",
      style: const TextStyle(fontWeight: FontWeight.bold),
    );
  }

  Widget buildUserTile(Map user) {
    bool isMe = user["user_id"] == currentUserId;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isMe
            ? Colors.greenAccent.withOpacity(0.15)
            : Colors.grey.shade900,
        borderRadius: BorderRadius.circular(16),
        border: isMe ? Border.all(color: Colors.greenAccent, width: 2) : null,
      ),
      child: Row(
        children: [
          // Medal / posição
          SizedBox(width: 40, child: buildMedal(user["position"])),

          // Avatar
          const CircleAvatar(
            backgroundColor: Colors.blueAccent,
            child: Icon(Icons.person, color: Colors.white),
          ),

          const SizedBox(width: 12),

          // Email
          Expanded(
            child: Text(
              user["email"],
              style: TextStyle(
                color: isMe ? Colors.greenAccent : Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),

          // XP
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                "${user["weekly_xp"]} XP",
                style: const TextStyle(
                  color: Colors.amber,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                user["league"]["icon"],
                style: const TextStyle(fontSize: 18),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _podiumController.dispose();
    _glowController.dispose();
    _crownController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,

      appBar: AppBar(
        title: const Text("🏆 Weekly Ranking"),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFF0F172A), Color(0xFF020617)],
            ),
          ),

          child: loading
              ? const Center(child: CircularProgressIndicator(color: Colors.amber,))
              : Column(
                  children: [
                    const SizedBox(height: 20),

                    const Text(
                      "🔥 Competição Semanal",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 20),

                    // 🏆 PÓDIO TOP 3
                    SlideTransition(
                      position: _podiumSlide,
                      child: buildPodium(ranking),
                    ),

                    const SizedBox(height: 10),

                    Expanded(
                      child: ListView.builder(
                        physics: const BouncingScrollPhysics(),
                        itemCount: ranking.length > 3 ? ranking.length - 3 : 0,
                        itemBuilder: (context, index) {
                          return buildUserTile(ranking[index + 3]);
                        },
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget buildPodium(List ranking) {
    if (ranking.isEmpty) {
      return const SizedBox();
    }

    final screenHeight = MediaQuery.of(context).size.height;
    final podiumHeight = screenHeight * 0.30;

    int count = ranking.length > 3 ? 3 : ranking.length;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: podiumHeight),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(count, (index) {
          final user = ranking[index];

          double baseHeight = podiumHeight * 0.6;

          double height;
          Color color;

          if (index == 0) {
            height = baseHeight;
            color = Colors.amber;
          } else if (index == 1) {
            height = baseHeight * 0.8;
            color = Colors.grey.shade400;
          } else {
            height = baseHeight * 0.7;
            color = Colors.brown.shade300;
          }

          return Expanded(
            child: buildPodiumItem(user, index + 1, height, color),
          );
        }),
      ),
    );
  }

  Widget buildPodiumItem(
    dynamic user,
    int position,
    double height,
    Color color,
  ) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 80,
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              if (position == 1)
                AnimatedBuilder(
                  animation: _crownFloat,
                  builder: (context, child) {
                    return Positioned(
                      top: -10 + _crownFloat.value,
                      child: const Text("👑", style: TextStyle(fontSize: 30)),
                    );
                  },
                ),

              Positioned(
                bottom: 0,
                child: CircleAvatar(
                  radius: position == 1 ? 32 : 20,
                  backgroundColor: color,
                  child: Text(
                    position.toString(),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 6),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            user["email"],
            softWrap: false,
            overflow: TextOverflow.fade,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.white,
              fontSize: 12,
            ),
          ),
        ),

        const SizedBox(height: 4),

        Text(
          "⭐ ${user["weekly_xp"]}",
          style: const TextStyle(color: Colors.amber, fontSize: 12),
        ),

        const SizedBox(height: 8),

        Expanded(
          child: AnimatedBuilder(
            animation: _glowAnimation,
            builder: (context, child) {
              return Container(
                width: position == 1 ? 72 : 60,
                // Remova a propriedade height: height, o Expanded cuidará disso
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12),
                  ), // Arredonda só em cima fica estiloso
                  boxShadow: [
                    if (position == 1)
                      BoxShadow(
                        color: Colors.amber.withOpacity(0.8),
                        blurRadius: _glowAnimation.value,
                        spreadRadius: 2,
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
