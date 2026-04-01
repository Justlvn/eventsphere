import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../../features/events/presentation/providers/events_provider.dart';
import '../../../../features/events/presentation/screens/event_detail_screen.dart';
import '../../../../models/enums.dart';
import '../../../../models/event.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  // ── constants ─────────────────────────────────────────────────────────────
  // 8h → 00h (midnight). Midnight is represented as hour 24 for positioning.
  static const int _kStartHour = 8;
  static const int _kEndHour = 24;
  static const int _kTotalHours = _kEndHour - _kStartHour; // 16
  static const double _kTimeColumnWidth = 46.0;

  /// Lundi de référence pour indexer les pages du [PageView] (scroll infini).
  static final DateTime _kEpochMonday = DateTime(2020, 1, 6);

  // ── state ─────────────────────────────────────────────────────────────────
  late DateTime _weekStart;
  late DateTime _today;
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    _today = _dateOnly(DateTime.now());
    _weekStart = _monday(_today);
    _pageController = PageController(
      initialPage: _pageForWeek(_weekStart),
    );
    // Après le 1er layout, [PageController.page] est défini — sync de l’en-tête.
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncHeaderToPage());
  }

  /// Aligne [_weekStart] sur la page actuelle (utile après layout ou navigation).
  void _syncHeaderToPage() {
    if (!mounted || !_pageController.hasClients) return;
    final p = _pageController.page;
    if (p == null) return;
    final ws = _weekStartForPage(p.round());
    if (!_isSameDay(ws, _weekStart)) {
      setState(() => _weekStart = ws);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // ── date helpers ──────────────────────────────────────────────────────────

  static DateTime _dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

  static DateTime _monday(DateTime d) =>
      _dateOnly(d.subtract(Duration(days: d.weekday - 1)));

  static bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// Jours du lundi au dimanche — arithmétique calendaire (évite les décalages DST).
  static List<DateTime> _weekDaysFor(DateTime weekStart) {
    final s = _dateOnly(weekStart);
    return List.generate(
      7,
      (i) => _dateOnly(DateTime(s.year, s.month, s.day + i)),
    );
  }

  /// Index de page pour un lundi donné (aligné sur [_kEpochMonday]).
  ///
  /// Ne pas utiliser `m.difference(epoch).inDays ~/ 7` : avec le changement d’heure,
  /// 7 jours civils entre deux lundis peuvent donner 167 h ou 169 h, donc `inDays`
  /// vaut parfois 6 → page « Aujourd’hui » décalée d’une semaine.
  static int _pageForWeek(DateTime monday) {
    final m = _dateOnly(monday);
    final epoch = _dateOnly(_kEpochMonday);
    if (_isSameDay(m, epoch)) return 0;

    if (m.isBefore(epoch)) {
      var cur = epoch;
      var page = 0;
      while (!_isSameDay(cur, m)) {
        cur = _dateOnly(DateTime(cur.year, cur.month, cur.day - 7));
        page--;
      }
      return page;
    }

    var cur = epoch;
    var page = 0;
    while (!_isSameDay(cur, m)) {
      cur = _dateOnly(DateTime(cur.year, cur.month, cur.day + 7));
      page++;
    }
    return page;
  }

  /// Lundi de la semaine d’indice [page] (cohérent avec [_pageForWeek]).
  static DateTime _weekStartForPage(int page) {
    final e = _dateOnly(_kEpochMonday);
    return _dateOnly(DateTime(e.year, e.month, e.day + page * 7));
  }

  bool _isCurrentWeekFor(DateTime weekStart) =>
      _isSameDay(weekStart, _monday(_today));

  // Normalise hour: midnight (0) → 24, so it lands at the bottom of the grid.
  static int _hour24(int hour) => hour == 0 ? 24 : hour;

  // ── navigation ────────────────────────────────────────────────────────────

  int get _currentPage {
    if (!_pageController.hasClients) return _pageForWeek(_weekStart);
    final p = _pageController.page;
    if (p == null) return _pageForWeek(_weekStart);
    return p.round();
  }

  void _goToPrevWeek() {
    final page = _currentPage;
    _pageController.animateToPage(
      page - 1,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    ).then((_) {
      if (mounted) _syncHeaderToPage();
    });
  }

  void _goToNextWeek() {
    final page = _currentPage;
    _pageController.animateToPage(
      page + 1,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    ).then((_) {
      if (mounted) _syncHeaderToPage();
    });
  }

  void _goToToday() {
    final today = _dateOnly(DateTime.now());
    final monday = _monday(today);
    final target = _pageForWeek(monday);

    setState(() {
      _today = today;
      _weekStart = monday;
    });

    void jump() {
      if (!_pageController.hasClients) return;
      _pageController.jumpToPage(target);
    }

    jump();
    if (!_pageController.hasClients) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        jump();
      });
    }
  }

  // ── event helpers ─────────────────────────────────────────────────────────

  List<AppEvent> _eventsForDay(List<AppEvent> all, DateTime day) => all
      .where((e) => e.eventDate != null && _isSameDay(e.eventDate!, day))
      .toList()
    ..sort((a, b) => a.eventDate!.compareTo(b.eventDate!));

  double _topOffset(DateTime dt, double hourHeight) {
    final h = _hour24(dt.hour);
    return ((h - _kStartHour) + dt.minute / 60.0) * hourHeight;
  }

  bool _isInVisibleRange(DateTime dt) {
    final h = _hour24(dt.hour);
    return h >= _kStartHour && h < _kEndHour;
  }

  double _blockHeight(AppEvent event, double hourHeight) {
    final dur = event.duration;
    if (dur != null && dur.inMinutes > 0) {
      return (dur.inMinutes / 60.0 * hourHeight).clamp(20.0, double.infinity);
    }
    return (hourHeight - 2).clamp(20.0, double.infinity);
  }

  static Color _categoryColor(EventCategory cat) {
    switch (cat) {
      case EventCategory.soiree:
        return const Color(0xFF5E5CE6);
      case EventCategory.afterwork:
        return const Color(0xFFFF9500);
      case EventCategory.journee:
        return const Color(0xFF34C759);
      case EventCategory.venteNourriture:
        return const Color(0xFFFF3B30);
      case EventCategory.sport:
        return const Color(0xFF30B0C7);
      case EventCategory.culture:
        return const Color(0xFF007AFF);
      case EventCategory.concert:
        return const Color(0xFFAF52DE);
    }
  }

  // ── build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final eventsProvider = context.watch<EventsProvider>();
    final allEvents = eventsProvider.allEvents;

    return Scaffold(
      body: SafeArea(
        child: eventsProvider.status == EventsStatus.loading
            ? const Center(child: CircularProgressIndicator())
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // En-tête fixe (ne swipe pas)
                  _buildMonthHeader(context, _weekStart),
                  // Ligne des jours + grille horaire uniquement
                  Expanded(
                    child: PageView.builder(
                      controller: _pageController,
                      onPageChanged: (page) {
                        setState(() {
                          _weekStart = _weekStartForPage(page);
                        });
                      },
                      itemBuilder: (context, index) {
                        final weekStart = _weekStartForPage(index);
                        final days = _weekDaysFor(weekStart);
                        return Column(
                          children: [
                            _buildDayRow(context, days),
                            Divider(
                              height: 1,
                              color: Theme.of(context)
                                  .colorScheme
                                  .outlineVariant,
                            ),
                            Expanded(
                              child: LayoutBuilder(
                                builder: (context, constraints) {
                                  final hourHeight =
                                      constraints.maxHeight / _kTotalHours;
                                  return _buildTimeGrid(
                                    context,
                                    days,
                                    allEvents,
                                    hourHeight,
                                    constraints.maxHeight,
                                  );
                                },
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  // ── month header ──────────────────────────────────────────────────────────

  Widget _buildMonthHeader(BuildContext context, DateTime weekStart) {
    final cs = Theme.of(context).colorScheme;
    final raw = DateFormat('MMMM yyyy', 'fr_FR').format(weekStart);
    final label = raw.substring(0, 1).toUpperCase() + raw.substring(1);

    final weekEnd = weekStart.add(const Duration(days: 6));
    final rangeLabel = weekStart.month == weekEnd.month
        ? '${weekStart.day} – ${weekEnd.day} ${DateFormat('MMMM', 'fr_FR').format(weekStart)}'
        : '${weekStart.day} ${DateFormat('MMM', 'fr_FR').format(weekStart)} – '
            '${weekEnd.day} ${DateFormat('MMM', 'fr_FR').format(weekEnd)}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: cs.onSurface,
                        height: 1.1,
                      ),
                ),
                Text(
                  rangeLabel,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
          if (!_isCurrentWeekFor(weekStart))
            TextButton.icon(
              onPressed: _goToToday,
              icon: const Icon(Icons.today_outlined, size: 16),
              label: const Text("Auj."),
              style: TextButton.styleFrom(
                foregroundColor: cs.primary,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                visualDensity: VisualDensity.compact,
              ),
            ),
          IconButton(
            icon: const Icon(Icons.chevron_left),
            onPressed: _goToPrevWeek,
            tooltip: 'Semaine précédente',
            visualDensity: VisualDensity.compact,
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right),
            onPressed: _goToNextWeek,
            tooltip: 'Semaine suivante',
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  // ── day row header ─────────────────────────────────────────────────────────

  Widget _buildDayRow(BuildContext context, List<DateTime> days) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6, top: 4),
      child: Row(
        children: [
          SizedBox(width: _kTimeColumnWidth),
          ...days.map((day) {
            final isToday = _isSameDay(day, _today);
            final abbr = DateFormat('E', 'fr_FR')
                .format(day)
                .toUpperCase()
                .substring(0, 3);

            return Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    abbr,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: isToday ? cs.primary : cs.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                  ),
                  const SizedBox(height: 3),
                  Container(
                    width: 28,
                    height: 28,
                    decoration: isToday
                        ? BoxDecoration(
                            color: cs.primary,
                            shape: BoxShape.circle,
                          )
                        : null,
                    alignment: Alignment.center,
                    child: Text(
                      '${day.day}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: isToday ? cs.onPrimary : cs.onSurface,
                            fontWeight:
                                isToday ? FontWeight.bold : FontWeight.w400,
                          ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ── time grid (no scroll — fits exactly in available height) ──────────────

  Widget _buildTimeGrid(
    BuildContext context,
    List<DateTime> days,
    List<AppEvent> allEvents,
    double hourHeight,
    double gridHeight,
  ) {
    return SizedBox(
      height: gridHeight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Time label column
          SizedBox(
            width: _kTimeColumnWidth,
            height: gridHeight,
            child: _buildTimeLabels(context, hourHeight),
          ),
          // One column per day of the week
          ...days.map(
            (day) => Expanded(
              child: _buildDayColumn(
                context,
                day,
                _eventsForDay(allEvents, day),
                gridHeight,
                hourHeight,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeLabels(BuildContext context, double hourHeight) {
    final cs = Theme.of(context).colorScheme;

    return Stack(
      children: List.generate(_kTotalHours + 1, (i) {
        // Hour label: 08, 09, ..., 23, 00 (midnight at bottom)
        final labelHour = (_kStartHour + i) % 24;
        return Positioned(
          top: i * hourHeight - 8,
          left: 0,
          right: 4,
          child: Text(
            '${labelHour.toString().padLeft(2, '0')}:00',
            textAlign: TextAlign.right,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontSize: 10,
                ),
          ),
        );
      }),
    );
  }

  // ── day column ────────────────────────────────────────────────────────────

  Widget _buildDayColumn(
    BuildContext context,
    DateTime day,
    List<AppEvent> events,
    double gridHeight,
    double hourHeight,
  ) {
    final cs = Theme.of(context).colorScheme;
    final isToday = _isSameDay(day, _today);

    return SizedBox(
      height: gridHeight,
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [
          // Today tint
          if (isToday)
            Positioned.fill(
              child: Container(
                color: cs.primaryContainer.withValues(alpha: 0.10),
              ),
            ),

          // Hour separator lines
          ...List.generate(
            _kTotalHours,
            (i) => Positioned(
              top: i * hourHeight,
              left: 0,
              right: 0,
              child: Container(
                height: 1,
                color: cs.outlineVariant.withValues(alpha: 0.55),
              ),
            ),
          ),

          // Half-hour guide lines
          ...List.generate(
            _kTotalHours,
            (i) => Positioned(
              top: i * hourHeight + hourHeight / 2,
              left: 6,
              right: 0,
              child: Container(
                height: 1,
                color: cs.outlineVariant.withValues(alpha: 0.25),
              ),
            ),
          ),

          // Left vertical separator
          Positioned(
            top: 0,
            bottom: 0,
            left: 0,
            width: 1,
            child: Container(
              color: cs.outlineVariant.withValues(alpha: 0.4),
            ),
          ),

          // Event blocks
          ...events.map((e) => _buildEventBlock(context, e, hourHeight)),

          // Current-time indicator (today only)
          if (isToday) _buildNowIndicator(context, hourHeight),
        ],
      ),
    );
  }

  // ── event block ───────────────────────────────────────────────────────────

  Widget _buildEventBlock(
      BuildContext context, AppEvent event, double hourHeight) {
    if (event.eventDate == null) return const SizedBox.shrink();
    final dt = event.eventDate!;

    if (!_isInVisibleRange(dt)) return const SizedBox.shrink();

    final top = _topOffset(dt, hourHeight);
    final color = _categoryColor(event.category);

    return Positioned(
      top: top,
      left: 2,
      right: 2,
      height: _blockHeight(event, hourHeight),
      child: _EventBlock(
        event: event,
        color: color,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => EventDetailScreen(eventId: event.id),
          ),
        ),
      ),
    );
  }

  // ── current-time indicator ────────────────────────────────────────────────

  Widget _buildNowIndicator(BuildContext context, double hourHeight) {
    final now = DateTime.now();
    if (!_isInVisibleRange(now)) return const SizedBox.shrink();
    final top = _topOffset(now, hourHeight);
    final cs = Theme.of(context).colorScheme;

    return Positioned(
      top: top - 1,
      left: 0,
      right: 0,
      child: Row(
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: cs.error,
              shape: BoxShape.circle,
            ),
          ),
          Expanded(
            child: Container(height: 2, color: cs.error),
          ),
        ],
      ),
    );
  }
}

// ── Event block widget ────────────────────────────────────────────────────────

class _EventBlock extends StatelessWidget {
  final AppEvent event;
  final Color color;
  final VoidCallback onTap;

  const _EventBlock({
    required this.event,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final assoName = event.association?.name?.trim();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.88),
          borderRadius: BorderRadius.circular(5),
          border: Border(
            left: BorderSide(color: color, width: 3),
          ),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.25),
              blurRadius: 3,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        padding: const EdgeInsets.fromLTRB(6, 4, 4, 4),
        child: LayoutBuilder(
          builder: (context, constraints) {
            return FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.topLeft,
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: constraints.maxWidth),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      event.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        height: 1.15,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 3,
                    ),
                    if (assoName != null && assoName.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        assoName,
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.82),
                          fontSize: 8.5,
                          fontWeight: FontWeight.w500,
                          height: 1.15,
                        ),
                        softWrap: true,
                      ),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
