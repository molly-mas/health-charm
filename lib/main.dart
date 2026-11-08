import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'face_prompt.dart';
import 'on_device_face_engine.dart';

void main() => runApp(const HealthCharmApp());

class HealthCharmApp extends StatelessWidget {
  const HealthCharmApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'HealthCharm',
        theme: ThemeData(
          useMaterial3: true,
          scaffoldBackgroundColor: const Color(0xFFFFF8FA),
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFFE77AA5),
            brightness: Brightness.light,
            surface: Colors.white,
          ),
          fontFamily: 'Roboto',
        ),
        home: const HealthCharmPreview(),
      );
}

class BuddyMood {
  const BuddyMood(
      {required this.name,
      required this.note,
      required this.face,
      required this.emoji});
  final String name;
  final String note;
  final String face;
  final String emoji;
}

class FacePalette {
  const FacePalette({
    required this.name,
    required this.page,
    required this.heroStart,
    required this.heroEnd,
    required this.iconSurface,
    required this.accent,
    required this.ink,
    required this.muted,
    required this.border,
    required this.shadow,
  });

  final String name;
  final Color page;
  final Color heroStart;
  final Color heroEnd;
  final Color iconSurface;
  final Color accent;
  final Color ink;
  final Color muted;
  final Color border;
  final Color shadow;
}

const _palettes = <FacePalette>[
  FacePalette(
      name: 'Pink',
      page: Color(0xFFFFF8FA),
      heroStart: Color(0xFFFFEAF1),
      heroEnd: Color(0xFFF8EFFF),
      iconSurface: Color(0xFFFFE6EF),
      accent: Color(0xFFD85B8C),
      ink: Color(0xFF482D3D),
      muted: Color(0xFF806477),
      border: Color(0xFFF2E8ED),
      shadow: Color(0x1AD95788)),
  FacePalette(
      name: 'Lavender',
      page: Color(0xFFFAF8FF),
      heroStart: Color(0xFFEEE9FF),
      heroEnd: Color(0xFFF7EEFF),
      iconSurface: Color(0xFFEDE7FF),
      accent: Color(0xFF8270C7),
      ink: Color(0xFF3E3557),
      muted: Color(0xFF766D91),
      border: Color(0xFFEAE5F4),
      shadow: Color(0x188271C7)),
  FacePalette(
      name: 'Light blue',
      page: Color(0xFFF6FBFF),
      heroStart: Color(0xFFE3F3FF),
      heroEnd: Color(0xFFEDF4FF),
      iconSurface: Color(0xFFE0F1FF),
      accent: Color(0xFF548EBE),
      ink: Color(0xFF2F4558),
      muted: Color(0xFF6A8295),
      border: Color(0xFFE2ECF4),
      shadow: Color(0x18548EBE)),
  FacePalette(
      name: 'Light green',
      page: Color(0xFFF7FCF7),
      heroStart: Color(0xFFE5F6E8),
      heroEnd: Color(0xFFF0F8E8),
      iconSurface: Color(0xFFE1F3E4),
      accent: Color(0xFF568F67),
      ink: Color(0xFF334B39),
      muted: Color(0xFF6D8773),
      border: Color(0xFFE3EEE4),
      shadow: Color(0x18568F67)),
  FacePalette(
      name: 'Light orange',
      page: Color(0xFFFFFAF5),
      heroStart: Color(0xFFFFEFDF),
      heroEnd: Color(0xFFFFF5E9),
      iconSurface: Color(0xFFFFEAD6),
      accent: Color(0xFFC77A43),
      ink: Color(0xFF58402F),
      muted: Color(0xFF8A735F),
      border: Color(0xFFF1E8DE),
      shadow: Color(0x18C77A43)),
  FacePalette(
      name: 'Light red',
      page: Color(0xFFFFF8F7),
      heroStart: Color(0xFFFFE8E5),
      heroEnd: Color(0xFFFFF0EE),
      iconSurface: Color(0xFFFFE4E1),
      accent: Color(0xFFD66B67),
      ink: Color(0xFF513330),
      muted: Color(0xFF896D69),
      border: Color(0xFFF3E4E1),
      shadow: Color(0x18D66B67)),
];

class FaceReminder {
  static const customTaskSymbol = '!';

  FaceReminder(
      {required this.title, required this.icon, required this.schedule});
  final String title;
  final IconData? icon;
  ReminderSchedule schedule;
  bool enabled = true;
}

class ReminderSchedule {
  const ReminderSchedule.everySeconds(this.intervalSeconds) : timeOfDay = null;
  const ReminderSchedule.everyMinutes(int minutes)
      : intervalSeconds = minutes * 60,
        timeOfDay = null;
  const ReminderSchedule.dailyAt(this.timeOfDay) : intervalSeconds = null;

  final int? intervalSeconds;
  final TimeOfDay? timeOfDay;

  String label(BuildContext context) => timeOfDay == null
      ? _intervalLabel(intervalSeconds!)
      : 'Daily at ${timeOfDay!.format(context)}';
}

const _intervals = <int>[
  30,
  60,
  300,
  600,
  900,
  1200,
  1800,
  2700,
  3600,
  7200,
  10800,
  14400,
  21600,
  43200,
  86400
];

String _intervalLabel(int seconds) {
  if (seconds < 60) return 'Every $seconds sec';
  final minutes = seconds ~/ 60;
  if (minutes < 60) return 'Every $minutes min';
  if (minutes < 1440) {
    if (minutes % 60 != 0) {
      return 'Every ${minutes ~/ 60} hr ${minutes % 60} min';
    }
    final hours = minutes ~/ 60;
    return hours == 1 ? 'Every hour' : 'Every $hours hours';
  }
  if (minutes % 1440 == 0) {
    final days = minutes ~/ 1440;
    return days == 1 ? 'Every day' : 'Every $days days';
  }
  return 'Every $minutes min';
}

final _moods = <String, BuddyMood>{
  'happy': BuddyMood(
    name: 'Feeling sunny',
    note: 'A little joy goes a long way.',
    emoji: '\u2728',
    face: faceById('default').ascii,
  ),
  'press': BuddyMood(
    name: 'So excited!',
    note: 'That button made my day.',
    emoji: '\u2605',
    face: faceById('excited').ascii,
  ),
  'shake': BuddyMood(
    name: 'Wheee!',
    note: 'I felt that little shake.',
    emoji: '\u273f',
    face: faceById('dizzy').ascii,
  ),
  'touch': BuddyMood(
    name: 'Loved up',
    note: 'A tiny hello, right back.',
    emoji: '\u2665',
    face: faceById('loved').ascii,
  ),
};

class HealthCharmPreview extends StatefulWidget {
  const HealthCharmPreview({super.key});

  @override
  State<HealthCharmPreview> createState() => _HealthCharmPreviewState();
}

class _HealthCharmPreviewState extends State<HealthCharmPreview> {
  FacePalette _palette = _palettes.first;
  FaceStyle _faceStyle = FaceStyle.surprise;
  final TextEditingController _faceHintController = TextEditingController();
  final OnDeviceFaceEngine _faceEngine = OnDeviceFaceEngine();
  String? _modelPath;
  String? _selectedFace;
  String _modelStatus = 'Import the model to enable local faces';
  bool _modelBusy = false;
  bool _generatingFace = false;
  int _faceRequestId = 0;
  FaceSelectionRequest? _pendingFaceRequest;
  String _moodKey = 'happy';
  int _tapCount = 0;
  double _motion = 0.0;
  bool _touched = false;
  final List<FaceReminder> _reminders = [
    FaceReminder(
        title: 'Eat something',
        icon: Icons.restaurant_rounded,
        schedule: const ReminderSchedule.everyMinutes(240)),
    FaceReminder(
        title: 'Drink water',
        icon: Icons.water_drop_rounded,
        schedule: const ReminderSchedule.everyMinutes(60)),
    FaceReminder(
        title: 'Chat with a friend',
        icon: Icons.chat_bubble_rounded,
        schedule: const ReminderSchedule.everyMinutes(1440)),
    FaceReminder(
        title: 'Go for a walk',
        icon: Icons.directions_walk_rounded,
        schedule: const ReminderSchedule.everyMinutes(1440)),
  ];

  BuddyMood get _mood => _moods[_moodKey]!;

  final _reminderTimers = <FaceReminder, Timer>{};
  Future<void> _reminderDelivery = Future<void>.value();

  void _scheduleReminder(FaceReminder reminder) {
    _reminderTimers.remove(reminder)?.cancel();
    if (!reminder.enabled) return;
    final schedule = reminder.schedule;
    final time = schedule.timeOfDay;
    final now = DateTime.now();
    final today = time == null
        ? null
        : DateTime(now.year, now.month, now.day, time.hour, time.minute);
    final delay = today == null
        ? Duration(seconds: schedule.intervalSeconds!)
        : (today.isAfter(now)
                ? today
                : DateTime(
                    now.year, now.month, now.day + 1, time!.hour, time.minute))
            .difference(now);
    _reminderTimers[reminder] = Timer(delay, () {
      _scheduleReminder(reminder);
      final icon = switch (reminder.icon) {
        Icons.restaurant_rounded => 'eat',
        Icons.water_drop_rounded => 'water',
        Icons.chat_bubble_rounded => 'chat',
        Icons.directions_walk_rounded => 'walk',
        _ => 'custom',
      };
      _reminderDelivery = _reminderDelivery.then((_) async {
        if (!mounted || !reminder.enabled) return;
        try {
          await const MethodChannel('healthcharm/pico')
              .invokeMethod<void>('reminder', icon);
        } on PlatformException catch (error) {
          if (mounted) {
            _reminderMessage(error.message ?? 'Could not reach Pico W');
          }
          return;
        } on MissingPluginException {
          // The web preview shows the reminder locally.
        }
        if (mounted) _reminderMessage(reminder.title);
      });
    });
  }

  void _reminderMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  void initState() {
    super.initState();
    for (final reminder in _reminders) {
      _scheduleReminder(reminder);
    }
    if (LocalModelStore.supported) unawaited(_restoreModel());
  }

  @override
  void dispose() {
    for (final timer in _reminderTimers.values) {
      timer.cancel();
    }
    unawaited(_faceEngine.dispose());
    _faceHintController.dispose();
    super.dispose();
  }

  Future<void> _restoreModel() async {
    try {
      final path = await LocalModelStore.modelPath();
      if (!mounted || path == null) return;
      await _loadModel(path);
    } catch (error) {
      if (mounted) setState(() => _modelStatus = 'Model check failed: $error');
    }
  }

  Future<void> _loadModel(String path) async {
    setState(() {
      _modelPath = path;
      _modelBusy = true;
      _modelStatus = 'Loading Nemotron on this phone...';
    });
    try {
      await _faceEngine.load(path);
      if (mounted) {
        setState(() => _modelStatus = 'Nemotron ready on this phone');
      }
    } catch (error) {
      if (mounted) {
        setState(() => _modelStatus = 'Could not load model: $error');
      }
    } finally {
      if (mounted) setState(() => _modelBusy = false);
    }
  }

  Future<void> _importModel() async {
    if (_modelBusy) return;
    setState(() {
      _modelBusy = true;
      _modelStatus = 'Choose the NVIDIA GGUF file from Downloads';
    });
    try {
      final path = await LocalModelStore.importModel();
      if (!mounted) return;
      if (path == null) {
        setState(() => _modelStatus = 'Model import cancelled');
        return;
      }
      setState(() => _modelStatus = 'Model verified and copied');
      await _loadModel(path);
    } catch (error) {
      if (mounted) setState(() => _modelStatus = 'Import failed: $error');
    } finally {
      if (mounted) setState(() => _modelBusy = false);
    }
  }

  void _react(String key) {
    _faceRequestId++;
    setState(() {
      _moodKey = key;
      _tapCount += key == 'press' ? 1 : 0;
      _motion = key == 'shake' ? 2.8 : 0.4;
      _touched = key == 'touch';
      _selectedFace = null;
    });
    if (_faceEngine.isLoaded) {
      final request = buildFaceSelectionRequest(
        style: _faceStyle,
        faceHint: _faceHintController.text,
        buttonPressed: key == 'press',
        motionMagnitude: _motion,
        touched: _touched,
      );
      if (_generatingFace) {
        _pendingFaceRequest = request;
      } else {
        unawaited(_chooseFace(request, _faceRequestId));
      }
    }
  }

  Future<void> _chooseFace(FaceSelectionRequest request, int requestId) async {
    setState(() => _generatingFace = true);
    try {
      final face = await _faceEngine.choose(request);
      if (mounted && requestId == _faceRequestId) {
        setState(() => _selectedFace = face.ascii);
      }
    } catch (error) {
      if (mounted && requestId == _faceRequestId) {
        setState(() => _modelStatus = 'Face selection failed: $error');
      }
    } finally {
      if (mounted) {
        setState(() => _generatingFace = false);
        final pending = _pendingFaceRequest;
        _pendingFaceRequest = null;
        if (pending != null) unawaited(_chooseFace(pending, _faceRequestId));
      }
    }
  }

  void _openSettings() {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        var selectedPalette = _palette;
        return Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.viewInsetsOf(sheetContext).bottom),
          child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: (MediaQuery.sizeOf(sheetContext).height -
                        MediaQuery.viewInsetsOf(sheetContext).bottom) *
                    .82,
              ),
              child: StatefulBuilder(
                builder: (context, setSheetState) => Container(
                  padding: const EdgeInsets.fromLTRB(22, 12, 22, 24),
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(28)),
                  ),
                  child: SingleChildScrollView(
                      child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                        width: 38,
                        height: 4,
                        decoration: BoxDecoration(
                            color: const Color(0xFFE9DDE4),
                            borderRadius: BorderRadius.circular(8))),
                    const SizedBox(height: 18),
                    Row(children: [
                      Expanded(
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                            Text('Make it yours',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(
                                        fontWeight: FontWeight.w800,
                                        color: _palette.ink)),
                            const SizedBox(height: 3),
                            Text('Choose colors and a face direction',
                                style: TextStyle(
                                    color: _palette.muted, fontSize: 13)),
                          ])),
                      IconButton(
                          onPressed: () => Navigator.pop(sheetContext),
                          icon: const Icon(Icons.close_rounded)),
                    ]),
                    const SizedBox(height: 16),
                    GridView.count(
                      crossAxisCount: 3,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: 1.55,
                      children: [
                        for (final palette in _palettes)
                          InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () {
                              setState(() => _palette = palette);
                              setSheetState(() => selectedPalette = palette);
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 9, vertical: 8),
                              decoration: BoxDecoration(
                                color: palette.page,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                    color: selectedPalette == palette
                                        ? palette.accent
                                        : palette.border,
                                    width: selectedPalette == palette ? 2 : 1),
                              ),
                              child: Row(children: [
                                Container(
                                    width: 25,
                                    height: 25,
                                    decoration: BoxDecoration(
                                        color: palette.accent,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                            color: Colors.white, width: 3))),
                                const SizedBox(width: 7),
                                Expanded(
                                    child: Text(palette.name,
                                        maxLines: 2,
                                        style: TextStyle(
                                            color: palette.ink,
                                            fontSize: 11,
                                            fontWeight: FontWeight.w700))),
                                if (selectedPalette == palette)
                                  Icon(Icons.check_circle_rounded,
                                      size: 16, color: palette.accent),
                              ]),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Face direction',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: _palette.ink)),
                    ),
                    const SizedBox(height: 5),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Pick a vibe for Nemotron to choose from',
                          style:
                              TextStyle(color: _palette.muted, fontSize: 12)),
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          for (final style in FaceStyle.values)
                            ChoiceChip(
                              label: Text(style.label),
                              selected: _faceStyle == style,
                              selectedColor: _palette.iconSurface,
                              onSelected: (_) {
                                setState(() {
                                  _faceStyle = style;
                                  _selectedFace = null;
                                });
                                setSheetState(() {});
                              },
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _faceHintController,
                      maxLength: 80,
                      maxLines: 2,
                      textCapitalization: TextCapitalization.sentences,
                      onChanged: (_) => setState(() => _selectedFace = null),
                      decoration: const InputDecoration(
                        labelText: 'Your face hint (optional)',
                        hintText: 'e.g. Tiny cat ears and sleepy eyes',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                          LocalModelStore.supported
                              ? 'Your hint guides which preset face Nemotron chooses.'
                              : 'Chrome shows preset faces; Nemotron runs in the Android app.',
                          style:
                              TextStyle(color: _palette.muted, fontSize: 11)),
                    ),
                    if (LocalModelStore.supported) ...[
                      const SizedBox(height: 20),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text('On-device Nemotron',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                    fontWeight: FontWeight.w700,
                                    color: _palette.ink)),
                      ),
                      const SizedBox(height: 6),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(_modelStatus,
                            style:
                                TextStyle(color: _palette.muted, fontSize: 12)),
                      ),
                      if (_modelBusy) const LinearProgressIndicator(),
                      const SizedBox(height: 8),
                      Wrap(spacing: 8, children: [
                        TextButton.icon(
                          onPressed: () async {
                            try {
                              await LocalModelStore.openModelPage();
                            } catch (error) {
                              if (mounted) {
                                setState(() => _modelStatus =
                                    'Could not open model page: $error');
                                setSheetState(() {});
                              }
                            }
                          },
                          icon: const Icon(Icons.download_rounded),
                          label: const Text('Get model file'),
                        ),
                        FilledButton.tonalIcon(
                          onPressed: _modelBusy || _faceEngine.isLoaded
                              ? null
                              : () async {
                                  if (_modelPath == null) {
                                    await _importModel();
                                  } else {
                                    await _loadModel(_modelPath!);
                                  }
                                  if (sheetContext.mounted) {
                                    setSheetState(() {});
                                  }
                                },
                          icon: const Icon(Icons.memory_rounded),
                          label: Text(_modelPath == null
                              ? 'Import model'
                              : 'Load model'),
                        ),
                      ]),
                      const SizedBox(height: 5),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                            'The 2.84 GB file is verified and stored privately on your phone.',
                            style:
                                TextStyle(color: _palette.muted, fontSize: 11)),
                      ),
                    ],
                    const SizedBox(height: 12),
                  ])),
                ),
              )),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final horizontalPadding = width < 400 ? 18.0 : 24.0;
    return Scaffold(
      backgroundColor: _palette.page,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: EdgeInsets.fromLTRB(
                  horizontalPadding, 18, horizontalPadding, 28),
              children: [
                _buildHeader(context),
                const SizedBox(height: 22),
                _buildBuddyCard(context),
                const SizedBox(height: 18),
                _buildSensors(context),
                const SizedBox(height: 22),
                _buildReminders(context),
                const SizedBox(height: 22),
                Text('Give your buddy a little moment',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700, color: _palette.ink)),
                const SizedBox(height: 12),
                _buildActions(),
                const SizedBox(height: 17),
                Center(
                  child: Text('UI PREVIEW  \u00b7  hardware not required',
                      style: TextStyle(
                          color: _palette.muted,
                          fontSize: 11,
                          letterSpacing: 1.15,
                          fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) => Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
                color: _palette.iconSurface,
                borderRadius: BorderRadius.circular(17)),
            child: Icon(Icons.bolt_rounded, color: _palette.accent, size: 29),
          ),
          const SizedBox(width: 12),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('HealthCharm',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                      color: _palette.ink)),
              Text('your pocket-sized pal',
                  style: TextStyle(color: _palette.muted, fontSize: 13)),
            ]),
          ),
          IconButton(
            tooltip: 'Settings',
            onPressed: _openSettings,
            style: IconButton.styleFrom(
                backgroundColor: _palette.iconSurface,
                foregroundColor: _palette.accent),
            icon: const Icon(Icons.palette_rounded),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
            decoration: BoxDecoration(
                color: _palette.iconSurface,
                borderRadius: BorderRadius.circular(30)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(
                  _faceEngine.isLoaded
                      ? Icons.auto_awesome_rounded
                      : Icons.bluetooth_disabled_rounded,
                  size: 15,
                  color: _palette.muted),
              const SizedBox(width: 5),
              Text(_faceEngine.isLoaded ? 'Local AI' : 'Demo',
                  style: TextStyle(
                      color: _palette.ink,
                      fontSize: 12,
                      fontWeight: FontWeight.w700)),
            ]),
          ),
        ],
      );

  Widget _buildBuddyCard(BuildContext context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [_palette.heroStart, _palette.heroEnd]),
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
                color: _palette.shadow,
                blurRadius: 22,
                offset: const Offset(0, 10))
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  Text(_mood.name,
                      style: Theme.of(context)
                          .textTheme
                          .headlineSmall
                          ?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: _palette.ink)),
                  const SizedBox(height: 4),
                  Text(_mood.note,
                      style: TextStyle(color: _palette.muted, fontSize: 13)),
                ])),
            Text(_mood.emoji, style: const TextStyle(fontSize: 25)),
          ]),
          const SizedBox(height: 18),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 230),
            transitionBuilder: (child, animation) => FadeTransition(
                opacity: animation,
                child: ScaleTransition(scale: animation, child: child)),
            child: Container(
              key: ValueKey('$_moodKey:${_selectedFace ?? ''}'),
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 17, horizontal: 12),
              decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: .88),
                  borderRadius: BorderRadius.circular(22)),
              child: Text(_selectedFace ?? _mood.face,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 21,
                      height: 1.19,
                      color: _palette.ink,
                      fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(height: 13),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.auto_awesome_rounded, size: 14, color: _palette.accent),
            SizedBox(width: 5),
            Text('A tiny face, a big feeling',
                style: TextStyle(
                    color: _palette.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ]),
        ]),
      );

  Widget _buildSensors(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Little signals',
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(fontWeight: FontWeight.w700, color: _palette.ink)),
        const SizedBox(height: 11),
        Row(children: [
          Expanded(
              child: _signalTile(
                  icon: Icons.touch_app_rounded,
                  label: 'BUTTON',
                  value: '$_tapCount taps',
                  color: const Color(0xFFE56C99))),
          const SizedBox(width: 10),
          Expanded(
              child: _signalTile(
                  icon: Icons.waves_rounded,
                  label: 'MOTION',
                  value: '${_motion.toStringAsFixed(1)} m/s',
                  color: const Color(0xFF8B7AE8))),
          const SizedBox(width: 10),
          Expanded(
              child: _signalTile(
                  icon: Icons.favorite_rounded,
                  label: 'TOUCH',
                  value: _touched ? 'hello!' : 'waiting',
                  color: const Color(0xFFE99572))),
        ]),
      ]);

  Widget _buildReminders(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Text('Gentle reminders',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700, color: _palette.ink)),
            ),
            TextButton.icon(
              onPressed: _addReminder,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: const Text('Add'),
              style: TextButton.styleFrom(foregroundColor: _palette.accent),
            ),
          ]),
          Text('Choose an interval or a daily time',
              style: TextStyle(color: _palette.muted, fontSize: 12)),
          const SizedBox(height: 10),
          for (final reminder in _reminders) ...[
            _reminderTile(reminder),
            const SizedBox(height: 8),
          ],
          Text('Preview schedule · hardware delivery needs device integration',
              style: TextStyle(color: _palette.muted, fontSize: 10)),
        ],
      );

  Widget _reminderTile(FaceReminder reminder) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: _palette.border),
        ),
        child: Row(children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
                color: _palette.iconSurface,
                borderRadius: BorderRadius.circular(13)),
            child: reminder.icon == null
                ? Center(
                    child: Text(FaceReminder.customTaskSymbol,
                        style: TextStyle(
                            color: _palette.accent,
                            fontFamily: 'monospace',
                            fontSize: 23,
                            fontWeight: FontWeight.w900)))
                : Icon(reminder.icon, color: _palette.accent, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(reminder.title,
                  style: TextStyle(
                      color: _palette.ink,
                      fontWeight: FontWeight.w700,
                      fontSize: 13)),
              InkWell(
                onTap: () async {
                  final schedule =
                      await _pickSchedule(context, reminder.schedule);
                  if (schedule != null && mounted) {
                    setState(() => reminder.schedule = schedule);
                    _scheduleReminder(reminder);
                  }
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Text(reminder.schedule.label(context),
                        style: TextStyle(color: _palette.muted, fontSize: 11)),
                    Icon(Icons.arrow_drop_down_rounded,
                        color: _palette.muted, size: 18),
                  ]),
                ),
              ),
            ]),
          ),
          Switch.adaptive(
            value: reminder.enabled,
            activeThumbColor: _palette.accent,
            onChanged: (value) {
              setState(() => reminder.enabled = value);
              _scheduleReminder(reminder);
            },
          ),
        ]),
      );

  Future<ReminderSchedule?> _pickSchedule(
      BuildContext context, ReminderSchedule current) async {
    final choice = await showModalBottomSheet<int>(
      context: context,
      useSafeArea: true,
      builder: (sheetContext) => SizedBox(
        height: MediaQuery.sizeOf(sheetContext).height * .65,
        child: ListView(children: [
          const ListTile(title: Text('Choose a reminder time')),
          for (final seconds in _intervals)
            ListTile(
              title: Text(_intervalLabel(seconds)),
              trailing: current.intervalSeconds == seconds
                  ? const Icon(Icons.check_rounded)
                  : null,
              onTap: () => Navigator.pop(sheetContext, seconds),
            ),
          ListTile(
            leading: const Icon(Icons.tune_rounded),
            title: const Text('Custom interval'),
            subtitle: const Text('Any number of minutes, up to 7 days'),
            onTap: () => Navigator.pop(sheetContext, -1),
          ),
          ListTile(
            leading: const Icon(Icons.schedule_rounded),
            title: const Text('At a specific time'),
            subtitle: const Text('Every day at a clock time'),
            onTap: () => Navigator.pop(sheetContext, -2),
          ),
        ]),
      ),
    );
    if (choice == null || !context.mounted) return null;
    if (choice > 0) return ReminderSchedule.everySeconds(choice);
    if (choice == -2) {
      final time = await showTimePicker(
        context: context,
        initialTime: current.timeOfDay ?? TimeOfDay.now(),
      );
      return time == null ? null : ReminderSchedule.dailyAt(time);
    }

    final controller = TextEditingController(
        text: current.intervalSeconds == null
            ? '60'
            : (current.intervalSeconds! < 60
                    ? 1
                    : current.intervalSeconds! ~/ 60)
                .toString());
    final formKey = GlobalKey<FormState>();
    final minutes = await showDialog<int>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Custom interval'),
        content: Form(
          key: formKey,
          child: TextFormField(
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              labelText: 'Minutes between reminders',
              helperText: '1 to 10,080 minutes (7 days)',
            ),
            validator: (value) {
              final number = int.tryParse(value ?? '');
              if (number == null || number < 1 || number > 10080) {
                return 'Enter a number from 1 to 10,080';
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(dialogContext, int.parse(controller.text));
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    return minutes == null ? null : ReminderSchedule.everyMinutes(minutes);
  }

  Future<void> _addReminder() async {
    final titleController = TextEditingController();
    var schedule = const ReminderSchedule.everyMinutes(60);
    final result = await showDialog<FaceReminder>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Add a reminder'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: titleController,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                  labelText: 'What should your buddy remind you to do?'),
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('When should it remind you?'),
              subtitle: Text(schedule.label(context)),
              trailing: const Icon(Icons.edit_calendar_rounded),
              onTap: () async {
                final selected = await _pickSchedule(dialogContext, schedule);
                if (selected != null && dialogContext.mounted) {
                  setDialogState(() => schedule = selected);
                }
              },
            ),
          ]),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                final title = titleController.text.trim();
                if (title.isEmpty) return;
                Navigator.pop(
                  dialogContext,
                  FaceReminder(
                    title: title,
                    schedule: schedule,
                    icon: _iconForReminder(title),
                  ),
                );
              },
              child: const Text('Add reminder'),
            ),
          ],
        ),
      ),
    );
    titleController.dispose();
    if (result != null && mounted) {
      setState(() => _reminders.add(result));
      _scheduleReminder(result);
    }
  }

  IconData? _iconForReminder(String title) {
    final text = title.toLowerCase();
    if (text.contains('water') || text.contains('drink')) {
      return Icons.water_drop_rounded;
    }
    if (text.contains('eat') ||
        text.contains('food') ||
        text.contains('meal')) {
      return Icons.restaurant_rounded;
    }
    if (text.contains('walk') || text.contains('exercise')) {
      return Icons.directions_walk_rounded;
    }
    if (text.contains('friend') ||
        text.contains('chat') ||
        text.contains('call')) {
      return Icons.chat_bubble_rounded;
    }
    return null;
  }

  Widget _signalTile(
          {required IconData icon,
          required String label,
          required String value,
          required Color color}) =>
      Container(
        padding: const EdgeInsets.fromLTRB(12, 13, 8, 13),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(19),
            border: Border.all(color: _palette.border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 9),
          Text(label,
              style: const TextStyle(
                  fontSize: 9,
                  letterSpacing: .7,
                  color: Color(0xFF9A8290),
                  fontWeight: FontWeight.w800)),
          const SizedBox(height: 3),
          FittedBox(
              alignment: Alignment.centerLeft,
              fit: BoxFit.scaleDown,
              child: Text(value,
                  style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF503A49),
                      fontWeight: FontWeight.w700))),
        ]),
      );

  Widget _buildActions() => Row(children: [
        Expanded(
            child: _actionButton(
                label: 'Press',
                icon: Icons.touch_app_rounded,
                color: const Color(0xFFE56C99),
                onPressed: () => _react('press'))),
        const SizedBox(width: 9),
        Expanded(
            child: _actionButton(
                label: 'Shake',
                icon: Icons.waves_rounded,
                color: const Color(0xFF8B7AE8),
                onPressed: () => _react('shake'))),
        const SizedBox(width: 9),
        Expanded(
            child: _actionButton(
                label: 'Touch',
                icon: Icons.favorite_rounded,
                color: const Color(0xFFE99572),
                onPressed: () => _react('touch'))),
      ]);

  Widget _actionButton(
          {required String label,
          required IconData icon,
          required Color color,
          required VoidCallback onPressed}) =>
      FilledButton.tonalIcon(
        onPressed: onPressed,
        icon: Icon(icon, size: 17, color: color),
        label: Text(label,
            style: TextStyle(
                color: color, fontWeight: FontWeight.w700, fontSize: 12)),
        style: FilledButton.styleFrom(
          backgroundColor: color.withValues(alpha: .10),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 7),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      );
}
