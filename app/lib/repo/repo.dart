import 'dart:typed_data';
import '../models.dart';

class AuthFailure implements Exception {
  final String message;
  AuthFailure(this.message);
  @override
  String toString() => message;
}

/// Everything the screens need. Two versions: SupabaseRepo (real) and DemoRepo (in memory).
abstract class Repo {
  bool get isDemo;

  // ---- sign in ----
  Future<Profile?> restore();
  Future<Profile> signIn(String email, String password);

  /// First login for an invited employee: sets their password and links the invite.
  Future<Profile> activate(String email, String password);
  Future<void> sendReset(String email);
  Future<void> changePassword(String newPassword);
  Future<void> signOut();

  // ---- employee ----
  Future<Company> company();
  Future<List<LearnerCourse>> myCourses();
  Future<LearnerCourse> course(String id);
  Future<List<Question>> questions(String courseId, String kind);
  Future<int> completeStep(String stepId);
  Future<TestResult> submitTest(String courseId, String kind, List<int?> answers);
  Future<void> submitSurvey(String courseId, int rating, String? comment);
  Future<List<PointsEntry>> pointsHistory();
  Future<List<LeaderRow>> leaderboard();
  Future<List<Certificate>> certificates();
  Future<List<Notif>> notifications();
  Future<void> markRead(String? id); // null = all
  Future<Profile> updateMyProfile({String? phone, bool? hideOnLeaderboard, bool? consent});

  // ---- HR admin ----
  Future<List<Person>> people();
  Future<int> invite(List<InviteInput> people);
  Future<List<Course>> allCourses();
  Future<Course> saveCourse(Course c); // creates when id is empty
  Future<void> deleteCourse(String id);
  Future<List<Question>> adminQuestions(String courseId, String kind);
  Future<void> saveQuestions(String courseId, String kind, List<Question> qs);
  Future<String> uploadMedia(Uint8List bytes, String filename);
  Future<int> assign(String courseId, List<String> userIds, DateTime? dueAt);
  Future<Map<String, DateTime?>> assignmentsFor(String courseId); // userId -> due
  Future<List<ReportRow>> report();
  Future<Company> updateCompany(Company c);
}
