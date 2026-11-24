import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../state.dart';
import '../theme.dart';
import 'common.dart';

class NavItem {
  final String label, path;
  final IconData icon;
  final bool badge;
  const NavItem(this.label, this.path, this.icon, {this.badge = false});
}

const learnerNav = [
  NavItem('Beranda', '/', Icons.home_outlined),
  NavItem('Kelas saya', '/classes', Icons.menu_book_outlined),
  NavItem('Sertifikat', '/certificates', Icons.workspace_premium_outlined),
  NavItem('Poin saya', '/points', Icons.stars_outlined),
  NavItem('Peringkat', '/leaderboard', Icons.leaderboard_outlined),
  NavItem('Notifikasi', '/notifications', Icons.notifications_none, badge: true),
];
const learnerFoot = [
  NavItem('Profil', '/profile', Icons.person_outline),
  NavItem('Bantuan', '/help', Icons.help_outline),
];
const adminNav = [
  NavItem('Dasbor', '/admin', Icons.space_dashboard_outlined),
  NavItem('Karyawan', '/admin/people', Icons.group_outlined),
  NavItem('Kelas dan materi', '/admin/courses', Icons.video_library_outlined),
  NavItem('Penugasan', '/admin/assign', Icons.assignment_outlined),
  NavItem('Laporan', '/admin/reports', Icons.insert_chart_outlined),
];
const adminFoot = [
  NavItem('Pengaturan', '/admin/settings', Icons.settings_outlined),
  NavItem('Bantuan', '/help', Icons.help_outline),
];

/// Style B frame: navy tinted sidebar and top bar in an L, white sheet for the work.
class Shell extends StatelessWidget {
  final Widget child;
  final String location;
  const Shell({super.key, required this.child, required this.location});

  @override
  Widget build(BuildContext context) {
    final st = Scope.of(context);
    final admin = st.profile?.isAdmin ?? false;
    final phone = MediaQuery.sizeOf(context).width < 900;
    final nav = admin ? adminNav : learnerNav;
    final foot = admin ? adminFoot : learnerFoot;
    final side = _Sidebar(nav: nav, foot: foot, location: location, inDrawer: phone);
    final sheet = Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: phone ? const BorderRadius.vertical(top: Radius.circular(16)) : const BorderRadius.only(topLeft: Radius.circular(16)),
        border: const Border(top: BorderSide(color: C.line), left: BorderSide(color: C.line)),
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
    return Scaffold(
      backgroundColor: C.frame,
      drawer: phone ? Drawer(backgroundColor: C.frame, width: 280, child: SafeArea(child: side)) : null,
      body: SafeArea(
        bottom: false,
        child: phone
            ? Column(children: [_TopBar(phone: true), Expanded(child: sheet)])
            : Row(children: [
                SizedBox(width: 232, child: side),
                Expanded(child: Column(children: [_TopBar(phone: false), Expanded(child: sheet)])),
              ]),
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final co = Scope.of(context).company;
    return Row(children: [
      Container(
        width: 34,
        height: 34,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: C.navy, borderRadius: BorderRadius.circular(9)),
        child: co?.logoUrl != null
            ? ClipRRect(borderRadius: BorderRadius.circular(9), child: Image.network(co!.logoUrl!, fit: BoxFit.cover, width: 34, height: 34))
            : Text(co?.mark ?? 'B', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 13)),
      ),
      const SizedBox(width: 10),
      Flexible(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(co?.name ?? 'Bigma', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: C.ink)),
          const Text('Belajar', style: TextStyle(fontSize: 11, color: C.muted)),
        ]),
      ),
    ]);
  }
}

class _Sidebar extends StatelessWidget {
  final List<NavItem> nav, foot;
  final String location;
  final bool inDrawer;
  const _Sidebar({required this.nav, required this.foot, required this.location, required this.inDrawer});

  bool _active(String p) {
    if (p == '/' || p == '/admin') return location == p;
    return location == p || location.startsWith('$p/') || (p == '/classes' && location.startsWith('/class/'));
  }

  @override
  Widget build(BuildContext context) {
    final st = Scope.of(context);
    Widget item(NavItem n) {
      final on = _active(n.path);
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 1),
        child: Material(
          color: on ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            hoverColor: C.frameHover,
            onTap: () {
              if (inDrawer) Navigator.of(context).pop();
              context.go(n.path);
            },
            child: Container(
              height: 42,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(children: [
                Icon(n.icon, size: 20, color: on ? C.navy : C.muted),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(n.label,
                      style: TextStyle(fontSize: 14, fontWeight: on ? FontWeight.w700 : FontWeight.w500, color: on ? C.navy : const Color(0xFF3A4458))),
                ),
                if (n.badge && st.unread > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                    decoration: BoxDecoration(color: C.orange, borderRadius: BorderRadius.circular(99)),
                    child: Text('${st.unread}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
                  ),
              ]),
            ),
          ),
        ),
      );
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SizedBox(height: 56, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 18), child: Align(alignment: Alignment.centerLeft, child: _Brand()))),
      const SizedBox(height: 8),
      Expanded(child: ListView(children: [for (final n in nav) item(n)])),
      for (final n in foot) item(n),
      const SizedBox(height: 8),
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 6, 24, 16),
        child: Row(children: [
          const Text('Powered by ', style: TextStyle(fontSize: 11, color: C.muted)),
          Text('Bigma', style: TextStyle(fontSize: 11, color: C.navy.withValues(alpha: .9), fontWeight: FontWeight.w800)),
        ]),
      ),
    ]);
  }
}

class _TopBar extends StatelessWidget {
  final bool phone;
  const _TopBar({required this.phone});
  @override
  Widget build(BuildContext context) {
    final st = Scope.of(context);
    final p = st.profile;
    final admin = p?.isAdmin ?? false;
    return SizedBox(
      height: 56,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: phone ? 4 : 20),
        child: Row(children: [
          if (phone) ...[
            Builder(builder: (c) => IconButton(tooltip: 'Menu', icon: const Icon(Icons.menu, color: C.navy), onPressed: () => Scaffold.of(c).openDrawer())),
            Expanded(child: _Brand()),
          ] else ...[
            if (st.repo.isDemo)
              const Pill('Mode contoh: data kembali awal saat halaman dimuat ulang', tone: Tone.orange),
            const Spacer(),
          ],
          if (!admin && p != null) ...[
            InkWell(
              borderRadius: BorderRadius.circular(99),
              onTap: () => context.go('/points'),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(99), border: Border.all(color: C.navy100)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.stars_rounded, size: 16, color: C.orange),
                  const SizedBox(width: 4),
                  Text('${fmtNum(st.points)} poin', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: C.navy, fontFeatures: tabular)),
                ]),
              ),
            ),
            IconButton(
              tooltip: 'Notifikasi',
              onPressed: () => context.go('/notifications'),
              icon: Badge(isLabelVisible: st.unread > 0, backgroundColor: C.orange, label: Text('${st.unread}'), child: const Icon(Icons.notifications_none, color: C.navy)),
            ),
          ],
          if (admin && !phone) const Padding(padding: EdgeInsets.only(right: 8), child: Pill('Admin HR', tone: Tone.navy)),
          if (p != null)
            PopupMenuButton<String>(
              tooltip: 'Akun',
              offset: const Offset(0, 44),
              color: Colors.white,
              onSelected: (v) async {
                if (v == 'out') {
                  await st.signOut();
                  if (context.mounted) context.go('/login');
                } else {
                  context.go(v);
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(enabled: false, child: Text('${p.fullName}\n${p.email}', style: small)),
                if (!admin) const PopupMenuItem(value: '/profile', child: Text('Profil saya')),
                const PopupMenuItem(value: '/password', child: Text('Ganti kata sandi')),
                const PopupMenuItem(value: 'out', child: Text('Keluar')),
              ],
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Avatar(p.initials, size: 32),
                  if (!phone) ...[
                    const SizedBox(width: 8),
                    Text(p.firstName, style: const TextStyle(fontWeight: FontWeight.w600)),
                    const Icon(Icons.expand_more, size: 18, color: C.muted),
                  ],
                ]),
              ),
            ),
        ]),
      ),
    );
  }
}
