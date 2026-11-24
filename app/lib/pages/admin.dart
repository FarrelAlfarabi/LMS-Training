import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models.dart';
import '../state.dart';
import '../theme.dart';
import '../util/download.dart';
import '../util/pick.dart';
import '../widgets/common.dart';

// ---------------------------------------------------------------- Dashboard

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});
  @override
  Widget build(BuildContext context) {
    final st = Scope.of(context);
    return Loader<(List<Person>, List<ReportRow>, List<Course>)>(
      load: () async => (await st.repo.people(), await st.repo.report(), await st.repo.allCourses()),
      builder: (c, d, _) {
        final (people, rows, courses) = d;
        final learners = people.where((p) => p.role == 'learner').toList();
        final active = learners.where((p) => p.active).length;
        final done = rows.where((r) => r.completed).length;
        final late = rows.where((r) => r.late).toList();
        final scored = rows.where((r) => r.bestScore != null).toList();
        final avg = scored.isEmpty ? 0 : (scored.fold<int>(0, (a, r) => a + r.bestScore!) / scored.length).round();
        final byCourse = <String, List<ReportRow>>{};
        for (final r in rows) {
          (byCourse[r.course] ??= []).add(r);
        }
        final byDept = <String, List<ReportRow>>{};
        for (final r in rows) {
          (byDept[r.dept] ??= []).add(r);
        }
        final lateBy = <String, int>{};
        for (final r in late) {
          lateBy[r.person] = (lateBy[r.person] ?? 0) + 1;
        }
        return PageBody(
          rail: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Box(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [
                  Expanded(child: Text('Lewat tenggat', style: h3(context))),
                  Pill('${late.length}', tone: late.isEmpty ? Tone.ok : Tone.bad),
                ]),
                const SizedBox(height: 8),
                if (lateBy.isEmpty) const Text('Tidak ada yang terlambat.', style: muted),
                for (final e in (lateBy.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).take(6))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(children: [
                      Avatar(initialsOf(e.key), size: 28),
                      const SizedBox(width: 10),
                      Expanded(child: Text(e.key)),
                      Text('${e.value} kelas', style: small),
                    ]),
                  ),
                if (late.isNotEmpty)
                  TextButton(onPressed: () => context.go('/admin/reports?filter=late'), child: const Text('Lihat di laporan')),
              ]),
            ),
            const SizedBox(height: 16),
            Box(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text('Langkah cepat', style: h3(context)),
                const SizedBox(height: 10),
                FilledButton.icon(onPressed: () => context.go('/admin/assign'), icon: const Icon(Icons.assignment_add, size: 18), label: const Text('Tugaskan kelas')),
                const SizedBox(height: 8),
                OutlinedButton.icon(onPressed: () => context.go('/admin/people'), icon: const Icon(Icons.person_add_alt, size: 18), label: const Text('Undang karyawan')),
                const SizedBox(height: 8),
                OutlinedButton.icon(onPressed: () => context.go('/admin/courses/new'), icon: const Icon(Icons.add, size: 18), label: const Text('Buat kelas baru')),
              ]),
            ),
          ]),
          children: [
            PageHead('Dasbor', sub: '${st.company?.name ?? ''} · data per ${fmtDate(DateTime.now())}'),
            KpiStrip([
              ('Karyawan aktif', '$active', 'dari ${learners.length} diundang'),
              ('Tugas selesai', '$done', 'dari ${rows.length} tugas'),
              ('Lewat tenggat', '${late.length}', 'tugas'),
              ('Rata-rata nilai', '$avg', 'post test terbaik'),
            ]),
            const SizedBox(height: 24),
            SectionTitle('Kemajuan per kelas', trailing: TextButton(onPressed: () => context.go('/admin/reports'), child: const Text('Laporan lengkap'))),
            DataList(
              headers: const ['Kelas', 'Ditugaskan', 'Selesai', 'Terlambat'],
              flex: const [5, 2, 3, 2],
              rows: [
                for (final e in byCourse.entries)
                  [
                    Text(e.key, style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text('${e.value.length}', style: const TextStyle(fontFeatures: tabular)),
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      SizedBox(width: 60, child: Bar(e.value.where((r) => r.completed).length / e.value.length, color: C.ok)),
                      const SizedBox(width: 8),
                      Text('${e.value.where((r) => r.completed).length}', style: const TextStyle(fontFeatures: tabular)),
                    ]),
                    Text('${e.value.where((r) => r.late).length}',
                        style: TextStyle(color: e.value.any((r) => r.late) ? C.bad : C.ink, fontWeight: FontWeight.w600, fontFeatures: tabular)),
                  ],
              ],
            ),
            const SizedBox(height: 24),
            const SectionTitle('Per divisi'),
            DataList(
              headers: const ['Divisi', 'Tugas', 'Selesai', 'Persentase'],
              flex: const [4, 2, 2, 4],
              rows: [
                for (final e in byDept.entries)
                  [
                    Text(e.key, style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text('${e.value.length}'),
                    Text('${e.value.where((r) => r.completed).length}'),
                    Row(mainAxisSize: MainAxisSize.min, children: [
                      SizedBox(width: 100, child: Bar(e.value.where((r) => r.completed).length / e.value.length)),
                      const SizedBox(width: 8),
                      Text('${(e.value.where((r) => r.completed).length * 100 / e.value.length).round()}%'),
                    ]),
                  ],
              ],
            ),
            const SizedBox(height: 12),
            Text('${courses.where((c) => !c.published).length} kelas masih draf.', style: small),
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------- People

class PeoplePage extends StatefulWidget {
  const PeoplePage({super.key});
  @override
  State<PeoplePage> createState() => _PeoplePageState();
}

class _PeoplePageState extends State<PeoplePage> {
  final _q = TextEditingController();
  String _dept = 'Semua';
  int _v = 0;

  Future<void> _inviteOne() async {
    final name = TextEditingController(), email = TextEditingController(), dept = TextEditingController(), title = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text('Undang karyawan', style: h2(d)),
        content: SizedBox(
          width: 420,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: name, decoration: const InputDecoration(labelText: 'Nama lengkap')),
            const SizedBox(height: 10),
            TextField(controller: email, decoration: const InputDecoration(labelText: 'Email kantor')),
            const SizedBox(height: 10),
            TextField(controller: dept, decoration: const InputDecoration(labelText: 'Divisi')),
            const SizedBox(height: 10),
            TextField(controller: title, decoration: const InputDecoration(labelText: 'Jabatan')),
            const SizedBox(height: 10),
            const Text('Karyawan masuk lewat "Aktifkan akun" dengan email ini.', style: small),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Undang')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    if (name.text.trim().isEmpty || !email.text.contains('@')) return toast(context, 'Isi nama dan email yang benar.');
    final n = await Scope.read(context).repo.invite([InviteInput(name.text.trim(), email.text.trim(), dept.text.trim().isEmpty ? null : dept.text.trim(), title.text.trim().isEmpty ? null : title.text.trim())]);
    if (mounted) {
      toast(context, n == 0 ? 'Email itu sudah diundang.' : 'Undangan dibuat untuk ${email.text.trim()}.');
      setState(() => _v++);
    }
  }

  Future<void> _import() async {
    final res = await pickOne(extensions: ['csv']);
    if (res == null || !mounted) return;
    final lines = const LineSplitter().convert(utf8.decode(res.bytes, allowMalformed: true)).where((l) => l.trim().isNotEmpty).toList();
    final list = <InviteInput>[];
    final bad = <int>[];
    for (var i = 0; i < lines.length; i++) {
      final cols = lines[i].replaceAll('﻿', '').split(RegExp(r'[;,]')).map((s) => s.trim().replaceAll('"', '')).toList();
      if (i == 0 && cols.first.toLowerCase().contains('nama')) continue;
      if (cols.length < 2 || !cols[1].contains('@')) {
        bad.add(i + 1);
        continue;
      }
      list.add(InviteInput(cols[0], cols[1], cols.length > 2 && cols[2].isNotEmpty ? cols[2] : null, cols.length > 3 && cols[3].isNotEmpty ? cols[3] : null));
    }
    if (!mounted) return;
    final ok = await confirm(context, 'Impor ${list.length} karyawan?',
        '${list.length} baris siap diundang.${bad.isEmpty ? '' : ' ${bad.length} baris dilewati karena email tidak valid (baris ${bad.take(5).join(', ')}).'} Email yang sudah terdaftar tidak diundang dua kali.',
        yes: 'Impor');
    if (!ok || !mounted) return;
    final n = await Scope.read(context).repo.invite(list);
    if (mounted) {
      toast(context, '$n undangan baru dibuat.');
      setState(() => _v++);
    }
  }

  @override
  Widget build(BuildContext context) {
    final st = Scope.of(context);
    return Loader<List<Person>>(
      key: ValueKey(_v),
      load: st.repo.people,
      builder: (c, all, _) {
        final depts = ['Semua', ...{for (final p in all) p.dept ?? '-'}];
        final q = _q.text.toLowerCase();
        final list = all.where((p) => (_dept == 'Semua' || p.dept == _dept) && (q.isEmpty || p.fullName.toLowerCase().contains(q) || p.email.contains(q))).toList();
        return PageBody(children: [
          PageHead('Karyawan', sub: '${all.where((p) => p.active).length} aktif dari ${all.length} diundang', actions: [
            OutlinedButton.icon(onPressed: _import, icon: const Icon(Icons.upload_file, size: 18), label: const Text('Impor CSV')),
            FilledButton.icon(onPressed: _inviteOne, icon: const Icon(Icons.person_add_alt, size: 18), label: const Text('Undang karyawan')),
          ]),
          Box(
            color: C.navy50,
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              const Icon(Icons.info_outline, color: C.navy, size: 20),
              const SizedBox(width: 10),
              const Expanded(child: Text('Format CSV: nama, email, divisi, jabatan. Satu karyawan per baris.')),
              TextButton(
                onPressed: () => downloadText('contoh-impor-karyawan.csv', 'nama,email,divisi,jabatan\nBudi Santoso,budi.santoso@perusahaan.co.id,Penjualan,Staf Penjualan\n')
                    ? null
                    : toast(context, 'Unduh contoh hanya di browser.'),
                child: const Text('Unduh contoh'),
              ),
            ]),
          ),
          const SizedBox(height: 16),
          Wrap(spacing: 12, runSpacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [
            SizedBox(
              width: 320,
              child: TextField(controller: _q, onChanged: (_) => setState(() {}), decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Cari nama atau email')),
            ),
            DropdownButton<String>(
              value: _dept,
              underline: const SizedBox(),
              items: [for (final d in depts) DropdownMenuItem(value: d, child: Text(d == 'Semua' ? 'Semua divisi' : d))],
              onChanged: (v) => setState(() => _dept = v!),
            ),
          ]),
          const SizedBox(height: 16),
          DataList(
            headers: const ['Nama', 'Divisi', 'Jabatan', 'Status', 'Kelas selesai'],
            flex: const [5, 3, 3, 3, 2],
            rows: [
              for (final p in list)
                [
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(p.fullName, style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text(p.email, style: small, overflow: TextOverflow.ellipsis),
                  ]),
                  Text(p.dept ?? '-'),
                  Text(p.title ?? '-'),
                  Pill(p.role == 'admin' ? 'Admin HR' : (p.active ? 'Aktif' : 'Undangan terkirim'), tone: p.role == 'admin' ? Tone.navy : (p.active ? Tone.ok : Tone.warn)),
                  Text(p.role == 'admin' ? '-' : '${p.done}/${p.assigned}${p.late > 0 ? ' · ${p.late} telat' : ''}',
                      style: TextStyle(color: p.late > 0 ? C.bad : C.ink, fontFeatures: tabular)),
                ],
            ],
          ),
        ]);
      },
    );
  }
}

// ---------------------------------------------------------------- Courses

class CoursesAdminPage extends StatelessWidget {
  const CoursesAdminPage({super.key});
  @override
  Widget build(BuildContext context) {
    final st = Scope.of(context);
    return Loader<(List<Course>, List<ReportRow>)>(
      load: () async => (await st.repo.allCourses(), await st.repo.report()),
      builder: (c, d, _) {
        final (courses, rows) = d;
        return PageBody(children: [
          PageHead('Kelas dan materi', sub: 'Susun kelas dari video, PDF, pre test, dan post test.', actions: [
            FilledButton.icon(onPressed: () => context.go('/admin/courses/new'), icon: const Icon(Icons.add, size: 18), label: const Text('Buat kelas')),
          ]),
          DataList(
            headers: const ['Kelas', 'Langkah', 'Status', 'Ditugaskan', ''],
            flex: const [6, 2, 2, 2, 2],
            onTap: (i) => context.go('/admin/courses/${courses[i].id}'),
            rows: [
              for (final co in courses)
                [
                  Row(children: [
                    SizedBox(width: 40, height: 40, child: CourseArt(co.art, height: 40, radius: BorderRadius.circular(8))),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(co.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                        Text('${co.category} · ${co.durationLabel}', style: small),
                      ]),
                    ),
                  ]),
                  Text('${co.steps.length}'),
                  Pill(co.published ? 'Terbit' : 'Draf', tone: co.published ? Tone.ok : Tone.neutral),
                  Text('${rows.where((r) => r.course == co.title).length} orang'),
                  TextButton(onPressed: () => context.go('/admin/assign?course=${co.id}'), child: const Text('Tugaskan')),
                ],
            ],
          ),
        ]);
      },
    );
  }
}

class CourseBuilderPage extends StatelessWidget {
  final String id;
  const CourseBuilderPage(this.id, {super.key});
  @override
  Widget build(BuildContext context) {
    final st = Scope.of(context);
    return Loader<Course>(
      key: ValueKey(id),
      load: () async {
        if (id == 'new') {
          return Course(id: '', title: '', category: 'Umum', durationLabel: '1 jam', steps: [
            LessonStep(id: '', courseId: '', kind: 'pre', title: 'Pre test', meta: '', points: 10),
            LessonStep(id: '', courseId: '', kind: 'post', title: 'Post test', meta: '', points: 50),
          ]);
        }
        return (await st.repo.allCourses()).firstWhere((c) => c.id == id);
      },
      builder: (c, course, _) => _Builder(course: course),
    );
  }
}

class _Builder extends StatefulWidget {
  final Course course;
  const _Builder({required this.course});
  @override
  State<_Builder> createState() => _BuilderState();
}

class _BuilderState extends State<_Builder> {
  late final Course c = widget.course;
  late final _title = TextEditingController(text: c.title);
  late final _cat = TextEditingController(text: c.category);
  late final _desc = TextEditingController(text: c.description);
  late final _dur = TextEditingController(text: c.durationLabel);
  late final _out = TextEditingController(text: c.outcomes.join('\n'));
  late final _pass = TextEditingController(text: c.passMark?.toString() ?? '');
  late final _att = TextEditingController(text: '${c.maxAttempts}');
  late final _time = TextEditingController(text: '${c.timeLimitMin}');
  late List<LessonStep> steps = [for (final s in c.steps) s.copy()];
  bool _busy = false, _dirty = false;

  void _touch() => setState(() => _dirty = true);

  Future<bool> _save({bool? publish}) async {
    if (_title.text.trim().isEmpty) {
      toast(context, 'Isi judul kelas dulu.');
      return false;
    }
    setState(() => _busy = true);
    try {
      c
        ..title = _title.text.trim()
        ..category = _cat.text.trim().isEmpty ? 'Umum' : _cat.text.trim()
        ..description = _desc.text.trim()
        ..durationLabel = _dur.text.trim()
        ..outcomes = _out.text.split('\n').map((s) => s.trim()).where((s) => s.isNotEmpty).toList()
        ..passMark = int.tryParse(_pass.text.trim())?.clamp(0, 100)
        ..maxAttempts = (int.tryParse(_att.text.trim()) ?? 3).clamp(1, 10)
        ..timeLimitMin = (int.tryParse(_time.text.trim()) ?? 30).clamp(5, 180)
        ..published = publish ?? c.published
        ..steps = steps;
      final saved = await Scope.read(context).repo.saveCourse(c);
      steps = [for (final s in saved.steps) s.copy()];
      if (mounted) {
        toast(context, publish == true ? 'Kelas diterbitkan.' : (publish == false ? 'Kelas dijadikan draf.' : 'Tersimpan.'));
        setState(() => _dirty = false);
        if (GoRouterState.of(context).uri.path.endsWith('/new')) context.go('/admin/courses/${saved.id}');
      }
      return true;
    } catch (e) {
      if (mounted) toast(context, errText(e));
      return false;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _editStep(LessonStep? s, String kind) async {
    final edit = s ?? LessonStep(id: '', courseId: c.id, kind: kind, title: '', points: kind == 'video' ? 50 : 3);
    final title = TextEditingController(text: edit.title), section = TextEditingController(text: edit.section ?? ''), meta = TextEditingController(text: edit.meta);
    final pts = TextEditingController(text: '${edit.points}');
    String? url = edit.mediaUrl;
    String? fileName;
    bool uploading = false;
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => StatefulBuilder(
        builder: (d, set) => AlertDialog(
          title: Text(s == null ? (kind == 'video' ? 'Tambah video' : 'Tambah PDF') : 'Ubah materi', style: h2(d)),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                TextField(controller: title, decoration: const InputDecoration(labelText: 'Judul materi')),
                const SizedBox(height: 10),
                TextField(controller: section, decoration: const InputDecoration(labelText: 'Bagian (mis. "Dasar UU PDP")')),
                const SizedBox(height: 10),
                TextField(controller: meta, decoration: InputDecoration(labelText: kind == 'video' ? 'Durasi (mis. 6:12)' : 'Keterangan (mis. PDF 12 halaman)')),
                const SizedBox(height: 10),
                TextField(controller: pts, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Poin')),
                const SizedBox(height: 14),
                Box(
                  padding: const EdgeInsets.all(12),
                  child: Row(children: [
                    Icon(kind == 'video' ? Icons.movie_outlined : Icons.picture_as_pdf_outlined, color: C.navy),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        uploading ? 'Mengunggah...' : (fileName ?? (url == null ? 'Belum ada file' : 'File terpasang')),
                        style: small,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    OutlinedButton(
                      onPressed: uploading
                          ? null
                          : () async {
                              final f = await pickOne(extensions: kind == 'video' ? ['mp4', 'webm', 'mov'] : ['pdf']);
                              if (f == null) return;
                              if (f.bytes.length > 50 * 1024 * 1024) {
                                if (d.mounted) toast(d, 'File maksimal 50 MB di prototipe ini.');
                                return;
                              }
                              set(() => uploading = true);
                              try {
                                final u = await Scope.read(context).repo.uploadMedia(f.bytes, f.name);
                                set(() {
                                  url = u;
                                  fileName = f.name;
                                });
                              } catch (e) {
                                if (d.mounted) toast(d, errText(e));
                              } finally {
                                set(() => uploading = false);
                              }
                            },
                      child: const Text('Unggah'),
                    ),
                  ]),
                ),
              ]),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Batal')),
            FilledButton(onPressed: uploading ? null : () => Navigator.pop(d, true), child: const Text('Simpan')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    if (title.text.trim().isEmpty) return toast(context, 'Judul materi wajib diisi.');
    edit
      ..title = title.text.trim()
      ..section = section.text.trim().isEmpty ? null : section.text.trim()
      ..meta = meta.text.trim()
      ..points = int.tryParse(pts.text) ?? edit.points
      ..mediaUrl = url;
    setState(() {
      if (s == null) {
        final post = steps.indexWhere((x) => x.kind == 'post');
        steps.insert(post < 0 ? steps.length : post, edit);
      }
      _dirty = true;
    });
  }

  void _move(int i, int d) {
    final j = i + d;
    if (j < 0 || j >= steps.length) return;
    if (steps[i].isTest || steps[j].isTest) return toast(context, 'Pre test selalu pertama dan post test selalu terakhir.');
    setState(() {
      final t = steps[i];
      steps[i] = steps[j];
      steps[j] = t;
      _dirty = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isNew = c.id.isEmpty;
    final phone = isPhone(context);
    Widget field(TextEditingController t, String label, {int lines = 1, String? help, TextInputType? kb}) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: TextField(controller: t, maxLines: lines, keyboardType: kb, onChanged: (_) => _touch(), decoration: InputDecoration(labelText: label, helperText: help)),
        );
    final company = Scope.of(context).company;
    return PageBody(maxWidth: 1000, children: [
      PageHead(isNew ? 'Kelas baru' : 'Atur kelas',
          back: BackLink('Kelas dan materi', () => context.go('/admin/courses')),
          sub: isNew ? null : (c.published ? 'Terbit, terlihat oleh karyawan' : 'Draf, belum terlihat oleh karyawan'),
          actions: [
            OutlinedButton(onPressed: _busy ? null : () => _save(), child: Text(_dirty ? 'Simpan' : 'Tersimpan')),
            if (!isNew)
              FilledButton(
                onPressed: _busy
                    ? null
                    : () async {
                        if (!c.published) {
                          final pre = await Scope.read(context).repo.adminQuestions(c.id, 'pre');
                          final post = await Scope.read(context).repo.adminQuestions(c.id, 'post');
                          if (!context.mounted) return;
                          if (post.isEmpty || pre.isEmpty) return toast(context, 'Isi soal pre test dan post test dulu sebelum terbit.');
                        }
                        _save(publish: !c.published);
                      },
                child: Text(c.published ? 'Jadikan draf' : 'Terbitkan'),
              ),
          ]),
      Flex(
        direction: phone ? Axis.vertical : Axis.horizontal,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(
            flex: phone ? 0 : 5,
            child: Box(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text('Informasi kelas', style: h3(context)),
                const SizedBox(height: 12),
                field(_title, 'Judul kelas'),
                field(_cat, 'Kategori'),
                field(_dur, 'Perkiraan durasi', help: 'Contoh: 1,5 jam'),
                field(_desc, 'Deskripsi', lines: 3),
                field(_out, 'Hasil belajar', lines: 3, help: 'Satu per baris'),
                Text('Aturan post test', style: h3(context)),
                const SizedBox(height: 12),
                field(_pass, 'Nilai lulus', kb: TextInputType.number, help: 'Kosongkan untuk ikut standar perusahaan (${company?.passMark ?? 70})'),
                Row(children: [
                  Expanded(child: field(_att, 'Kesempatan', kb: TextInputType.number)),
                  const SizedBox(width: 12),
                  Expanded(child: field(_time, 'Waktu (menit)', kb: TextInputType.number)),
                ]),
                Text('Gambar sampul', style: small),
                const SizedBox(height: 8),
                Row(children: [
                  for (var a = 0; a < courseArt.length; a++)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: InkWell(
                        onTap: () => setState(() {
                          c.art = a;
                          _dirty = true;
                        }),
                        child: Container(
                          decoration: BoxDecoration(border: Border.all(color: c.art == a ? C.orange : Colors.transparent, width: 2), borderRadius: BorderRadius.circular(10)),
                          child: SizedBox(width: 48, height: 34, child: CourseArt(a, height: 34, radius: BorderRadius.circular(8))),
                        ),
                      ),
                    ),
                ]),
              ]),
            ),
          ),
          SizedBox(width: phone ? 0 : 20, height: phone ? 20 : 0),
          Flexible(
            flex: phone ? 0 : 6,
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Box(
                padding: EdgeInsets.zero,
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 8, 6),
                    child: Row(children: [
                      Expanded(child: Text('Langkah (${steps.length})', style: h3(context))),
                      TextButton.icon(onPressed: () => _editStep(null, 'video'), icon: const Icon(Icons.add, size: 18), label: const Text('Video')),
                      TextButton.icon(onPressed: () => _editStep(null, 'pdf'), icon: const Icon(Icons.add, size: 18), label: const Text('PDF')),
                    ]),
                  ),
                  for (var i = 0; i < steps.length; i++) ...[
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 10, 4, 10),
                      child: Row(children: [
                        Text('${i + 1}', style: small.copyWith(fontWeight: FontWeight.w700)),
                        const SizedBox(width: 12),
                        Icon(switch (steps[i].kind) { 'video' => Icons.play_circle_outline, 'pdf' => Icons.description_outlined, _ => Icons.quiz_outlined }, color: C.navy, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text(steps[i].title, style: const TextStyle(fontWeight: FontWeight.w600)),
                            Text(
                              [
                                if (steps[i].section != null) steps[i].section!,
                                if (steps[i].meta.isNotEmpty) steps[i].meta,
                                '+${steps[i].points} poin',
                                if (!steps[i].isTest && steps[i].mediaUrl == null) 'belum ada file',
                              ].join(' · '),
                              style: small.copyWith(color: !steps[i].isTest && steps[i].mediaUrl == null ? C.bad : C.muted),
                            ),
                          ]),
                        ),
                        if (steps[i].isTest)
                          TextButton(
                            onPressed: () async {
                              if (_dirty || c.id.isEmpty) {
                                final ok = await _save();
                                if (!ok || !context.mounted) return;
                              }
                              if (context.mounted) context.go('/admin/courses/${c.id}/test/${steps[i].kind}');
                            },
                            child: const Text('Atur soal'),
                          )
                        else ...[
                          IconButton(tooltip: 'Naik', onPressed: () => _move(i, -1), icon: const Icon(Icons.arrow_upward, size: 18)),
                          IconButton(tooltip: 'Turun', onPressed: () => _move(i, 1), icon: const Icon(Icons.arrow_downward, size: 18)),
                          IconButton(tooltip: 'Ubah', onPressed: () => _editStep(steps[i], steps[i].kind), icon: const Icon(Icons.edit_outlined, size: 18)),
                          IconButton(
                            tooltip: 'Hapus',
                            onPressed: () async {
                              if (await confirm(context, 'Hapus materi?', '"${steps[i].title}" dihapus dari kelas. Kemajuan karyawan di materi ini ikut terhapus.', yes: 'Hapus', danger: true)) {
                                setState(() {
                                  steps.removeAt(i);
                                  _dirty = true;
                                });
                              }
                            },
                            icon: const Icon(Icons.delete_outline, size: 18, color: C.bad),
                          ),
                        ],
                      ]),
                    ),
                  ],
                ]),
              ),
              const SizedBox(height: 12),
              const Text('Karyawan membuka langkah berurutan. Video dihitung selesai saat ditonton sampai akhir.', style: small),
              if (!isNew) ...[
                const SizedBox(height: 20),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () async {
                      if (await confirm(context, 'Hapus kelas?', 'Kelas, soal, penugasan, dan kemajuan semua karyawan di kelas ini dihapus permanen.', yes: 'Hapus kelas', danger: true)) {
                        await Scope.read(context).repo.deleteCourse(c.id);
                        if (context.mounted) context.go('/admin/courses');
                      }
                    },
                    icon: const Icon(Icons.delete_outline, color: C.bad, size: 18),
                    label: const Text('Hapus kelas', style: TextStyle(color: C.bad)),
                  ),
                ),
              ],
            ]),
          ),
        ],
      ),
    ]);
  }
}

class TestEditorPage extends StatelessWidget {
  final String courseId, kind;
  const TestEditorPage(this.courseId, this.kind, {super.key});
  @override
  Widget build(BuildContext context) {
    final st = Scope.of(context);
    return Loader<(Course, List<Question>)>(
      load: () async => ((await st.repo.allCourses()).firstWhere((c) => c.id == courseId), await st.repo.adminQuestions(courseId, kind)),
      builder: (c, d, _) => _TestEditor(course: d.$1, kind: kind, qs: d.$2),
    );
  }
}

class _TestEditor extends StatefulWidget {
  final Course course;
  final String kind;
  final List<Question> qs;
  const _TestEditor({required this.course, required this.kind, required this.qs});
  @override
  State<_TestEditor> createState() => _TestEditorState();
}

class _TestEditorState extends State<_TestEditor> {
  late final List<(TextEditingController, List<TextEditingController>, int)> _q = [
    for (final q in widget.qs) (TextEditingController(text: q.body), [for (final o in q.options) TextEditingController(text: o)], q.answer ?? 0)
  ];
  bool _busy = false;

  void _add() => setState(() => _q.add((TextEditingController(), [for (var i = 0; i < 4; i++) TextEditingController()], 0)));

  Future<void> _save() async {
    final out = <Question>[];
    for (final (i, q) in _q.indexed) {
      final opts = q.$2.map((t) => t.text.trim()).where((s) => s.isNotEmpty).toList();
      if (q.$1.text.trim().isEmpty || opts.length < 2) return toast(context, 'Soal ${i + 1}: isi pertanyaan dan minimal 2 pilihan.');
      if (q.$3 >= q.$2.length || q.$2[q.$3].text.trim().isEmpty) return toast(context, 'Soal ${i + 1}: pilih jawaban benar.');
      final ans = opts.indexOf(q.$2[q.$3].text.trim());
      out.add(Question(id: '', body: q.$1.text.trim(), options: opts, answer: ans));
    }
    setState(() => _busy = true);
    try {
      await Scope.read(context).repo.saveQuestions(widget.course.id, widget.kind, out);
      if (mounted) toast(context, '${out.length} soal tersimpan.');
    } catch (e) {
      if (mounted) toast(context, errText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PageBody(maxWidth: 820, children: [
        PageHead('${widget.kind == 'pre' ? 'Pre test' : 'Post test'}: ${_q.length} soal',
            sub: widget.course.title,
            back: BackLink('Atur kelas', () => context.go('/admin/courses/${widget.course.id}')),
            actions: [
              OutlinedButton.icon(onPressed: _add, icon: const Icon(Icons.add, size: 18), label: const Text('Tambah soal')),
              FilledButton(onPressed: _busy ? null : _save, child: const Text('Simpan soal')),
            ]),
        const Text('Pilih lingkaran di samping jawaban yang benar. Kunci jawaban tidak pernah terlihat oleh karyawan.', style: small),
        const SizedBox(height: 16),
        if (_q.isEmpty) Empty(Icons.quiz_outlined, 'Belum ada soal', 'Tambah soal pertama.', action: FilledButton(onPressed: _add, child: const Text('Tambah soal'))),
        for (var i = 0; i < _q.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Box(
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Row(children: [
                  Text('Soal ${i + 1}', style: h3(context)),
                  const Spacer(),
                  IconButton(tooltip: 'Hapus soal', onPressed: () => setState(() => _q.removeAt(i)), icon: const Icon(Icons.delete_outline, color: C.bad)),
                ]),
                TextField(controller: _q[i].$1, maxLines: 2, decoration: const InputDecoration(labelText: 'Pertanyaan')),
                const SizedBox(height: 10),
                for (var o = 0; o < _q[i].$2.length; o++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(children: [
                      Radio<int>(
                        value: o,
                        groupValue: _q[i].$3,
                        activeColor: C.ok,
                        onChanged: (v) => setState(() => _q[i] = (_q[i].$1, _q[i].$2, v!)),
                      ),
                      Expanded(
                        child: TextField(
                          controller: _q[i].$2[o],
                          decoration: InputDecoration(labelText: 'Pilihan ${String.fromCharCode(65 + o)}${o == _q[i].$3 ? ' (benar)' : ''}'),
                        ),
                      ),
                    ]),
                  ),
                if (_q[i].$2.length < 6)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton(onPressed: () => setState(() => _q[i].$2.add(TextEditingController())), child: const Text('Tambah pilihan')),
                  ),
              ]),
            ),
          ),
      ]);
}

// ---------------------------------------------------------------- Assign

class AssignPage extends StatefulWidget {
  final String? courseId;
  const AssignPage({super.key, this.courseId});
  @override
  State<AssignPage> createState() => _AssignPageState();
}

class _AssignPageState extends State<AssignPage> {
  late String? _course = widget.courseId;
  final _sel = <String>{};
  DateTime? _due = DateTime.now().add(const Duration(days: 14));
  String _dept = 'Semua';
  Map<String, DateTime?> _existing = {};
  int _v = 0;

  Future<void> _loadExisting() async {
    if (_course == null) return;
    final m = await Scope.read(context).repo.assignmentsFor(_course!);
    setState(() => _existing = m);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadExisting());
  }

  @override
  Widget build(BuildContext context) {
    final st = Scope.of(context);
    return Loader<(List<Course>, List<Person>)>(
      key: ValueKey(_v),
      load: () async => ((await st.repo.allCourses()).where((c) => c.published).toList(), await st.repo.people()),
      builder: (c, d, _) {
        final (courses, people) = d;
        final active = people.where((p) => p.active && p.role == 'learner' && p.userId != null).toList();
        final depts = ['Semua', ...{for (final p in active) p.dept ?? '-'}];
        final shown = active.where((p) => _dept == 'Semua' || p.dept == _dept).toList();
        final fresh = _sel.where((u) => !_existing.containsKey(u)).length;
        return PageBody(maxWidth: 900, children: [
          const PageHead('Tugaskan kelas', sub: 'Pilih kelas, orang, dan tenggat. Karyawan langsung mendapat notifikasi.'),
          Box(
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Text('1. Kelas', style: h3(context)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: courses.any((x) => x.id == _course) ? _course : null,
                isExpanded: true,
                hint: const Text('Pilih kelas yang sudah terbit'),
                items: [for (final co in courses) DropdownMenuItem(value: co.id, child: Text(co.title, overflow: TextOverflow.ellipsis))],
                onChanged: (v) {
                  setState(() {
                    _course = v;
                    _sel.clear();
                  });
                  _loadExisting();
                },
              ),
              const SizedBox(height: 20),
              Text('2. Tenggat', style: h3(context)),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
                OutlinedButton.icon(
                  onPressed: () async {
                    final p = await showDatePicker(
                        context: context, initialDate: _due ?? DateTime.now(), firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)), locale: const Locale('id'));
                    if (p != null) setState(() => _due = DateTime(p.year, p.month, p.day, 23, 59));
                  },
                  icon: const Icon(Icons.event, size: 18),
                  label: Text(_due == null ? 'Tanpa tenggat' : fmtDate(_due)),
                ),
                for (final w in [7, 14, 30])
                  TextButton(onPressed: () => setState(() => _due = DateTime.now().add(Duration(days: w))), child: Text('$w hari')),
                TextButton(onPressed: () => setState(() => _due = null), child: const Text('Tanpa tenggat')),
              ]),
              const SizedBox(height: 20),
              Row(children: [
                Expanded(child: Text('3. Karyawan (${_sel.length} dipilih)', style: h3(context))),
                DropdownButton<String>(
                  value: _dept,
                  underline: const SizedBox(),
                  items: [for (final dd in depts) DropdownMenuItem(value: dd, child: Text(dd == 'Semua' ? 'Semua divisi' : dd))],
                  onChanged: (v) => setState(() => _dept = v!),
                ),
              ]),
              Row(children: [
                TextButton(onPressed: () => setState(() => _sel.addAll(shown.map((p) => p.userId!))), child: Text('Pilih semua (${shown.length})')),
                TextButton(onPressed: () => setState(() => _sel.removeAll(shown.map((p) => p.userId!))), child: const Text('Kosongkan')),
              ]),
              const Divider(),
              SizedBox(
                height: 320,
                child: ListView(children: [
                  for (final p in shown)
                    CheckboxListTile(
                      dense: true,
                      controlAffinity: ListTileControlAffinity.leading,
                      value: _sel.contains(p.userId),
                      onChanged: (v) => setState(() => v! ? _sel.add(p.userId!) : _sel.remove(p.userId)),
                      title: Text(p.fullName),
                      subtitle: Text(
                          '${p.dept ?? '-'} · ${p.title ?? '-'}${_existing.containsKey(p.userId) ? ' · sudah ditugaskan, tenggat ${fmtDate(_existing[p.userId])}' : ''}',
                          style: small),
                    ),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: 16),
          Wrap(spacing: 12, crossAxisAlignment: WrapCrossAlignment.center, children: [
            FilledButton(
              onPressed: _course == null || _sel.isEmpty
                  ? null
                  : () async {
                      final ok = await confirm(context, 'Tugaskan ke ${_sel.length} orang?',
                          '$fresh orang baru${_sel.length - fresh > 0 ? ', ${_sel.length - fresh} orang diperbarui tenggatnya' : ''}. Tenggat: ${_due == null ? 'tanpa tenggat' : fmtDate(_due)}. Mereka mendapat notifikasi.',
                          yes: 'Tugaskan');
                      if (!ok || !context.mounted) return;
                      final n = await Scope.read(context).repo.assign(_course!, _sel.toList(), _due);
                      if (context.mounted) {
                        toast(context, 'Kelas ditugaskan ke $n orang.');
                        setState(() {
                          _sel.clear();
                          _v++;
                        });
                        _loadExisting();
                      }
                    },
              child: const Text('Tugaskan'),
            ),
            if (_course != null) Text('${_existing.length} orang sudah ditugaskan kelas ini.', style: small),
          ]),
        ]);
      },
    );
  }
}

// ---------------------------------------------------------------- Reports

class ReportsPage extends StatefulWidget {
  final String? filter;
  const ReportsPage({super.key, this.filter});
  @override
  State<ReportsPage> createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  String _course = 'Semua', _dept = 'Semua';
  late String _status = widget.filter == 'late' ? 'Terlambat' : 'Semua';

  @override
  Widget build(BuildContext context) {
    final st = Scope.of(context);
    return Loader<List<ReportRow>>(
      load: st.repo.report,
      builder: (c, all, _) {
        final courses = ['Semua', ...{for (final r in all) r.course}];
        final depts = ['Semua', ...{for (final r in all) r.dept}];
        final rows = all
            .where((r) => (_course == 'Semua' || r.course == _course) && (_dept == 'Semua' || r.dept == _dept) && (_status == 'Semua' || r.status == _status))
            .toList()
          ..sort((a, b) => a.person.compareTo(b.person));
        Widget dd(String label, String v, List<String> items, void Function(String) on) => DropdownButton<String>(
              value: v,
              underline: const SizedBox(),
              items: [for (final i in items) DropdownMenuItem(value: i, child: Text(i == 'Semua' ? 'Semua $label' : i, overflow: TextOverflow.ellipsis))],
              onChanged: (x) => setState(() => on(x!)),
            );
        return PageBody(children: [
          PageHead('Laporan', sub: '${rows.length} baris · ${rows.where((r) => r.completed).length} selesai · ${rows.where((r) => r.late).length} terlambat', actions: [
            FilledButton.icon(
              onPressed: () {
                String esc(String s) => '"${s.replaceAll('"', '""')}"';
                final csv = StringBuffer('Nama,Email,Divisi,Kelas,Tenggat,Langkah selesai,Total langkah,Nilai post test terbaik,Status\n');
                for (final r in rows) {
                  csv.writeln([esc(r.person), esc(r.email), esc(r.dept), esc(r.course), r.dueAt == null ? '' : fmtDate(r.dueAt), r.stepsDone, r.stepsTotal, r.bestScore ?? '', r.status].join(','));
                }
                if (!downloadText('laporan-pelatihan-${DateTime.now().toIso8601String().substring(0, 10)}.csv', csv.toString())) {
                  toast(context, 'Ekspor hanya tersedia di browser.');
                }
              },
              icon: const Icon(Icons.download, size: 18),
              label: const Text('Ekspor CSV'),
            ),
          ]),
          Wrap(spacing: 16, runSpacing: 8, children: [
            dd('kelas', _course, courses, (v) => _course = v),
            dd('divisi', _dept, depts, (v) => _dept = v),
            dd('status', _status, const ['Semua', 'Selesai', 'Berjalan', 'Belum mulai', 'Terlambat'], (v) => _status = v),
          ]),
          const SizedBox(height: 12),
          DataList(
            headers: const ['Karyawan', 'Kelas', 'Tenggat', 'Kemajuan', 'Nilai', 'Status'],
            flex: const [4, 5, 2, 3, 1, 2],
            rows: [
              for (final r in rows)
                [
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(r.person, style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text(r.dept, style: small),
                  ]),
                  Text(r.course, maxLines: 2, overflow: TextOverflow.ellipsis),
                  Text(r.dueAt == null ? '-' : fmtDate(r.dueAt), style: TextStyle(color: r.late ? C.bad : C.ink)),
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    SizedBox(width: 56, child: Bar(r.stepsTotal == 0 ? 0 : r.stepsDone / r.stepsTotal, color: r.completed ? C.ok : C.navy)),
                    const SizedBox(width: 6),
                    Text('${r.stepsDone}/${r.stepsTotal}', style: small),
                  ]),
                  Text(r.bestScore?.toString() ?? '-', style: const TextStyle(fontFeatures: tabular)),
                  Pill(r.status, tone: r.completed ? Tone.ok : (r.late ? Tone.bad : (r.stepsDone > 0 ? Tone.navy : Tone.neutral))),
                ],
            ],
          ),
        ]);
      },
    );
  }
}

// ---------------------------------------------------------------- Settings

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late Company co = Scope.read(context).company!;
  late final _name = TextEditingController(text: co.name);
  late final _mark = TextEditingController(text: co.mark);
  late final _pass = TextEditingController(text: '${co.passMark}');
  late final _email = TextEditingController(text: co.hrEmail ?? '');
  late final _wa = TextEditingController(text: co.hrWhatsapp ?? '');
  bool _busy = false;

  @override
  Widget build(BuildContext context) => PageBody(maxWidth: 720, children: [
        const PageHead('Pengaturan perusahaan', sub: 'Tampil di aplikasi karyawan dan sertifikat.'),
        Box(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Identitas', style: h3(context)),
            const SizedBox(height: 12),
            Row(children: [
              Container(
                width: 64,
                height: 64,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: C.navy, borderRadius: BorderRadius.circular(14)),
                child: co.logoUrl != null
                    ? ClipRRect(borderRadius: BorderRadius.circular(14), child: Image.network(co.logoUrl!, width: 64, height: 64, fit: BoxFit.cover))
                    : Text(co.mark, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 20)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Wrap(spacing: 8, runSpacing: 8, children: [
                  OutlinedButton(
                    onPressed: () async {
                      final f = await pickOne(type: FileType.image);
                      if (f == null || !context.mounted) return;
                      try {
                        final url = await Scope.read(context).repo.uploadMedia(f.bytes, f.name);
                        setState(() => co = co.copyWith(logoUrl: url));
                      } catch (e) {
                        if (context.mounted) toast(context, errText(e));
                      }
                    },
                    child: const Text('Unggah logo'),
                  ),
                  const Text('PNG persegi, minimal 256 px. Teks "Powered by Bigma" tetap tampil.', style: small),
                ]),
              ),
            ]),
            const SizedBox(height: 16),
            TextField(controller: _name, decoration: const InputDecoration(labelText: 'Nama perusahaan')),
            const SizedBox(height: 12),
            TextField(controller: _mark, maxLength: 3, decoration: const InputDecoration(labelText: 'Inisial (tanpa logo dan untuk nomor sertifikat)')),
          ]),
        ),
        const SizedBox(height: 16),
        Box(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Aturan belajar', style: h3(context)),
            const SizedBox(height: 12),
            TextField(controller: _pass, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Nilai lulus standar', helperText: 'Dipakai semua kelas kecuali diatur sendiri di kelas.')),
          ]),
        ),
        const SizedBox(height: 16),
        Box(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Kontak HR untuk karyawan', style: h3(context)),
            const SizedBox(height: 12),
            TextField(controller: _email, decoration: const InputDecoration(labelText: 'Email HR')),
            const SizedBox(height: 12),
            TextField(controller: _wa, decoration: const InputDecoration(labelText: 'WhatsApp HR')),
          ]),
        ),
        const SizedBox(height: 20),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton(
            onPressed: _busy
                ? null
                : () async {
                    final pm = int.tryParse(_pass.text.trim());
                    if (pm == null || pm < 0 || pm > 100) return toast(context, 'Nilai lulus harus 0 sampai 100.');
                    setState(() => _busy = true);
                    final st = Scope.read(context);
                    try {
                      final saved = await st.repo.updateCompany(co.copyWith(
                          name: _name.text.trim(), mark: _mark.text.trim().toUpperCase(), passMark: pm, hrEmail: _email.text.trim(), hrWhatsapp: _wa.text.trim()));
                      st.setCompany(saved);
                      if (context.mounted) toast(context, 'Pengaturan disimpan.');
                    } catch (e) {
                      if (context.mounted) toast(context, errText(e));
                    } finally {
                      if (mounted) setState(() => _busy = false);
                    }
                  },
            child: const Text('Simpan pengaturan'),
          ),
        ),
      ]);
}
