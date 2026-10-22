"""
Featured-card thumbnail for Lab 2.

LinkedIn renders a Featured link thumbnail in a PORTRAIT box, measured at
roughly 350x545 (ratio ~0.64). A 1280x640 landscape source gets scaled to fill
that height and then cropped to about a third of its width, which slices text
mid-word no matter how narrow the safe band is.

So this one is built portrait at 800x1245 to match the box. Nothing is cropped,
which means the full width is usable and the type can breathe.
"""
from PIL import Image, ImageDraw, ImageFont
import sys

W, H = 1200, 628
S = 3
w, h = W * S, H * S
PAD = 70
CONTENT = W - PAD * 2
OUT = sys.argv[1] if len(sys.argv) > 1 else "/tmp/lab2-preview.png"

BOLD = "/System/Library/Fonts/Supplemental/Arial Bold.ttf"
REG  = "/System/Library/Fonts/Supplemental/Arial.ttf"

BLUE, WHITE = (63, 158, 255), (255, 255, 255)
SUB, MID, DIM, RULE = (198, 211, 230), (150, 168, 194), (124, 142, 168), (48, 60, 82)

img = Image.new("RGB", (w, h), (12, 17, 32))
d = ImageDraw.Draw(img)
top, bot = (10, 14, 28), (21, 28, 48)
for y in range(h):
    t = y / (h - 1)
    d.line([(0, y), (w, y)], fill=tuple(int(top[i] + (bot[i] - top[i]) * t) for i in range(3)))

# thin keyline just inside the edge
m = 22 * S
d.rectangle([m, m, w - m, h - m], outline=(38, 49, 72), width=max(1, int(1.2 * S)))

def font(p, sz): return ImageFont.truetype(p, int(sz * S))
def width_of(s, f, tr=0):
    if tr: return sum(d.textlength(c, font=f) for c in s) + tr*S*(len(s)-1)
    return d.textlength(s, font=f)
def fit(s, path, start, maxw, tr=0):
    sz = start
    while sz > 6:
        f = font(path, sz)
        if width_of(s, f, tr) <= maxw * S: return f
        sz -= 1
    return font(path, 6)
def center(s, f, y, fill, tr=0):
    tw = width_of(s, f, tr); x, yy = w/2 - tw/2, y*S
    if tr:
        for c in s:
            d.text((x, yy), c, font=f, fill=fill); x += d.textlength(c, font=f) + tr*S
    else:
        d.text((x, yy), s, font=f, fill=fill)
def rule(y, frac=0.72):
    rw = CONTENT * frac * S
    d.line([(w/2 - rw/2, y*S), (w/2 + rw/2, y*S)], fill=RULE, width=max(1, int(1.4*S)))

# ---------- content ----------
center("IAM PORTFOLIO", fit("IAM PORTFOLIO", BOLD, 30, CONTENT, tr=6), 52, BLUE, tr=6)
center("Leaver: Off-boarding That Says It Worked", fit("Leaver: Off-boarding That Says It Worked", BOLD, 70, CONTENT), 100, WHITE)
rule(200, 0.6)
fd = fit("The user kept their access. Zero failures reported.", REG, 40, CONTENT)
center("6 of 6 tasks complete.", fd, 228, SUB)
center("The user kept their access. Zero failures reported.", fd, 282, SUB)
rule(360, 0.6)
center("Mukhtar Houry", fit("Mukhtar Houry", BOLD, 52, CONTENT), 385, WHITE)
center("CompTIA Security+  ·  ISC2 CC", fit("CompTIA Security+  ·  ISC2 CC", REG, 32, CONTENT), 455, MID)
URL = "mukhoury.github.io/iam-portfolio/leaver"
center(URL, fit(URL, REG, 36, CONTENT), 525, SUB)
img.resize((W, H), Image.LANCZOS).save(OUT, "PNG", optimize=True)
print("wrote", OUT, W, H)
