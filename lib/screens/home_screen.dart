import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/transaction.dart';
import '../models/upcoming.dart';
import '../state/expense_store.dart';
import '../utils/format.dart';
import '../widgets/budgets.dart';
import '../widgets/premium_bottom_bar.dart';
import '../widgets/profile_drawer.dart';
import '../widgets/quick_add.dart';
import '../widgets/ui.dart';
import '../widgets/upcoming_sheet.dart';
import 'dashboard_view.dart';
import 'reports_view.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.store});
  final ExpenseStore store;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  late final AnimationController _pos = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
  );
  double _width = 1;
  final Set<String> _dismissed = {};
  DateTime? _lastBackAt;

  @override
  void dispose() {
    _pos.dispose();
    super.dispose();
  }

  /// Back button priority: drawer -> Reports -> exit on second press.
  Future<void> _onBackInvoked(bool didPop) async {
    if (didPop) return;

    final scaffold = _scaffoldKey.currentState;
    if (scaffold != null && scaffold.isDrawerOpen) {
      scaffold.closeDrawer();
      return;
    }
    if (_pos.value > 0.5) {
      _goTo(0);
      return;
    }

    final now = DateTime.now();
    final last = _lastBackAt;
    if (last != null && now.difference(last) < const Duration(seconds: 2)) {
      _lastBackAt = null;
      await SystemNavigator.pop();
      return;
    }
    _lastBackAt = now;
    if (!mounted) return;
    showAppToast(context, message: 'Press back again to exit');
  }

  void _goTo(int i) {
    _pos.animateTo(
      i.toDouble(),
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeOutCubic,
    );
  }

  void _switchView() => _goTo(_pos.value > 0.5 ? 0 : 1);
  void _onDragStart(DragStartDetails _) => _pos.stop();
  void _onDragUpdate(DragUpdateDetails d) {
    _pos.value = _pos.value - (d.primaryDelta ?? 0) / _width;
  }

  void _onDragEnd(DragEndDetails d) {
    final v = d.primaryVelocity ?? 0;
    if (_pos.value <= 0 && v > 300) {
      _scaffoldKey.currentState?.openDrawer();
      _goTo(0);
      return;
    }
    final int target;
    if (v.abs() > 300) {
      target = v < 0 ? 1 : 0;
    } else {
      target = _pos.value > 0.5 ? 1 : 0;
    }
    _goTo(target);
  }

  Upcoming? _dueSoon(ExpenseStore store) {
    final limit = DateTime.now().add(const Duration(days: 3));
    for (final u in store.upcoming) {
      if (!_dismissed.contains(u.id) && !u.dueDate.isAfter(limit)) return u;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        if (!store.isLoaded) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) {
            _onBackInvoked(didPop);
          },
          child: Scaffold(
            key: _scaffoldKey,
            backgroundColor: Theme.of(context).colorScheme.surface,
            drawer: ProfileDrawer(
              store: store,
              hostContext: context,
              onOpenReports: () => _goTo(1),
            ),
            body: Stack(
              children: [
                LayoutBuilder(
                  builder: (context, c) {
                    _width = c.maxWidth;
                    return GestureDetector(
                      behavior: HitTestBehavior.translucent,
                      onHorizontalDragStart: _onDragStart,
                      onHorizontalDragUpdate: _onDragUpdate,
                      onHorizontalDragEnd: _onDragEnd,
                      child: ClipRect(
                        child: AnimatedBuilder(
                          animation: _pos,
                          builder: (context, _) {
                            final t = _pos.value.clamp(0.0, 1.0).toDouble();
                            final w = _width;
                            return Stack(
                              children: [
                                Positioned.fill(
                                  child: Transform.translate(
                                    offset: Offset(-t * w, 0),
                                    child: DashboardView(
                                      store: store,
                                      onOpenReports: () => _goTo(1),
                                    ),
                                  ),
                                ),
                                Positioned.fill(
                                  child: Transform.translate(
                                    offset: Offset((1 - t) * w, 0),
                                    child: SafeArea(
                                      bottom: false,
                                      child: Column(
                                        children: [
                                          _ReportsTopBar(
                                            onBack: () => _goTo(0),
                                          ),
                                          Expanded(
                                            child: ReportsView(store: store),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    );
                  },
                ),
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: AnimatedBuilder(
                    animation: _pos,
                    builder: (context, _) {
                      final due = _dueSoon(store);
                      return SafeArea(
                        top: false,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (due != null)
                              NoticeBubble(
                                text:
                                    '${due.title} is due ${formatDay(due.dueDate)} · '
                                    '${formatRupees(due.amountPaise / 100)}',
                                onView: () => showUpcomingSheet(context, store),
                                onClose: () =>
                                    setState(() => _dismissed.add(due.id)),
                              ),
                            PremiumBottomBar(
                              onHome: _pos.value <= 0.5,
                              onSwitchView: _switchView,
                              onSpent: () =>
                                  startAddFlow(context, store, TxType.expense),
                              onReceived: () =>
                                  startAddFlow(context, store, TxType.income),
                              onBudgets: () => showBudgetSheet(context, store),
                              onUpcoming: () =>
                                  showUpcomingSheet(context, store),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ReportsTopBar extends StatelessWidget {
  const _ReportsTopBar({required this.onBack});
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 12, 0),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Back to Home',
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          const SizedBox(width: 4),
          Text(
            'Reports',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
