import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/auth_service.dart';
import '../services/cloud_service.dart';
import '../state/expense_store.dart';
import 'home_screen.dart';

enum _Gate { checking, accountSwitch, guestData, welcome, ready }

/// Decides what to show between "authenticated" and "home":
///  - account switch prompt  (device data belongs to a different account)
///  - guest data prompt      (entering guest mode with a signed-in user's data)
///  - welcome screen         (only right after a real sign-in)
/// Cloud sync is attached ONLY after the decision, so data can never
/// leak into the wrong account before the user chooses.
class SessionGate extends StatefulWidget {
  const SessionGate({super.key, required this.store, required this.auth});
  final ExpenseStore store;
  final AuthService auth;

  @override
  State<SessionGate> createState() => _SessionGateState();
}

class _SessionGateState extends State<SessionGate> {
  static const _kOwner = 'data_owner_uid';
  static const _kOwnerLabel = 'data_owner_label';
  static const _kSeen = 'seen_uids';

  _Gate _gate = _Gate.checking;
  bool _evaluating = false;
  bool _busy = false;
  bool _returning = false;
  String? _resolvedIdentity;
  String? _owner;
  String? _ownerLabel;
  String? _syncResult;
  Set<String> _seen = {};

  @override
  void initState() {
    super.initState();
    widget.auth.addListener(_onAuth);
    _evaluate();
  }

  @override
  void dispose() {
    widget.auth.removeListener(_onAuth);
    super.dispose();
  }

  void _onAuth() {
    if (mounted) _evaluate();
  }

  String get _identity =>
      widget.auth.isGuest ? 'guest' : (widget.auth.uid ?? '');

  Future<void> _evaluate() async {
    if (_evaluating) return;
    final identity = _identity;
    final fresh = widget.auth.justSignedIn;
    if (_resolvedIdentity == identity && !fresh) return;

    _evaluating = true;
    if (mounted) setState(() => _gate = _Gate.checking);

    try {
      final prefs = await SharedPreferences.getInstance();
      _owner = prefs.getString(_kOwner);
      _ownerLabel = prefs.getString(_kOwnerLabel);
      _seen = (prefs.getStringList(_kSeen) ?? []).toSet();

      final hasLocal = widget.store.hasAnyData;
      final ownerSet = _owner != null && _owner!.isNotEmpty;

      // ---------- GUEST ----------
      if (widget.auth.isGuest) {
        widget.store.detachCloud();
        if (hasLocal && ownerSet) {
          if (!mounted) return;
          setState(() => _gate = _Gate.guestData);
          return;
        }
        await _setOwner(null, null);
        _resolvedIdentity = identity;
        if (!mounted) return;
        setState(() => _gate = _Gate.ready);
        return;
      }

      // ---------- SIGNED IN ----------
      final uid = widget.auth.uid!;
      if (hasLocal && ownerSet && _owner != uid) {
        widget.store.detachCloud(); // never push into the new account yet
        if (!mounted) return;
        setState(() => _gate = _Gate.accountSwitch);
        return;
      }

      await _syncAs(uid);
      _returning = _seen.contains(uid);
      _seen.add(uid);
      await prefs.setStringList(_kSeen, _seen.toList());
      await _setOwner(uid, widget.auth.email);

      _resolvedIdentity = identity;
      if (!mounted) return;
      setState(() => _gate = fresh ? _Gate.welcome : _Gate.ready);
      if (!fresh) widget.auth.consumeJustSignedIn();
    } finally {
      _evaluating = false;
    }
  }

  Future<void> _syncAs(String uid) async {
    widget.store.attachCloud(CloudService(uid));
    _syncResult = await widget.store.reconcileWithCloud();
    debugPrint('Cloud sync: $_syncResult');
  }

  Future<void> _setOwner(String? uid, String? label) async {
    final prefs = await SharedPreferences.getInstance();
    if (uid == null || uid.isEmpty) {
      await prefs.remove(_kOwner);
      await prefs.remove(_kOwnerLabel);
    } else {
      await prefs.setString(_kOwner, uid);
      await prefs.setString(_kOwnerLabel, label ?? uid);
    }
    _owner = uid;
    _ownerLabel = label;
  }

  Future<void> _finishSignIn({required bool wipeFirst}) async {
    setState(() => _busy = true);
    final uid = widget.auth.uid!;

    if (wipeFirst) {
      await widget.store.replaceAllData(
        accounts: const [],
        transactions: const [],
        upcoming: const [],
        budgets: const {},
      );
    }

    await _syncAs(uid);

    final prefs = await SharedPreferences.getInstance();
    _returning = _seen.contains(uid);
    _seen.add(uid);
    await prefs.setStringList(_kSeen, _seen.toList());
    await _setOwner(uid, widget.auth.email);

    _resolvedIdentity = _identity;
    widget.auth.consumeJustSignedIn();
    if (!mounted) return;
    setState(() {
      _busy = false;
      _gate = _Gate.welcome;
    });
  }

  Future<void> _resolveGuest({required bool wipe}) async {
    setState(() => _busy = true);
    if (wipe) {
      await widget.store.replaceAllData(
        accounts: const [],
        transactions: const [],
        upcoming: const [],
        budgets: const {},
      );
    }
    await _setOwner(null, null);
    _resolvedIdentity = _identity;
    if (!mounted) return;
    setState(() {
      _busy = false;
      _gate = _Gate.ready;
    });
  }

  void _finishWelcome() {
    widget.auth.consumeJustSignedIn();
    setState(() => _gate = _Gate.ready);
  }

  @override
  Widget build(BuildContext context) {
    switch (_gate) {
      case _Gate.checking:
        return const _CheckingView();
      case _Gate.accountSwitch:
        return _AccountSwitchView(
          busy: _busy,
          ownerLabel: _ownerLabel ?? 'another account',
          newLabel: widget.auth.email ?? 'your account',
          onKeep: () => _finishSignIn(wipeFirst: false),
          onFresh: () => _finishSignIn(wipeFirst: true),
        );
      case _Gate.guestData:
        return _GuestDataView(
          busy: _busy,
          ownerLabel: _ownerLabel ?? 'a signed-in account',
          onKeep: () => _resolveGuest(wipe: false),
          onFresh: () => _resolveGuest(wipe: true),
        );
      case _Gate.welcome:
        return _WelcomeView(
          returning: _returning,
          name: widget.auth.displayName ?? 'there',
          syncResult: _syncResult,
          onContinue: _finishWelcome,
        );
      case _Gate.ready:
        return HomeScreen(store: widget.store, auth: widget.auth);
    }
  }
}

// ---------------- shared chrome ----------------

const _bgTop = Color(0xFF0E4D45);
const _bgBottom = Color(0xFF06201C);
const _accent = Color(0xFF3DD6B4);

class _GateShell extends StatelessWidget {
  const _GateShell({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_bgTop, _bgBottom],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ),
      ),
    );
  }
}

class _CheckingView extends StatelessWidget {
  const _CheckingView();

  @override
  Widget build(BuildContext context) {
    return const _GateShell(
      children: [
        Spacer(),
        Center(
          child: SizedBox(
            width: 34,
            height: 34,
            child: CircularProgressIndicator(strokeWidth: 3, color: _accent),
          ),
        ),
        SizedBox(height: 20),
        Text(
          'Preparing your workspace…',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.white70, fontSize: 14),
        ),
        Spacer(),
      ],
    );
  }
}

class _ChoiceButton extends StatelessWidget {
  const _ChoiceButton({
    required this.title,
    required this.subtitle,
    required this.primary,
    required this.onTap,
    this.busy = false,
  });

  final String title;
  final String subtitle;
  final bool primary;
  final VoidCallback onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: primary ? Colors.white : Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: busy ? null : onTap,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: primary
                    ? Colors.transparent
                    : Colors.white.withValues(alpha: 0.25),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: primary ? _bgBottom : Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: primary
                        ? _bgBottom.withValues(alpha: 0.7)
                        : Colors.white.withValues(alpha: 0.6),
                    fontSize: 12.5,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------- account switch ----------------

class _AccountSwitchView extends StatelessWidget {
  const _AccountSwitchView({
    required this.busy,
    required this.ownerLabel,
    required this.newLabel,
    required this.onKeep,
    required this.onFresh,
  });

  final bool busy;
  final String ownerLabel;
  final String newLabel;
  final VoidCallback onKeep;
  final VoidCallback onFresh;

  @override
  Widget build(BuildContext context) {
    return _GateShell(
      children: [
        const Spacer(),
        Container(
          width: 64,
          height: 64,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _accent.withValues(alpha: 0.18),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.switch_account_rounded,
            color: _accent,
            size: 30,
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Different account detected',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'This device currently holds data from\n$ownerLabel.\n\nYou are signing in as $newLabel.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 14,
            height: 1.45,
          ),
        ),
        const Spacer(),
        if (busy)
          const Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: Center(
              child: SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: _accent,
                ),
              ),
            ),
          ),
        _ChoiceButton(
          busy: busy,
          primary: true,
          title: 'Keep this data',
          subtitle: 'Merge it into $newLabel and sync both ways.',
          onTap: onKeep,
        ),
        _ChoiceButton(
          busy: busy,
          primary: false,
          title: 'Start fresh',
          subtitle:
              'Clear this device and load $newLabel’s cloud data. The other account keeps its own data in its cloud.',
          onTap: onFresh,
        ),
      ],
    );
  }
}

// ---------------- guest with existing data ----------------

class _GuestDataView extends StatelessWidget {
  const _GuestDataView({
    required this.busy,
    required this.ownerLabel,
    required this.onKeep,
    required this.onFresh,
  });

  final bool busy;
  final String ownerLabel;
  final VoidCallback onKeep;
  final VoidCallback onFresh;

  @override
  Widget build(BuildContext context) {
    return _GateShell(
      children: [
        const Spacer(),
        Container(
          width: 64,
          height: 64,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: _accent.withValues(alpha: 0.18),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.person_outline_rounded,
            color: _accent,
            size: 30,
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'You already have data here',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'This device holds data from $ownerLabel.\n\nGuest mode keeps everything on this device only — nothing syncs to the cloud.',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 14,
            height: 1.45,
          ),
        ),
        const Spacer(),
        if (busy)
          const Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: Center(
              child: SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: _accent,
                ),
              ),
            ),
          ),
        _ChoiceButton(
          busy: busy,
          primary: true,
          title: 'Keep viewing this data',
          subtitle: 'Continue offline with the existing transactions.',
          onTap: onKeep,
        ),
        _ChoiceButton(
          busy: busy,
          primary: false,
          title: 'Start a fresh guest session',
          subtitle:
              'Clears this device. That account’s data stays safe in its cloud — sign back in to restore it.',
          onTap: onFresh,
        ),
      ],
    );
  }
}

// ---------------- welcome ----------------

class _WelcomeView extends StatelessWidget {
  const _WelcomeView({
    required this.returning,
    required this.name,
    required this.syncResult,
    required this.onContinue,
  });

  final bool returning;
  final String name;
  final String? syncResult;
  final VoidCallback onContinue;

  String get _firstName {
    final t = name.trim();
    if (t.isEmpty) return 'there';
    return t.split(' ').first;
  }

  String get _syncLine {
    switch (syncResult) {
      case 'merged':
        return 'Your device data and cloud data were merged safely.';
      case 'pulled':
        return 'Restored everything from your cloud backup.';
      case 'pushed':
        return 'Your data is now backed up to the cloud.';
      case 'error':
        return 'Signed in, but sync failed. We’ll retry automatically.';
      default:
        return 'You’re all set. Your data stays synced from now on.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return _GateShell(
      children: [
        const Spacer(flex: 2),
        Center(
          child: Container(
            width: 88,
            height: 88,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [_accent, Color(0xFF00897B)],
              ),
              boxShadow: [
                BoxShadow(
                  color: _accent.withValues(alpha: 0.45),
                  blurRadius: 28,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: const Icon(
              Icons.check_rounded,
              color: Colors.white,
              size: 44,
            ),
          ),
        ),
        const SizedBox(height: 28),
        Text(
          returning ? 'Welcome back,' : 'Welcome,',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _firstName,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 30,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
          ),
          child: Row(
            children: [
              const Icon(Icons.cloud_done_rounded, color: _accent, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _syncLine,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
        ),
        const Spacer(flex: 3),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Colors.white,
            foregroundColor: _bgBottom,
            padding: const EdgeInsets.symmetric(vertical: 18),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 0,
          ),
          onPressed: onContinue,
          child: const Text(
            'Continue',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}
