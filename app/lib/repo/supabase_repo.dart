import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models.dart';
import 'repo.dart';

/// Real version: Supabase login, database with row level security, file storage.
class SupabaseRepo implements Repo {
  @override
  bool get isDemo => false;
  SupabaseClient get _db => Supabase.instance.client;
  Profile? _me;
  Company? _co;

  String get _uid {
    final u = _db.auth.currentUser;
    if (u == null) throw AuthFailure('Silakan masuk lagi.');
    return u.id;
  }

  Future<Profile> _loadProfile() async {
    var row = await _db.from('profiles').select().eq('id', _uid).maybeSingle();
    if (row == null) {
      try {
        await _db.rpc('claim_invite');
      } on PostgrestException {
        await _db.auth.signOut();
        throw AuthFailure('Email ini belum diundang. Hubungi HR perusahaan Anda.');
      }
      row = await _db.from('profiles').select().eq('id', _uid).single();
    }
    return _me = Profile.fromJson(row);
  }

  // ---- sign in ----
  @override
  Future<Profile?> restore() async {
    if (_db.auth.currentSession == null) return null;
    try {
      return await _loadProfile();
    } catch (_) {
      return null;
    }
  }

  @override
  Future<Profile> signIn(String email, String password) async {
    try {
      await _db.auth.signInWithPassword(email: email.trim().toLowerCase(), password: password);
    } on AuthException catch (e) {
      if (e.message.toLowerCase().contains('invalid')) throw AuthFailure('Email atau kata sandi salah. Jika ini login pertama, pilih "Aktifkan akun".');
      throw AuthFailure(e.message);
    }
    return _loadProfile();
  }

  @override
  Future<Profile> activate(String email, String password) async {
    final res = await _db.functions.invoke('activate', body: {'email': email.trim().toLowerCase(), 'password': password});
    final data = res.data;
    if (data is Map && data['error'] != null) throw AuthFailure(data['error'].toString());
    return signIn(email, password);
  }

  @override
  Future<void> sendReset(String email) async {
    try {
      await _db.auth.resetPasswordForEmail(email.trim().toLowerCase(), redirectTo: Uri.base.origin);
    } on AuthException catch (e) {
      throw AuthFailure(e.message);
    }
  }

  @override
  Future<void> changePassword(String newPassword) async {
    try {
      await _db.auth.updateUser(UserAttributes(password: newPassword));
    } on AuthException catch (e) {
      throw AuthFailure(e.message);
    }
  }

  @override
  Future<void> signOut() async {
    _me = null;
    _co = null;
    await _db.auth.signOut();
  }

  // ---- employee ----
  @override
  Future<Company> company() async => _co ??= Company.fromJson(await _db.from('companies').select().single());

  Future<List<LearnerCourse>> _learnerCourses({String? onlyId}) async {
    var q = _db.from('courses').select('*, steps(*)');
    if (onlyId != null) q = q.eq('id', onlyId);
    final courses = (await q).map((r) => Course.fromJson(r)).toList();
    final uid = _uid;
    final co = await company();
    final asg = await _db.from('assignments').select('course_id, due_at').eq('user_id', uid);
    final done = await _db.from('step_progress').select('step_id').eq('user_id', uid);
    final att = await _db.from('attempts').select('course_id, test_kind, score, passed, created_at').eq('user_id', uid);
    final due = {for (final a in asg) a['course_id'] as String: a['due_at'] == null ? null : DateTime.parse(a['due_at'])};
    final doneSet = {for (final d in done) d['step_id'] as String};
    return [
      for (final c in courses)
        if (c.published || onlyId != null)
          LearnerCourse(
            course: c,
            dueAt: due[c.id],
            assigned: due.containsKey(c.id),
            doneSteps: doneSet,
            attempts: [
              for (final a in att)
                if (a['course_id'] == c.id) Attempt(a['test_kind'], a['score'], a['passed'], DateTime.parse(a['created_at']))
            ],
            passMark: c.passMark ?? co.passMark,
          )
    ];
  }

  @override
  Future<List<LearnerCourse>> myCourses() => _learnerCourses();

  @override
  Future<LearnerCourse> course(String id) async {
    final l = await _learnerCourses(onlyId: id);
    if (l.isEmpty) throw AuthFailure('Kelas tidak ditemukan.');
    return l.first;
  }

  @override
  Future<List<Question>> questions(String courseId, String kind) async {
    final rows = await _db.from('questions').select('id, body, options').eq('course_id', courseId).eq('test_kind', kind).order('position');
    return [for (final r in rows) Question(id: r['id'], body: r['body'], options: List<String>.from(r['options']))];
  }

  @override
  Future<int> completeStep(String stepId) async => (await _db.rpc('complete_step', params: {'p_step': stepId})) as int;

  @override
  Future<TestResult> submitTest(String courseId, String kind, List<int?> answers) async {
    try {
      final r = await _db.rpc('submit_test', params: {'p_course': courseId, 'p_kind': kind, 'p_answers': answers});
      return TestResult.fromJson(Map<String, dynamic>.from(r));
    } on PostgrestException catch (e) {
      throw AuthFailure(e.message.contains('no attempts') ? 'Kesempatan sudah habis.' : e.message);
    }
  }

  @override
  Future<void> submitSurvey(String courseId, int rating, String? comment) async {
    await _db.from('surveys').upsert({'user_id': _uid, 'course_id': courseId, 'rating': rating, 'comment': comment});
  }

  @override
  Future<List<PointsEntry>> pointsHistory() async {
    final rows = await _db.from('points_ledger').select('amount, reason, created_at').eq('user_id', _uid).order('created_at', ascending: false);
    return [for (final r in rows) PointsEntry(r['amount'], r['reason'], DateTime.parse(r['created_at']))];
  }

  @override
  Future<List<LeaderRow>> leaderboard() async {
    final rows = await _db.rpc('leaderboard');
    return [for (final r in rows) LeaderRow((r['rank'] as num).toInt(), r['name'], r['dept'], (r['points'] as num).toInt(), r['is_me'] == true)];
  }

  @override
  Future<List<Certificate>> certificates() async {
    final rows = await _db.from('certificates').select('id, course_id, number, score, issued_at, courses(title)').eq('user_id', _uid).order('issued_at', ascending: false);
    final me = _me ?? await _loadProfile();
    return [
      for (final r in rows)
        Certificate(id: r['id'], courseId: r['course_id'], courseTitle: r['courses']['title'], number: r['number'], score: r['score'],
            issuedAt: DateTime.parse(r['issued_at']), ownerName: me.fullName)
    ];
  }

  @override
  Future<List<Notif>> notifications() async {
    final rows = await _db.from('notifications').select().eq('user_id', _uid).order('created_at', ascending: false).limit(50);
    return [
      for (final r in rows)
        Notif(id: r['id'], title: r['title'], body: r['body'], link: r['link'], at: DateTime.parse(r['created_at']), read: r['read_at'] != null)
    ];
  }

  @override
  Future<void> markRead(String? id) async {
    var q = _db.from('notifications').update({'read_at': DateTime.now().toUtc().toIso8601String()}).eq('user_id', _uid).isFilter('read_at', null);
    if (id != null) q = q.eq('id', id);
    await q;
  }

  @override
  Future<Profile> updateMyProfile({String? phone, bool? hideOnLeaderboard, bool? consent}) async {
    await _db.rpc('update_my_profile', params: {'p_phone': phone, 'p_hide': hideOnLeaderboard, 'p_consent': consent ?? false});
    return _loadProfile();
  }

  // ---- HR admin ----
  Future<({List<Map<String, dynamic>> invites, Map<String, Profile> profiles, List<Course> courses, List<Map<String, dynamic>> asg, Map<String, Set<String>> done, List<Map<String, dynamic>> att})> _adminData() async {
    final res = await Future.wait([
      _db.from('invites').select(),
      _db.from('profiles').select(),
      _db.from('courses').select('*, steps(*)'),
      _db.from('assignments').select('course_id, user_id, due_at'),
      _db.from('step_progress').select('user_id, step_id'),
      _db.from('attempts').select('user_id, course_id, test_kind, score, passed, created_at'),
    ]);
    final done = <String, Set<String>>{};
    for (final r in res[4]) {
      (done[r['user_id'] as String] ??= {}).add(r['step_id']);
    }
    return (
      invites: List<Map<String, dynamic>>.from(res[0]),
      profiles: {for (final r in res[1]) r['id'] as String: Profile.fromJson(r)},
      courses: [for (final r in res[2]) Course.fromJson(r)],
      asg: List<Map<String, dynamic>>.from(res[3]),
      done: done,
      att: List<Map<String, dynamic>>.from(res[5]),
    );
  }

  LearnerCourse _lcFor(Course c, String uid, DateTime? due, Map<String, Set<String>> done, List<Map<String, dynamic>> att, int mark) => LearnerCourse(
        course: c,
        dueAt: due,
        assigned: true,
        doneSteps: done[uid] ?? const {},
        attempts: [
          for (final a in att)
            if (a['user_id'] == uid && a['course_id'] == c.id) Attempt(a['test_kind'], a['score'], a['passed'], DateTime.parse(a['created_at']))
        ],
        passMark: c.passMark ?? mark,
      );

  @override
  Future<List<Person>> people() async {
    final d = await _adminData();
    final co = await company();
    final byId = {for (final c in d.courses) c.id: c};
    final now = DateTime.now();
    return d.invites.map((inv) {
      final uid = inv['user_id'] as String?;
      var assigned = 0, done = 0, late = 0;
      if (uid != null) {
        for (final a in d.asg.where((a) => a['user_id'] == uid)) {
          final c = byId[a['course_id']];
          if (c == null) continue;
          assigned++;
          final due = a['due_at'] == null ? null : DateTime.parse(a['due_at']);
          final lc = _lcFor(c, uid, due, d.done, d.att, co.passMark);
          if (lc.completed) {
            done++;
          } else if (due != null && due.isBefore(now)) {
            late++;
          }
        }
      }
      return Person(userId: uid, email: inv['email'], fullName: inv['full_name'], role: inv['role'], status: inv['status'], dept: inv['dept'],
          title: inv['title'], assigned: assigned, done: done, late: late);
    }).toList()
      ..sort((a, b) => a.fullName.compareTo(b.fullName));
  }

  @override
  Future<int> invite(List<InviteInput> people) async {
    final co = await company();
    final rows = [
      for (final p in people) {'company_id': co.id, 'email': p.email.trim().toLowerCase(), 'full_name': p.fullName, 'dept': p.dept, 'title': p.title}
    ];
    final res = await _db.from('invites').upsert(rows, onConflict: 'company_id,email', ignoreDuplicates: true).select('id');
    return res.length;
  }

  @override
  Future<List<Course>> allCourses() async => [for (final r in await _db.from('courses').select('*, steps(*)').order('created_at')) Course.fromJson(r)];

  @override
  Future<Course> saveCourse(Course c) async {
    final co = await company();
    final row = c.toRow()..['company_id'] = co.id;
    if (c.id.isEmpty) row.remove('id');
    final saved = await _db.from('courses').upsert(row).select().single();
    final id = saved['id'] as String;
    final keep = [for (final s in c.steps) if (s.id.isNotEmpty) s.id];
    var del = _db.from('steps').delete().eq('course_id', id);
    if (keep.isNotEmpty) del = del.not('id', 'in', '(${keep.join(',')})');
    await del;
    for (var i = 0; i < c.steps.length; i++) {
      final s = c.steps[i]
        ..courseId = id
        ..position = i;
      final r = s.toJson();
      if (s.id.isEmpty) r.remove('id');
      final out = await _db.from('steps').upsert(r).select('id').single();
      s.id = out['id'];
    }
    c.id = id;
    return c;
  }

  @override
  Future<void> deleteCourse(String id) async => _db.from('courses').delete().eq('id', id);

  @override
  Future<List<Question>> adminQuestions(String courseId, String kind) async {
    final rows = await _db.from('questions').select('id, body, options, question_keys(answer)').eq('course_id', courseId).eq('test_kind', kind).order('position');
    return [
      for (final r in rows)
        Question(id: r['id'], body: r['body'], options: List<String>.from(r['options']), answer: (r['question_keys'] as Map?)?['answer'] ?? 0)
    ];
  }

  @override
  Future<void> saveQuestions(String courseId, String kind, List<Question> qs) async {
    await _db.from('questions').delete().eq('course_id', courseId).eq('test_kind', kind);
    if (qs.isEmpty) return;
    final rows = await _db
        .from('questions')
        .insert([
          for (var i = 0; i < qs.length; i++) {'course_id': courseId, 'test_kind': kind, 'position': i, 'body': qs[i].body, 'options': qs[i].options}
        ])
        .select('id, position');
    final byPos = {for (final r in rows) r['position'] as int: r['id'] as String};
    await _db.from('question_keys').insert([
      for (var i = 0; i < qs.length; i++) {'question_id': byPos[i], 'answer': qs[i].answer ?? 0}
    ]);
  }

  @override
  Future<String> uploadMedia(Uint8List bytes, String filename) async {
    final co = await company();
    final safe = filename.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final path = '${co.id}/${DateTime.now().millisecondsSinceEpoch}_$safe';
    await _db.storage.from('course-media').uploadBinary(path, bytes,
        fileOptions: FileOptions(contentType: safe.toLowerCase().endsWith('.pdf') ? 'application/pdf' : 'video/mp4'));
    return _db.storage.from('course-media').getPublicUrl(path);
  }

  @override
  Future<int> assign(String courseId, List<String> userIds, DateTime? dueAt) async =>
      (await _db.rpc('assign_course', params: {'p_course': courseId, 'p_users': userIds, 'p_due': dueAt?.toUtc().toIso8601String()})) as int;

  @override
  Future<Map<String, DateTime?>> assignmentsFor(String courseId) async {
    final rows = await _db.from('assignments').select('user_id, due_at').eq('course_id', courseId);
    return {for (final r in rows) r['user_id'] as String: r['due_at'] == null ? null : DateTime.parse(r['due_at'])};
  }

  @override
  Future<List<ReportRow>> report() async {
    final d = await _adminData();
    final co = await company();
    final byId = {for (final c in d.courses) c.id: c};
    final rows = <ReportRow>[];
    for (final a in d.asg) {
      final c = byId[a['course_id']];
      final p = d.profiles[a['user_id']];
      if (c == null || p == null) continue;
      final due = a['due_at'] == null ? null : DateTime.parse(a['due_at']);
      final lc = _lcFor(c, p.id, due, d.done, d.att, co.passMark);
      rows.add(ReportRow(person: p.fullName, email: p.email, dept: p.dept ?? '-', course: c.title, dueAt: due, stepsDone: lc.stepsDone,
          stepsTotal: lc.stepsTotal, bestScore: lc.bestPost, completed: lc.completed));
    }
    return rows;
  }

  @override
  Future<Company> updateCompany(Company c) async {
    final r = await _db
        .from('companies')
        .update({'name': c.name, 'mark': c.mark, 'pass_mark': c.passMark, 'hr_email': c.hrEmail, 'hr_whatsapp': c.hrWhatsapp, 'logo_url': c.logoUrl})
        .eq('id', c.id)
        .select()
        .single();
    return _co = Company.fromJson(r);
  }
}
