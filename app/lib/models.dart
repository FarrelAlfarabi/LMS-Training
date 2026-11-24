class Company {
  final String id, name, mark;
  final String? logoUrl, hrEmail, hrWhatsapp;
  final int passMark;
  Company({required this.id, required this.name, required this.mark, this.logoUrl, this.hrEmail, this.hrWhatsapp, this.passMark = 70});
  factory Company.fromJson(Map<String, dynamic> j) => Company(
        id: j['id'], name: j['name'], mark: j['mark'] ?? 'CO', logoUrl: j['logo_url'],
        hrEmail: j['hr_email'], hrWhatsapp: j['hr_whatsapp'], passMark: j['pass_mark'] ?? 70);
  Company copyWith({String? name, String? mark, String? hrEmail, String? hrWhatsapp, int? passMark, String? logoUrl}) => Company(
      id: id, name: name ?? this.name, mark: mark ?? this.mark, logoUrl: logoUrl ?? this.logoUrl,
      hrEmail: hrEmail ?? this.hrEmail, hrWhatsapp: hrWhatsapp ?? this.hrWhatsapp, passMark: passMark ?? this.passMark);
}

class Profile {
  final String id, companyId, fullName, email, role;
  final String? dept, title, phone;
  final DateTime? consentAt;
  final bool hideOnLeaderboard;
  Profile({required this.id, required this.companyId, required this.fullName, required this.email, this.role = 'learner',
      this.dept, this.title, this.phone, this.consentAt, this.hideOnLeaderboard = false});
  bool get isAdmin => role == 'admin';
  String get firstName => fullName.split(' ').first;
  String get initials {
    final p = fullName.trim().split(RegExp(r'\s+'));
    return (p.first[0] + (p.length > 1 ? p.last[0] : '')).toUpperCase();
  }

  factory Profile.fromJson(Map<String, dynamic> j) => Profile(
        id: j['id'], companyId: j['company_id'], fullName: j['full_name'], email: j['email'], role: j['role'] ?? 'learner',
        dept: j['dept'], title: j['title'], phone: j['phone'],
        consentAt: j['consent_at'] == null ? null : DateTime.parse(j['consent_at']),
        hideOnLeaderboard: j['hide_on_leaderboard'] ?? false);
  Profile copyWith({String? phone, bool? hide, DateTime? consentAt}) => Profile(
      id: id, companyId: companyId, fullName: fullName, email: email, role: role, dept: dept, title: title,
      phone: phone ?? this.phone, consentAt: consentAt ?? this.consentAt, hideOnLeaderboard: hide ?? hideOnLeaderboard);
}

/// kind: pre, video, pdf, post
class LessonStep {
  String id, courseId, kind, title, meta;
  String? section, mediaUrl;
  int position, points;
  LessonStep({required this.id, required this.courseId, required this.kind, required this.title, this.meta = '', this.section,
      this.mediaUrl, this.position = 0, this.points = 0});
  bool get isTest => kind == 'pre' || kind == 'post';
  factory LessonStep.fromJson(Map<String, dynamic> j) => LessonStep(
      id: j['id'], courseId: j['course_id'], kind: j['kind'], title: j['title'], meta: j['meta'] ?? '',
      section: j['section'], mediaUrl: j['media_url'], position: j['position'] ?? 0, points: j['points'] ?? 0);
  Map<String, dynamic> toJson() => {
        'id': id, 'course_id': courseId, 'kind': kind, 'title': title, 'meta': meta, 'section': section,
        'media_url': mediaUrl, 'position': position, 'points': points};
  LessonStep copy() => LessonStep.fromJson(toJson());
}

class Course {
  String id, title, category, description, durationLabel;
  List<String> outcomes;
  int art, maxAttempts, timeLimitMin;
  int? passMark;
  bool published;
  List<LessonStep> steps;
  Course({required this.id, required this.title, this.category = 'Umum', this.description = '', this.durationLabel = '',
      this.outcomes = const [], this.art = 0, this.maxAttempts = 3, this.timeLimitMin = 30, this.passMark,
      this.published = false, this.steps = const []});
  int get totalPoints => steps.fold(0, (s, e) => s + e.points);
  LessonStep? stepOf(String kind) => steps.where((s) => s.kind == kind).firstOrNull;
  factory Course.fromJson(Map<String, dynamic> j) {
    final st = ((j['steps'] as List?) ?? []).map((e) => LessonStep.fromJson(Map<String, dynamic>.from(e))).toList()
      ..sort((a, b) => a.position.compareTo(b.position));
    return Course(
        id: j['id'], title: j['title'], category: j['category'] ?? 'Umum', description: j['description'] ?? '',
        durationLabel: j['duration_label'] ?? '', outcomes: List<String>.from(j['outcomes'] ?? const []),
        art: j['art'] ?? 0, maxAttempts: j['max_attempts'] ?? 3, timeLimitMin: j['time_limit_min'] ?? 30,
        passMark: j['pass_mark'], published: j['published'] ?? false, steps: st);
  }
  Map<String, dynamic> toRow() => {
        'id': id, 'title': title, 'category': category, 'description': description, 'duration_label': durationLabel,
        'outcomes': outcomes, 'art': art, 'max_attempts': maxAttempts, 'time_limit_min': timeLimitMin,
        'pass_mark': passMark, 'published': published};
}

class Question {
  String id, body;
  List<String> options;
  int? answer; // only filled for admins
  Question({required this.id, required this.body, required this.options, this.answer});
}

class Attempt {
  final String kind;
  final int score;
  final bool? passed;
  final DateTime at;
  Attempt(this.kind, this.score, this.passed, this.at);
}

/// One course as the signed in employee sees it.
class LearnerCourse {
  final Course course;
  final DateTime? dueAt;
  final bool assigned;
  final Set<String> doneSteps;
  final List<Attempt> attempts;
  final int passMark;
  LearnerCourse({required this.course, this.dueAt, this.assigned = false, this.doneSteps = const {}, this.attempts = const [], required this.passMark});

  int get stepsTotal => course.steps.length;
  int get stepsDone => course.steps.where((s) => doneSteps.contains(s.id)).length;
  double get progress => stepsTotal == 0 ? 0 : stepsDone / stepsTotal;
  bool get completed => stepsTotal > 0 && stepsDone == stepsTotal;
  List<Attempt> get postAttempts => attempts.where((a) => a.kind == 'post').toList();
  int get attemptsLeft => course.maxAttempts - postAttempts.length;
  int? get bestPost => postAttempts.isEmpty ? null : postAttempts.map((a) => a.score).reduce((a, b) => a > b ? a : b);
  bool get failedOut => !completed && attemptsLeft <= 0;
  bool get late => !completed && dueAt != null && dueAt!.isBefore(DateTime.now());
  bool get started => stepsDone > 0 || attempts.isNotEmpty;
  int get pointsGot => course.steps.where((s) => doneSteps.contains(s.id)).fold(0, (a, s) => a + s.points);

  /// Steps unlock in order: a step is open when every step before it is done.
  bool isOpen(LessonStep s) {
    for (final x in course.steps) {
      if (x.id == s.id) return true;
      if (!doneSteps.contains(x.id)) return false;
    }
    return false;
  }

  LessonStep? get nextStep => course.steps.where((s) => !doneSteps.contains(s.id)).firstOrNull;

  String get statusText {
    if (completed) return 'Selesai';
    if (failedOut) return 'Kesempatan habis';
    if (postAttempts.isNotEmpty) return 'Belum lulus';
    if (late) return 'Terlambat';
    if (started) return 'Sedang berjalan';
    return 'Belum dimulai';
  }
}

class TestResult {
  final int score, correct, total, passMark, points, attemptsUsed, maxAttempts;
  final bool? passed;
  final List<int?> chosen;
  final List<int>? answers; // shown only after passing or using every attempt
  TestResult({required this.score, required this.correct, required this.total, required this.passMark, required this.points,
      required this.attemptsUsed, required this.maxAttempts, this.passed, required this.chosen, this.answers});
  factory TestResult.fromJson(Map<String, dynamic> j) {
    final rv = List<Map<String, dynamic>>.from(((j['review'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e)));
    final hasKeys = rv.isNotEmpty && rv.first.containsKey('answer');
    return TestResult(
        score: j['score'], correct: j['correct'], total: j['total'], passMark: j['pass_mark'], points: j['points'] ?? 0,
        attemptsUsed: j['attempts_used'], maxAttempts: j['max_attempts'], passed: j['passed'],
        chosen: rv.map((e) => e['chosen'] as int?).toList(), answers: hasKeys ? rv.map((e) => e['answer'] as int).toList() : null);
  }
}

class PointsEntry {
  final int amount;
  final String reason;
  final DateTime at;
  PointsEntry(this.amount, this.reason, this.at);
}

class Certificate {
  final String id, courseId, courseTitle, number, ownerName;
  final int score;
  final DateTime issuedAt;
  Certificate({required this.id, required this.courseId, required this.courseTitle, required this.number, required this.score, required this.issuedAt, required this.ownerName});
}

class Notif {
  final String id, title, body;
  final String? link;
  final DateTime at;
  bool read;
  Notif({required this.id, required this.title, required this.body, this.link, required this.at, this.read = false});
}

class LeaderRow {
  final int rank, points;
  final String name;
  final String? dept;
  final bool isMe;
  LeaderRow(this.rank, this.name, this.dept, this.points, this.isMe);
}

/// One employee as HR sees them.
class Person {
  final String? userId;
  final String email, fullName, role, status;
  final String? dept, title;
  final int assigned, done, late;
  Person({this.userId, required this.email, required this.fullName, this.role = 'learner', this.status = 'sent', this.dept, this.title,
      this.assigned = 0, this.done = 0, this.late = 0});
  bool get active => status == 'active';
}

class InviteInput {
  final String fullName, email;
  final String? dept, title;
  InviteInput(this.fullName, this.email, this.dept, this.title);
}

/// One row of the HR report: a person on a course.
class ReportRow {
  final String person, email, dept, course;
  final DateTime? dueAt;
  final int stepsDone, stepsTotal;
  final int? bestScore;
  final bool completed;
  ReportRow({required this.person, required this.email, required this.dept, required this.course, this.dueAt,
      required this.stepsDone, required this.stepsTotal, this.bestScore, required this.completed});
  bool get late => !completed && dueAt != null && dueAt!.isBefore(DateTime.now());
  String get status => completed ? 'Selesai' : late ? 'Terlambat' : stepsDone > 0 ? 'Berjalan' : 'Belum mulai';
}
