import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';
import '../models.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'learner.dart' show openStep;

Uri mediaUri(String url) => Uri.base.resolve(url);

/// Video or PDF lesson. A video counts as done when it plays to the end.
class StepPage extends StatelessWidget {
  final String courseId, stepId;
  const StepPage(this.courseId, this.stepId, {super.key});
  @override
  Widget build(BuildContext context) {
    final st = Scope.of(context);
    return Loader<LearnerCourse>(
      key: ValueKey(stepId),
      load: () => st.repo.course(courseId),
      builder: (c, lc, reload) {
        final s = lc.course.steps.where((x) => x.id == stepId).firstOrNull;
        if (s == null) return const Center(child: Text('Materi tidak ditemukan.'));
        if (!lc.isOpen(s)) {
          return PageBody(maxWidth: 720, children: [
            BackLink(lc.course.title, () => context.go('/class/$courseId')),
            const SizedBox(height: 20),
            const Empty(Icons.lock_outline, 'Materi ini masih terkunci', 'Selesaikan langkah sebelumnya dulu.'),
          ]);
        }
        final idx = lc.course.steps.indexOf(s);
        return PageBody(maxWidth: 980, children: [
          BackLink(lc.course.title, () => context.go('/class/$courseId')),
          const SizedBox(height: 10),
          Text('Langkah ${idx + 1} dari ${lc.course.steps.length}${s.section != null ? ' · ${s.section}' : ''}', style: small),
          const SizedBox(height: 4),
          Text(s.title, style: h1(context)),
          const SizedBox(height: 16),
          _Lesson(lc: lc, step: s),
        ]);
      },
    );
  }
}

class _Lesson extends StatefulWidget {
  final LearnerCourse lc;
  final LessonStep step;
  const _Lesson({required this.lc, required this.step});
  @override
  State<_Lesson> createState() => _LessonState();
}

class _LessonState extends State<_Lesson> {
  VideoPlayerController? _v;
  bool _ended = false, _opened = false, _busy = false, _failed = false;
  late bool _done = widget.lc.doneSteps.contains(widget.step.id);

  @override
  void initState() {
    super.initState();
    if (widget.step.kind == 'video' && widget.step.mediaUrl != null) {
      _v = VideoPlayerController.networkUrl(mediaUri(widget.step.mediaUrl!))
        ..initialize().then((_) => setState(() {})).catchError((_) => setState(() => _failed = true))
        ..addListener(_tick);
    }
  }

  void _tick() {
    final v = _v!.value;
    if (!_ended && v.isInitialized && v.duration > Duration.zero && v.position >= v.duration - const Duration(milliseconds: 400)) {
      setState(() => _ended = true);
      if (!_done) _complete();
    } else {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _v?.removeListener(_tick);
    _v?.dispose();
    super.dispose();
  }

  Future<void> _complete() async {
    if (_busy || _done) return;
    setState(() => _busy = true);
    final st = Scope.read(context);
    try {
      final pts = await st.repo.completeStep(widget.step.id);
      await st.refresh();
      setState(() => _done = true);
      if (mounted && pts > 0) toast(context, 'Materi selesai. +$pts poin');
    } catch (e) {
      if (mounted) toast(context, errText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _next() async {
    final st = Scope.read(context);
    final lc = await st.repo.course(widget.lc.course.id);
    if (!mounted) return;
    final n = lc.nextStep;
    if (n == null) {
      context.go('/class/${lc.course.id}');
    } else {
      openStep(context, lc, n);
    }
  }

  String _t(Duration d) => '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final s = widget.step;
    final Widget media;
    if (s.kind == 'video') {
      final v = _v;
      media = ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Container(
          color: Colors.black,
          child: Column(children: [
            AspectRatio(
              aspectRatio: 16 / 9,
              child: _failed
                  ? const Center(child: Text('Video tidak bisa diputar. Periksa koneksi lalu muat ulang.', style: TextStyle(color: Colors.white)))
                  : (v == null || !v.value.isInitialized)
                      ? const Center(child: CircularProgressIndicator(color: Colors.white))
                      : GestureDetector(onTap: () => v.value.isPlaying ? v.pause() : v.play(), child: VideoPlayer(v)),
            ),
            if (v != null && v.value.isInitialized)
              Container(
                color: C.ink,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(children: [
                  IconButton(
                    tooltip: v.value.isPlaying ? 'Jeda' : 'Putar',
                    onPressed: () => v.value.isPlaying ? v.pause() : v.play(),
                    icon: Icon(v.value.isPlaying ? Icons.pause : Icons.play_arrow, color: Colors.white),
                  ),
                  Text('${_t(v.value.position)} / ${_t(v.value.duration)}', style: const TextStyle(color: Colors.white, fontSize: 12, fontFeatures: tabular)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: VideoProgressIndicator(v,
                        allowScrubbing: _done, colors: const VideoProgressColors(playedColor: C.orange, bufferedColor: Color(0x55FFFFFF), backgroundColor: Color(0x33FFFFFF))),
                  ),
                ]),
              ),
          ]),
        ),
      );
    } else {
      media = Box(
        child: Row(children: [
          Container(
            width: 56,
            height: 64,
            decoration: BoxDecoration(color: C.badBg, borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.picture_as_pdf_outlined, color: C.bad, size: 30),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s.title, style: h3(context)),
              Text(s.meta, style: small),
            ]),
          ),
          FilledButton.icon(
            onPressed: s.mediaUrl == null
                ? null
                : () async {
                    await launchUrl(mediaUri(s.mediaUrl!), webOnlyWindowName: '_blank');
                    setState(() => _opened = true);
                  },
            icon: const Icon(Icons.open_in_new, size: 18),
            label: const Text('Buka dokumen'),
          ),
        ]),
      );
    }
    final status = _done
        ? Box(
            color: C.okBg,
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              const Icon(Icons.check_circle, color: C.ok),
              const SizedBox(width: 10),
              Expanded(child: Text('Selesai. +${s.points} poin sudah masuk.', style: const TextStyle(color: C.ok, fontWeight: FontWeight.w600))),
            ]),
          )
        : Box(
            color: C.navy50,
            padding: const EdgeInsets.all(14),
            child: Text(
              s.kind == 'video'
                  ? 'Tonton sampai akhir untuk menyelesaikan materi ini dan mendapat +${s.points} poin.'
                  : 'Buka dan baca dokumen, lalu tandai selesai untuk mendapat +${s.points} poin.',
            ),
          );
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      media,
      const SizedBox(height: 16),
      status,
      const SizedBox(height: 16),
      Wrap(spacing: 8, runSpacing: 8, children: [
        if (s.kind == 'pdf' && !_done) FilledButton(onPressed: _opened && !_busy ? _complete : null, child: const Text('Saya sudah membaca')),
        if (_done) FilledButton(onPressed: _next, child: const Text('Lanjut ke langkah berikutnya')),
        OutlinedButton(onPressed: () => context.go('/class/${widget.lc.course.id}'), child: const Text('Kembali ke kelas')),
      ]),
    ]);
  }
}

// ---------------------------------------------------------------- Tests

class TestPage extends StatelessWidget {
  final String courseId, kind;
  const TestPage(this.courseId, this.kind, {super.key});
  @override
  Widget build(BuildContext context) {
    final st = Scope.of(context);
    return Loader<(LearnerCourse, List<Question>)>(
      key: ValueKey('$courseId/$kind'),
      load: () async => (await st.repo.course(courseId), await st.repo.questions(courseId, kind)),
      builder: (c, d, reload) => _Test(lc: d.$1, qs: d.$2, kind: kind, reload: reload),
    );
  }
}

class _Test extends StatefulWidget {
  final LearnerCourse lc;
  final List<Question> qs;
  final String kind;
  final VoidCallback reload;
  const _Test({required this.lc, required this.qs, required this.kind, required this.reload});
  @override
  State<_Test> createState() => _TestState();
}

class _TestState extends State<_Test> {
  bool _started = false, _busy = false, _review = false;
  int _i = 0;
  late List<int?> _a = List.filled(widget.qs.length, null);
  TestResult? _res;
  Timer? _timer;
  int _left = 0;

  bool get _post => widget.kind == 'post';
  LessonStep get _step => widget.lc.course.stepOf(widget.kind)!;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _start() {
    setState(() {
      _started = true;
      _i = 0;
      _a = List.filled(widget.qs.length, null);
      _res = null;
      _review = false;
      _left = widget.lc.course.timeLimitMin * 60;
    });
    if (_post) {
      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 1), (t) {
        setState(() => _left--);
        if (_left <= 0) {
          t.cancel();
          _submit(force: true);
        }
      });
    }
  }

  Future<void> _submit({bool force = false}) async {
    final blank = _a.where((x) => x == null).length;
    if (!force) {
      final ok = await confirm(context, 'Kirim jawaban?',
          blank > 0 ? 'Masih ada $blank soal belum dijawab. Soal kosong dihitung salah.' : 'Jawaban tidak bisa diubah setelah dikirim.',
          yes: 'Kirim');
      if (!ok) return;
    }
    _timer?.cancel();
    setState(() => _busy = true);
    final st = Scope.read(context);
    try {
      final r = await st.repo.submitTest(widget.lc.course.id, widget.kind, _a);
      await st.refresh();
      setState(() => _res = r);
      if (mounted && r.passed == true) _askSurvey();
    } catch (e) {
      if (mounted) toast(context, errText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _askSurvey() async {
    int rating = 0;
    final note = TextEditingController();
    await Future.delayed(const Duration(milliseconds: 600));
    if (!mounted) return;
    final sent = await showDialog<bool>(
      context: context,
      builder: (d) => StatefulBuilder(
        builder: (d, set) => AlertDialog(
          title: Text('Bagaimana kelas ini?', style: h2(d)),
          content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Tidak wajib. Masukan Anda membantu HR memperbaiki materi.', style: muted),
            const SizedBox(height: 12),
            Row(children: [
              for (var k = 1; k <= 5; k++)
                IconButton(
                  tooltip: '$k dari 5',
                  onPressed: () => set(() => rating = k),
                  icon: Icon(k <= rating ? Icons.star_rounded : Icons.star_outline_rounded, color: C.orange, size: 32),
                ),
            ]),
            TextField(controller: note, maxLines: 2, decoration: const InputDecoration(hintText: 'Catatan (boleh kosong)')),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Lewati')),
            FilledButton(onPressed: rating == 0 ? null : () => Navigator.pop(d, true), child: const Text('Kirim')),
          ],
        ),
      ),
    );
    if (sent == true && mounted) {
      await Scope.read(context).repo.submitSurvey(widget.lc.course.id, rating, note.text.trim().isEmpty ? null : note.text.trim());
      if (mounted) toast(context, 'Terima kasih atas masukannya.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final lc = widget.lc;
    final back = BackLink(lc.course.title, () => context.go('/class/${lc.course.id}'));
    if (!lc.isOpen(_step)) {
      return PageBody(maxWidth: 720, children: [back, const SizedBox(height: 20), const Empty(Icons.lock_outline, 'Tes ini masih terkunci', 'Selesaikan semua materi sebelumnya dulu.')]);
    }
    if (_res != null) return _resultView(back);
    if (!_started) return _intro(back);
    return _questionView(back);
  }

  Widget _intro(Widget back) {
    final lc = widget.lc;
    final already = lc.doneSteps.contains(_step.id);
    final left = lc.attemptsLeft;
    final blocked = already || (_post && left <= 0) || widget.qs.isEmpty;
    Widget rule(IconData i, String t) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(children: [Icon(i, size: 20, color: C.navy), const SizedBox(width: 12), Expanded(child: Text(t))]),
        );
    return PageBody(maxWidth: 720, children: [
      back,
      const SizedBox(height: 12),
      PageHead(_post ? 'Post test' : 'Pre test', sub: lc.course.title),
      Box(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          rule(Icons.format_list_numbered, '${widget.qs.length} soal pilihan ganda'),
          if (_post) ...[
            rule(Icons.timer_outlined, 'Waktu ${lc.course.timeLimitMin} menit. Jawaban terkirim otomatis saat waktu habis.'),
            rule(Icons.flag_outlined, 'Nilai lulus ${lc.passMark} dari 100'),
            rule(Icons.replay, 'Sisa $left dari ${lc.course.maxAttempts} kesempatan'),
          ] else
            rule(Icons.info_outline, 'Tidak ada nilai lulus. Pre test mengukur pemahaman awal Anda dan hanya bisa dikerjakan sekali.'),
          rule(Icons.stars_outlined, _post ? '+${_step.points} poin jika lulus' : '+${_step.points} poin setelah selesai'),
        ]),
      ),
      if (_post && lc.postAttempts.isNotEmpty) ...[
        const SizedBox(height: 16),
        Text('Percobaan sebelumnya', style: h3(context)),
        const SizedBox(height: 8),
        Box(
          padding: EdgeInsets.zero,
          child: Column(children: [
            for (final (i, a) in lc.postAttempts.indexed) ...[
              if (i > 0) const Divider(height: 1),
              ListTile(
                title: Text('Percobaan ${i + 1}: nilai ${a.score}'),
                subtitle: Text(fmtDateTime(a.at), style: small),
                trailing: Pill(a.passed == true ? 'Lulus' : 'Belum lulus', tone: a.passed == true ? Tone.ok : Tone.bad),
              ),
            ],
          ]),
        ),
      ],
      const SizedBox(height: 20),
      if (already) const Text('Tes ini sudah selesai.', style: muted),
      if (_post && left <= 0 && !already) const Text('Kesempatan sudah habis. Hubungi HR untuk kesempatan tambahan.', style: TextStyle(color: C.bad)),
      if (widget.qs.isEmpty) const Text('Soal belum disiapkan HR.', style: muted),
      const SizedBox(height: 8),
      Align(alignment: Alignment.centerLeft, child: FilledButton(onPressed: blocked ? null : _start, child: const Text('Mulai tes'))),
    ]);
  }

  Widget _questionView(Widget back) {
    final q = widget.qs[_i];
    final answered = _a.where((x) => x != null).length;
    final low = _post && _left < 120;
    return PageBody(maxWidth: 820, children: [
      Row(children: [
        Expanded(child: Text('${_post ? 'Post test' : 'Pre test'} · ${widget.lc.course.title}', style: small, maxLines: 1, overflow: TextOverflow.ellipsis)),
        if (_post)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: low ? C.badBg : C.navy50, borderRadius: BorderRadius.circular(99)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.timer_outlined, size: 16, color: low ? C.bad : C.navy),
              const SizedBox(width: 4),
              Text('${_left ~/ 60}:${(_left % 60).toString().padLeft(2, '0')}',
                  style: TextStyle(fontWeight: FontWeight.w700, color: low ? C.bad : C.navy, fontFeatures: tabular)),
            ]),
          ),
      ]),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: Bar(answered / widget.qs.length)),
        const SizedBox(width: 10),
        Text('$answered dari ${widget.qs.length} dijawab', style: small),
      ]),
      const SizedBox(height: 20),
      Text('Soal ${_i + 1} dari ${widget.qs.length}', style: small.copyWith(fontWeight: FontWeight.w700, color: C.navy)),
      const SizedBox(height: 6),
      Text(q.body, style: h2(context)),
      const SizedBox(height: 16),
      for (var k = 0; k < q.options.length; k++)
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Material(
            color: _a[_i] == k ? C.navy50 : Colors.white,
            shape: RoundedRectangleBorder(
              side: BorderSide(color: _a[_i] == k ? C.navy : C.line, width: _a[_i] == k ? 1.6 : 1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => setState(() => _a[_i] = k),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(children: [
                  Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: _a[_i] == k ? C.navy : C.navy50, shape: BoxShape.circle),
                    child: Text(String.fromCharCode(65 + k), style: TextStyle(fontWeight: FontWeight.w700, color: _a[_i] == k ? Colors.white : C.navy)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(child: Text(q.options[k])),
                ]),
              ),
            ),
          ),
        ),
      const SizedBox(height: 10),
      Row(children: [
        OutlinedButton(onPressed: _i == 0 ? null : () => setState(() => _i--), child: const Text('Sebelumnya')),
        const Spacer(),
        if (_i < widget.qs.length - 1)
          FilledButton(onPressed: () => setState(() => _i++), child: const Text('Berikutnya'))
        else
          FilledButton(onPressed: _busy ? null : _submit, child: Text(_busy ? 'Mengirim...' : 'Kirim jawaban')),
      ]),
      const SizedBox(height: 24),
      Text('Lompat ke soal', style: small),
      const SizedBox(height: 8),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (var k = 0; k < widget.qs.length; k++)
          InkWell(
            onTap: () => setState(() => _i = k),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _a[k] != null ? C.navy : Colors.white,
                border: Border.all(color: k == _i ? C.orange : (_a[k] != null ? C.navy : C.navy200), width: k == _i ? 2 : 1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text('${k + 1}', style: TextStyle(fontWeight: FontWeight.w700, color: _a[k] != null ? Colors.white : C.navy)),
            ),
          ),
      ]),
      if (_i < widget.qs.length - 1) ...[
        const SizedBox(height: 20),
        Align(alignment: Alignment.centerLeft, child: TextButton(onPressed: _busy ? null : _submit, child: const Text('Kirim sekarang'))),
      ],
    ]);
  }

  Widget _resultView(Widget back) {
    final r = _res!;
    final lc = widget.lc;
    final left = r.maxAttempts - r.attemptsUsed;
    final pass = r.passed == true;
    final fail = r.passed == false;
    final color = pass ? C.ok : (fail ? C.bad : C.navy);
    return PageBody(maxWidth: 820, children: [
      back,
      const SizedBox(height: 16),
      Box(
        color: pass ? C.okBg : (fail ? C.badBg : C.navy50),
        padding: const EdgeInsets.all(24),
        child: Column(children: [
          Icon(pass ? Icons.emoji_events_outlined : (fail ? Icons.refresh : Icons.check_circle_outline), size: 40, color: color),
          const SizedBox(height: 8),
          Text(pass ? 'Selamat, Anda lulus' : (fail ? 'Belum lulus' : 'Pre test selesai'), style: h1(context).copyWith(color: color)),
          const SizedBox(height: 6),
          Text('${r.score}', style: h1(context).copyWith(fontSize: 56, color: color, fontFeatures: tabular)),
          Text('${r.correct} dari ${r.total} benar${_post ? ' · nilai lulus ${r.passMark}' : ''}', style: muted),
          const SizedBox(height: 10),
          if (r.points > 0) Pill('+${r.points} poin', tone: Tone.orange),
          if (fail) ...[
            const SizedBox(height: 10),
            Text(left > 0 ? 'Sisa $left kesempatan. Pelajari lagi bagian yang salah, lalu coba lagi.' : 'Kesempatan habis. Hubungi HR untuk kesempatan tambahan.',
                textAlign: TextAlign.center),
          ],
          if (pass) ...[const SizedBox(height: 10), const Text('Sertifikat Anda sudah terbit.', textAlign: TextAlign.center)],
        ]),
      ),
      const SizedBox(height: 16),
      Wrap(spacing: 8, runSpacing: 8, children: [
        if (pass) FilledButton(onPressed: () => context.go('/certificates'), child: const Text('Lihat sertifikat')),
        if (!_post)
          FilledButton(
            onPressed: () async {
              final lc2 = await Scope.read(context).repo.course(lc.course.id);
              if (!mounted) return;
              final n = lc2.nextStep;
              n == null ? context.go('/class/${lc.course.id}') : openStep(context, lc2, n);
            },
            child: const Text('Lanjut ke materi'),
          ),
        if (fail && left > 0) FilledButton(onPressed: _start, child: const Text('Coba lagi')),
        if (_post) OutlinedButton(onPressed: () => setState(() => _review = !_review), child: Text(_review ? 'Tutup pembahasan' : 'Lihat jawaban saya')),
        OutlinedButton(onPressed: () => context.go('/class/${lc.course.id}'), child: const Text('Kembali ke kelas')),
      ]),
      if (_review) ...[
        const SizedBox(height: 20),
        if (r.answers == null)
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text('Kunci jawaban tampil setelah Anda lulus atau kesempatan habis, agar tes tetap adil.', style: muted),
          ),
        for (var k = 0; k < widget.qs.length; k++) _reviewItem(k, r),
      ],
    ]);
  }

  Widget _reviewItem(int k, TestResult r) {
    final q = widget.qs[k];
    final chosen = k < r.chosen.length ? r.chosen[k] : null;
    final ans = r.answers?[k];
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Box(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('${k + 1}. ${q.body}', style: const TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          for (var o = 0; o < q.options.length; o++)
            if (o == chosen || o == ans)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(children: [
                  Icon(
                    o == ans ? Icons.check_circle : (ans == null ? Icons.radio_button_checked : Icons.cancel),
                    size: 18,
                    color: o == ans ? C.ok : (ans == null ? C.navy : C.bad),
                  ),
                  const SizedBox(width: 8),
                  Expanded(child: Text('${q.options[o]}${o == chosen ? '  (jawaban Anda)' : ''}${o == ans && o != chosen ? '  (jawaban benar)' : ''}')),
                ]),
              ),
          if (chosen == null) const Padding(padding: EdgeInsets.only(top: 4), child: Text('Tidak dijawab', style: TextStyle(color: C.bad))),
        ]),
      ),
    );
  }
}
