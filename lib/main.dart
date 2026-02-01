import 'dart:math';
import 'dart:async';
import 'dart:html' as html; // web only
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:ui' as ui; // web platformViewRegistry

// ignore: avoid_web_libraries_in_flutter
void main() => runApp(const WeirdArcadeApp());

class WeirdArcadeApp extends StatelessWidget {
  const WeirdArcadeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: ArcadePage(),
    );
  }
}

enum _OverlayMode { none, donate }

class ArcadePage extends StatefulWidget {
  const ArcadePage({super.key});

  @override
  State<ArcadePage> createState() => _ArcadePageState();
}

class _ArcadePageState extends State<ArcadePage> {
  final _rng = Random();

  // ---------- overlay ----------
  _OverlayMode overlay = _OverlayMode.none;

  // ---------- mini TV (ไม่บังเกม) ----------
  bool tvOn = false;
  int tvLeft = 0; // seconds
  Timer? tvTimer;

  String tvYoutubeId = "";
  String tvViewId = "";
  int lastTvAtPlayed = -999;

  static const double tvChanceOnWin = 0.10;
  static const int tvCooldownGames = 4;
  static const int tvDurationSeconds = 60;

  final List<String> ytIds = const [
    "hY7m5jjJ9mM",
    "J---aiyznGQ",
    "C0DPdy98e4c",
    "dQw4w9WgXcQ",
  ];

  // ---------- donate ----------
  static const String donateBank = "กสิกรไทย";
  static const String donateName = "สุทธิดา บุญสุข";
  static const String donateAcc = "102-1-67784-8";
  static const String donateQrAsset = "assets/qr_promptpay.png";

  final List<String> beggarStickers = const [
    "https://cdn.jsdelivr.net/gh/twitter/twemoji@14.0.2/assets/72x72/1f97a.png",
    "https://cdn.jsdelivr.net/gh/twitter/twemoji@14.0.2/assets/72x72/1f62d.png",
    "https://cdn.jsdelivr.net/gh/twitter/twemoji@14.0.2/assets/72x72/1f64f.png",
    "https://cdn.jsdelivr.net/gh/twitter/twemoji@14.0.2/assets/72x72/1f4b8.png",
  ];

  // ---------- game ----------
  late final List<_GameFactory> games;
  int currentLevel = 0; // ด่านเรียง
  bool finished = false;

  int played = 0;
  int wins = 0;
  int cleared = 0; // ครบ 3 = บอกรักสุ่ม
  int levelSeed = 0; // รีเซ็ต state ของด่าน

  // ---------- fake players + goal + share ----------
  static const int goalPlayers = 100000000; // 100 ล้าน
  int fakePlayers = 24873421;
  Timer? fakeTimer;

  final List<String> heckle = const [
    "อ้าว ยังอยู่เหรอ",
    "อย่าจริงจัง เดี๋ยวเว็บเครียด",
    "คุณแพ้ได้เก่งมาก (ชมจริง)",
    "ถ้าคุณงง แสดงว่าเว็บทำงานถูกแล้ว",
    "นี่ไม่ใช่บัค นี่คือบุคลิก",
    "เว็บไม่ได้แกล้งคุณ… แค่หยอกแรงไปนิด",
    "อย่ามองหน้าจอนาน เดี๋ยวหน้าจอมองกลับ",
    "อย่าถามว่าทำไม ถามว่าทำไมยังเล่น",
  ];

  @override
  void initState() {
    super.initState();

    games = [
      _GameFactory("🌀 ปุ่มหนี", (done) => RunawayButtonGame(done: done)),
      _GameFactory("ห้ามแตะ", (done) => DontTapGame(done: done)),
      _GameFactory("Reaction", (done) => ReactionTapGame(done: done)),
      _GameFactory("กดค้าง", (done) => HoldToCalmGame(done: done)),
      _GameFactory("หาอันแปลก", (done) => OddOneOutGame(done: done)),
      _GameFactory("เดาอะไรไม่รู้", (done) => GuessNothingGame(done: done)),
      _GameFactory("รอให้เบื่อ", (done) => IdleWinGame(done: done)),
      _GameFactory("แพ้คือชนะ", (done) => LoseToWinGame(done: done)),
      _GameFactory("อย่าขยับเมาส์", (done) => StillMouseGame(done: done)),
      _GameFactory("พิมพ์อะไรก็ได้", (done) => TypeAnythingGame(done: done)),
      _GameFactory("ลากให้ดูมั่นใจ", (done) => DragConfidentGame(done: done)),
      _GameFactory("ทาสแมว (รูปจริง)", (done) => CatCareGame(done: done)),
    ];

    // fake players ticker
    fakeTimer = Timer.periodic(const Duration(milliseconds: 850), (_) {
      if (!mounted) return;
      if (fakePlayers >= goalPlayers) return;
      // เพิ่มแบบสุ่ม (แต่ไม่เยอะจนเว่อร์)
      final inc = 5 + _rng.nextInt(35);
      setState(() => fakePlayers = min(goalPlayers, fakePlayers + inc));
    });
  }

  @override
  void dispose() {
    tvTimer?.cancel();
    fakeTimer?.cancel();
    super.dispose();
  }

  // ---------- flow: ด่าน ----------
  void _goNextLevel() {
    if (currentLevel >= games.length - 1) {
      setState(() => finished = true);
      return;
    }
    setState(() {
      currentLevel += 1;
      levelSeed++;
    });
  }

  void _restartLevel() => setState(() => levelSeed++);

  void _restartAll() {
    tvTimer?.cancel();
    setState(() {
      finished = false;
      tvOn = false;
      tvLeft = 0;
      played = 0;
      wins = 0;
      cleared = 0;
      currentLevel = 0;
      levelSeed = 0;
      lastTvAtPlayed = -999;
      overlay = _OverlayMode.none;
    });
  }

  void _onGameDone(_GameResult r) {
    setState(() {
      played++;
      if (r.win) {
        wins++;
        cleared++;
      }
    });

    if (r.win && cleared >= 3) {
      _showLoveNow();
    }

    if (r.win) {
      final canTv = (played - lastTvAtPlayed) >= tvCooldownGames;
      if (canTv && !tvOn && _rng.nextDouble() < tvChanceOnWin) {
        _startMiniTV(seconds: tvDurationSeconds);
      }
      _goNextLevel();
    } else {
      _restartLevel();
    }
  }

  // ---------- share ----------
  Future<void> _shareGame() async {
    final url = html.window.location.href;
    final text = "มาเล่นเกมกวนๆ อันนี้หน่อย 😂 ต้องการผู้เล่น 100 ล้านคน!\n$url";

    // ใช้ Web Share API ถ้ามี
    try {
      final nav = html.window.navigator;
      final dyn = nav as dynamic;
      if (dyn.share != null) {
        await dyn.share({
          "title": "Weird Arcade",
          "text": text,
          "url": url,
        });
        return;
      }
    } catch (_) {}

    // fallback: copy
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("ก๊อปลิงก์/ข้อความแชร์ให้แล้ว ✅ ส่งให้เพื่อนเลย")),
    );
  }

  // ---------- mini TV ----------
  void _startMiniTV({required int seconds}) {
    tvTimer?.cancel();
    tvYoutubeId = ytIds[_rng.nextInt(ytIds.length)];
    tvLeft = seconds;
    lastTvAtPlayed = played;

    tvViewId = "yt_${tvYoutubeId}_${DateTime.now().millisecondsSinceEpoch}";
    _registerYouTubeIFrame(viewId: tvViewId, videoId: tvYoutubeId);

    setState(() => tvOn = true);

    tvTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => tvLeft--);
      if (tvLeft <= 0) _stopMiniTV();
    });
  }

  void _stopMiniTV() {
    tvTimer?.cancel();
    if (!mounted) return;
    setState(() => tvOn = false);
  }

  // ignore: undefined_prefixed_name
  void _registerYouTubeIFrame({required String viewId, required String videoId}) {
    // ignore: undefined_prefixed_name
    ui.platformViewRegistry.registerViewFactory(viewId, (int _) {
      final iframe = html.IFrameElement()
        ..style.border = "0"
        ..width = "320"
        ..height = "180"
        ..allow = "autoplay; encrypted-media; picture-in-picture"
        ..src =
            "https://www.youtube.com/embed/$videoId?autoplay=1&mute=1&controls=1&modestbranding=1&rel=0";
      return iframe;
    });
  }

  // ---------- donate ----------
  void _openDonate() => setState(() => overlay = _OverlayMode.donate);
  void _closeOverlay() => setState(() => overlay = _OverlayMode.none);

  Future<void> _copy(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("ก็อปแล้วนะ: $text")),
    );
  }

  // ---------- love ----------
  Future<void> _showLoveNow() async {
    if (!mounted) return;

    final controller = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text("บอกชื่อหน่อยดิ 😳"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: "ชื่อเล่นก็ได้"),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop("คนดื้อ"),
            child: const Text("ไม่บอก"),
          ),
          ElevatedButton(
            onPressed: () {
              final t = controller.text.trim();
              Navigator.of(context).pop(t.isEmpty ? "คนดื้อ" : t);
            },
            child: const Text("โอเค"),
          ),
        ],
      ),
    );

    final loveLines = [
      "รักนะ $name 💖",
      "$name เก่งมาก แบบ…น่าหมั่นไส้นิด ๆ 😈",
      "โอเค…รัก $name ก็ได้ (แต่ห้ามหยิ่ง)",
      "$name ทำให้เว็บนี้ดูมีอนาคตขึ้น 0.0001% 😭",
      "รัก $name แบบกวน ๆ แต่จริงใจนะ 🤡💘",
      "ถ้า $name เบื่อเมื่อไหร่ กลับมาให้เว็บแกล้งต่อได้เลย",
    ];

    if (!mounted) return;
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text("💌"),
        content: Text(
          loveLines[_rng.nextInt(loveLines.length)],
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
          textAlign: TextAlign.center,
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("พอ เขิน"),
          )
        ],
      ),
    );

    if (!mounted) return;
    setState(() => cleared = 0);
  }

  String _fmt(int n) {
    // 12,345,678
    final s = n.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      final idxFromEnd = s.length - i;
      buf.write(s[i]);
      if (idxFromEnd > 1 && idxFromEnd % 3 == 1) buf.write(",");
    }
    return buf.toString();
  }

  @override
  Widget build(BuildContext context) {
    if (finished) {
      return Scaffold(
        backgroundColor: const Color(0xFF141428),
        body: Stack(
          children: [
            Positioned.fill(
              child: _FinishScreen(
                onRestart: _restartAll,
                onDonate: _openDonate,
                onShare: _shareGame,
                fakePlayersText: "${_fmt(fakePlayers)}/${_fmt(goalPlayers)} คน",
              ),
            ),
            if (tvOn) Positioned(left: 12, bottom: 12, child: _miniTv()),
            if (overlay == _OverlayMode.donate) Positioned.fill(child: _donateOverlay()),
          ],
        ),
      );
    }

    final game = games[currentLevel];

    return Scaffold(
      backgroundColor: const Color(0xFF141428),
      body: Stack(
        children: [
          Positioned.fill(
            child: KeyedSubtree(
              key: ValueKey<String>("L$currentLevel-S$levelSeed"),
              child: game.builder(_onGameDone),
            ),
          ),

          // HUD
          Positioned(
            top: 14,
            left: 14,
            right: 14,
            child: Row(
              children: [
                _pill("ด่าน ${currentLevel + 1}/${games.length}"),
                const SizedBox(width: 8),
                _pill("เล่น $played"),
                const SizedBox(width: 8),
                _pill("ชนะ $wins"),
                const SizedBox(width: 8),
                _pill("ลุ้น ${cleared}/3"),
                const Spacer(),
                _pill("ผู้เล่น ${_fmt(fakePlayers)}/${_fmt(goalPlayers)}"),
                const SizedBox(width: 8),
                TextButton(
                  onPressed: _shareGame,
                  child: const Text("แชร์ให้เพื่อนเล่น", style: TextStyle(color: Colors.white70)),
                ),
              ],
            ),
          ),

          Positioned(
            top: 54,
            right: 14,
            child: Row(
              children: [
                TextButton(
                  onPressed: _restartLevel,
                  child: const Text("เล่นด่านนี้ใหม่", style: TextStyle(color: Colors.white54)),
                ),
                const SizedBox(width: 10),
                Text(
                  heckle[_rng.nextInt(heckle.length)],
                  style: const TextStyle(color: Colors.white38, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),

          // Donate button
          Positioned(
            right: 18,
            bottom: 18,
            child: ElevatedButton.icon(
              onPressed: _openDonate,
              icon: const Icon(Icons.favorite),
              label: const Text("โดเนท"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.pinkAccent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
              ),
            ),
          ),

          // Mini TV
          if (tvOn) Positioned(left: 12, bottom: 12, child: _miniTv()),

          if (overlay == _OverlayMode.donate) Positioned.fill(child: _donateOverlay()),
        ],
      ),
    );
  }

  Widget _pill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.15)),
      ),
      child: Text(text, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w800)),
    );
  }

  Widget _miniTv() {
    final mm = (tvLeft ~/ 60).toString().padLeft(2, '0');
    final ss = (tvLeft % 60).toString().padLeft(2, '0');
    final openUrl = "https://www.youtube.com/watch?v=$tvYoutubeId";

    return Container(
      width: 340,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.55),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.15)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Text("📺 ทีวีแทรก (ไม่บังคับดู)",
                  style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w800)),
              const Spacer(),
              Text("$mm:$ss", style: const TextStyle(color: Colors.white60)),
              IconButton(
                onPressed: _stopMiniTV,
                icon: const Icon(Icons.close, color: Colors.white70, size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(width: 28, height: 28),
              ),
            ],
          ),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: SizedBox(
              width: 320,
              height: 180,
              child: HtmlElementView(viewType: tvViewId),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              TextButton(
                onPressed: () => html.window.open(openUrl, "_blank"),
                child: const Text("เปิดเต็ม", style: TextStyle(color: Colors.white70)),
              ),
              const Spacer(),
              Text("เล่นต่อเถอะ", style: TextStyle(color: Colors.white54)),
            ],
          )
        ],
      ),
    );
  }

  Widget _donateOverlay() {
    final sticker = beggarStickers[_rng.nextInt(beggarStickers.length)];

    return Container(
      color: Colors.black.withOpacity(0.75),
      child: Center(
        child: Container(
          width: 640,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.10),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white.withOpacity(0.16)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Image.network(
                    sticker,
                    width: 46,
                    height: 46,
                    errorBuilder: (_, __, ___) => const SizedBox(width: 46, height: 46),
                  ),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      "โหมดขอทาน (กวน ๆ แต่จริงจัง) 😭",
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18),
                    ),
                  ),
                  IconButton(
                    onPressed: _closeOverlay,
                    icon: const Icon(Icons.close, color: Colors.white70),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: Container(
                  color: Colors.white,
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    children: [
                      Image.asset(
                        donateQrAsset,
                        width: 260,
                        height: 260,
                        fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(
                          width: 260,
                          height: 260,
                          alignment: Alignment.center,
                          color: Colors.black12,
                          child: const Text(
                            "ยังไม่พบรูป QR\nวางไฟล์ assets/qr_promptpay.png\nแล้ว flutter pub get",
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Text(
                        "สแกนได้ก็สแกน…ไม่ได้ก็ไม่เป็นไร (แต่แอบหวัง)",
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white.withOpacity(0.14)),
                ),
                child: Column(
                  children: [
                    _infoRow("ธนาคาร", donateBank, onCopy: () => _copy(donateBank)),
                    const SizedBox(height: 8),
                    _infoRow("ชื่อบัญชี", donateName, onCopy: () => _copy(donateName)),
                    const SizedBox(height: 8),
                    _infoRow("เลขบัญชี", donateAcc, onCopy: () => _copy(donateAcc)),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Text(
                [
                  "โดเนทแล้วเว็บจะทำเป็นเฉย…แต่แอบยิ้ม 😈",
                  "ถ้าไม่โดเนทก็ไม่ว่า แค่… (🥺)",
                  "โดเนท = เติมน้ำมันความกวน 💸",
                ][_rng.nextInt(3)],
                style: TextStyle(color: Colors.white.withOpacity(0.85)),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value, {required VoidCallback onCopy}) {
    return Row(
      children: [
        SizedBox(
          width: 90,
          child: Text(label, style: const TextStyle(color: Colors.white60, fontWeight: FontWeight.w800)),
        ),
        Expanded(
          child: Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
        ),
        TextButton(onPressed: onCopy, child: const Text("คัดลอก")),
      ],
    );
  }
}

// ------------------ Finish screen ------------------

class _FinishScreen extends StatelessWidget {
  const _FinishScreen({
    required this.onRestart,
    required this.onDonate,
    required this.onShare,
    required this.fakePlayersText,
  });

  final VoidCallback onRestart;
  final VoidCallback onDonate;
  final VoidCallback onShare;
  final String fakePlayersText;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.10),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white.withOpacity(0.18)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "🎉 จบทุกด่านแล้ว",
                style: TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              Text(
                "ยินดีด้วย…คุณชนะเว็บได้ (ชั่วคราว)\nเดี๋ยวเว็บค่อยหาทางกลับมาแกล้งใหม่",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white.withOpacity(0.75), fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              Text(
                "🔥 เป้าหมาย: ต้องการผู้เล่น 100 ล้านคน\nตอนนี้: $fakePlayersText\nช่วยแชร์ให้เพื่อนเล่นหน่อยนะ 😈",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white.withOpacity(0.85), fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: onRestart,
                    icon: const Icon(Icons.refresh),
                    label: const Text("เริ่มใหม่ทั้งหมด"),
                  ),
                  ElevatedButton.icon(
                    onPressed: onShare,
                    icon: const Icon(Icons.share),
                    label: const Text("แชร์ให้เพื่อนเล่น"),
                  ),
                  ElevatedButton.icon(
                    onPressed: onDonate,
                    icon: const Icon(Icons.favorite),
                    label: const Text("โดเนท (เผื่อเว็บใจดีขึ้น)"),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.pinkAccent),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ------------------ Game infra ------------------

class _GameFactory {
  _GameFactory(this.title, this.builder);
  final String title;
  final Widget Function(void Function(_GameResult r)) builder;
}

class _GameResult {
  _GameResult({required this.win, required this.reason});
  final bool win;
  final String reason;
}

// ------------------ Games (12) ------------------

// 1) Runaway button
class RunawayButtonGame extends StatefulWidget {
  const RunawayButtonGame({super.key, required this.done});
  final void Function(_GameResult r) done;

  @override
  State<RunawayButtonGame> createState() => _RunawayButtonGameState();
}

class _RunawayButtonGameState extends State<RunawayButtonGame> {
  final _rng = Random();
  int got = 0;
  double bx = 0.45, by = 0.55;
  late DateTime startTime;

  @override
  void initState() {
    super.initState();
    startTime = DateTime.now();
  }

  int get mercyLevel {
    final seconds = DateTime.now().difference(startTime).inSeconds;
    if (seconds < 60) return 0;
    if (seconds < 90) return 1;
    if (seconds < 120) return 2;
    return 3;
  }

  void _runAway() {
    final double moveScale = <double>[0.80, 0.55, 0.35, 0.22][mercyLevel];
    setState(() {
      bx = (bx + (_rng.nextDouble() - 0.5) * moveScale).clamp(0.10, 0.90);
      by = (by + (_rng.nextDouble() - 0.5) * moveScale).clamp(0.20, 0.85);
    });
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (_, c) {
      final w = c.maxWidth, h = c.maxHeight;

      return Stack(
        children: [
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  "🌀 จับปุ่มให้ได้ 3 ครั้ง ($got/3)",
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 20),
                ),
                const SizedBox(height: 6),
                Text(
                  mercyLevel == 0
                      ? "ปุ่ม: อย่าจับดิ"
                      : mercyLevel == 1
                          ? "ปุ่ม: เออ…เริ่มเหนื่อย"
                          : mercyLevel == 2
                              ? "ปุ่ม: โอเค…ช้าลงนิด"
                              : "ปุ่ม: พอๆ ยอมก็ได้",
                  style: TextStyle(color: Colors.white.withOpacity(0.65), fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          Positioned(
            left: bx * w - 70,
            top: by * h - 26,
            child: MouseRegion(
              onHover: (_) => _runAway(),
              child: GestureDetector(
                onTap: () {
                  setState(() => got++);
                  if (got >= 3) {
                    widget.done(_GameResult(win: true, reason: "จับได้"));
                  } else {
                    _runAway();
                  }
                },
                child: AnimatedContainer(
                  duration: Duration(milliseconds: (120 + mercyLevel * 140).toInt()),
                  curve: Curves.easeOut,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: Colors.white.withOpacity(0.18)),
                  ),
                  child: const Text("กดสิ", style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
                ),
              ),
            ),
          ),
        ],
      );
    });
  }
}

// 2) Don't tap
class DontTapGame extends StatefulWidget {
  const DontTapGame({super.key, required this.done});
  final void Function(_GameResult r) done;

  @override
  State<DontTapGame> createState() => _DontTapGameState();
}

class _DontTapGameState extends State<DontTapGame> {
  int left = 6;
  Timer? t;

  @override
  void initState() {
    super.initState();
    t = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => left--);
      if (left <= 0) {
        t?.cancel();
        widget.done(_GameResult(win: true, reason: "ไม่แตะ"));
      }
    });
  }

  @override
  void dispose() {
    t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        t?.cancel();
        widget.done(_GameResult(win: false, reason: "แตะทำไม"));
      },
      child: Center(
        child: Text(
          "ห้ามแตะ $left วิ\n(อย่ามือไว)",
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900),
        ),
      ),
    );
  }
}

// 3) Reaction
class ReactionTapGame extends StatefulWidget {
  const ReactionTapGame({super.key, required this.done});
  final void Function(_GameResult r) done;

  @override
  State<ReactionTapGame> createState() => _ReactionTapGameState();
}

class _ReactionTapGameState extends State<ReactionTapGame> {
  final _rng = Random();
  bool go = false;
  int ms = 0;
  Timer? t;

  @override
  void initState() {
    super.initState();
    final wait = 700 + _rng.nextInt(1200);
    Future.delayed(Duration(milliseconds: wait), () {
      if (!mounted) return;
      setState(() => go = true);
      t = Timer.periodic(const Duration(milliseconds: 20), (_) {
        if (!mounted) return;
        setState(() => ms += 20);
        if (ms > 900) {
          t?.cancel();
          widget.done(_GameResult(win: false, reason: "ช้า"));
        }
      });
    });
  }

  @override
  void dispose() {
    t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: GestureDetector(
        onTap: () {
          if (!go) {
            widget.done(_GameResult(win: false, reason: "มือไวเกิน"));
            return;
          }
          t?.cancel();
          widget.done(_GameResult(win: true, reason: "ไว"));
        },
        child: Container(
          width: 380,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: (go ? Colors.green : Colors.red).withOpacity(0.16),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white.withOpacity(0.18)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                go ? "แตะตอนนี้!" : "ห้ามแตะ…รอ!",
                style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              Text(go ? "เวลา: ${ms}ms" : "แตะก่อน = แพ้", style: TextStyle(color: Colors.white.withOpacity(0.75))),
            ],
          ),
        ),
      ),
    );
  }
}

// 4) Hold to calm
class HoldToCalmGame extends StatefulWidget {
  const HoldToCalmGame({super.key, required this.done});
  final void Function(_GameResult r) done;

  @override
  State<HoldToCalmGame> createState() => _HoldToCalmGameState();
}

class _HoldToCalmGameState extends State<HoldToCalmGame> {
  double p = 0;
  Timer? t;

  void _start() {
    t?.cancel();
    t = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (!mounted) return;
      setState(() => p += 0.05);
      if (p >= 1) {
        t?.cancel();
        widget.done(_GameResult(win: true, reason: "สงบ"));
      }
    });
  }

  void _stop() {
    t?.cancel();
    widget.done(_GameResult(win: false, reason: "ใจร้อน"));
  }

  @override
  void dispose() {
    t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: GestureDetector(
        onTapDown: (_) => _start(),
        onTapUp: (_) => _stop(),
        onTapCancel: _stop,
        child: Container(
          width: 380,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.10),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white.withOpacity(0.18)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("กดค้างให้ครบ", style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
              const SizedBox(height: 12),
              LinearProgressIndicator(value: p, minHeight: 10, backgroundColor: Colors.white12),
              const SizedBox(height: 8),
              Text("ปล่อย = แพ้ (ชีวิตก็แบบนี้)", style: TextStyle(color: Colors.white.withOpacity(0.75))),
            ],
          ),
        ),
      ),
    );
  }
}

// 5) Odd one out
class OddOneOutGame extends StatefulWidget {
  const OddOneOutGame({super.key, required this.done});
  final void Function(_GameResult r) done;

  @override
  State<OddOneOutGame> createState() => _OddOneOutGameState();
}

class _OddOneOutGameState extends State<OddOneOutGame> {
  final _rng = Random();
  late List<String> grid;
  late int odd;
  int score = 0;
  final int need = 2;

  @override
  void initState() {
    super.initState();
    _gen();
  }

  void _gen() {
    const pairs = [
      ["😂", "😈"],
      ["🌚", "👻"],
      ["🤡", "💀"],
      ["😺", "🐶"],
      ["🍌", "🍎"],
    ];
    final pair = pairs[_rng.nextInt(pairs.length)];
    final base = pair[0];
    final other = pair[1];

    odd = _rng.nextInt(12);
    grid = List.generate(12, (i) => i == odd ? other : base);
  }

  void _tap(int i) {
    if (i == odd) {
      score++;
      if (score >= need) {
        widget.done(_GameResult(win: true, reason: "หาเจอ"));
      } else {
        setState(_gen);
      }
    } else {
      setState(_gen);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("ยังไม่ใช่ 😈 ลองใหม่")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "หาอันแปลกให้ได้ $need ครั้ง ($score/$need)",
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: List.generate(12, (i) {
                return InkWell(
                  onTap: () => _tap(i),
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white.withOpacity(0.16)),
                    ),
                    child: Center(child: Text(grid[i], style: const TextStyle(fontSize: 26))),
                  ),
                );
              }),
            ),
          ],
        ),
      ),
    );
  }
}

// 6) Guess nothing
class GuessNothingGame extends StatelessWidget {
  const GuessNothingGame({super.key, required this.done});
  final void Function(_GameResult r) done;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ElevatedButton(
        onPressed: () => done(_GameResult(win: true, reason: "ชนะเฉย")),
        child: const Text("เดาสุ่ม (ชนะเฉย ๆ)"),
      ),
    );
  }
}

// 7) Idle to win
class IdleWinGame extends StatefulWidget {
  const IdleWinGame({super.key, required this.done});
  final void Function(_GameResult r) done;

  @override
  State<IdleWinGame> createState() => _IdleWinGameState();
}

class _IdleWinGameState extends State<IdleWinGame> {
  int left = 10;
  Timer? t;

  @override
  void initState() {
    super.initState();
    t = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => left--);
      if (left <= 0) {
        t?.cancel();
        widget.done(_GameResult(win: true, reason: "นิ่งได้"));
      }
    });
  }

  @override
  void dispose() {
    t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        t?.cancel();
        widget.done(_GameResult(win: false, reason: "อดใจไม่ได้"));
      },
      child: Center(
        child: Text(
          "อย่าทำอะไรเลย $left วิ\n(แค่นิ่ง…เฉย…)",
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900),
        ),
      ),
    );
  }
}

// 8) Lose to win
class LoseToWinGame extends StatelessWidget {
  const LoseToWinGame({super.key, required this.done});
  final void Function(_GameResult r) done;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            "ห้ามกดปุ่มนี้นะ\n(จริง ๆ นะ)",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
              backgroundColor: Colors.white.withOpacity(0.12),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
            ),
            onPressed: () => done(_GameResult(win: true, reason: "กดแล้วชนะ")),
            child: const Text("ห้ามกด", style: TextStyle(fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }
}

// 9) Still mouse
class StillMouseGame extends StatefulWidget {
  const StillMouseGame({super.key, required this.done});
  final void Function(_GameResult r) done;

  @override
  State<StillMouseGame> createState() => _StillMouseGameState();
}

class _StillMouseGameState extends State<StillMouseGame> {
  int left = 7;
  Timer? t;
  int moves = 0;

  @override
  void initState() {
    super.initState();
    t = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => left--);
      if (left <= 0) {
        t?.cancel();
        widget.done(_GameResult(win: true, reason: "นิ่งจริง"));
      }
    });
  }

  @override
  void dispose() {
    t?.cancel();
    super.dispose();
  }

  void _moved() {
    moves++;
    if (moves >= 2) {
      t?.cancel();
      widget.done(_GameResult(win: false, reason: "มือสั่น"));
    }
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onHover: (_) => _moved(),
      child: Center(
        child: Text(
          "อย่าขยับเมาส์ $left วิ\n(ขยับ 2 ครั้ง = แพ้)",
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.w900),
        ),
      ),
    );
  }
}

// 10) Type anything
class TypeAnythingGame extends StatefulWidget {
  const TypeAnythingGame({super.key, required this.done});
  final void Function(_GameResult r) done;

  @override
  State<TypeAnythingGame> createState() => _TypeAnythingGameState();
}

class _TypeAnythingGameState extends State<TypeAnythingGame> {
  final _ctrl = TextEditingController();
  final _rng = Random();
  int need = 10;

  final List<String> heckles = const [
    "พิมพ์อะไรก็ได้…แต่พิมพ์ดี ๆ หน่อยนะ",
    "พิมพ์ไปเถอะ เว็บไม่ตัดสิน (มั้ง)",
    "ถ้าพิมพ์มั่วแล้วชนะ อย่าไปบอกใคร",
    "พิมพ์อะไรก็ได้จริง ๆ…อย่าคาดหวัง",
  ];

  @override
  void initState() {
    super.initState();
    need = 8 + _rng.nextInt(8);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = _ctrl.text;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              heckles[_rng.nextInt(heckles.length)],
              style: TextStyle(color: Colors.white.withOpacity(0.7), fontWeight: FontWeight.w800),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              "พิมพ์ให้ครบ $need ตัวอักษร (${text.length}/$need)",
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 20),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _ctrl,
              autofocus: true,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
              decoration: InputDecoration(
                hintText: "พิมพ์อะไรก็ได้จริง ๆ",
                hintStyle: TextStyle(color: Colors.white.withOpacity(0.35)),
                filled: true,
                fillColor: Colors.white.withOpacity(0.10),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.18)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: Colors.white.withOpacity(0.30)),
                ),
              ),
              onChanged: (v) {
                setState(() {});
                if (v.length >= need) widget.done(_GameResult(win: true, reason: "พิมพ์ครบ"));
              },
            ),
            const SizedBox(height: 10),
            Text(
              "ทิป: พิมพ์ ‘aaaaaaaaaa’ ก็ได้ เว็บไม่ดุ (มาก)",
              style: TextStyle(color: Colors.white.withOpacity(0.45)),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// 11) Drag confident
class DragConfidentGame extends StatefulWidget {
  const DragConfidentGame({super.key, required this.done});
  final void Function(_GameResult r) done;

  @override
  State<DragConfidentGame> createState() => _DragConfidentGameState();
}

class _DragConfidentGameState extends State<DragConfidentGame> {
  final _rng = Random();

  double progress = 0;
  int wobble = 0;
  Offset? last;
  Offset? lastDir;

  static const double winProgress = 1200;
  static const int wobbleLimit = 12;

  String taunt = "ลากจุดนี้ให้ดูมีเหตุผลหน่อย";

  void _onPanStart(DragStartDetails d) {
    last = d.localPosition;
    lastDir = null;
    taunt = [
      "โอเค เริ่มละนะ อย่าลังเล",
      "ลากแบบมั่นใจหน่อย เดี๋ยวเว็บนับ",
      "ถ้าสั่น ๆ เว็บจะหาว่าคุณไม่แน่ใจ",
    ][_rng.nextInt(3)];
    setState(() {});
  }

  void _onPanUpdate(DragUpdateDetails d) {
    final p = d.localPosition;
    if (last == null) {
      last = p;
      return;
    }

    final delta = p - last!;
    final dist = delta.distance;
    if (dist < 2) return;

    progress += dist;
    final dir = delta / dist;

    if (lastDir != null) {
      final dot = (dir.dx * lastDir!.dx) + (dir.dy * lastDir!.dy);
      if (dot < 0.55) wobble++;
    }

    lastDir = dir;
    last = p;

    if (wobble >= wobbleLimit) {
      widget.done(_GameResult(win: false, reason: "โลเลเกินไป"));
      return;
    }
    if (progress >= winProgress) {
      widget.done(_GameResult(win: true, reason: "มั่นใจดี"));
      return;
    }

    if (progress > 420 && progress < 450) taunt = "เริ่มเหมือนคนมีเป้าหมายละ";
    if (progress > 820 && progress < 850) taunt = "อีกนิด อย่าหักมุมเยอะ";
    setState(() {});
  }

  void _onPanEnd(_) {
    taunt = [
      "ปล่อยทำไม กลัวความสำเร็จเหรอ",
      "พักได้ แต่เว็บยังจดจำความโลเล",
      "ปล่อยแล้วก็ลากต่อสิ…",
    ][_rng.nextInt(3)];
    last = null;
    lastDir = null;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final p = (progress / winProgress).clamp(0.0, 1.0);
    final leftWobble = (wobbleLimit - wobble).clamp(0, wobbleLimit);

    return Center(
      child: GestureDetector(
        onPanStart: _onPanStart,
        onPanUpdate: _onPanUpdate,
        onPanEnd: _onPanEnd,
        child: Container(
          width: 520,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.10),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: Colors.white.withOpacity(0.18)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "🎯 ลากให้ดูมีเหตุผล",
                style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              Text(
                taunt,
                style: TextStyle(color: Colors.white.withOpacity(0.70), fontWeight: FontWeight.w700),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(child: LinearProgressIndicator(value: p, minHeight: 10, backgroundColor: Colors.white12)),
                  const SizedBox(width: 12),
                  Text("${(p * 100).toInt()}%", style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w900)),
                ],
              ),
              const SizedBox(height: 10),
              Text("สิทธิ์โลเลเหลือ: $leftWobble (เปลี่ยนทิศบ่อย = แพ้)", style: TextStyle(color: Colors.white.withOpacity(0.60))),
              const SizedBox(height: 14),
              Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.white.withOpacity(0.18)),
                ),
                child: const Center(
                  child: Text("ลากในกรอบนี้", textAlign: TextAlign.center, style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w900)),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                "ทิป: ลากโค้งนิดได้ แต่ห้ามสะบัดไปมาเหมือนใจไม่แน่ 😈",
                style: TextStyle(color: Colors.white.withOpacity(0.45)),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
// 12) Cat care (รูปจริง + assets) — เวอร์ชันเขียนใหม่ทั้งคลาส
// ✅ ทุกอย่าง (แมว / อึ / ฟองน้ำ / ข้าว / ถังขยะ) อยู่ “ในกรอบ playArea”
// ✅ ลากข้าวเข้าปากเพื่อเพิ่ม hunger
// ✅ ลากฟองน้ำถูตัวแมวเพื่อเพิ่ม clean
// ✅ แตะอึให้บินไปถังขยะเพื่อลด poopLeft
// ✅ ทำครบแล้วแมวโต + โชว์ Dialog "กูยังไม่อยากโตเลยไอ้สัสเอ้ย 😾" แล้วค่อยชนะ

class CatCareGame extends StatefulWidget {
  const CatCareGame({super.key, required this.done});
  final void Function(_GameResult r) done;

  @override
  State<CatCareGame> createState() => _CatCareGameState();
}

class _CatCareGameState extends State<CatCareGame> with TickerProviderStateMixin {
  final _rng = Random();

  // เป้าหมาย
  static const int needPoop = 3;
  int poopLeft = needPoop;
  double hunger = 0.0; // 0..1
  double clean = 0.0; // 0..1

  bool grown = false;
  bool finishing = false;

  // normalized ภายใน playArea (0..1)
  Offset spongePos = const Offset(0.18, 0.86);
  Offset foodPos = const Offset(0.82, 0.86);
  late List<Offset> poops;

  // keys
  final GlobalKey _catKey = GlobalKey();
  final GlobalKey _playKey = GlobalKey();

  // anim: grow
  late final AnimationController _growCtrl;
  late final Animation<double> _growAnim;

  // anim: poop fly
  late final AnimationController _poopFlyCtrl;
  Offset? _flyingPoopStartN; // normalized in playArea
  Offset? _flyingPoopEndPx; // local px in playArea

  int _scrubHits = 0;

  final List<String> taunts = const [
    "แมว: ถูให้ถึง ไม่ใช่ลูบ ๆ 😾",
    "แมว: เอาข้าวเข้าปาก ไม่ใช่เข้าหัว",
    "แมว: อึแล้วก็เก็บดิ ยืนมองทำไม",
    "แมว: ถูแรงไปเดี๋ยวกัดนะ",
    "แมว: ถ้าทำดี เดี๋ยวโตให้ (มั้ง)",
  ];
  String taunt = "เริ่มงานทาสแมวได้ 😼";

  @override
  void initState() {
    super.initState();

    // สุ่มอึให้อยู่โซนล่างกลางในกรอบ
    poops = List.generate(needPoop, (_) {
      final x = 0.30 + _rng.nextDouble() * 0.40;
      final y = 0.60 + _rng.nextDouble() * 0.22;
      return Offset(x, y);
    });

    _growCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 650));
    _growAnim = CurvedAnimation(parent: _growCtrl, curve: Curves.easeOutBack);

    _poopFlyCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 520));
    _poopFlyCtrl.addStatusListener((s) {
      if (s == AnimationStatus.completed) {
        if (!mounted) return;
        setState(() {
          _flyingPoopStartN = null;
          _flyingPoopEndPx = null;
        });
        _poopFlyCtrl.reset();
      }
    });
  }

  @override
  void dispose() {
    _growCtrl.dispose();
    _poopFlyCtrl.dispose();
    super.dispose();
  }

  bool get _doneAll => poopLeft <= 0 && hunger >= 1.0 && clean >= 1.0;

  Widget _assetOrEmoji(String path, String emoji, {double? w, double? h}) {
    return Image.asset(
      path,
      width: w,
      height: h,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => Text(emoji, style: TextStyle(fontSize: (w ?? 64) * 0.7)),
    );
  }

  // แปลง global -> local ของ playArea แบบถูกตัว
  Offset? _globalToPlayLocal(Offset globalPos) {
    final ctx = _playKey.currentContext;
    if (ctx == null) return null;
    final box = ctx.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    return box.globalToLocal(globalPos);
  }

  // ถูตัวแมว (รับ global) -> เพิ่ม clean
  void _scrubAtGlobal(Offset spongeGlobal) {
    if (grown || finishing) return;

    final catCtx = _catKey.currentContext;
    if (catCtx == null) return;
    final catBox = catCtx.findRenderObject() as RenderBox?;
    if (catBox == null || !catBox.hasSize) return;

    final catRect = catBox.localToGlobal(Offset.zero) & catBox.size;

    if (catRect.contains(spongeGlobal)) {
      _scrubHits++;
      if (_scrubHits % 3 == 0) {
        setState(() {
          clean = (clean + 0.06).clamp(0.0, 1.0);
          taunt = "แมว: อืม…พอใช้ได้ 🧼";
        });
        _checkWinAndGrow();
      }
    } else {
      if (_rng.nextDouble() < 0.04) setState(() => taunt = "แมว: ถูโดนอากาศทำไม 😾");
    }
  }

  Future<void> _showGrowDialog() async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: const Text("😾"),
        content: const Text(
          "กูยังไม่อยากโตเลยไอ้สัสเอ้ย",
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          textAlign: TextAlign.center,
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("โอเคๆ"),
          )
        ],
      ),
    );
  }

  // เช็คชนะ + โต + พูดแรง ๆ หลังโต
  Future<void> _checkWinAndGrow() async {
    if (!_doneAll || grown || finishing) return;

    setState(() {
      finishing = true;
      taunt = "แมว: …เออ โตละมั้ง 😼";
    });

    _growCtrl.forward();

    // รอแอนิเมชันโต
    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;

    setState(() {
      grown = true;
      taunt = "แมว: กูยังไม่อยากโตเลยไอ้สัสเอ้ย 😾";
    });

    // โชว์ dialog หลังโต
    await _showGrowDialog();
    if (!mounted) return;

    // หน่วงนิดให้คนเห็นว่ามันโตแล้วจริง ๆ
    await Future.delayed(const Duration(milliseconds: 250));
    if (!mounted) return;

    widget.done(_GameResult(win: true, reason: "แมวโตแล้ว"));
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (_, c) {
      return Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 900),
          child: Container(
            margin: const EdgeInsets.all(18),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.10),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: Colors.white.withOpacity(0.18)),
            ),
            child: Stack(
              children: [
                // header
                Positioned(
                  left: 12,
                  right: 12,
                  top: 10,
                  child: Column(
                    children: [
                      const Text(
                        "🐱 ด่านทาสแมว (รูปจริง): อึ / ข้าว / อาบน้ำ",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        taunt,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.white70, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(child: _statusBar("🍚 อิ่ม", hunger)),
                          const SizedBox(width: 10),
                          Expanded(child: _statusBar("🧼 สะอาด", clean)),
                          const SizedBox(width: 10),
                          _pillSmall("💩 เหลือ $poopLeft"),
                        ],
                      ),
                    ],
                  ),
                ),

                // playArea (กรอบ)
                Positioned(
                  left: 16,
                  right: 16,
                  top: 120,
                  bottom: 54,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: Container(
                      key: _playKey,
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.18),
                        border: Border.all(color: Colors.white.withOpacity(0.14)),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: LayoutBuilder(builder: (_, pc) {
                        final playSize = Size(pc.maxWidth, pc.maxHeight);

                        Offset clampN(Offset n) =>
                            Offset(n.dx.clamp(0.06, 0.94), n.dy.clamp(0.08, 0.92));
                        Offset toPx(Offset n) => Offset(n.dx * playSize.width, n.dy * playSize.height);
                        Offset toNorm(Offset px) => Offset(px.dx / playSize.width, px.dy / playSize.height);

                        // แมวอยู่กลางกรอบ (ขวานิด)
                        final catCenter = Offset(playSize.width * 0.62, playSize.height * 0.46);
                        final catBoxW = min(320.0, playSize.width * 0.55);
                        final catRect = Rect.fromCenter(center: catCenter, width: catBoxW, height: catBoxW);

                        // จุดปาก (ใช้คำนวณชนสำหรับข้าว)
                        final mouthCenter = Offset(
                          catRect.center.dx + catRect.width * 0.18,
                          catRect.center.dy - catRect.height * 0.06,
                        );
                        const mouthSize = Size(60, 50);
                        final mouthRect = Rect.fromCenter(
                          center: mouthCenter,
                          width: mouthSize.width,
                          height: mouthSize.height,
                        );

                        // ถังขยะ “อยู่ในกรอบ”
                        final binPx = Offset(18, playSize.height - 82);
                        final binCenterPx = binPx + const Offset(32, 32);

                        void handleFoodEnd() {
                          if (grown || finishing) return;

                          final foodCenterPx = toPx(foodPos);
                          if (mouthRect.contains(foodCenterPx)) {
                            setState(() {
                              hunger = (hunger + 0.25).clamp(0.0, 1.0);
                              taunt = hunger >= 1 ? "แมว: อิ่มละ…(มั้ง) 🍚" : "แมว: ป้อนอีก 😾🍚";
                              foodPos = const Offset(0.82, 0.86);
                            });
                            _checkWinAndGrow();
                          } else {
                            setState(() {
                              foodPos = const Offset(0.82, 0.86);
                              if (_rng.nextDouble() < 0.25) taunt = "แมว: เอาเข้าปาก ไม่ใช่โยนเล่น 😾";
                            });
                          }
                        }

                        void pickPoop(int index) {
                          if (grown || finishing) return;

                          setState(() {
                            _flyingPoopStartN = poops[index];
                            _flyingPoopEndPx = binCenterPx;
                            poops.removeAt(index);
                            poopLeft -= 1;
                            taunt = "แมว: เก็บแล้วก็ทิ้งให้ถูกที่สิ 😾";
                          });

                          _poopFlyCtrl.forward(from: 0);
                          _checkWinAndGrow();
                        }

                        return Stack(
                          children: [
                            // ถังขยะ (ในกรอบ)
                            Positioned(
                              left: binPx.dx,
                              top: binPx.dy,
                              child: Container(
                                width: 64,
                                height: 64,
                                decoration: BoxDecoration(
                                  color: Colors.black.withOpacity(0.25),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: Colors.white.withOpacity(0.14)),
                                ),
                                child: Center(child: _assetOrEmoji("assets/bin.png", "🗑️", w: 44, h: 44)),
                              ),
                            ),

                            // แมว (ในกรอบ)
                            Positioned(
                              left: catRect.left,
                              top: catRect.top,
                              width: catRect.width,
                              height: catRect.height,
                              child: AnimatedBuilder(
                                animation: _growAnim,
                                builder: (_, __) {
                                  final scale = grown ? 1.12 : (finishing ? (1.0 + 0.12 * _growAnim.value) : 1.0);
                                  return Transform.scale(
                                    scale: scale,
                                    child: Container(
                                      key: _catKey,
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.04),
                                        borderRadius: BorderRadius.circular(28),
                                        border: Border.all(color: Colors.white.withOpacity(0.14)),
                                      ),
                                      child: Center(
                                        child: _assetOrEmoji(
                                          grown ? "assets/cat_big.png" : "assets/cat_small.png",
                                          grown ? "😼" : "😺",
                                          w: catRect.width * 0.74,
                                          h: catRect.height * 0.74,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),

                            // อึ (ในกรอบ)
                            for (int i = 0; i < poops.length; i++)
                              Positioned(
                                left: toPx(poops[i]).dx - 22,
                                top: toPx(poops[i]).dy - 22,
                                child: GestureDetector(
                                  onTap: () => pickPoop(i),
                                  child: Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.22),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(color: Colors.white.withOpacity(0.12)),
                                    ),
                                    child: Center(child: _assetOrEmoji("assets/poop.png", "💩", w: 30, h: 30)),
                                  ),
                                ),
                              ),

                            // อึบินไปถัง
                            if (_flyingPoopStartN != null && _flyingPoopEndPx != null)
                              AnimatedBuilder(
                                animation: _poopFlyCtrl,
                                builder: (_, __) {
                                  final startPx = toPx(_flyingPoopStartN!);
                                  final endPx = _flyingPoopEndPx!;
                                  final t = Curves.easeInOut.transform(_poopFlyCtrl.value);
                                  final pos = Offset.lerp(startPx, endPx, t)!;
                                  return Positioned(
                                    left: pos.dx - 18,
                                    top: pos.dy - 18,
                                    child: Opacity(
                                      opacity: (1 - t).clamp(0.2, 1.0),
                                      child: _assetOrEmoji("assets/poop.png", "💩", w: 36, h: 36),
                                    ),
                                  );
                                },
                              ),

                            // ฟองน้ำ (ลากถู) อยู่ในกรอบ 100%
                            Positioned(
                              left: toPx(spongePos).dx - 36,
                              top: toPx(spongePos).dy - 36,
                              child: Draggable<String>(
                                data: "sponge",
                                feedback: _assetOrEmoji("assets/sponge.png", "🧽", w: 72, h: 72),
                                childWhenDragging: Opacity(
                                  opacity: 0.35,
                                  child: _assetOrEmoji("assets/sponge.png", "🧽", w: 72, h: 72),
                                ),
                                onDragUpdate: (d) {
                                  final local = _globalToPlayLocal(d.globalPosition);
                                  if (local == null) return;
                                  setState(() => spongePos = clampN(toNorm(local)));
                                  _scrubAtGlobal(d.globalPosition);
                                },
                                onDragEnd: (_) {
                                  setState(() {
                                    spongePos = clampN(spongePos);
                                    if (_rng.nextDouble() < 0.10) taunt = taunts[_rng.nextInt(taunts.length)];
                                  });
                                },
                                child: _assetOrEmoji("assets/sponge.png", "🧽", w: 72, h: 72),
                              ),
                            ),

                            // ข้าว (ลากเข้าปาก) อยู่ในกรอบ 100%
                            Positioned(
                              left: toPx(foodPos).dx - 40,
                              top: toPx(foodPos).dy - 40,
                              child: Draggable<String>(
                                data: "food",
                                feedback: _assetOrEmoji("assets/food.png", "🍚", w: 80, h: 80),
                                childWhenDragging: Opacity(
                                  opacity: 0.35,
                                  child: _assetOrEmoji("assets/food.png", "🍚", w: 80, h: 80),
                                ),
                                onDragUpdate: (d) {
                                  final local = _globalToPlayLocal(d.globalPosition);
                                  if (local == null) return;
                                  setState(() => foodPos = clampN(toNorm(local)));
                                },
                                onDragEnd: (_) => handleFoodEnd(),
                                child: _assetOrEmoji("assets/food.png", "🍚", w: 80, h: 80),
                              ),
                            ),
                          ],
                        );
                      }),
                    ),
                  ),
                ),

                // footer tip
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 10,
                  child: Text(
                    grown
                        ? "จบแล้ว ไปต่อ…"
                        : "ทิป: ลาก 🧽 ถูตัวแมว / ลาก 🍚 เข้าปาก / แตะ 💩 ทิ้งถัง 🗑️ (ทุกอย่างอยู่ในกรอบแล้ว)",
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white54, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }

  Widget _pillSmall(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.14)),
      ),
      child: Text(text, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w900)),
    );
  }

  Widget _statusBar(String label, double v) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.14)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 84,
            child: Text(label, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w900)),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: v.clamp(0.0, 1.0),
                minHeight: 10,
                backgroundColor: Colors.white12,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Text("${(v * 100).toInt()}%", style: const TextStyle(color: Colors.white60, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

