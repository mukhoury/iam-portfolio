"""
Build the 1280x640 GitHub social preview.

CONSTRAINT (learned the hard way, four times):
LinkedIn's Featured link card renders the thumbnail in a PORTRAIT box and crops
a 2:1 image to roughly the centre 36% of its width -- a ~455px band out of 1280.
Anything wider than that is sliced mid-word.

So EVERYTHING lives inside the centre band, stacked vertically to use the full
640px of height that LinkedIn does show. A subtle panel sits behind that column
so the wide GitHub view reads as a deliberate vertical card rather than a banner
with empty sides.

Every string is auto-fitted to the band width, so no future edit can silently
push text past the crop boundary the way "larger text" did in d68dc24.
"""
from PIL import Image, ImageDraw, ImageFont
import sys

W, H = 1280, 640
S = 3
w, h = W * S, H * S
SAFE_W = 420                            # measured crop is ~455; stay inside it
OUT = sys.argv[1] if len(sys.argv) > 1 else "/tmp/social-preview.png"

BOLD = "/System/Library/Fonts/Supplemental/Arial Bold.ttf"
REG  = "/System/Library/Fonts/Supplemental/Arial.ttf"

BLUE, WHITE = (63, 158, 255), (255, 255, 255)
SUB, MID, DIM, RULE = (198, 211, 230), (150, 168, 194), (124, 142, 168), (48, 60, 82)

# ---------- background ----------
img = Image.new("RGB", (w, h), (12, 17, 32))
d = ImageDraw.Draw(img)
top, bot = (11, 15, 29), (19, 26, 44)
for y in range(h):
    t = y / (h - 1)
    d.line([(0, y), (w, y)], fill=tuple(int(top[i] + (bot[i] - top[i]) * t) for i in range(3)))

# centre panel, so the wide view looks intentional
pw = (SAFE_W + 46) * S
d.rectangle([w/2 - pw/2, 0, w/2 + pw/2, h], fill=(17, 23, 40))
for px in (w/2 - pw/2, w/2 + pw/2):
    d.line([(px, 0), (px, h)], fill=(34, 44, 66), width=max(1, int(1.2*S)))

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
    tw = width_of(s, f, tr)
    x, yy = w/2 - tw/2, y*S
    if tr:
        for c in s:
            d.text((x, yy), c, font=f, fill=fill)
            x += d.textlength(c, font=f) + tr*S
    else:
        d.text((x, yy), s, font=f, fill=fill)

def rule(y, frac=0.80):
    rw = SAFE_W * frac * S
    d.line([(w/2 - rw/2, y*S), (w/2 + rw/2, y*S)], fill=RULE, width=max(1, int(1.4*S)))

# ---------- content, all inside SAFE_W ----------
center("IDENTITY & ACCESS", fit("IDENTITY & ACCESS", BOLD, 24, SAFE_W, tr=4), 44, BLUE, tr=4)

center("IAM Portfolio", fit("IAM Portfolio", BOLD, 66, SAFE_W), 84, WHITE)

center("Hands-On Labs,",        fit("Hands-On Labs,", REG, 27, SAFE_W), 168, SUB)
center("Documented as Case Studies", fit("Documented as Case Studies", REG, 27, SAFE_W), 202, SUB)

rule(258)

center("Mukhtar Houry", fit("Mukhtar Houry", BOLD, 42, SAFE_W), 280, WHITE)
center("CompTIA Security+  ·  ISC2 CC", fit("CompTIA Security+  ·  ISC2 CC", REG, 25, SAFE_W), 336, MID)

rule(388)

f_lab = fit("Identity Governance  ·  PIM  ·  Access Reviews", REG, 23, SAFE_W)
labs = [
    "Dynamic Groups  ·  Conditional Access",
    "Identity Governance  ·  PIM  ·  Access Reviews",
    "Lifecycle Workflows  ·  Graph PowerShell",
    "Hybrid Identity  ·  Entra Connect Sync",
]
for i, s in enumerate(labs):
    center(s, f_lab, 412 + i*38, DIM)

rule(578)
URL = "https://github.com/mukhoury/iam-portfolio"
center(URL, fit(URL, REG, 22, SAFE_W), 596, MID)

img.resize((W, H), Image.LANCZOS).save(OUT, "PNG", optimize=True)
print("wrote", OUT)
