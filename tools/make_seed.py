"""Builds the fictional sample data once, as JSON for the in-memory demo and as SQL for Supabase.
All people and the company are made up. Run: python3 tools/make_seed.py
"""
import json, random, uuid, os

random.seed(7)
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
NS = uuid.UUID('6f1c2b8e-3d0a-4e55-9b2a-0c7d1e5f9a10')
def uid(*k): return str(uuid.uuid5(NS, '/'.join(k)))
DOMAIN = 'contohsejahtera.example'

company = dict(id=uid('company'), name='PT Contoh Sejahtera', mark='CS', pass_mark=70,
               hr_email='hr@' + DOMAIN, hr_whatsapp='+62 812 0000 1234')

names = {
 'Penjualan': ['Rina Wulandari', 'Andi Saputra', 'Siti Rahma', 'Nanda Putra', 'Maya Anggraini', 'Yusuf Hidayat', 'Lina Marlina',
               'Rizky Ramadhan', 'Desi Ratnasari', 'Hari Santoso', 'Wulan Sari', 'Eko Prasetyo', 'Tari Kusuma', 'Galih Permana', 'Indah Puspita'],
 'Gudang': ['Agus Setiawan', 'Bayu Pratama', 'Sri Handayani', 'Dedi Kurniawan', 'Joko Susilo', 'Teguh Wibowo', 'Rudi Hartono',
            'Slamet Riyadi', 'Asep Sunandar', 'Wahyu Nugraha'],
 'Keuangan': ['Dewi Lestari', 'Fajar Nugroho', 'Ratna Dewi', 'Bambang Sutrisno', 'Mega Pertiwi', 'Irfan Hakim'],
 'Umum dan HR': ['Putri Maharani', 'Hendra Dharma', 'Nur Aini', 'Ahmad Fauzi', 'Lestari Wahyuni', 'Dimas Aditya', 'Sari Indah',
                 'Taufik Hidayat', 'Ayu Lestari', 'Rahmat Saleh'],
}
titles = {'Penjualan': 'Staf Penjualan', 'Gudang': 'Staf Gudang', 'Keuangan': 'Staf Keuangan', 'Umum dan HR': 'Staf Umum'}
special_titles = {'Bayu Pratama': 'Kepala Regu Gudang', 'Fajar Nugroho': 'Staf Pajak', 'Putri Maharani': 'Staf HR', 'Hendra Dharma': 'Manajer HR'}
invited_only = {'Maya Anggraini', 'Teguh Wibowo'}

people = []
for dept, ns in names.items():
    for n in ns:
        email = n.lower().replace(' ', '.') + '@' + DOMAIN
        people.append(dict(id=uid('user', email), full_name=n, email=email, dept=dept,
                           title=special_titles.get(n, titles[dept]),
                           role='admin' if n == 'Hendra Dharma' else 'learner',
                           status='sent' if n in invited_only else 'active',
                           phone='0812 3456 7890' if n == 'Rina Wulandari' else None,
                           hide=n in ('Ratna Dewi', 'Asep Sunandar')))
learners = [p for p in people if p['role'] == 'learner']
assert len([p for p in learners if p['status'] == 'active']) == 38, len([p for p in learners if p['status'] == 'active'])

def q(body, opts, ans): return dict(body=body, options=opts, answer=ans)

stress_post = [
 q('Apa tanda awal stres yang paling sering muncul di tempat kerja?', ['Lebih sering tertawa', 'Sulit fokus dan mudah tersinggung', 'Nafsu makan selalu bertambah', 'Ingin lembur setiap hari', 'Tidak pernah merasa lelah'], 1),
 q('Sumber stres mana yang paling bisa Anda kendalikan sendiri?', ['Kebijakan perusahaan', 'Cuaca', 'Cara Anda mengatur prioritas kerja', 'Target tahunan kantor', 'Lalu lintas'], 2),
 q('Teknik napas 4-7-8 dilakukan dengan cara:', ['Tarik 4 detik, tahan 7, buang 8', 'Tarik 8 detik, buang 4', 'Tahan napas 47 detik', 'Napas cepat 8 kali', 'Tarik 7 detik, buang 4'], 0),
 q('Rekan kerja Anda terlihat kewalahan menjelang tenggat. Apa langkah pertama yang paling membantu?', ['Mengambil alih semua pekerjaannya tanpa bertanya', 'Menanyakan bagian mana yang paling membebani, lalu menawarkan bantuan', 'Melaporkannya ke atasan agar diberi teguran', 'Membiarkannya, karena stres adalah urusan pribadi', 'Menyarankan lembur sampai pekerjaan selesai'], 1),
 q('Kapan waktu terbaik untuk istirahat singkat saat bekerja?', ['Hanya saat makan siang', 'Setiap 60 sampai 90 menit', 'Setelah pulang kerja', 'Saat atasan tidak melihat', 'Tidak perlu istirahat'], 1),
 q('Apa yang sebaiknya dilakukan saat beban kerja terasa tidak masuk akal?', ['Diam dan bekerja lebih keras', 'Membicarakan prioritas dengan atasan', 'Mengambil cuti mendadak', 'Mengeluh di grup kantor', 'Mengerjakan semuanya setengah-setengah'], 1),
 q('Kebiasaan tidur yang membantu mengurangi stres adalah:', ['Tidur di jam yang sama setiap hari', 'Memakai ponsel sampai tertidur', 'Minum kopi sebelum tidur', 'Tidur 4 jam di hari kerja', 'Tidur siang 3 jam'], 0),
 q('Contoh dukungan sosial di tempat kerja adalah:', ['Bersaing diam-diam', 'Berbagi cara kerja dengan rekan', 'Menghindari semua rapat', 'Bekerja sendiri terus', 'Menyimpan masalah sendiri'], 1),
 q('Stres jangka panjang yang dibiarkan dapat menyebabkan:', ['Kinerja selalu naik', 'Kelelahan dan gangguan kesehatan', 'Lebih mudah tidur', 'Tidak berpengaruh apa pun', 'Gaji naik'], 1),
 q('Langkah pertama mengelola stres adalah:', ['Menyadari dan menamai apa yang dirasakan', 'Menyalahkan orang lain', 'Mengabaikannya', 'Mengambil pekerjaan tambahan', 'Pindah kerja'], 0),
]

courses = [
 dict(key='c0', title='Orientasi Perusahaan', category='Umum', art=1, published=True, duration_label='1 jam',
      description='Kenali sejarah, nilai, dan cara kerja PT Contoh Sejahtera di minggu pertama Anda.',
      outcomes=['Memahami nilai dan budaya kerja perusahaan', 'Tahu ke mana harus bertanya untuk urusan sehari-hari'],
      steps=[('pre', None, 'Pre test', '5 soal', None, 10), ('video', 'Kenali perusahaan', 'Sejarah dan nilai kita', '0:30', 'orientasi-1', 50),
             ('video', 'Kenali perusahaan', 'Cara kerja sehari-hari', '0:30', 'orientasi-2', 50),
             ('pdf', 'Pegangan', 'Buku saku karyawan', 'PDF 3 halaman', 'buku-saku', 5), ('post', None, 'Post test', '5 soal', None, 20)],
      pre=[q('Kapan jam kerja kantor pusat dimulai?', ['07.00', '08.00', '09.00', '10.00'], 1),
           q('Ke mana Anda mengajukan cuti?', ['Langsung ke direktur', 'Melalui tim HR', 'Grup WhatsApp', 'Tidak perlu izin'], 1),
           q('Nilai perusahaan yang utama adalah:', ['Cepat tanpa teliti', 'Jujur dan melayani', 'Menang sendiri', 'Diam saja'], 1),
           q('Kartu karyawan dipakai untuk:', ['Absensi dan akses gedung', 'Belanja', 'Parkir saja', 'Tidak ada'], 0),
           q('Saat bingung soal pekerjaan, sebaiknya:', ['Bertanya ke atasan atau rekan', 'Diam', 'Menebak', 'Pulang'], 0)],
      post=None),
 dict(key='c1', title='Manajemen Stres di Tempat Kerja', category='Pengembangan Diri', art=0, published=True, duration_label='1,5 jam',
      description='Mengenali tanda stres, sumbernya di kantor, dan cara meredakannya sebelum mengganggu kerja dan kesehatan.',
      outcomes=['Mengenali tanda awal stres pada diri sendiri dan rekan kerja', 'Memetakan sumber stres yang paling sering muncul di kantor', 'Memakai tiga teknik sederhana untuk meredakan stres saat bekerja'],
      steps=[('pre', None, 'Pre test', '5 soal', None, 10), ('video', 'Mengenal stres', 'Pengantar', '0:30', 'stres-1', 50),
             ('video', 'Mengenal stres', 'Sumber stres di kantor', '0:30', 'stres-2', 50),
             ('pdf', 'Ringkasan', 'Ringkasan materi', 'PDF 3 halaman', 'ringkasan-stres', 3), ('post', None, 'Post test', '10 soal · 30 menit', None, 60)],
      pre=stress_post[:5], post=stress_post),
 dict(key='c2', title='Pelindungan Data Pribadi untuk Karyawan', category='Kepatuhan', art=2, published=True, duration_label='2 jam',
      description='Apa itu data pribadi, kewajiban perusahaan dan karyawan menurut UU PDP, dan cara menangani data pelanggan dengan aman.',
      outcomes=['Membedakan data pribadi umum dan spesifik', 'Menangani data pelanggan sesuai prosedur', 'Melaporkan dugaan kebocoran data'],
      steps=[('pre', None, 'Pre test', '5 soal', None, 10), ('video', 'Dasar UU PDP', 'Apa itu data pribadi', '0:30', 'pdp-1', 50),
             ('video', 'Dasar UU PDP', 'Hak pemilik data', '0:30', 'pdp-2', 50),
             ('video', 'Data pelanggan di tempat kerja', 'Contoh kasus di toko', '0:30', 'pdp-3', 50),
             ('pdf', 'Data pelanggan di tempat kerja', 'Prosedur penanganan data', 'PDF 3 halaman', 'prosedur-data', 3), ('post', None, 'Post test', '5 soal · 20 menit', None, 27)],
      pre=[q('Manakah yang termasuk data pribadi spesifik?', ['Nama toko', 'Data kesehatan', 'Alamat kantor', 'Nomor telepon kantor'], 1),
           q('Siapa yang wajib menjaga data pelanggan?', ['Hanya tim IT', 'Semua karyawan yang menanganinya', 'Hanya direktur', 'Pelanggan sendiri'], 1),
           q('Boleh mengirim foto KTP pelanggan ke grup WhatsApp pribadi?', ['Boleh', 'Tidak boleh', 'Boleh jika malam hari', 'Boleh jika teman'], 1),
           q('Jika menduga ada kebocoran data, Anda:', ['Diam', 'Melapor ke petugas pelindungan data', 'Menghapus semua file', 'Memposting di media sosial'], 1),
           q('UU PDP adalah undang-undang tentang:', ['Pajak', 'Pelindungan data pribadi', 'Ketenagakerjaan', 'Lalu lintas'], 1)],
      post=[q('Data pribadi umum contohnya:', ['Nama lengkap', 'Data biometrik', 'Catatan kejahatan', 'Data kesehatan'], 0),
            q('Pelanggan meminta datanya dihapus. Langkah Anda:', ['Menolak', 'Meneruskan sesuai prosedur permintaan hak', 'Menghapus sendiri tanpa catatan', 'Mengabaikan'], 1),
            q('Cara menyimpan formulir pelanggan yang benar:', ['Di meja terbuka', 'Di lemari terkunci atau sistem resmi', 'Dibawa pulang', 'Difoto di ponsel pribadi'], 1),
            q('Dalam berapa lama kebocoran data harus dilaporkan ke atasan?', ['Secepatnya di hari yang sama', 'Bulan depan', 'Tidak perlu', 'Setahun sekali'], 0),
            q('Persetujuan pemilik data harus:', ['Jelas dan tercatat', 'Diasumsikan', 'Lisan saja tanpa catatan', 'Tidak perlu'], 0)]),
 dict(key='c3', title='Komunikasi dengan Pelanggan', category='Komunikasi', art=1, published=True, duration_label='1 jam',
      description='Cara mendengar, bertanya, dan menjawab keluhan pelanggan dengan tenang.',
      outcomes=['Mendengar aktif sebelum menjawab', 'Menjawab keluhan dengan tenang dan jelas'],
      steps=[('pre', None, 'Pre test', '5 soal', None, 10), ('video', 'Mendengar aktif', 'Mendengar sebelum menjawab', '0:30', 'komunikasi-1', 50),
             ('video', 'Mendengar aktif', 'Bertanya yang membantu', '0:30', 'komunikasi-2', 50),
             ('pdf', 'Menjawab keluhan', 'Contoh kalimat', 'PDF 3 halaman', 'contoh-kalimat', 3), ('post', None, 'Post test', '5 soal · 20 menit', None, 37)],
      pre=[q('Mendengar aktif berarti:', ['Menunggu giliran bicara', 'Memahami maksud pelanggan sebelum menjawab', 'Menyela agar cepat', 'Mengangguk saja'], 1),
           q('Pelanggan marah. Kalimat pembuka terbaik:', ['Itu bukan salah saya', 'Saya mengerti, boleh saya bantu cek?', 'Tunggu saja', 'Silakan ke cabang lain'], 1),
           q('Pertanyaan terbuka contohnya:', ['Sudah?', 'Bisa ceritakan apa yang terjadi?', 'Ya atau tidak?', 'Benar kan?'], 1),
           q('Nada suara saat pelanggan kesal sebaiknya:', ['Lebih keras', 'Tenang dan pelan', 'Datar dan cepat', 'Bercanda'], 1),
           q('Setelah masalah selesai, Anda:', ['Langsung pergi', 'Memastikan pelanggan puas', 'Meminta tip', 'Mengeluh ke rekan'], 1)],
      post=None),
 dict(key='c4', title='Presentasi yang Efektif', category='Pengembangan Diri', art=3, published=True, duration_label='1 jam',
      description='Menyusun dan membawakan presentasi singkat yang jelas.',
      outcomes=['Menyusun alur 3 bagian', 'Membawakan presentasi dengan percaya diri'],
      steps=[('pre', None, 'Pre test', '5 soal', None, 10), ('video', 'Menyusun materi', 'Alur 3 bagian', '0:30', 'presentasi-1', 50),
             ('video', 'Menyusun materi', 'Slide yang sederhana', '0:30', 'presentasi-2', 50), ('post', None, 'Post test', '5 soal · 20 menit', None, 50)],
      pre=[q('Alur presentasi 3 bagian adalah:', ['Pembuka, isi, penutup', 'Isi saja', 'Penutup, isi, pembuka', 'Tanya jawab saja'], 0),
           q('Satu slide sebaiknya berisi:', ['Satu gagasan utama', 'Sepuluh paragraf', 'Semua data', 'Tidak ada tulisan'], 0),
           q('Cara mengurangi gugup:', ['Latihan sebelumnya', 'Tidak tidur', 'Membaca slide kata per kata', 'Membelakangi audiens'], 0),
           q('Penutup yang baik berisi:', ['Ringkasan dan ajakan', 'Lelucon panjang', 'Materi baru', 'Permintaan maaf'], 0),
           q('Durasi ideal presentasi internal singkat:', ['5 sampai 10 menit', '2 jam', '1 menit', 'Sehari penuh'], 0)],
      post=None),
 dict(key='c5', title='Keselamatan Kerja di Gudang', category='K3', art=2, published=True, duration_label='45 menit',
      description='Aturan dasar K3 di gudang: alat pelindung diri, mengangkat barang, dan jalur aman.',
      outcomes=['Memakai alat pelindung diri dengan benar', 'Mengangkat barang tanpa cedera'],
      steps=[('pre', None, 'Pre test', '5 soal', None, 10), ('video', 'Dasar K3', 'Alat pelindung diri', '0:30', 'k3-1', 50),
             ('pdf', 'Dasar K3', 'Jalur aman gudang', 'PDF 3 halaman', 'jalur-aman', 3), ('post', None, 'Post test', '5 soal · 20 menit', None, 37)],
      pre=[q('Sepatu keselamatan wajib dipakai di:', ['Area gudang', 'Kantin saja', 'Parkiran saja', 'Tidak perlu'], 0),
           q('Cara mengangkat barang berat:', ['Tekuk lutut, punggung lurus', 'Membungkuk', 'Sambil berlari', 'Satu tangan'], 0),
           q('Jalur pejalan kaki di gudang ditandai dengan:', ['Garis kuning', 'Tidak ada tanda', 'Garis merah muda', 'Bendera'], 0),
           q('Jika melihat tumpahan oli, Anda:', ['Pasang tanda dan laporkan', 'Biarkan', 'Lompati', 'Tutup dengan kardus'], 0),
           q('Forklift boleh dikemudikan oleh:', ['Operator bersertifikat', 'Siapa saja', 'Tamu', 'Anak magang tanpa izin'], 0)],
      post=None),
 dict(key='c6', title='Dasar Negosiasi Penjualan', category='Komunikasi', art=3, published=False, duration_label='1 jam',
      description='Draf kelas: menyiapkan dan menutup negosiasi dengan pelanggan.',
      outcomes=['Menyiapkan batas harga', 'Menutup kesepakatan'],
      steps=[('pre', None, 'Pre test', '0 soal', None, 10), ('video', 'Persiapan', 'Mengenal kebutuhan pelanggan', '0:30', 'negosiasi-1', 50),
             ('post', None, 'Post test', '0 soal', None, 40)],
      pre=[], post=[]),
]
for c in courses:
    if c['post'] is None:
        c['post'] = [dict(x) for x in reversed(c['pre'])]

# Build steps with ids and media paths
for c in courses:
    c['id'] = uid('course', c['key'])
    st = []
    for i, (kind, section, title, meta, media, pts) in enumerate(c['steps']):
        st.append(dict(id=uid('step', c['key'], str(i)), course_id=c['id'], position=i, kind=kind, section=section, title=title,
                       meta=meta, media_url=None if media is None else ('media/%s.%s' % (media, 'mp4' if kind == 'video' else 'pdf')), points=pts))
    c['steps'] = st
    for kind in ('pre', 'post'):
        for i, qq in enumerate(c[kind]):
            qq['id'] = uid('q', c['key'], kind, str(i))
            qq['position'] = i
            qq['test_kind'] = kind

C = {c['key']: c for c in courses}
by_name = {p['full_name']: p for p in people}
active_learners = [p for p in learners if p['status'] == 'active']

# Assignments: (course, who, due ISO, assigned ISO)
plan = [('c0', None, '2026-10-20T16:59:00Z', '2026-10-06T01:00:00Z'), ('c1', None, '2026-11-27T16:59:00Z', '2026-11-16T01:00:00Z'),
        ('c2', None, '2026-11-28T16:59:00Z', '2026-11-18T01:00:00Z'), ('c3', 'Penjualan', '2026-12-05T16:59:00Z', '2026-11-23T01:10:00Z'),
        ('c5', 'Gudang', '2026-11-10T16:59:00Z', '2026-10-27T01:00:00Z')]
assignments, progress, attempts, ledger, certs, notifs = [], [], [], [], [], []
cert_n = 141

def finish(person, c, upto, post_scores, when):
    """Marks the first `upto` steps done; post_scores are post attempts in order."""
    global cert_n
    for s in c['steps'][:upto]:
        if s['kind'] == 'post':
            continue
        progress.append(dict(user_id=person['id'], step_id=s['id'], completed_at=when))
        if s['kind'] == 'pre':
            attempts.append(dict(user_id=person['id'], course_id=c['id'], test_kind='pre', score=random.choice([20, 40, 40, 60, 60, 80]), passed=None, created_at=when))
        ledger.append(dict(user_id=person['id'], amount=s['points'], reason=('Mengerjakan pre test ' + c['title']) if s['kind'] == 'pre' else 'Menyelesaikan ' + s['title'], ref=('test:' if s['kind'] == 'pre' else 'step:') + s['id'], created_at=when))
    for sc in post_scores:
        ok = sc >= 70
        attempts.append(dict(user_id=person['id'], course_id=c['id'], test_kind='post', score=sc, passed=ok, created_at=when))
        if ok:
            post = c['steps'][-1]
            progress.append(dict(user_id=person['id'], step_id=post['id'], completed_at=when))
            ledger.append(dict(user_id=person['id'], amount=post['points'], reason='Lulus post test ' + c['title'], ref='test:' + post['id'], created_at=when))
            cert_n += 1
            certs.append(dict(id=uid('cert', person['id'], c['key']), user_id=person['id'], course_id=c['id'], number='CS-2026-%04d' % cert_n, score=sc, issued_at=when))
            break

for key, dept, due, at in plan:
    c = C[key]
    for p in active_learners + [by_name['Maya Anggraini'], by_name['Teguh Wibowo']]:
        if dept and p['dept'] != dept:
            continue
        assignments.append(dict(id=uid('as', key, p['id']), course_id=c['id'], user_id=p['id'], due_at=due, assigned_at=at))

for p in active_learners:
    n = p['full_name']
    if n == 'Rina Wulandari':
        finish(p, C['c0'], 5, [85], '2026-10-14T03:20:00Z')
        finish(p, C['c1'], 4, [60], '2026-11-20T06:15:00Z')
        continue
    r = random.random()
    finish(p, C['c0'], 5, [random.choice([75, 80, 85, 90, 100])], '2026-10-1%dT03:00:00Z' % random.randint(0, 9))
    # c1: 21 of 37 others finish, rest partly
    k = random.random()
    if k < 0.57: finish(p, C['c1'], 5, [random.choice([60, 70, 80, 90])] + [80], '2026-11-2%dT04:00:00Z' % random.randint(0, 2))
    elif k < 0.85: finish(p, C['c1'], random.randint(1, 4), [], '2026-11-19T04:00:00Z')
    k = random.random()
    if k < 0.25: finish(p, C['c2'], 6, [random.choice([80, 100])], '2026-11-21T05:00:00Z')
    elif k < 0.6: finish(p, C['c2'], random.randint(1, 4), [], '2026-11-20T05:00:00Z')
    if p['dept'] == 'Penjualan' and random.random() < 0.15: finish(p, C['c3'], 2, [], '2026-11-23T02:00:00Z')
    if p['dept'] == 'Gudang':
        k = random.random()
        if k < 0.45: finish(p, C['c5'], 4, [80], '2026-11-0%dT03:00:00Z' % random.randint(3, 9))
        else: finish(p, C['c5'], random.randint(0, 3), [], '2026-11-08T03:00:00Z')

rina = by_name['Rina Wulandari']
notifs = [
 dict(user_id=rina['id'], title='Kelas baru ditugaskan', body='Komunikasi dengan Pelanggan · tenggat 5 Des 2026', link='/class/' + C['c3']['id'], read_at=None, created_at='2026-11-23T01:10:00Z'),
 dict(user_id=rina['id'], title='Pengingat tenggat', body='Manajemen Stres di Tempat Kerja tutup Jum, 27 Nov 2026', link='/class/' + C['c1']['id'], read_at=None, created_at='2026-11-22T02:00:00Z'),
 dict(user_id=rina['id'], title='Kelas baru ditugaskan', body='Pelindungan Data Pribadi untuk Karyawan · tenggat 28 Nov 2026', link='/class/' + C['c2']['id'], read_at='2026-11-18T03:00:00Z', created_at='2026-11-18T01:00:00Z'),
 dict(user_id=rina['id'], title='Sertifikat terbit', body='Orientasi Perusahaan', link='/certificates', read_at='2026-10-14T04:00:00Z', created_at='2026-10-14T03:20:00Z'),
]
for n in notifs: n['id'] = uid('n', n['title'], n['created_at'])

seed = dict(company=company, people=people, courses=courses, assignments=assignments, progress=progress,
            attempts=attempts, ledger=ledger, certificates=certs, notifications=notifs)
os.makedirs(os.path.join(ROOT, 'app', 'assets'), exist_ok=True)
json.dump(seed, open(os.path.join(ROOT, 'app', 'assets', 'seed.json'), 'w'), ensure_ascii=False)

# ---------- SQL ----------
def s(v):
    if v is None: return 'null'
    if isinstance(v, bool): return 'true' if v else 'false'
    if isinstance(v, int): return str(v)
    if isinstance(v, list): return 'array[' + ','.join(s(x) for x in v) + ']::text[]' if v else "'{}'::text[]"
    return "'" + str(v).replace("'", "''") + "'"

out = ['-- Fictional sample data. Demo password for every seeded account: BigmaDemo2026!', 'begin;']
co = company
out.append("insert into companies(id,name,mark,pass_mark,hr_email,hr_whatsapp) values (%s,%s,%s,%s,%s,%s);" % tuple(s(co[k]) for k in ('id', 'name', 'mark', 'pass_mark', 'hr_email', 'hr_whatsapp')))
for p in people:
    out.append("insert into invites(company_id,email,full_name,dept,title,role,user_id,status) values (%s,%s,%s,%s,%s,%s,%s,%s);" % (
        s(co['id']), s(p['email']), s(p['full_name']), s(p['dept']), s(p['title']), s(p['role']), s(p['id'] if p['status'] == 'active' else None), s(p['status'])))
    if p['status'] != 'active' and p['full_name'] not in invited_only:
        continue
    if p['status'] != 'active':
        continue
    out.append(("insert into auth.users(instance_id,id,aud,role,email,encrypted_password,email_confirmed_at,raw_app_meta_data,raw_user_meta_data,created_at,updated_at,confirmation_token,recovery_token,email_change_token_new,email_change) "
                "values ('00000000-0000-0000-0000-000000000000',%s,'authenticated','authenticated',%s,crypt('BigmaDemo2026!',gen_salt('bf')),now(),'{\"provider\":\"email\",\"providers\":[\"email\"]}','{}',now(),now(),'','','','');") % (s(p['id']), s(p['email'])))
    out.append("insert into auth.identities(id,user_id,provider_id,identity_data,provider,last_sign_in_at,created_at,updated_at) values (gen_random_uuid(),%s,%s,jsonb_build_object('sub',%s,'email',%s,'email_verified',true),'email',now(),now(),now());" % (s(p['id']), s(p['id']), s(p['id']), s(p['email'])))
    out.append("insert into profiles(id,company_id,full_name,email,dept,title,phone,role,consent_at,hide_on_leaderboard) values (%s,%s,%s,%s,%s,%s,%s,%s,%s,%s);" % (
        s(p['id']), s(co['id']), s(p['full_name']), s(p['email']), s(p['dept']), s(p['title']), s(p['phone']), s(p['role']),
        "'2026-10-06T02:00:00Z'", s(p['hide'])))
for c in courses:
    out.append("insert into courses(id,company_id,title,category,description,outcomes,duration_label,art,published) values (%s,%s,%s,%s,%s,%s,%s,%s,%s);" % (
        s(c['id']), s(co['id']), s(c['title']), s(c['category']), s(c['description']), s(c['outcomes']), s(c['duration_label']), s(c['art']), s(c['published'])))
    for st in c['steps']:
        out.append("insert into steps(id,course_id,position,kind,section,title,meta,media_url,points) values (%s,%s,%s,%s,%s,%s,%s,%s,%s);" % tuple(
            s(st[k]) for k in ('id', 'course_id', 'position', 'kind', 'section', 'title', 'meta', 'media_url', 'points')))
    for kind in ('pre', 'post'):
        for qq in c[kind]:
            out.append("insert into questions(id,course_id,test_kind,position,body,options) values (%s,%s,%s,%s,%s,%s);" % (
                s(qq['id']), s(c['id']), s(kind), s(qq['position']), s(qq['body']), s(qq['options'])))
            out.append("insert into question_keys(question_id,answer) values (%s,%s);" % (s(qq['id']), s(qq['answer'])))
active_ids = {p['id'] for p in people if p['status'] == 'active'}
for a in assignments:
    if a['user_id'] not in active_ids: continue
    out.append("insert into assignments(id,company_id,course_id,user_id,due_at,assigned_at) values (%s,%s,%s,%s,%s,%s);" % (s(a['id']), s(co['id']), s(a['course_id']), s(a['user_id']), s(a['due_at']), s(a['assigned_at'])))
for r in progress:
    out.append("insert into step_progress(user_id,step_id,completed_at) values (%s,%s,%s) on conflict do nothing;" % (s(r['user_id']), s(r['step_id']), s(r['completed_at'])))
for r in attempts:
    out.append("insert into attempts(user_id,course_id,test_kind,score,passed,answers,created_at) values (%s,%s,%s,%s,%s,'[]',%s);" % (s(r['user_id']), s(r['course_id']), s(r['test_kind']), s(r['score']), s(r['passed']), s(r['created_at'])))
for r in ledger:
    out.append("insert into points_ledger(user_id,company_id,amount,reason,ref,created_at) values (%s,%s,%s,%s,%s,%s) on conflict do nothing;" % (s(r['user_id']), s(co['id']), s(r['amount']), s(r['reason']), s(r['ref']), s(r['created_at'])))
for r in certs:
    out.append("insert into certificates(id,user_id,course_id,number,score,issued_at) values (%s,%s,%s,%s,%s,%s);" % (s(r['id']), s(r['user_id']), s(r['course_id']), s(r['number']), s(r['score']), s(r['issued_at'])))
for r in notifs:
    out.append("insert into notifications(id,user_id,title,body,link,read_at,created_at) values (%s,%s,%s,%s,%s,%s,%s);" % (s(r['id']), s(r['user_id']), s(r['title']), s(r['body']), s(r['link']), s(r['read_at']), s(r['created_at'])))
out.append('commit;')
open(os.path.join(ROOT, 'supabase', 'seed.sql'), 'w').write('\n'.join(out) + '\n')

rp = sum(l['amount'] for l in ledger if l['user_id'] == rina['id'])
print('people', len(people), 'assignments', len(assignments), 'progress', len(progress), 'ledger', len(ledger), 'certs', len(certs), 'rina points', rp)
print('media', sorted({st['media_url'] for c in courses for st in c['steps'] if st['media_url']}))
