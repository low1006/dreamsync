import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dreamsync/viewmodels/user_viewmodel/profile_viewmodel.dart';
import 'package:dreamsync/viewmodels/data_collection_viewmodel/sleep_viewmodel.dart';
import 'package:dreamsync/viewmodels/data_collection_viewmodel/daily_activity_viewmodel.dart';
import 'package:dreamsync/widget/sleep_dashboard/behavioural_card.dart';
import 'package:dreamsync/widget/sleep_dashboard/behavioural_dialogs.dart';
import 'dart:math' as math;

class SleepDashboardScreen extends StatefulWidget {
  const SleepDashboardScreen({super.key});

  @override
  State<SleepDashboardScreen> createState() => _SleepDashboardScreenState();
}

class _SleepDashboardScreenState extends State<SleepDashboardScreen> {
  String _screenTime = "Fetching...";

  // NEW: Flag to ensure we only fetch data once after the user loads
  bool _hasFetchedData = false;

  @override
  void initState() {
    super.initState();
    // Fetch logic removed from here because user profile might be null on init
  }

  Future<void> fetchScreenTime() async {
    final user = context.read<UserViewModel>().userProfile;
    if (user == null) return;

    final String result = await context
        .read<DailyActivityViewModel>()
        .fetchAndSaveScreenTime(user.userId);

    if (mounted) {
      setState(() {
        _screenTime = result;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // 1. WATCH the user profile so the UI knows when it finishes loading
    final user = context.watch<UserViewModel>().userProfile;
    final dailyVM = context.watch<DailyActivityViewModel>();

    // 2. TRIGGER the fetches once the user is NOT null, but only do it ONCE.
    if (user != null && !_hasFetchedData) {
      _hasFetchedData = true; // Lock it so it doesn't run on every rebuild

      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<SleepViewModel>().loadSleepData(context, user.userId);
        context.read<DailyActivityViewModel>().loadTodayData(user.userId);
        fetchScreenTime();
      });
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text(
          'Sleep Dashboard',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.black87,
        automaticallyImplyLeading: false,
      ),
      body: Consumer<SleepViewModel>(
        builder: (context, viewModel, child) {
          if (viewModel.isLoading) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text("Syncing data..."),
                ],
              ),
            );
          }

          if (viewModel.errorMessage.isNotEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
                    const SizedBox(height: 16),
                    Text(
                      viewModel.errorMessage,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () {
                        final user = context.read<UserViewModel>().userProfile;
                        if (user != null) {
                          viewModel.loadSleepData(context, user.userId);
                        }
                      },
                      child: const Text("Try Again"),
                    )
                  ],
                ),
              ),
            );
          }

          final bool noData = viewModel.totalSleepDuration == "0h 0m";

          return RefreshIndicator(
            onRefresh: () async {
              final user = context.read<UserViewModel>().userProfile;
              if (user != null) {
                await viewModel.refreshData(context, user.userId);
                await context.read<DailyActivityViewModel>().loadTodayData(user.userId);
              }
              await fetchScreenTime();
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Last Night's Sleep",
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),

                  // STACK FOR DIMMING EFFECT & NO DATA OVERLAY
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      // Bottom Layer: The Sleep Cards (Dimmed to 0.4 opacity if no data)
                      AnimatedOpacity(
                        duration: const Duration(milliseconds: 300),
                        opacity: noData ? 0.4 : 1.0,
                        child: IgnorePointer(
                          ignoring: noData,
                          child: Column(
                            children: [
                              // 1. Main Sleep Score & Duration Card
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(24),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                padding: const EdgeInsets.all(28.0),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                                  children: [
                                    CustomPaint(
                                      size: const Size(120, 120),
                                      painter: SleepScoreGaugePainter(
                                        score: viewModel.sleepScore,
                                        themeColor: Colors.indigoAccent,
                                      ),
                                    ),
                                    Container(width: 1, height: 70, color: Colors.grey.shade200),
                                    Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          viewModel.totalSleepDuration,
                                          style: const TextStyle(
                                            fontSize: 32,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black87,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        const Text(
                                          "Time Asleep",
                                          style: TextStyle(color: Colors.grey, fontWeight: FontWeight.w500),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 32),
                              const Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  "Sleep Cycle (Hypnogram)",
                                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                                ),
                              ),
                              const SizedBox(height: 16),

                              // 2. The Hypnogram Chart Container
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    SizedBox(
                                      height: 160,
                                      child: CustomPaint(
                                        size: Size.infinite,
                                        painter: HypnogramPainter(
                                          data: viewModel.hypnogramData,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 14),
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                      children: [
                                        _buildLegendItem("Awake", const Color(0xFFFF7043)),
                                        _buildLegendItem("REM", const Color(0xFF9C64FF)),
                                        _buildLegendItem("Light", const Color(0xFF42A5F5)),
                                        _buildLegendItem("Deep", const Color(0xFF1A237E)),
                                      ],
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 16),

                              // 3. Sleep Stages Breakdown
                              Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      blurRadius: 10,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                padding: const EdgeInsets.all(20.0),
                                child: Column(
                                  children: [
                                    _buildSleepStageRow("Deep Sleep", viewModel.deepSleep, Colors.indigo),
                                    const Divider(height: 24),
                                    _buildSleepStageRow("Light Sleep", viewModel.lightSleep, Colors.lightBlue),
                                    const Divider(height: 24),
                                    _buildSleepStageRow("REM Sleep", viewModel.remSleep, Colors.purpleAccent),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Top Layer: The "No Data" Overlay Message
                      if (noData)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.95),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: const [
                              BoxShadow(color: Colors.black12, blurRadius: 10, offset: Offset(0, 4))
                            ],
                          ),
                          child: const Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.bedtime_off, size: 56, color: Colors.indigoAccent),
                              SizedBox(height: 16),
                              Text(
                                "No sleep data found",
                                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87),
                              ),
                              SizedBox(height: 8),
                              Text(
                                "Ensure your smartwatch is synced\nwith Health Connect.",
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.grey, fontSize: 14),
                              )
                            ],
                          ),
                        ),
                    ],
                  ),

                  // --- BEHAVIOURAL DATA SUMMARY ---
                  // Notice how this is outside the Stack, meaning it's always interactable!
                  const SizedBox(height: 32),
                  const Text(
                    "Behavioural Data",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),

                  BehaviouralCard(
                    title: "Screen Time",
                    value: _screenTime,
                    subtitle: "Fetched from OS",
                    icon: Icons.phone_android,
                    iconColor: Colors.blueGrey,
                  ),
                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: BehaviouralCard(
                          title: "Exercise",
                          value: "${dailyVM.exerciseMinutes} mins",
                          subtitle: "Tap to add",
                          icon: Icons.fitness_center,
                          iconColor: Colors.orange,
                          onTap: () => BehaviouralDialogs.showAddExerciseDialog(context),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: BehaviouralCard(
                          title: "Food Intake",
                          value: "${dailyVM.foodCalories} kcal",
                          subtitle: "Tap to add",
                          icon: Icons.restaurant,
                          iconColor: Colors.green,
                          onTap: () => BehaviouralDialogs.showAddFoodDialog(context),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 40),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
        ),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }

  Widget _buildSleepStageRow(String title, String duration, Color color) {
    return Row(
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 16),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        const Spacer(),
        Text(
          duration,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ],
    );
  }
}

class SleepScoreGaugePainter extends CustomPainter {
  final int score;
  final Color themeColor;

  SleepScoreGaugePainter({required this.score, required this.themeColor});

  @override
  void paint(Canvas canvas, Size size) {
    final double centerX = size.width / 2;
    final double centerY = size.height / 2;
    final double radius = size.width / 2;
    const double strokeWidth = 14.0;

    const double startAngle = math.pi * 0.8;
    const double sweepAngle = math.pi * 1.4;

    final Offset center = Offset(centerX, centerY);
    final Rect rect = Rect.fromCircle(center: center, radius: radius - strokeWidth / 2);

    final paintTrack = Paint()
      ..color = Colors.grey.shade200
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, startAngle, sweepAngle, false, paintTrack);

    final double scoreSweepAngle = (score / 100) * sweepAngle;
    final paintProgress = Paint()
      ..color = themeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, startAngle, scoreSweepAngle, false, paintProgress);

    final textPainterScore = TextPainter(
      text: TextSpan(
        text: score.toString(),
        style: const TextStyle(
          fontSize: 42,
          fontWeight: FontWeight.w900,
          color: Colors.black87,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainterScore.layout();
    textPainterScore.paint(
      canvas,
      Offset(centerX - textPainterScore.width / 2, centerY - 20),
    );

    final textPainterLabel = TextPainter(
      text: const TextSpan(
        text: "Sleep Score",
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: Colors.grey,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainterLabel.layout();
    textPainterLabel.paint(
      canvas,
      Offset(centerX - textPainterLabel.width / 2, centerY + textPainterScore.height - 20),
    );

    const textStyleNumbers = TextStyle(fontSize: 10, color: Colors.grey);
    final textPainterZero = TextPainter(
      text: const TextSpan(text: "0", style: textStyleNumbers),
      textDirection: TextDirection.ltr,
    )..layout();

    final textPainterHundred = TextPainter(
      text: const TextSpan(text: "100", style: textStyleNumbers),
      textDirection: TextDirection.ltr,
    )..layout();

    final double sinStart = math.sin(startAngle);
    final double cosStart = math.cos(startAngle);
    final double sinEnd = math.sin(startAngle + sweepAngle);
    final double cosEnd = math.cos(startAngle + sweepAngle);

    textPainterZero.paint(
      canvas,
      Offset(centerX + (radius) * cosStart - 5, centerY + (radius) * sinStart + 10),
    );

    textPainterHundred.paint(
      canvas,
      Offset(centerX + (radius) * cosEnd - 15, centerY + (radius) * sinEnd + 10),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class HypnogramPainter extends CustomPainter {
  final List<SleepChartPoint> data;

  static const _stageColors = {
    3: Color(0xFFFF7043), // Awake
    2: Color(0xFF9C64FF), // REM
    1: Color(0xFF42A5F5), // Light
    0: Color(0xFF1A237E), // Deep
  };

  static const _stageLabels = {3: "Awake", 2: "REM", 1: "Light", 0: "Deep"};

  static const double _labelWidth  = 38.0;
  static const double _timeHeight  = 18.0;
  static const double _topPad      = 4.0;
  static const int    _stageCount  = 4;

  HypnogramPainter({required this.data});

  @override
  void paint(Canvas canvas, Size size) {
    final double chartLeft   = _labelWidth;
    final double chartRight  = size.width;
    final double chartTop    = _topPad;
    final double chartBottom = size.height - _timeHeight;
    final double chartH      = chartBottom - chartTop;
    final double chartW      = chartRight - chartLeft;
    final double stageH = chartH / _stageCount;

    // Provide default 8-hour span if no data is available
    final double minHour = data.isEmpty ? 0.0 : data.first.hour;
    final double maxHour = data.isEmpty ? 8.0 : data.last.hour;
    final double hourSpan = (maxHour - minHour) == 0 ? 1 : (maxHour - minHour);

    double toX(double hour) => chartLeft + (hour - minHour) / hourSpan * chartW;
    double toY(int stage) => chartTop + (3 - stage) * stageH;

    // --- Draw subtle horizontal stage dividers ---
    final dividerPaint = Paint()
      ..color = const Color(0xFFEEEEEE)
      ..strokeWidth = 1;
    for (int s = 0; s <= _stageCount; s++) {
      final double y = chartTop + s * stageH;
      canvas.drawLine(Offset(chartLeft, y), Offset(chartRight, y), dividerPaint);
    }

    // --- Draw Y-axis stage labels ---
    for (int s = 0; s < _stageCount; s++) {
      final double y = chartTop + (3 - s) * stageH + stageH / 2;
      final tp = TextPainter(
        text: TextSpan(
          text: _stageLabels[s],
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            color: _stageColors[s]!,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: _labelWidth - 4);
      tp.paint(canvas, Offset(0, y - tp.height / 2));
    }

    // --- Draw X-axis time labels ---
    final timeLabelStyle = const TextStyle(fontSize: 10, color: Colors.grey);
    const int labelCount = 5;
    for (int i = 0; i <= labelCount; i++) {
      final double hour = minHour + (hourSpan / labelCount) * i;
      final double x = toX(hour);
      final String label = "${hour.toStringAsFixed(1)}h";
      final tp = TextPainter(
        text: TextSpan(text: label, style: timeLabelStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(x - tp.width / 2, chartBottom + 4));
    }

    // --- STOP HERE if no data. Do not attempt to draw the blocks. ---
    if (data.isEmpty) return;

    // --- Draw filled stage blocks ---
    for (int i = 0; i < data.length - 1; i++) {
      final SleepChartPoint cur  = data[i];
      final SleepChartPoint next = data[i + 1];

      final int stage = cur.stage.round().clamp(0, 3);
      final Color color = _stageColors[stage] ?? Colors.grey;

      final double x1 = toX(cur.hour);
      final double x2 = toX(next.hour);
      final double y1 = toY(stage);
      final double y2 = y1 + stageH;

      final blockPaint = Paint()..color = color.withOpacity(0.85);
      canvas.drawRect(Rect.fromLTRB(x1, y1, x2, y2), blockPaint);

      final linePaint = Paint()
        ..color = color
        ..strokeWidth = 2.5;
      canvas.drawLine(Offset(x1, y1), Offset(x2, y1), linePaint);
    }
  }

  @override
  bool shouldRepaint(covariant HypnogramPainter oldDelegate) =>
      oldDelegate.data != data;
}