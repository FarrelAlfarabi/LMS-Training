import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets/common.dart';

// ---------------------------------------------------------------- Home

class HomePage extends StatelessWidget {
  const HomePage({super.key});
  @override
  Widget build(BuildContext context) {
    final st = Scope.of(context);
    return Loader<(List<LearnerCourse>, List<LeaderRow>, List<Certificate>, List<Notif>)>(
      load: () async => (await st.repo.myCourses(), await st.repo.leaderboard(), await st.repo.certificates(), await st.repo.notifications()),
      builder: (c, d, _) {
        final (courses, board, certs, notifs) = d;
        final todo = courses.where((x) => x.assigned && !x.completed).toList()
          ..sort((a, b) => (a.dueAt ?? DateTime(2100)).compareTo(b.dueAt ?? DateTime(2100)));
        final me = board.where((r) => r.isMe).firstOrNull;
        final cont = courses.where((x) => x.started && !x.completed && !x.failedOut).firstOrNull ?? todo.firstOrNull;
        final doneCount = courses.where((x) => x.completed).length;
        return PageBody(
          rail: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            _BoardMini(board),
            const SizedBox(height: 16),
            _NotifMini(notifs.take(3).toList()),
          ]),
          children: [
            PageHead('Halo, ${st.profile!.firstName}', sub: todo.isEmpty ? 'Semua kelas dari HR sudah selesai. Kerja bagus.' : 'Ada ${todo.length} kelas dari HR yang perlu diselesaikan.'),
            KpiStrip([
              ('Poin', fmtNum(st.points), null),
              ('Peringkat', me == null ? '-' : '${me.rank}', 'dari ${board.length} karyawan'),
              ('Kelas selesai', '$doneCount', 'dari ${courses.where((x) => x.assigned).length} ditugaskan'),
              ('Sertifikat', '${certs.length}', null),
            ]),
            const SizedBox(height: 24),
            if (cont != null) ...[
              const SectionTitle('Lanjutkan belajar'),
              _ContinueCard(cont),
              const SizedBox(height: 24),
            ],
            SectionTitle('Tugas dari HR', trailing: TextButton(onPressed: () => context.go('/classes'), child: const Text('Semua kelas'))),
            if (todo.isEmpty)
              const Empty(Icons.task_alt, 'Tidak ada tugas', 'Kelas baru dari HR akan muncul di sini beserta tenggatnya.')
            else
              Box(
                padding: EdgeInsets.zero,
                child: Column(children: [
                  for (var i = 0; i < todo.length; i++) ...[if (i > 0) const Divider(height: 1), _TaskRow(todo[i])],
                ]),
              ),
          ],
        );
      },
    );
  }
}

class _ContinueCard extends StatelessWidget {
  final LearnerCourse lc;
  const _ContinueCard(this.lc);
  @override
  Widget build(BuildContext context) {
    final next = lc.nextStep;
    final phone = isPhone(context);
    final body = Padding(
      padding: const EdgeInsets.all(18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: 8, children: [Pill(lc.statusText, tone: Pill.toneFor(lc)), if (lc.dueAt != null) Pill('Tenggat ${fmtDue(lc.dueAt)}', tone: lc.late ? Tone.bad : Tone.neutral)]),
        const SizedBox(height: 10),
        Text(lc.course.title, style: h2(context)),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: Bar(lc.progress)),
          const SizedBox(width: 12),
          Text('${lc.stepsDone} dari ${lc.stepsTotal} langkah', style: small.copyWith(fontFeatures: tabular)),
        ]),
        const SizedBox(height: 14),
        Wrap(spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
          FilledButton(onPressed: () => context.go('/class/${lc.course.id}'), child: Text(next == null ? 'Lihat kelas' : 'Lanjut: ${next.title}')),
          if (lc.postAttempts.isNotEmpty && !lc.completed) Text('Sisa ${lc.attemptsLeft} kesempatan post test', style: small),
        ]),
      ]),
    );
    return Box(
      padding: EdgeInsets.zero,
      child: phone
          ? Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              CourseArt(lc.course.art, height: 96, label: lc.course.category, radius: const BorderRadius.vertical(top: Radius.circular(13))),
              body
            ])
          : IntrinsicHeight(
              child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                SizedBox(width: 220, child: CourseArt(lc.course.art, label: lc.course.category, radius: const BorderRadius.horizontal(left: Radius.circular(13)))),
                Expanded(child: body),
              ]),
            ),
    );
  }
}

class _TaskRow extends StatelessWidget {
  final LearnerCourse lc;
  const _TaskRow(this.lc);
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: () => context.go('/class/${lc.course.id}'),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            SizedBox(width: 44, height: 44, child: CourseArt(lc.course.art, height: 44, radius: BorderRadius.circular(10))),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(lc.course.title, style: h3(context)),
                const SizedBox(height: 4),
                Wrap(spacing: 10, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  Pill(lc.statusText, tone: Pill.toneFor(lc)),
                  Text('${lc.stepsDone} dari ${lc.stepsTotal} langkah', style: small),
                  if (lc.dueAt != null)
                    Text('Tenggat ${fmtDue(lc.dueAt)} (${dueHint(lc.dueAt)})', style: small.copyWith(color: lc.late ? C.bad : C.muted, fontWeight: lc.late ? FontWeight.w600 : null)),
                ]),
              ]),
            ),
            const Icon(Icons.chevron_right, color: C.muted),
          ]),
        ),
      );
}

class _BoardMini extends StatelessWidget {
  final List<LeaderRow> rows;
  const _BoardMini(this.rows);
  @override
  Widget build(BuildContext context) {
    final top = rows.take(5).toList();
    final me = rows.where((r) => r.isMe).firstOrNull;
    if (me != null && !top.contains(me)) top.add(me);
    return Box(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [Expanded(child: Text('Peringkat poin', style: h3(context))), TextButton(onPressed: () => context.go('/leaderboard'), child: const Text('Lihat'))]),
        for (final r in top) _LeaderLine(r, compact: true),
      ]),
    );
  }
}

class _LeaderLine extends StatelessWidget {
  final LeaderRow r;
  final bool compact;
  const _LeaderLine(this.r, {this.compact = false});
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.symmetric(vertical: 2),
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: compact ? 6 : 10),
        decoration: BoxDecoration(color: r.isMe ? C.orange50 : null, borderRadius: BorderRadius.circular(8)),
        child: Row(children: [
          SizedBox(width: 28, child: Text('${r.rank}', style: TextStyle(fontWeight: FontWeight.w700, color: r.rank <= 3 ? C.navy : C.muted, fontFeatures: tabular))),
          Avatar(initialsOf(r.name), size: compact ? 26 : 32, me: r.isMe),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(r.isMe ? '${r.name} (Anda)' : r.name, style: const TextStyle(fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
              if (!compact && r.dept != null) Text(r.dept!, style: small),
            ]),
          ),
          Text(fmtNum(r.points), style: const TextStyle(fontWeight: FontWeight.w700, fontFeatures: tabular)),
        ]),
      );
}

class _NotifMini extends StatelessWidget {
  final List<Notif> n;
  const _NotifMini(this.n);
  @override
  Widget build(BuildContext context) => Box(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [Expanded(child: Text('Notifikasi', style: h3(context))), TextButton(onPressed: () => context.go('/notifications'), child: const Text('Semua'))]),
          if (n.isEmpty) const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Text('Belum ada notifikasi.', style: muted)),
          for (final x in n)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Padding(padding: const EdgeInsets.only(top: 6, right: 8), child: CircleAvatar(radius: 4, backgroundColor: x.read ? C.navy100 : C.orange)),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(x.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    Text(x.body, style: small),
                  ]),
                ),
              ]),
            ),
        ]),
      );
}

// ---------------------------------------------------------------- Classes

class ClassesPage extends StatefulWidget {
  const ClassesPage({super.key});
  @override
  State<ClassesPage> createState() => _ClassesPageState();
}

class _ClassesPageState extends State<ClassesPage> {
  int _tab = 0;
  final _q = TextEditingController();
  @override
  Widget build(BuildContext context) {
    final st = Scope.of(context);
    return Loader<List<LearnerCourse>>(
      load: st.repo.myCourses,
      builder: (c, all, _) {
        final q = _q.text.trim().toLowerCase();
        final tabs = [
          ('Wajib dari HR', all.where((x) => x.assigned && !x.completed).toList()),
          ('Pilihan sendiri', all.where((x) => !x.assigned && !x.completed).toList()),
          ('Selesai', all.where((x) => x.completed).toList()),
        ];
        final list = tabs[_tab].$2.where((x) => q.isEmpty || x.course.title.toLowerCase().contains(q) || x.course.category.toLowerCase().contains(q)).toList();
        return PageBody(children: [
          const PageHead('Kelas saya', sub: 'Kelas wajib dari HR dan kelas yang bisa Anda ikuti sendiri.'),
          TextField(
            controller: _q,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Cari kelas atau kategori'),
          ),
          const SizedBox(height: 12),
          _Tabs(labels: [for (final t in tabs) '${t.$1} (${t.$2.length})'], index: _tab, onTap: (i) => setState(() => _tab = i)),
          const SizedBox(height: 20),
          if (list.isEmpty)
            Empty(Icons.menu_book_outlined, q.isNotEmpty ? 'Tidak ada yang cocok' : 'Belum ada kelas di sini',
                q.isNotEmpty ? 'Coba kata lain.' : (_tab == 2 ? 'Kelas yang sudah lulus akan pindah ke sini.' : 'HR akan menambah kelas baru.'))
          else
            LayoutBuilder(builder: (c, box) {
              final cols = box.maxWidth > 900 ? 3 : box.maxWidth > 560 ? 2 : 1;
              final w = (box.maxWidth - (cols - 1) * 16) / cols;
              return Wrap(spacing: 16, runSpacing: 16, children: [for (final x in list) SizedBox(width: w, child: CourseCard(x))]);
            }),
        ]);
      },
    );
  }
}

class _Tabs extends StatelessWidget {
  final List<String> labels;
  final int index;
  final void Function(int) onTap;
  const _Tabs({required this.labels, required this.index, required this.onTap});
  @override
  Widget build(BuildContext context) => Container(
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: C.line))),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            for (var i = 0; i < labels.length; i++)
              InkWell(
                onTap: () => onTap(i),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(border: Border(bottom: BorderSide(color: i == index ? C.navy : Colors.transparent, width: 2.5))),
                  child: Text(labels[i], style: TextStyle(fontWeight: i == index ? FontWeight.w700 : FontWeight.w500, color: i == index ? C.navy : C.muted)),
                ),
              ),
          ]),
        ),
      );
}

class CourseCard extends StatelessWidget {
  final LearnerCourse lc;
  const CourseCard(this.lc, {super.key});
  @override
  Widget build(BuildContext context) => Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(side: const BorderSide(color: C.line), borderRadius: BorderRadius.circular(14)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.go('/class/${lc.course.id}'),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            CourseArt(lc.course.art, height: 110, label: lc.course.category, radius: BorderRadius.zero),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(lc.course.title, style: h3(context), maxLines: 2, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 6),
                Text('${lc.course.durationLabel} · ${lc.stepsTotal} langkah · ${lc.course.totalPoints} poin', style: small),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: Bar(lc.progress, color: lc.completed ? C.ok : C.navy)),
                  const SizedBox(width: 10),
                  Text('${lc.stepsDone}/${lc.stepsTotal}', style: small.copyWith(fontFeatures: tabular)),
                ]),
                const SizedBox(height: 10),
                Wrap(spacing: 8, runSpacing: 6, children: [
                  Pill(lc.statusText, tone: Pill.toneFor(lc)),
                  if (lc.dueAt != null && !lc.completed) Pill('Tenggat ${fmtDue(lc.dueAt)}', tone: lc.late ? Tone.bad : Tone.neutral),
                ]),
              ]),
            ),
          ]),
        ),
      );
}

// ---------------------------------------------------------------- Class detail

class ClassPage extends StatelessWidget {
  final String id;
  const ClassPage(this.id, {super.key});
  @override
  Widget build(BuildContext context) {
    final st = Scope.of(context);
    return Loader<(LearnerCourse, List<Certificate>)>(
      load: () async => (await st.repo.course(id), await st.repo.certificates()),
      builder: (c, d, reload) {
        final (lc, certs) = d;
        final co = lc.course;
        final cert = certs.where((x) => x.courseId == co.id).firstOrNull;
        final next = lc.nextStep;
        final sections = <String?, List<LessonStep>>{};
        for (final s in co.steps) {
          sections.putIfAbsent(s.isTest ? '#${s.id}' : s.section, () => []).add(s);
        }
        return PageBody(
          rail: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Box(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Kemajuan Anda', style: h3(context)),
                const SizedBox(height: 12),
                Text('${(lc.progress * 100).round()}%', style: h1(context).copyWith(fontFeatures: tabular)),
                Text('${lc.stepsDone} dari ${lc.stepsTotal} langkah selesai', style: small),
                const SizedBox(height: 10),
                Bar(lc.progress, color: lc.completed ? C.ok : C.navy),
                const SizedBox(height: 16),
                const Divider(),
                _kv('Poin di kelas ini', '${lc.pointsGot} dari ${co.totalPoints}'),
                _kv('Nilai lulus post test', '${lc.passMark}'),
                _kv('Kesempatan post test', '${lc.attemptsLeft.clamp(0, co.maxAttempts)} dari ${co.maxAttempts} tersisa'),
                if (lc.bestPost != null) _kv('Nilai terbaik', '${lc.bestPost}'),
                _kv('Tenggat', lc.dueAt == null ? 'Tanpa tenggat' : fmtDateTime(lc.dueAt)),
              ]),
            ),
            const SizedBox(height: 16),
            Box(
              color: cert != null ? C.okBg : null,
              child: Row(children: [
                Icon(Icons.workspace_premium_outlined, color: cert != null ? C.ok : C.muted, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(cert != null ? 'Sertifikat sudah terbit' : 'Sertifikat', style: h3(context)),
                    Text(cert != null ? 'No. ${cert.number}' : 'Lulus post test dengan nilai ${lc.passMark} atau lebih.', style: small),
                  ]),
                ),
                if (cert != null) TextButton(onPressed: () => context.go('/certificates/${cert.id}'), child: const Text('Lihat')),
              ]),
            ),
          ]),
          children: [
            BackLink('Kelas saya', () => context.go('/classes')),
            const SizedBox(height: 12),
            CourseArt(co.art, height: isPhone(context) ? 120 : 160, label: co.category),
            const SizedBox(height: 18),
            Wrap(spacing: 8, runSpacing: 6, children: [
              Pill(lc.statusText, tone: Pill.toneFor(lc)),
              Pill(lc.assigned ? 'Wajib dari HR' : 'Pilihan sendiri', tone: lc.assigned ? Tone.navy : Tone.neutral),
              if (lc.dueAt != null && !lc.completed) Pill('Tenggat ${fmtDue(lc.dueAt)} · ${dueHint(lc.dueAt)}', tone: lc.late ? Tone.bad : Tone.neutral),
            ]),
            const SizedBox(height: 10),
            Text(co.title, style: h1(context)),
            const SizedBox(height: 6),
            Text('${co.durationLabel} · ${co.steps.length} langkah · ${co.totalPoints} poin', style: muted),
            const SizedBox(height: 12),
            Text(co.description),
            if (co.outcomes.isNotEmpty) ...[
              const SizedBox(height: 18),
              Text('Setelah kelas ini Anda bisa', style: h3(context)),
              const SizedBox(height: 8),
              for (final o in co.outcomes)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Icon(Icons.check_circle_outline, size: 18, color: C.ok),
                    const SizedBox(width: 8),
                    Expanded(child: Text(o)),
                  ]),
                ),
            ],
            if (lc.failedOut) ...[
              const SizedBox(height: 16),
              Box(
                color: C.badBg,
                child: const Text('Kesempatan post test sudah habis. Hubungi HR jika Anda perlu kesempatan tambahan.', style: TextStyle(color: C.bad)),
              ),
            ],
            const SizedBox(height: 24),
            SectionTitle('Langkah belajar', trailing: next != null && !lc.failedOut ? FilledButton(onPressed: () => openStep(context, lc, next), child: Text(lc.started ? 'Lanjutkan' : 'Mulai kelas')) : null),
            Box(
              padding: EdgeInsets.zero,
              child: Column(children: [
                for (final e in sections.entries.toList().asMap().entries) ...[
                  if (e.key > 0) const Divider(height: 1),
                  if (e.value.key != null && !e.value.key!.startsWith('#'))
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 2),
                      child: Row(children: [
                        Expanded(child: Text(e.value.key!, style: h3(context))),
                        Text('${e.value.value.where((s) => lc.doneSteps.contains(s.id)).length} dari ${e.value.value.length} selesai', style: small),
                      ]),
                    ),
                  for (final s in e.value.value) _StepRow(lc, s),
                ],
              ]),
            ),
          ],
        );
      },
    );
  }

  Widget _kv(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(children: [Expanded(child: Text(k, style: muted)), Text(v, style: const TextStyle(fontWeight: FontWeight.w600))]),
      );
}

void openStep(BuildContext context, LearnerCourse lc, LessonStep s) {
  if (s.isTest) {
    context.go('/class/${lc.course.id}/test/${s.kind}');
  } else {
    context.go('/class/${lc.course.id}/step/${s.id}');
  }
}

class _StepRow extends StatelessWidget {
  final LearnerCourse lc;
  final LessonStep s;
  const _StepRow(this.lc, this.s);
  @override
  Widget build(BuildContext context) {
    final done = lc.doneSteps.contains(s.id);
    final open = lc.isOpen(s);
    final blocked = s.kind == 'post' && lc.failedOut;
    final icon = switch (s.kind) { 'video' => Icons.play_circle_outline, 'pdf' => Icons.description_outlined, _ => Icons.quiz_outlined };
    String meta = s.meta;
    if (s.kind == 'post') {
      meta = 'Nilai lulus ${lc.passMark} · sisa ${lc.attemptsLeft.clamp(0, lc.course.maxAttempts)} dari ${lc.course.maxAttempts} kesempatan · ${lc.course.timeLimitMin} menit';
      if (lc.bestPost != null) meta += ' · nilai terbaik ${lc.bestPost}';
    }
    final prev = lc.course.steps.takeWhile((x) => x.id != s.id).where((x) => !lc.doneSteps.contains(x.id)).firstOrNull;
    return InkWell(
      onTap: open && !blocked && !(done && s.isTest)
          ? () => openStep(context, lc, s)
          : (!open ? () => toast(context, 'Selesaikan "${prev?.title}" dulu untuk membuka langkah ini.') : null),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(color: done ? C.okBg : (open ? C.navy50 : const Color(0xFFF3F4F7)), shape: BoxShape.circle),
            child: Icon(done ? Icons.check : (open ? icon : Icons.lock_outline), size: 18, color: done ? C.ok : (open ? C.navy : C.muted)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s.title, style: TextStyle(fontWeight: FontWeight.w600, color: open ? C.ink : C.muted)),
              Text(meta, style: small),
              if (!open) Text('Terkunci sampai "${prev?.title}" selesai', style: small.copyWith(fontStyle: FontStyle.italic)),
            ]),
          ),
          const SizedBox(width: 8),
          Text('+${s.points}', style: TextStyle(fontWeight: FontWeight.w700, color: done ? C.ok : C.orangeInk, fontSize: 13, fontFeatures: tabular)),
          if (open && !done && !blocked) const Padding(padding: EdgeInsets.only(left: 6), child: Icon(Icons.chevron_right, color: C.muted)),
        ]),
      ),
    );
  }
}

// ---------------------------------------------------------------- Points, board, certificates

class PointsPage extends StatelessWidget {
  const PointsPage({super.key});
  @override
  Widget build(BuildContext context) {
    final st = Scope.of(context);
    return Loader<(List<PointsEntry>, List<LeaderRow>)>(
      load: () async => (await st.repo.pointsHistory(), await st.repo.leaderboard()),
      builder: (c, d, _) {
        final (h, b) = d;
        final me = b.where((r) => r.isMe).firstOrNull;
        final month = h.where((e) => e.at.toLocal().month == DateTime.now().month && e.at.toLocal().year == DateTime.now().year).fold(0, (a, e) => a + e.amount);
        return PageBody(maxWidth: 820, children: [
          const PageHead('Poin saya', sub: 'Poin didapat dari setiap materi dan tes yang selesai.'),
          KpiStrip([
            ('Total poin', fmtNum(h.fold(0, (a, e) => a + e.amount)), null),
            ('Bulan ini', '+${fmtNum(month)}', null),
            ('Peringkat', me == null ? '-' : '${me.rank}', 'dari ${b.length}'),
          ]),
          const SizedBox(height: 24),
          const SectionTitle('Riwayat poin'),
          if (h.isEmpty)
            const Empty(Icons.stars_outlined, 'Belum ada poin', 'Selesaikan materi pertama untuk mendapat poin.')
          else
            Box(
              padding: EdgeInsets.zero,
              child: Column(children: [
                for (var i = 0; i < h.length; i++) ...[
                  if (i > 0) const Divider(height: 1),
                  ListTile(
                    leading: const CircleAvatar(backgroundColor: C.orange50, child: Icon(Icons.add, color: C.orangeInk, size: 18)),
                    title: Text(h[i].reason, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(fmtDateTime(h[i].at), style: small),
                    trailing: Text('+${h[i].amount}', style: const TextStyle(fontWeight: FontWeight.w700, color: C.ok, fontFeatures: tabular)),
                  ),
                ],
              ]),
            ),
        ]);
      },
    );
  }
}

class LeaderboardPage extends StatelessWidget {
  const LeaderboardPage({super.key});
  @override
  Widget build(BuildContext context) {
    final st = Scope.of(context);
    return Loader<List<LeaderRow>>(
      load: st.repo.leaderboard,
      builder: (c, b, _) => PageBody(maxWidth: 820, children: [
        PageHead('Peringkat', sub: 'Semua karyawan ${st.company?.name ?? ''}, berdasarkan total poin.'),
        Box(
          color: C.navy50,
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            const Icon(Icons.visibility_off_outlined, color: C.navy, size: 20),
            const SizedBox(width: 10),
            Expanded(child: Text(st.profile!.hideOnLeaderboard ? 'Nama Anda disembunyikan untuk orang lain.' : 'Tidak ingin nama Anda tampil? Anda bisa menyembunyikannya.')),
            TextButton(onPressed: () => context.go('/profile'), child: const Text('Atur')),
          ]),
        ),
        const SizedBox(height: 16),
        Box(padding: const EdgeInsets.all(8), child: Column(children: [for (final r in b) _LeaderLine(r)])),
      ]),
    );
  }
}

class CertificatesPage extends StatelessWidget {
  const CertificatesPage({super.key});
  @override
  Widget build(BuildContext context) {
    final st = Scope.of(context);
    return Loader<List<Certificate>>(
      load: st.repo.certificates,
      builder: (c, list, _) => PageBody(children: [
        const PageHead('Sertifikat', sub: 'Terbit otomatis saat Anda lulus post test.'),
        if (list.isEmpty)
          const Empty(Icons.workspace_premium_outlined, 'Belum ada sertifikat', 'Lulus post test di kelas mana pun untuk mendapat sertifikat pertama.')
        else
          LayoutBuilder(builder: (c, box) {
            final cols = box.maxWidth > 700 ? 2 : 1;
            final w = (box.maxWidth - (cols - 1) * 16) / cols;
            return Wrap(spacing: 16, runSpacing: 16, children: [
              for (final x in list)
                SizedBox(
                  width: w,
                  child: Box(
                    child: Row(children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(color: C.navy, borderRadius: BorderRadius.circular(12)),
                        child: const Icon(Icons.workspace_premium, color: C.orange),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(x.courseTitle, style: h3(context)),
                          Text('No. ${x.number} · ${fmtDate(x.issuedAt)} · nilai ${x.score}', style: small),
                        ]),
                      ),
                      FilledButton(onPressed: () => context.go('/certificates/${x.id}'), child: const Text('Lihat')),
                    ]),
                  ),
                ),
            ]);
          }),
      ]),
    );
  }
}

class CertificatePage extends StatelessWidget {
  final String id;
  const CertificatePage(this.id, {super.key});
  @override
  Widget build(BuildContext context) {
    final st = Scope.of(context);
    return Loader<List<Certificate>>(
      load: st.repo.certificates,
      builder: (c, list, _) {
        final x = list.where((e) => e.id == id).firstOrNull;
        if (x == null) return const Center(child: Text('Sertifikat tidak ditemukan.'));
        final phone = isPhone(context);
        return PageBody(maxWidth: 900, children: [
          PageHead('Sertifikat', back: BackLink('Semua sertifikat', () => context.go('/certificates')), actions: [
            OutlinedButton.icon(onPressed: () => toast(context, 'Pakai Cetak di browser lalu pilih Simpan sebagai PDF.'), icon: const Icon(Icons.download_outlined, size: 18), label: const Text('Unduh PDF')),
          ]),
          AspectRatio(
            aspectRatio: phone ? 0.8 : 1.414,
            child: Container(
              decoration: BoxDecoration(color: Colors.white, border: Border.all(color: C.navy, width: 2), borderRadius: BorderRadius.circular(6)),
              padding: const EdgeInsets.all(8),
              child: Container(
                decoration: BoxDecoration(border: Border.all(color: C.navy200)),
                padding: EdgeInsets.all(phone ? 18 : 40),
                child: Column(children: [
                  Row(children: [
                    Container(
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: C.navy, borderRadius: BorderRadius.circular(9)),
                      child: Text(st.company?.mark ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Text(st.company?.name ?? '', style: const TextStyle(fontWeight: FontWeight.w700))),
                    Text('No. ${x.number}', style: small),
                  ]),
                  const Spacer(),
                  Text('SERTIFIKAT KELULUSAN', style: TextStyle(letterSpacing: 3, color: C.orangeInk, fontWeight: FontWeight.w700, fontSize: phone ? 11 : 13)),
                  const SizedBox(height: 12),
                  const Text('Diberikan kepada', style: muted),
                  const SizedBox(height: 6),
                  Text(x.ownerName, textAlign: TextAlign.center, style: h1(context).copyWith(fontSize: phone ? 24 : 34, color: C.navy)),
                  const SizedBox(height: 10),
                  const Text('atas kelulusan kelas', style: muted),
                  const SizedBox(height: 4),
                  Text(x.courseTitle, textAlign: TextAlign.center, style: h2(context)),
                  const SizedBox(height: 8),
                  Text('Nilai post test ${x.score}', style: muted),
                  const Spacer(),
                  Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(fmtDate(x.issuedAt), style: const TextStyle(fontWeight: FontWeight.w600)),
                        const Text('Tanggal terbit', style: small),
                      ]),
                    ),
                    Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Row(mainAxisSize: MainAxisSize.min, children: const [
                        Text('Powered by ', style: small),
                        Text('Bigma', style: TextStyle(fontWeight: FontWeight.w800, color: C.navy, fontSize: 12)),
                      ]),
                    ]),
                  ]),
                ]),
              ),
            ),
          ),
        ]);
      },
    );
  }
}

// ---------------------------------------------------------------- Notifications, profile, help

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});
  @override
  Widget build(BuildContext context) {
    final st = Scope.of(context);
    return Loader<List<Notif>>(
      load: st.repo.notifications,
      builder: (c, list, reload) => PageBody(maxWidth: 820, children: [
        PageHead('Notifikasi', actions: [
          if (list.any((n) => !n.read))
            OutlinedButton(
              onPressed: () async {
                await st.repo.markRead(null);
                await st.refresh();
                reload();
              },
              child: const Text('Tandai semua dibaca'),
            ),
        ]),
        if (list.isEmpty)
          const Empty(Icons.notifications_none, 'Belum ada notifikasi', 'Tugas baru, pengingat tenggat, dan sertifikat akan muncul di sini.')
        else
          Box(
            padding: EdgeInsets.zero,
            child: Column(children: [
              for (var i = 0; i < list.length; i++) ...[
                if (i > 0) const Divider(height: 1),
                InkWell(
                  onTap: () async {
                    if (!list[i].read) {
                      await st.repo.markRead(list[i].id);
                      await st.refresh();
                    }
                    if (context.mounted && list[i].link != null) context.go(list[i].link!);
                  },
                  child: Container(
                    color: list[i].read ? null : const Color(0xFFFFFAF5),
                    padding: const EdgeInsets.all(16),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Padding(padding: const EdgeInsets.only(top: 6, right: 12), child: CircleAvatar(radius: 5, backgroundColor: list[i].read ? C.navy100 : C.orange)),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(list[i].title, style: TextStyle(fontWeight: list[i].read ? FontWeight.w600 : FontWeight.w800)),
                          Text(list[i].body, style: muted),
                          const SizedBox(height: 4),
                          Text(fmtAgo(list[i].at), style: small),
                        ]),
                      ),
                      if (!list[i].read) const Pill('Baru', tone: Tone.orange),
                    ]),
                  ),
                ),
              ],
            ]),
          ),
      ]),
    );
  }
}

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});
  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late final _phone = TextEditingController(text: Scope.read(context).profile?.phone ?? '');
  @override
  Widget build(BuildContext context) {
    final st = Scope.of(context);
    final p = st.profile!;
    Widget ro(String k, String? v) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(children: [
            SizedBox(width: 130, child: Text(k, style: muted)),
            Expanded(child: Text(v ?? '-', style: const TextStyle(fontWeight: FontWeight.w600))),
          ]),
        );
    return PageBody(maxWidth: 720, children: [
      const PageHead('Profil saya'),
      Box(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Avatar(p.initials, size: 56),
            const SizedBox(width: 16),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(p.fullName, style: h2(context)),
                Text(p.email, style: muted),
              ]),
            ),
          ]),
          const SizedBox(height: 16),
          const Divider(),
          ro('Perusahaan', st.company?.name),
          ro('Divisi', p.dept),
          ro('Jabatan', p.title),
          const Text('Nama, divisi, dan jabatan diatur oleh HR. Hubungi HR jika ada yang salah.', style: small),
          const SizedBox(height: 16),
          TextField(controller: _phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Nomor ponsel (boleh kosong)')),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: () async {
              final np = await st.repo.updateMyProfile(phone: _phone.text.trim());
              st.setProfile(np);
              if (context.mounted) toast(context, 'Profil disimpan.');
            },
            child: const Text('Simpan'),
          ),
        ]),
      ),
      const SizedBox(height: 16),
      Box(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Privasi', style: h3(context)),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            value: p.hideOnLeaderboard,
            title: const Text('Sembunyikan nama saya di papan peringkat'),
            subtitle: const Text('Rekan kerja melihat "Karyawan" dan inisial divisi, bukan nama Anda.', style: small),
            onChanged: (v) async => st.setProfile(await st.repo.updateMyProfile(hideOnLeaderboard: v)),
          ),
          const Divider(),
          ro('Persetujuan data', p.consentAt == null ? 'Belum' : 'Disetujui ${fmtDate(p.consentAt)}'),
          Wrap(spacing: 8, children: [
            TextButton(onPressed: () => context.go('/privacy'), child: const Text('Kebijakan privasi')),
            TextButton(onPressed: () => context.go('/password'), child: const Text('Ganti kata sandi')),
          ]),
        ]),
      ),
      const SizedBox(height: 16),
      Align(
        alignment: Alignment.centerLeft,
        child: OutlinedButton.icon(
          onPressed: () async {
            await st.signOut();
            if (context.mounted) context.go('/login');
          },
          icon: const Icon(Icons.logout, size: 18),
          label: const Text('Keluar'),
        ),
      ),
    ]);
  }
}

class HelpPage extends StatelessWidget {
  const HelpPage({super.key});
  @override
  Widget build(BuildContext context) {
    final co = Scope.of(context).company;
    const faq = [
      ('Kenapa langkah berikutnya terkunci?', 'Langkah dibuka berurutan. Selesaikan langkah sebelumnya dulu. Video selesai saat diputar sampai akhir.'),
      ('Berapa kali saya boleh mengulang post test?', 'Sesuai aturan kelas, biasanya 3 kali. Sisa kesempatan tampil di halaman kelas.'),
      ('Kapan sertifikat terbit?', 'Langsung setelah Anda lulus post test.'),
      ('Saya lupa kata sandi.', 'Pilih "Lupa kata sandi" di halaman masuk. Tautan dikirim ke email kantor Anda.'),
      ('Data saya dipakai untuk apa?', 'Hanya untuk pelatihan di perusahaan Anda. Lihat kebijakan privasi.'),
    ];
    return PageBody(maxWidth: 820, children: [
      const PageHead('Bantuan'),
      Box(
        padding: EdgeInsets.zero,
        child: Column(children: [
          for (final f in faq) ExpansionTile(title: Text(f.$1, style: const TextStyle(fontWeight: FontWeight.w600)), childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16), children: [Text(f.$2)]),
        ]),
      ),
      const SizedBox(height: 16),
      Box(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Masih butuh bantuan?', style: h3(context)),
          const SizedBox(height: 6),
          Text('Hubungi HR ${co?.name ?? ''}:', style: muted),
          const SizedBox(height: 6),
          if (co?.hrEmail != null) Text('Email: ${co!.hrEmail}'),
          if (co?.hrWhatsapp != null) Text('WhatsApp: ${co!.hrWhatsapp}'),
        ]),
      ),
    ]);
  }
}

class PrivacyPage extends StatelessWidget {
  const PrivacyPage({super.key});
  @override
  Widget build(BuildContext context) => PageBody(maxWidth: 760, children: [
        PageHead('Kebijakan privasi', sub: 'Draf untuk prototipe. Teks final perlu ditinjau bagian hukum.', back: BackLink('Kembali', () => context.canPop() ? context.pop() : context.go('/'))),
        for (final s in const [
          ('Data yang dikumpulkan', 'Nama, email kantor, divisi, jabatan, nomor ponsel bila diisi, kemajuan belajar, jawaban dan nilai tes, poin, sertifikat, serta catatan masuk.'),
          ('Tujuan', 'Menjalankan pelatihan karyawan, memberi laporan kepada HR perusahaan Anda, dan menerbitkan sertifikat.'),
          ('Siapa yang bisa melihat', 'Anda melihat data Anda sendiri. HR perusahaan Anda melihat kemajuan dan nilai karyawan di perusahaan itu saja. Bigma sebagai pemroses data hanya mengakses untuk dukungan teknis.'),
          ('Penyimpanan', 'Data disimpan selama Anda bekerja di perusahaan dan dihapus atau dianonimkan setelah masa simpan yang ditetapkan perusahaan.'),
          ('Hak Anda', 'Sesuai UU No. 27 Tahun 2022, Anda berhak meminta akses, perbaikan, penghapusan, dan menarik persetujuan melalui HR.'),
        ]) ...[
          Text(s.$1, style: h3(context)),
          const SizedBox(height: 6),
          Text(s.$2),
          const SizedBox(height: 18),
        ],
      ]);
}
