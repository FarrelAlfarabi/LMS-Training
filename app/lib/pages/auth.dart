import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../repo/demo_repo.dart';
import '../state.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Two panel sign in layout: navy panel with the promise, white panel with the form.
class AuthFrame extends StatelessWidget {
  final String title, sub;
  final List<Widget> children;
  const AuthFrame({super.key, required this.title, required this.sub, required this.children});
  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final form = Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            if (!wide) ...[
              Row(children: [
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: C.navy, borderRadius: BorderRadius.circular(9)),
                  child: const Text('B', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                ),
                const SizedBox(width: 10),
                const Text('Bigma Belajar', style: TextStyle(fontWeight: FontWeight.w800, color: C.navy, fontSize: 16)),
              ]),
              const SizedBox(height: 28),
            ],
            Text(title, style: h1(context)),
            const SizedBox(height: 6),
            Text(sub, style: muted),
            const SizedBox(height: 24),
            ...children,
          ]),
        ),
      ),
    );
    return Scaffold(
      backgroundColor: wide ? C.frame : Colors.white,
      body: wide
          ? Row(children: [
              Expanded(
                child: Container(
                  color: C.navy,
                  padding: const EdgeInsets.all(48),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      Container(
                        width: 38,
                        height: 38,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
                        child: const Text('B', style: TextStyle(color: C.navy, fontWeight: FontWeight.w800, fontSize: 18)),
                      ),
                      const SizedBox(width: 12),
                      const Text('Bigma Belajar', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)),
                    ]),
                    const Spacer(),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 460),
                      child: Text('Pelatihan wajib dari kantor, selesai dari ponsel Anda.',
                          style: h1(context).copyWith(color: Colors.white, fontSize: 34, height: 1.2)),
                    ),
                    const SizedBox(height: 16),
                    const Text('Tonton materi, kerjakan tes, dan dapatkan sertifikat. HR melihat kemajuan tim tanpa perlu rekap manual.',
                        style: TextStyle(color: C.navy200, fontSize: 15)),
                    const SizedBox(height: 48),
                    Container(width: 48, height: 4, color: C.orange),
                  ]),
                ),
              ),
              Expanded(child: Container(color: Colors.white, child: form)),
            ])
          : SafeArea(child: form),
    );
  }
}

class _Err extends StatelessWidget {
  final String? text;
  const _Err(this.text);
  @override
  Widget build(BuildContext context) => text == null
      ? const SizedBox.shrink()
      : Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: C.badBg, borderRadius: BorderRadius.circular(10)),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.error_outline, color: C.bad, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(text!, style: const TextStyle(color: C.bad))),
          ]),
        );
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _email = TextEditingController(), _pw = TextEditingController();
  String? _err;
  bool _busy = false, _show = false;

  Future<void> _go() async {
    setState(() {
      _busy = true;
      _err = null;
    });
    final st = Scope.read(context);
    try {
      final p = await st.repo.signIn(_email.text, _pw.text);
      await st.onSignedIn(p);
      if (mounted) context.go(p.consentAt == null ? '/welcome' : (p.isAdmin ? '/admin' : '/'));
    } catch (e) {
      setState(() => _err = errText(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _fill(String email) {
    _email.text = email;
    _pw.text = DemoRepo.demoPassword;
    _go();
  }

  @override
  Widget build(BuildContext context) {
    final st = Scope.of(context);
    return AuthFrame(
      title: 'Masuk',
      sub: 'Pakai email kantor yang didaftarkan HR.',
      children: [
        _Err(_err),
        AutofillGroup(
          child: Column(children: [
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              decoration: const InputDecoration(labelText: 'Email kantor'),
              onSubmitted: (_) => _go(),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _pw,
              obscureText: !_show,
              autofillHints: const [AutofillHints.password],
              decoration: InputDecoration(
                labelText: 'Kata sandi',
                suffixIcon: IconButton(
                  tooltip: _show ? 'Sembunyikan' : 'Tampilkan',
                  icon: Icon(_show ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                  onPressed: () => setState(() => _show = !_show),
                ),
              ),
              onSubmitted: (_) => _go(),
            ),
          ]),
        ),
        Align(alignment: Alignment.centerRight, child: TextButton(onPressed: () => context.go('/forgot'), child: const Text('Lupa kata sandi?'))),
        const SizedBox(height: 4),
        FilledButton(onPressed: _busy ? null : _go, child: Text(_busy ? 'Memproses...' : 'Masuk')),
        const SizedBox(height: 12),
        OutlinedButton(onPressed: () => context.go('/activate'), child: const Text('Login pertama? Aktifkan akun')),
        const SizedBox(height: 28),
        Box(
          color: C.navy50,
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Akun contoh untuk mencoba', style: h3(context)),
            const SizedBox(height: 4),
            const Text('Kata sandi: ${DemoRepo.demoPassword}', style: small),
            const SizedBox(height: 10),
            Wrap(spacing: 8, runSpacing: 8, children: [
              OutlinedButton.icon(
                  onPressed: _busy ? null : () => _fill('rina.wulandari@contohsejahtera.example'),
                  icon: const Icon(Icons.badge_outlined, size: 18),
                  label: const Text('Karyawan: Rina')),
              OutlinedButton.icon(
                  onPressed: _busy ? null : () => _fill('hendra.dharma@contohsejahtera.example'),
                  icon: const Icon(Icons.admin_panel_settings_outlined, size: 18),
                  label: const Text('HR: Hendra')),
            ]),
            const SizedBox(height: 8),
            const Text('Untuk mencoba login pertama, aktifkan maya.anggraini@contohsejahtera.example.', style: small),
            if (st.repo.isDemo) ...[
              const SizedBox(height: 6),
              const Text('Mode contoh: data tersimpan di browser ini saja dan kembali awal saat dimuat ulang.', style: small),
            ],
          ]),
        ),
      ],
    );
  }
}

class ActivatePage extends StatefulWidget {
  const ActivatePage({super.key});
  @override
  State<ActivatePage> createState() => _ActivatePageState();
}

class _ActivatePageState extends State<ActivatePage> {
  final _email = TextEditingController(), _pw = TextEditingController(), _pw2 = TextEditingController();
  String? _err;
  bool _busy = false;

  Future<void> _go() async {
    String? e;
    if (!_email.text.contains('@')) e = 'Isi email kantor Anda.';
    if (_pw.text.length < 8) e = 'Kata sandi minimal 8 karakter.';
    if (_pw.text != _pw2.text) e = 'Kedua kata sandi belum sama.';
    if (e != null) return setState(() => _err = e);
    setState(() {
      _busy = true;
      _err = null;
    });
    final st = Scope.read(context);
    try {
      final p = await st.repo.activate(_email.text, _pw.text);
      await st.onSignedIn(p);
      if (mounted) context.go('/welcome');
    } catch (x) {
      setState(() => _err = errText(x));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => AuthFrame(
        title: 'Aktifkan akun',
        sub: 'HR sudah mendaftarkan email kantor Anda. Buat kata sandi untuk mulai belajar.',
        children: [
          _Err(_err),
          TextField(controller: _email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email kantor')),
          const SizedBox(height: 12),
          TextField(controller: _pw, obscureText: true, decoration: const InputDecoration(labelText: 'Kata sandi baru', helperText: 'Minimal 8 karakter')),
          const SizedBox(height: 12),
          TextField(controller: _pw2, obscureText: true, decoration: const InputDecoration(labelText: 'Ulangi kata sandi'), onSubmitted: (_) => _go()),
          const SizedBox(height: 20),
          FilledButton(onPressed: _busy ? null : _go, child: Text(_busy ? 'Memproses...' : 'Aktifkan dan masuk')),
          const SizedBox(height: 8),
          TextButton(onPressed: () => context.go('/login'), child: const Text('Sudah punya akun? Masuk')),
        ],
      );
}

class ForgotPage extends StatefulWidget {
  const ForgotPage({super.key});
  @override
  State<ForgotPage> createState() => _ForgotPageState();
}

class _ForgotPageState extends State<ForgotPage> {
  final _email = TextEditingController();
  bool _sent = false, _busy = false;
  String? _err;
  @override
  Widget build(BuildContext context) => AuthFrame(
        title: _sent ? 'Cek email Anda' : 'Lupa kata sandi',
        sub: _sent ? 'Jika email terdaftar, tautan untuk membuat kata sandi baru sudah dikirim ke ${_email.text}.' : 'Kami kirim tautan untuk membuat kata sandi baru.',
        children: [
          _Err(_err),
          if (!_sent) ...[
            TextField(controller: _email, keyboardType: TextInputType.emailAddress, decoration: const InputDecoration(labelText: 'Email kantor')),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _busy
                  ? null
                  : () async {
                      setState(() => _busy = true);
                      try {
                        await Scope.read(context).repo.sendReset(_email.text);
                        setState(() => _sent = true);
                      } catch (e) {
                        setState(() => _err = errText(e));
                      } finally {
                        setState(() => _busy = false);
                      }
                    },
              child: const Text('Kirim tautan'),
            ),
          ],
          const SizedBox(height: 8),
          TextButton(onPressed: () => context.go('/login'), child: const Text('Kembali ke halaman masuk')),
        ],
      );
}

/// First login: three short intro steps, then the UU PDP consent.
class WelcomePage extends StatefulWidget {
  const WelcomePage({super.key});
  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  int _i = 0;
  bool _agree = false, _hide = false, _busy = false;

  static const _steps = [
    (Icons.assignment_turned_in_outlined, 'Kelas dari HR muncul di Beranda', 'Setiap kelas punya tenggat. Kerjakan berurutan: pre test, materi, lalu post test.'),
    (Icons.stars_outlined, 'Kumpulkan poin', 'Setiap materi dan tes yang selesai menambah poin. Lihat posisi Anda di papan peringkat.'),
    (Icons.workspace_premium_outlined, 'Lulus, dapat sertifikat', 'Lulus post test untuk mendapat sertifikat yang bisa diunduh kapan saja.'),
  ];

  @override
  Widget build(BuildContext context) {
    final st = Scope.of(context);
    final co = st.company?.name ?? 'perusahaan Anda';
    if (_i < 3) {
      final s = _steps[_i];
      return AuthFrame(
        title: _i == 0 ? 'Halo, ${st.profile?.firstName ?? ''}' : s.$2,
        sub: _i == 0 ? 'Selamat datang di ruang belajar $co.' : s.$3,
        children: [
          Box(
            color: C.navy50,
            child: Row(children: [
              Icon(s.$1, color: C.navy, size: 32),
              const SizedBox(width: 16),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(s.$2, style: h3(context)),
                  const SizedBox(height: 4),
                  Text(s.$3, style: muted),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: 20),
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            for (var k = 0; k < 4; k++)
              Container(
                width: k == _i ? 20 : 8,
                height: 8,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(color: k == _i ? C.navy : C.navy200, borderRadius: BorderRadius.circular(9)),
              ),
          ]),
          const SizedBox(height: 20),
          FilledButton(onPressed: () => setState(() => _i++), child: const Text('Lanjut')),
          TextButton(onPressed: () => setState(() => _i = 3), child: const Text('Lewati')),
        ],
      );
    }
    return AuthFrame(
      title: 'Persetujuan data pribadi',
      sub: 'Sesuai UU No. 27 Tahun 2022 tentang Pelindungan Data Pribadi.',
      children: [
        Box(
          padding: const EdgeInsets.all(16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Data yang kami pakai', style: h3(context)),
            const SizedBox(height: 8),
            for (final t in [
              'Nama, email kantor, divisi, dan jabatan dari HR $co.',
              'Kemajuan belajar, nilai tes, poin, dan sertifikat Anda.',
              'Dipakai hanya untuk pelatihan di $co. Tidak dijual atau dibagikan ke pihak lain.',
              'Anda bisa meminta salinan atau penghapusan data melalui HR.',
            ])
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Padding(padding: EdgeInsets.only(top: 7, right: 8), child: CircleAvatar(radius: 3, backgroundColor: C.navy)),
                  Expanded(child: Text(t)),
                ]),
              ),
            TextButton(onPressed: () => context.push('/privacy'), child: const Text('Baca kebijakan privasi lengkap')),
          ]),
        ),
        const SizedBox(height: 12),
        CheckboxListTile(
          value: _agree,
          onChanged: (v) => setState(() => _agree = v ?? false),
          controlAffinity: ListTileControlAffinity.leading,
          contentPadding: EdgeInsets.zero,
          title: const Text('Saya sudah membaca dan setuju data saya dipakai untuk pelatihan.'),
        ),
        SwitchListTile(
          value: _hide,
          onChanged: (v) => setState(() => _hide = v),
          contentPadding: EdgeInsets.zero,
          title: const Text('Sembunyikan nama saya di papan peringkat'),
          subtitle: const Text('Bisa diubah kapan saja di Profil.', style: small),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: !_agree || _busy
              ? null
              : () async {
                  setState(() => _busy = true);
                  try {
                    final p = await st.repo.updateMyProfile(consent: true, hideOnLeaderboard: _hide);
                    st.setProfile(p);
                    if (context.mounted) context.go(p.isAdmin ? '/admin' : '/');
                  } catch (e) {
                    if (context.mounted) toast(context, errText(e));
                    setState(() => _busy = false);
                  }
                },
          child: const Text('Setuju dan mulai'),
        ),
        TextButton(
          onPressed: () async {
            await st.signOut();
            if (context.mounted) context.go('/login');
          },
          child: const Text('Tidak setuju, keluar'),
        ),
      ],
    );
  }
}

class PasswordPage extends StatefulWidget {
  const PasswordPage({super.key});
  @override
  State<PasswordPage> createState() => _PasswordPageState();
}

class _PasswordPageState extends State<PasswordPage> {
  final _a = TextEditingController(), _b = TextEditingController();
  String? _err;
  @override
  Widget build(BuildContext context) => PageBody(maxWidth: 480, children: [
        PageHead('Ganti kata sandi', back: BackLink('Kembali', () => context.pop())),
        _Err(_err),
        TextField(controller: _a, obscureText: true, decoration: const InputDecoration(labelText: 'Kata sandi baru', helperText: 'Minimal 8 karakter')),
        const SizedBox(height: 12),
        TextField(controller: _b, obscureText: true, decoration: const InputDecoration(labelText: 'Ulangi kata sandi baru')),
        const SizedBox(height: 20),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton(
            onPressed: () async {
              if (_a.text.length < 8) return setState(() => _err = 'Kata sandi minimal 8 karakter.');
              if (_a.text != _b.text) return setState(() => _err = 'Kedua kata sandi belum sama.');
              try {
                await Scope.read(context).repo.changePassword(_a.text);
                if (context.mounted) {
                  toast(context, 'Kata sandi diganti.');
                  context.pop();
                }
              } catch (e) {
                setState(() => _err = errText(e));
              }
            },
            child: const Text('Simpan kata sandi'),
          ),
        ),
      ]);
}
