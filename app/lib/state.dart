import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'models.dart';
import 'repo/repo.dart';

/// Who is signed in, plus the small numbers shown in the frame (points, unread).
class AppState extends ChangeNotifier {
  final Repo repo;
  AppState(this.repo);

  Profile? profile;
  Company? company;
  int points = 0;
  int unread = 0;
  bool ready = false;

  bool get signedIn => profile != null;
  bool get needsConsent => profile != null && profile!.consentAt == null;

  Future<void> boot() async {
    profile = await repo.restore();
    if (profile != null) await refresh();
    ready = true;
    notifyListeners();
  }

  Future<void> onSignedIn(Profile p) async {
    profile = p;
    await refresh();
  }

  Future<void> refresh() async {
    if (profile == null) return;
    company = await repo.company();
    if (!profile!.isAdmin) {
      final h = await repo.pointsHistory();
      points = h.fold(0, (a, e) => a + e.amount);
      unread = (await repo.notifications()).where((n) => !n.read).length;
    }
    notifyListeners();
  }

  void setProfile(Profile p) {
    profile = p;
    notifyListeners();
  }

  void setCompany(Company c) {
    company = c;
    notifyListeners();
  }

  Future<void> signOut() async {
    await repo.signOut();
    profile = null;
    company = null;
    points = 0;
    unread = 0;
    notifyListeners();
  }
}

/// Lets any widget reach the app state.
class Scope extends InheritedNotifier<AppState> {
  const Scope({super.key, required AppState state, required super.child}) : super(notifier: state);
  static AppState of(BuildContext c) => c.dependOnInheritedWidgetOfExactType<Scope>()!.notifier!;
  static AppState read(BuildContext c) => c.getInheritedWidgetOfExactType<Scope>()!.notifier!;
}

final _d = DateFormat('d MMM yyyy', 'id');
final _dt = DateFormat('d MMM yyyy, HH.mm', 'id');
final _dw = DateFormat('EEE, d MMM', 'id');
String fmtDate(DateTime? d) => d == null ? '-' : _d.format(d.toLocal());
String fmtDateTime(DateTime? d) => d == null ? '-' : _dt.format(d.toLocal());
String fmtDue(DateTime? d) => d == null ? 'Tanpa tenggat' : _dw.format(d.toLocal());
String fmtNum(int n) => NumberFormat.decimalPattern('id').format(n);

String fmtAgo(DateTime d) {
  final now = DateTime.now();
  final l = d.toLocal();
  final days = DateTime(now.year, now.month, now.day).difference(DateTime(l.year, l.month, l.day)).inDays;
  final t = DateFormat('HH.mm').format(l);
  if (days == 0) return 'Hari ini, $t';
  if (days == 1) return 'Kemarin, $t';
  return fmtDate(d);
}

/// "3 hari lagi", "besok", "lewat 2 hari"
String dueHint(DateTime? d) {
  if (d == null) return '';
  final now = DateTime.now();
  final l = d.toLocal();
  final days = DateTime(l.year, l.month, l.day).difference(DateTime(now.year, now.month, now.day)).inDays;
  if (days < 0) return 'lewat ${-days} hari';
  if (days == 0) return 'hari ini';
  if (days == 1) return 'besok';
  return '$days hari lagi';
}

void toast(BuildContext c, String msg) {
  ScaffoldMessenger.of(c)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg)));
}

String errText(Object e) => e is AuthFailure ? e.message : 'Ada masalah: $e';
