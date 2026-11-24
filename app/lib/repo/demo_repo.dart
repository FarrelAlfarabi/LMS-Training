import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import '../models.dart';
import 'repo.dart';

/// In-memory version with the same rules as the database. Used when no Supabase keys are set.
/// Data resets when the page reloads.
class DemoRepo implements Repo {
  @override
  bool get isDemo => true;
  static const demoPassword = 'BigmaDemo2026!';

  late Company _company;
  final _profiles = <String, Profile>{};
  final _invites = <String, Map<String, dynamic>>{}; // email -> person json
  final _passwords = <String, String>{};
  final _courses = <String, Course>{};
  final _questions = <String, List<Question>>{}; // courseId/kind
  final _assign = <String, Map<String, DateTime?>>{}; // courseId -> userId -> due
  final _done = <String, Set<String>>{}; // userId -> stepIds
  final _attempts = <String, List<(String course, Attempt a)>>{};
  final _ledger = <String, List<(String ref, PointsEntry e)>>{};
  final _certs = <String, List<Certificate>>{};
  final _notifs = <String, List<Notif>>{};
  final _surveys = <String, int>{};
  String? _me;
  bool _loaded = false;
  int _n = 0;
  String _id() => 'demo-${DateTime.now().microsecondsSinceEpoch}-${_n++}';

  Future<void> _load() async {
    if (_loaded) return;
    final j = jsonDecode(await rootBundle.loadString('assets/seed.json')) as Map<String, dynamic>;
    _company = Company.fromJson(j['company']);
    for (final p in j['people']) {
      _invites[p['email']] = Map<String, dynamic>.from(p);
      if (p['status'] == 'active') {
        _profiles[p['id']] = Profile(
            id: p['id'], companyId: _company.id, fullName: p['full_name'], email: p['email'], dept: p['dept'], title: p['title'],
            phone: p['phone'], role: p['role'], consentAt: DateTime.utc(2026, 10, 6), hideOnLeaderboard: p['hide'] ?? false);
        _passwords[p['email']] = demoPassword;
      }
    }
    for (final c in j['courses']) {
      final course = Course.fromJson(Map<String, dynamic>.from(c));
      _courses[course.id] = course;
      for (final kind in ['pre', 'post']) {
        _questions['${course.id}/$kind'] = [
          for (final q in c[kind]) Question(id: q['id'], body: q['body'], options: List<String>.from(q['options']), answer: q['answer'])
        ];
      }
    }
    for (final a in j['assignments']) {
      (_assign[a['course_id']] ??= {})[a['user_id']] = DateTime.parse(a['due_at']);
    }
    for (final r in j['progress']) {
      (_done[r['user_id']] ??= {}).add(r['step_id']);
    }
    for (final r in j['attempts']) {
      (_attempts[r['user_id']] ??= []).add((r['course_id'], Attempt(r['test_kind'], r['score'], r['passed'], DateTime.parse(r['created_at']))));
    }
    for (final r in j['ledger']) {
      (_ledger[r['user_id']] ??= []).add((r['ref'], PointsEntry(r['amount'], r['reason'], DateTime.parse(r['created_at']))));
    }
    for (final r in j['certificates']) {
      (_certs[r['user_id']] ??= []).add(Certificate(
          id: r['id'], courseId: r['course_id'], courseTitle: _courses[r['course_id']]!.title, number: r['number'], score: r['score'],
          issuedAt: DateTime.parse(r['issued_at']), ownerName: _profiles[r['user_id']]!.fullName));
    }
    for (final r in j['notifications']) {
      (_notifs[r['user_id']] ??= []).add(Notif(
          id: r['id'], title: r['title'], body: r['body'], link: r['link'], at: DateTime.parse(r['created_at']), read: r['read_at'] != null));
    }
    _loaded = true;
  }

  Profile get _p {
    final p = _profiles[_me];
    if (p == null) throw AuthFailure('Silakan masuk lagi.');
    return p;
  }

  void _requireAdmin() {
    if (!_p.isAdmin) throw AuthFailure('Hanya admin HR.');
  }

  // ---- sign in ----
  @override
  Future<Profile?> restore() async {
    await _load();
    return _me == null ? null : _profiles[_me];
  }

  @override
  Future<Profile> signIn(String email, String password) async {
    await _load();
    final e = email.trim().toLowerCase();
    if (_passwords[e] == null) {
      if (_invites[e] != null) throw AuthFailure('Akun ini belum diaktifkan. Pilih "Aktifkan akun" untuk membuat kata sandi.');
      throw AuthFailure('Email atau kata sandi salah.');
    }
    if (_passwords[e] != password) throw AuthFailure('Email atau kata sandi salah.');
    _me = _profiles.values.firstWhere((p) => p.email == e).id;
    return _p;
  }

  @override
  Future<Profile> activate(String email, String password) async {
    await _load();
    final e = email.trim().toLowerCase();
    final inv = _invites[e];
    if (inv == null) throw AuthFailure('Email ini belum diundang. Hubungi HR perusahaan Anda.');
    if (_passwords[e] != null) throw AuthFailure('Akun ini sudah aktif. Silakan masuk.');
    final id = inv['id'] as String? ?? _id();
    _profiles[id] = Profile(id: id, companyId: _company.id, fullName: inv['full_name'], email: e, dept: inv['dept'], title: inv['title'], role: inv['role'] ?? 'learner');
    inv['status'] = 'active';
    inv['id'] = id;
    _passwords[e] = password;
    _me = id;
    return _p;
  }

  @override
  Future<void> sendReset(String email) async {}

  @override
  Future<void> changePassword(String newPassword) async {
    _passwords[_p.email] = newPassword;
  }

  @override
  Future<void> signOut() async => _me = null;

  // ---- employee ----
  @override
  Future<Company> company() async {
    await _load();
    return _company;
  }

  LearnerCourse _lc(Course c, String uid) => LearnerCourse(
        course: c,
        dueAt: _assign[c.id]?[uid],
        assigned: _assign[c.id]?.containsKey(uid) ?? false,
        doneSteps: {...?_done[uid]},
        attempts: [for (final (cid, a) in _attempts[uid] ?? const <(String, Attempt)>[]) if (cid == c.id) a],
        passMark: c.passMark ?? _company.passMark,
      );

  @override
  Future<List<LearnerCourse>> myCourses() async {
    final uid = _p.id;
    return [for (final c in _courses.values) if (c.published) _lc(c, uid)];
  }

  @override
  Future<LearnerCourse> course(String id) async {
    final c = _courses[id];
    if (c == null || (!c.published && !_p.isAdmin)) throw AuthFailure('Kelas tidak ditemukan.');
    return _lc(c, _p.id);
  }

  @override
  Future<List<Question>> questions(String courseId, String kind) async =>
      [for (final q in _questions['$courseId/$kind'] ?? const <Question>[]) Question(id: q.id, body: q.body, options: q.options)];

  int _award(String uid, int amount, String reason, String ref) {
    final l = _ledger[uid] ??= [];
    if (l.any((e) => e.$1 == ref)) return 0;
    l.add((ref, PointsEntry(amount, reason, DateTime.now())));
    return amount;
  }

  @override
  Future<int> completeStep(String stepId) async {
    final s = _courses.values.expand((c) => c.steps).firstWhere((s) => s.id == stepId);
    if (s.isTest) throw StateError('tests go through submitTest');
    (_done[_p.id] ??= {}).add(stepId);
    return _award(_p.id, s.points, 'Menyelesaikan ${s.title}', 'step:$stepId');
  }

  @override
  Future<TestResult> submitTest(String courseId, String kind, List<int?> answers) async {
    final c = _courses[courseId]!;
    final uid = _p.id;
    final s = c.stepOf(kind)!;
    final mark = c.passMark ?? _company.passMark;
    final mine = [for (final (cid, a) in _attempts[uid] ?? const <(String, Attempt)>[]) if (cid == courseId && a.kind == kind) a];
    if (kind == 'post' && mine.length >= c.maxAttempts) throw AuthFailure('Kesempatan sudah habis.');
    if (kind == 'pre' && mine.isNotEmpty) throw AuthFailure('Pre test sudah dikerjakan.');
    final qs = _questions['$courseId/$kind']!;
    var correct = 0;
    for (var i = 0; i < qs.length; i++) {
      if (i < answers.length && answers[i] == qs[i].answer) correct++;
    }
    final score = qs.isEmpty ? 0 : (correct * 100 / qs.length).round();
    final passed = kind == 'post' ? score >= mark : null;
    (_attempts[uid] ??= []).add((courseId, Attempt(kind, score, passed, DateTime.now())));
    var earned = 0;
    if (kind == 'pre' || passed == true) {
      (_done[uid] ??= {}).add(s.id);
      earned = _award(uid, s.points, kind == 'pre' ? 'Mengerjakan pre test ${c.title}' : 'Lulus post test ${c.title}', 'test:${s.id}');
    }
    if (passed == true) {
      final list = _certs[uid] ??= [];
      if (!list.any((x) => x.courseId == courseId)) {
        final n = _certs.values.fold<int>(0, (a, l) => a + l.length) + 142;
        list.add(Certificate(id: _id(), courseId: courseId, courseTitle: c.title, number: '${_company.mark}-${DateTime.now().year}-${n.toString().padLeft(4, '0')}',
            score: score, issuedAt: DateTime.now(), ownerName: _p.fullName));
        (_notifs[uid] ??= []).add(Notif(id: _id(), title: 'Sertifikat terbit', body: c.title, link: '/certificates', at: DateTime.now()));
      }
    }
    final used = mine.length + 1;
    final reveal = kind == 'post' && (passed == true || used >= c.maxAttempts);
    return TestResult(
        score: score, correct: correct, total: qs.length, passMark: mark, points: earned, attemptsUsed: used, maxAttempts: c.maxAttempts,
        passed: passed, chosen: [for (var i = 0; i < qs.length; i++) i < answers.length ? answers[i] : null],
        answers: reveal ? [for (final q in qs) q.answer!] : null);
  }

  @override
  Future<void> submitSurvey(String courseId, int rating, String? comment) async => _surveys['${_p.id}/$courseId'] = rating;

  @override
  Future<List<PointsEntry>> pointsHistory() async => [for (final e in _ledger[_p.id] ?? const <(String, PointsEntry)>[]) e.$2]..sort((a, b) => b.at.compareTo(a.at));

  @override
  Future<List<LeaderRow>> leaderboard() async {
    final rows = _profiles.values.where((p) => !p.isAdmin).map((p) {
      final pts = (_ledger[p.id] ?? const <(String, PointsEntry)>[]).fold<int>(0, (a, e) => a + e.$2.amount);
      final name = p.hideOnLeaderboard && p.id != _me ? 'Karyawan ${(p.dept ?? 'X')[0]}.' : p.fullName;
      return (p, name, pts);
    }).toList()
      ..sort((a, b) => b.$3 != a.$3 ? b.$3.compareTo(a.$3) : a.$2.compareTo(b.$2));
    final out = <LeaderRow>[];
    for (var i = 0; i < rows.length; i++) {
      final rank = i > 0 && rows[i].$3 == rows[i - 1].$3 ? out.last.rank : i + 1;
      out.add(LeaderRow(rank, rows[i].$2, rows[i].$1.dept, rows[i].$3, rows[i].$1.id == _me));
    }
    return out;
  }

  @override
  Future<List<Certificate>> certificates() async => [...?_certs[_p.id]]..sort((a, b) => b.issuedAt.compareTo(a.issuedAt));

  @override
  Future<List<Notif>> notifications() async => [...?_notifs[_p.id]]..sort((a, b) => b.at.compareTo(a.at));

  @override
  Future<void> markRead(String? id) async {
    for (final n in _notifs[_p.id] ?? const <Notif>[]) {
      if (id == null || n.id == id) n.read = true;
    }
  }

  @override
  Future<Profile> updateMyProfile({String? phone, bool? hideOnLeaderboard, bool? consent}) async {
    final p = _p.copyWith(phone: phone, hide: hideOnLeaderboard, consentAt: consent == true ? (_p.consentAt ?? DateTime.now()) : null);
    _profiles[p.id] = p;
    return p;
  }

  // ---- HR admin ----
  @override
  Future<List<Person>> people() async {
    _requireAdmin();
    final now = DateTime.now();
    return _invites.values.map((inv) {
      final uid = inv['status'] == 'active' ? inv['id'] as String? : null;
      var assigned = 0, done = 0, late = 0;
      for (final e in _assign.entries) {
        final due = e.value[uid ?? inv['id']];
        if (!e.value.containsKey(uid ?? inv['id'])) continue;
        assigned++;
        final lc = uid == null ? null : _lc(_courses[e.key]!, uid);
        if (lc?.completed == true) {
          done++;
        } else if (due != null && due.isBefore(now)) {
          late++;
        }
      }
      return Person(userId: uid, email: inv['email'], fullName: inv['full_name'], role: inv['role'] ?? 'learner', status: inv['status'],
          dept: inv['dept'], title: inv['title'], assigned: assigned, done: done, late: late);
    }).toList()
      ..sort((a, b) => a.fullName.compareTo(b.fullName));
  }

  @override
  Future<int> invite(List<InviteInput> people) async {
    _requireAdmin();
    var n = 0;
    for (final p in people) {
      final e = p.email.trim().toLowerCase();
      if (_invites.containsKey(e)) continue;
      _invites[e] = {'id': _id(), 'email': e, 'full_name': p.fullName, 'dept': p.dept, 'title': p.title, 'role': 'learner', 'status': 'sent'};
      n++;
    }
    return n;
  }

  @override
  Future<List<Course>> allCourses() async {
    _requireAdmin();
    return _courses.values.toList();
  }

  @override
  Future<Course> saveCourse(Course c) async {
    _requireAdmin();
    if (c.id.isEmpty) c.id = _id();
    for (var i = 0; i < c.steps.length; i++) {
      final s = c.steps[i];
      if (s.id.isEmpty) s.id = _id();
      s.courseId = c.id;
      s.position = i;
    }
    _courses[c.id] = c;
    return c;
  }

  @override
  Future<void> deleteCourse(String id) async {
    _requireAdmin();
    _courses.remove(id);
    _assign.remove(id);
  }

  @override
  Future<List<Question>> adminQuestions(String courseId, String kind) async {
    _requireAdmin();
    return [for (final q in _questions['$courseId/$kind'] ?? const <Question>[]) Question(id: q.id, body: q.body, options: [...q.options], answer: q.answer)];
  }

  @override
  Future<void> saveQuestions(String courseId, String kind, List<Question> qs) async {
    _requireAdmin();
    _questions['$courseId/$kind'] = [for (final q in qs) Question(id: q.id.isEmpty ? _id() : q.id, body: q.body, options: [...q.options], answer: q.answer ?? 0)];
  }

  @override
  Future<String> uploadMedia(Uint8List bytes, String filename) async {
    _requireAdmin();
    final mime = filename.toLowerCase().endsWith('.pdf') ? 'application/pdf' : 'video/mp4';
    return Uri.dataFromBytes(bytes, mimeType: mime).toString();
  }

  @override
  Future<int> assign(String courseId, List<String> userIds, DateTime? dueAt) async {
    _requireAdmin();
    final m = _assign[courseId] ??= {};
    final c = _courses[courseId]!;
    for (final u in userIds) {
      m[u] = dueAt;
      (_notifs[u] ??= []).add(Notif(id: _id(), title: 'Kelas baru ditugaskan', body: c.title, link: '/class/$courseId', at: DateTime.now()));
    }
    return userIds.length;
  }

  @override
  Future<Map<String, DateTime?>> assignmentsFor(String courseId) async => {...?_assign[courseId]};

  @override
  Future<List<ReportRow>> report() async {
    _requireAdmin();
    final rows = <ReportRow>[];
    for (final e in _assign.entries) {
      final c = _courses[e.key];
      if (c == null) continue;
      for (final u in e.value.entries) {
        final p = _profiles[u.key];
        if (p == null) continue;
        final lc = _lc(c, p.id);
        rows.add(ReportRow(person: p.fullName, email: p.email, dept: p.dept ?? '-', course: c.title, dueAt: u.value,
            stepsDone: lc.stepsDone, stepsTotal: lc.stepsTotal, bestScore: lc.bestPost, completed: lc.completed));
      }
    }
    return rows;
  }

  @override
  Future<Company> updateCompany(Company c) async {
    _requireAdmin();
    return _company = c;
  }
}
