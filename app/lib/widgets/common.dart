import 'package:flutter/material.dart';
import '../models.dart';
import '../state.dart';
import '../theme.dart';

bool isPhone(BuildContext c) => MediaQuery.sizeOf(c).width < 760;

/// Loads data, shows a spinner, an error with retry, then the content.
class Loader<T> extends StatefulWidget {
  final Future<T> Function() load;
  final Widget Function(BuildContext, T, VoidCallback reload) builder;
  const Loader({super.key, required this.load, required this.builder});
  @override
  State<Loader<T>> createState() => _LoaderState<T>();
}

class _LoaderState<T> extends State<Loader<T>> {
  late Future<T> _f = widget.load();
  void _reload() => setState(() => _f = widget.load());
  @override
  Widget build(BuildContext context) => FutureBuilder<T>(
        future: _f,
        builder: (c, s) {
          if (s.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text(errText(s.error!), textAlign: TextAlign.center, style: muted),
                  const SizedBox(height: 12),
                  OutlinedButton(onPressed: _reload, child: const Text('Coba lagi')),
                ]),
              ),
            );
          }
          if (!s.hasData) return const Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator(color: C.navy)));
          return widget.builder(c, s.data as T, _reload);
        },
      );
}

/// Page body inside the white sheet: scrolls, keeps a readable width.
class PageBody extends StatelessWidget {
  final List<Widget> children;
  final double maxWidth;
  final Widget? rail;
  const PageBody({super.key, required this.children, this.maxWidth = 1120, this.rail});
  @override
  Widget build(BuildContext context) {
    final phone = isPhone(context);
    final pad = EdgeInsets.fromLTRB(phone ? 16 : 32, phone ? 16 : 28, phone ? 16 : 32, 48);
    final wide = MediaQuery.sizeOf(context).width >= 1180 && rail != null;
    final main = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children);
    return SingleChildScrollView(
      padding: pad,
      child: Align(
        alignment: Alignment.topLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: wide
              ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Expanded(child: main),
                  const SizedBox(width: 28),
                  SizedBox(width: 340, child: rail),
                ])
              : Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [main, if (rail != null) ...[const SizedBox(height: 24), rail!]]),
        ),
      ),
    );
  }
}

class PageHead extends StatelessWidget {
  final String title;
  final String? sub;
  final List<Widget> actions;
  final Widget? back;
  const PageHead(this.title, {super.key, this.sub, this.actions = const [], this.back});
  @override
  Widget build(BuildContext context) {
    final t = Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (back != null) ...[back!, const SizedBox(height: 6)],
      Text(title, style: h1(context)),
      if (sub != null) ...[const SizedBox(height: 4), Text(sub!, style: muted)],
    ]);
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: isPhone(context) || actions.isEmpty
          ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              t,
              if (actions.isNotEmpty) ...[const SizedBox(height: 12), Wrap(spacing: 8, runSpacing: 8, children: actions)],
            ])
          : Row(crossAxisAlignment: CrossAxisAlignment.end, children: [Expanded(child: t), Wrap(spacing: 8, children: actions)]),
    );
  }
}

class BackLink extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const BackLink(this.label, this.onTap, {super.key});
  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.arrow_back, size: 16, color: C.navy),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(color: C.navy, fontWeight: FontWeight.w600, fontSize: 13)),
          ]),
        ),
      );
}

/// White bordered block.
class Box extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final Color? color;
  const Box({super.key, required this.child, this.padding = const EdgeInsets.all(20), this.color});
  @override
  Widget build(BuildContext context) => Container(
        padding: padding,
        decoration: BoxDecoration(color: color ?? Colors.white, border: Border.all(color: C.line), borderRadius: BorderRadius.circular(14)),
        child: child,
      );
}

class SectionTitle extends StatelessWidget {
  final String text;
  final Widget? trailing;
  const SectionTitle(this.text, {super.key, this.trailing});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 12),
        child: Row(children: [Expanded(child: Text(text, style: h2(context))), if (trailing != null) trailing!]),
      );
}

/// One divided container of numbers, style B's KPI strip.
class KpiStrip extends StatelessWidget {
  final List<(String label, String value, String? sub)> items;
  const KpiStrip(this.items, {super.key});
  @override
  Widget build(BuildContext context) {
    final cols = isPhone(context) ? 2 : items.length;
    final rows = <Widget>[];
    for (var i = 0; i < items.length; i += cols) {
      final chunk = items.sublist(i, (i + cols).clamp(0, items.length));
      rows.add(IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          for (var j = 0; j < cols; j++) ...[
            if (j > 0) const VerticalDivider(width: 1, color: C.line),
            Expanded(child: j < chunk.length ? _kpi(context, chunk[j]) : const SizedBox()),
          ]
        ]),
      ));
      if (i + cols < items.length) rows.add(const Divider(height: 1));
    }
    return Container(
      decoration: BoxDecoration(color: Colors.white, border: Border.all(color: C.line), borderRadius: BorderRadius.circular(14)),
      child: Column(children: rows),
    );
  }

  Widget _kpi(BuildContext c, (String, String, String?) k) => Padding(
        padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(k.$1, style: small),
          const SizedBox(height: 4),
          Text(k.$2, style: h1(c).copyWith(fontSize: 22, fontFeatures: tabular)),
          if (k.$3 != null) Text(k.$3!, style: small),
        ]),
      );
}

enum Tone { neutral, ok, bad, warn, navy, orange }

class Pill extends StatelessWidget {
  final String text;
  final Tone tone;
  const Pill(this.text, {super.key, this.tone = Tone.neutral});
  static Tone toneFor(LearnerCourse lc) {
    if (lc.completed) return Tone.ok;
    if (lc.failedOut || lc.late) return Tone.bad;
    if (lc.postAttempts.isNotEmpty) return Tone.warn;
    if (lc.started) return Tone.navy;
    return Tone.neutral;
  }

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (tone) {
      Tone.ok => (C.okBg, C.ok),
      Tone.bad => (C.badBg, C.bad),
      Tone.warn => (C.warnBg, C.warnInk),
      Tone.navy => (C.navy50, C.navy),
      Tone.orange => (C.orange50, C.orangeInk),
      Tone.neutral => (const Color(0xFFF1F3F7), C.muted),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(text, style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}

class Bar extends StatelessWidget {
  final double value;
  final Color color;
  const Bar(this.value, {super.key, this.color = C.navy});
  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(99),
        child: LinearProgressIndicator(value: value.clamp(0, 1), minHeight: 6, backgroundColor: C.navy100, color: color),
      );
}

class CourseArt extends StatelessWidget {
  final int art;
  final double height;
  final String? label;
  final BorderRadius radius;
  const CourseArt(this.art, {super.key, this.height = 120, this.label, this.radius = const BorderRadius.all(Radius.circular(12))});
  @override
  Widget build(BuildContext context) {
    final g = courseArt[art % courseArt.length];
    return Container(
      height: height,
      decoration: BoxDecoration(borderRadius: radius, gradient: LinearGradient(colors: g, begin: Alignment.topLeft, end: Alignment.bottomRight)),
      child: Stack(children: [
        Positioned(right: -20, top: -30, child: _ring(height * 1.1)),
        Positioned(right: 30, bottom: -40, child: _ring(height * .7)),
        if (label != null)
          Positioned(
            left: 14,
            bottom: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: .16), borderRadius: BorderRadius.circular(99)),
              child: Text(label!, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
            ),
          ),
      ]),
    );
  }

  Widget _ring(double s) => Container(
        width: s,
        height: s,
        decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white.withValues(alpha: .12), width: 14)),
      );
}

class Empty extends StatelessWidget {
  final IconData icon;
  final String title, body;
  final Widget? action;
  const Empty(this.icon, this.title, this.body, {super.key, this.action});
  @override
  Widget build(BuildContext context) => Box(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
        child: Column(children: [
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(color: C.navy50, shape: BoxShape.circle),
            child: Icon(icon, color: C.navy),
          ),
          const SizedBox(height: 12),
          Text(title, style: h3(context), textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Text(body, style: muted, textAlign: TextAlign.center),
          if (action != null) ...[const SizedBox(height: 16), action!],
        ]),
      );
}

class Avatar extends StatelessWidget {
  final String initials;
  final double size;
  final bool me;
  const Avatar(this.initials, {super.key, this.size = 32, this.me = false});
  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: me ? C.orange : C.navy, shape: BoxShape.circle),
        child: Text(initials, style: TextStyle(color: Colors.white, fontSize: size * .38, fontWeight: FontWeight.w700)),
      );
}

String initialsOf(String name) {
  final p = name.trim().split(RegExp(r'\s+'));
  return (p.first[0] + (p.length > 1 ? p.last[0] : '')).toUpperCase();
}

/// Simple table that becomes stacked cards on phones.
class DataList extends StatelessWidget {
  final List<String> headers;
  final List<List<Widget>> rows;
  final List<int> flex;
  final void Function(int)? onTap;
  const DataList({super.key, required this.headers, required this.rows, required this.flex, this.onTap});
  @override
  Widget build(BuildContext context) {
    final phone = isPhone(context);
    return Container(
      decoration: BoxDecoration(color: Colors.white, border: Border.all(color: C.line), borderRadius: BorderRadius.circular(14)),
      clipBehavior: Clip.antiAlias,
      child: Column(children: [
        if (!phone)
          Container(
            color: const Color(0xFFF7F9FC),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(children: [
              for (var i = 0; i < headers.length; i++)
                Expanded(flex: flex[i], child: Text(headers[i], style: small.copyWith(fontWeight: FontWeight.w600))),
            ]),
          ),
        for (var r = 0; r < rows.length; r++) ...[
          if (r > 0 || !phone) const Divider(height: 1),
          InkWell(
            onTap: onTap == null ? null : () => onTap!(r),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: phone
                  ? Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      rows[r][0],
                      const SizedBox(height: 6),
                      Wrap(spacing: 14, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [
                        for (var i = 1; i < rows[r].length; i++)
                          Row(mainAxisSize: MainAxisSize.min, children: [Text('${headers[i]}: ', style: small), rows[r][i]]),
                      ]),
                    ])
                  : Row(children: [for (var i = 0; i < rows[r].length; i++) Expanded(flex: flex[i], child: Align(alignment: Alignment.centerLeft, child: rows[r][i]))]),
            ),
          ),
        ],
        if (rows.isEmpty) const Padding(padding: EdgeInsets.all(24), child: Text('Belum ada data.', style: muted)),
      ]),
    );
  }
}

Future<bool> confirm(BuildContext c, String title, String body, {String yes = 'Ya, lanjutkan', bool danger = false}) async =>
    await showDialog<bool>(
      context: c,
      builder: (d) => AlertDialog(
        title: Text(title, style: h2(d)),
        content: Text(body),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Batal')),
          FilledButton(
            style: danger ? FilledButton.styleFrom(backgroundColor: C.bad) : null,
            onPressed: () => Navigator.pop(d, true),
            child: Text(yes),
          ),
        ],
      ),
    ) ??
    false;
