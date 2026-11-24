const { chromium } = require('playwright');
const seed = require('../app/assets/seed.json');
const c1 = seed.courses.find(c => c.key === 'c1');
const out = '/tmp/claude-0/shots/';
(async () => {
  const b = await chromium.launch();
  const size = process.argv[2] === 'phone' ? { width: 390, height: 844 } : { width: 1366, height: 860 };
  const tag = process.argv[2] || 'desk';
  const p = await b.newPage({ viewport: size });
  const errs = [];
  p.on('console', m => { if (m.type() === 'error') errs.push(m.text()); });
  p.on('pageerror', e => errs.push(String(e)));
  await p.goto('http://localhost:8080/login');
  await p.waitForTimeout(4000);
  await p.evaluate(() => document.querySelector('flt-semantics-placeholder')?.click());
  await p.waitForTimeout(800);
  const shot = async n => { await p.waitForTimeout(1200); await p.screenshot({ path: out + tag + '-' + n + '.png' }); };
  const click = async (t, exact = false) => {
    const esc = t.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
    const byText = p.getByText(t, { exact });
    if (await byText.count()) return byText.first().click();
    const byRole = p.getByRole('button', { name: exact ? new RegExp('^' + esc + '$') : new RegExp(esc) });
    if (await byRole.count()) return byRole.first().click();
    return p.locator(`flt-semantics[aria-label*="${t}"]`).first().click({ timeout: 8000 });
  };
  const nav = async t => {
    t = t;
    if (tag === 'phone') { await p.getByRole('button', { name: 'Menu' }).click(); await p.waitForTimeout(500); }
    await click(t, t !== 'Notifikasi');
  };
  await shot('01-login');
  const who = process.argv[3] || 'learner';
  if (who === 'learner') {
    await click('Karyawan: Rina'); await shot('02-home');
    await nav('Kelas saya'); await shot('03-classes');
    await click('Manajemen Stres di Tempat Kerja'); await shot('04-class');
    await click('Lanjutkan'); await shot('05-test-intro');
    await click('Mulai tes'); await shot('06-question');
    for (let i = 0; i < 10; i++) { const q = c1.post[i]; const right = q.options[i === 9 ? (q.answer + 1) % q.options.length : q.answer]; await click(right).catch(e => console.log('opt miss', i));  const n = p.getByText('Berikutnya', { exact: true }); if (await n.count()) await n.click(); await p.waitForTimeout(150); }
    await click('Kirim jawaban'); await p.waitForTimeout(500); await shot('07-confirm');
    await click('Kirim', true); await shot('08-result');
    await p.keyboard.press('Escape');
    await click('Lihat jawaban saya').catch(()=>{}); await shot('09-review');
    await nav('Poin saya'); await shot('10-points');
    await nav('Peringkat'); await shot('11-board');
    await nav('Sertifikat'); await shot('12-certs');
    await click('Lihat', true); await shot('13-cert');
    await nav('Notifikasi'); await shot('14-notifs');
    await nav('Profil'); await shot('15-profile');
    await nav('Kelas saya'); await click('Pelindungan Data Pribadi untuk Karyawan'); await click('Mulai kelas'); await shot('16-pre-intro');
  } else {
    await click('HR: Hendra'); await shot('20-dash');
    await nav('Karyawan'); await shot('21-people');
    await nav('Kelas dan materi'); await shot('22-courses');
    await click('Dasar Negosiasi Penjualan'); await shot('23-builder');
    await nav('Penugasan'); await shot('24-assign');
    await nav('Laporan'); await shot('25-reports');
    await nav('Pengaturan'); await shot('26-settings');
  }
  console.log('errors:', JSON.stringify(errs.slice(0, 10)));
  await b.close();
})().catch(e => { console.error('FAIL', e.message); process.exit(1); });
