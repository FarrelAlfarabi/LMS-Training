"""Makes placeholder lesson videos (30 s title cards) and PDFs for the sample courses."""
import json, os, subprocess
from reportlab.lib.pagesizes import A4
from reportlab.pdfgen import canvas
from reportlab.lib.colors import HexColor

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, 'app', 'web', 'media')
os.makedirs(OUT, exist_ok=True)
seed = json.load(open(os.path.join(ROOT, 'app', 'assets', 'seed.json')))
FONT = '/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf'
FONT_R = '/usr/share/fonts/truetype/liberation/LiberationSans-Regular.ttf'

def esc(t): return t.replace('\\', '\\\\').replace(':', '\\:').replace("'", "’").replace(',', '\\,')

for c in seed['courses']:
    for s in c['steps']:
        if not s['media_url']:
            continue
        path = os.path.join(ROOT, 'app', 'web', s['media_url'])
        if os.path.exists(path):
            continue
        if s['kind'] == 'video':
            vf = (f"drawtext=fontfile={FONT_R}:text='{esc(c['title'])}':fontcolor=0xC3D0E6:fontsize=30:x=80:y=250,"
                  f"drawtext=fontfile={FONT}:text='{esc(s['title'])}':fontcolor=white:fontsize=60:x=80:y=300,"
                  f"drawtext=fontfile={FONT_R}:text='Video contoh untuk prototipe Bigma':fontcolor=0x9FB1D2:fontsize=26:x=80:y=400,"
                  f"drawbox=x=80:y=620:w=1120:h=8:color=0x1C3B73:t=fill,"
                  f"drawbox=x=80:y=620:w='1120*t/30':h=8:color=0xF26B1D:t=fill")
            subprocess.run(['ffmpeg', '-loglevel', 'error', '-f', 'lavfi', '-i', 'color=c=0x0F2A5C:s=1280x720:d=30:r=15',
                            '-f', 'lavfi', '-i', 'anullsrc=r=22050:cl=mono', '-shortest', '-vf', vf,
                            '-c:v', 'libx264', '-preset', 'veryslow', '-crf', '30', '-pix_fmt', 'yuv420p', '-c:a', 'aac', '-b:a', '24k',
                            '-movflags', '+faststart', path], check=True)
        else:
            pdf = canvas.Canvas(path, pagesize=A4)
            w, h = A4
            for page in range(1, 4):
                pdf.setFillColor(HexColor('#0F2A5C')); pdf.rect(0, h - 90, w, 90, fill=1, stroke=0)
                pdf.setFillColor(HexColor('#FFFFFF')); pdf.setFont('Helvetica-Bold', 18); pdf.drawString(50, h - 55, s['title'])
                pdf.setFillColor(HexColor('#111827')); pdf.setFont('Helvetica', 12)
                pdf.drawString(50, h - 130, c['title'] + '  |  halaman %d dari 3' % page)
                y = h - 170
                for i, line in enumerate(c['outcomes'] * 2):
                    pdf.drawString(60, y, '%d. %s' % (i + 1, line)); y -= 24
                pdf.setFillColor(HexColor('#596275')); pdf.setFont('Helvetica-Oblique', 10)
                pdf.drawString(50, 40, 'Dokumen contoh untuk prototipe Bigma. Isi asli diunggah oleh HR.')
                pdf.showPage()
            pdf.save()
        print('made', s['media_url'])
