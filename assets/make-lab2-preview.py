"""
Featured-card thumbnail for Lab 2, the lead project.

Same constraint as make-social-preview.py: LinkedIn crops the Featured link
thumbnail to roughly the centre 455px of a 1280px image, so everything lives
inside a 420px safe band and stacks vertically to use the full 640px height.

The hook is the number. A recruiter scrolling should read "6 of 6 tasks
complete, 0 failures, the user kept their access" before they read anything else.
"""
from PIL import Image, ImageDraw, ImageFont
import sys

W, H = 1280, 640
S = 3
w, h = W * S, H * S
SAFE_W = 420
OUT = sys.argv[1] if len(sys.argv) > 1 else "/tmp/lab2-preview.png"

BOLD = "/System/Library/Fonts/Supplemental/Arial Bold.ttf"
REG  = "/System/Library/Fonts/Supplemental/Arial.ttf"

BLUE, WHITE = (63, 158, 255), (255, 255, 255)
AMBER = (255, 176, 62)
SUB, MID, DIM, RULE = (198, 211, 230), (150, 168, 194), (124, 142, 168), (48, 60, 82)

img = Image.new("RGB", (w, h), (12, 17, 32))
d = ImageDraw.Draw(img)
top, bot = (11, 15, 29), (19, 26, 44)
for y in range(h):
    t = y / (h - 1)
    d.line([(0, y), (w, y)], fill=tuple(int(top[i] + (bot[i] - top[i]) * t) for i in range(3)))

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
    tw = width_of(s, f, tr); x, yy = w/2 - tw/2, y*S
    if tr:
        for c in s:
            d.text((x, yy), c, font=f, fill=fill); x += d.textlength(c, font=f) + tr*S
    else:
        d.text((x, yy), s, font=f, fill=fill)
def rule(y, frac=0.80):
    rw = SAFE_W * frac * S
    d.line([(w/2 - rw/2, y*S), (w/2 + rw/2, y*S)], fill=RULE, width=max(1, int(1.4*S)))

# ---------- content ----------
center("IAM PORTFOLIO  ·  LAB 2", fit("IAM PORTFOLIO  ·  LAB 2", BOLD, 22, SAFE_W, tr=3), 40, BLUE, tr=3)

center("Identity Governance",      fit("Identity Governance", BOLD, 46, SAFE_W), 80, WHITE)
center("and Lifecycle Automation", fit("and Lifecycle Automation", BOLD, 46, SAFE_W), 132, WHITE)

rule(200)

center("6 of 6 tasks complete.", fit("6 of 6 tasks complete.", BOLD, 32, SAFE_W), 224, WHITE)
center("0 failures.",            fit("0 failures.", BOLD, 32, SAFE_W), 268, WHITE)
center("The user kept their access.", fit("The user kept their access.", REG, 26, SAFE_W), 320, AMBER)

rule(378)

center("Mukhtar Houry", fit("Mukhtar Houry", BOLD, 38, SAFE_W), 400, WHITE)
center("CompTIA Security+  ·  ISC2 CC", fit("CompTIA Security+  ·  ISC2 CC", REG, 24, SAFE_W), 452, MID)

rule(506)

f = fit("Microsoft Entra ID  ·  Lifecycle Workflows", REG, 22, SAFE_W)
center("Microsoft Entra ID  ·  Lifecycle Workflows", f, 528, DIM)
center("Access Reviews  ·  PIM  ·  Entitlement Mgmt", f, 562, DIM)

URL = "mukhoury.github.io/iam-portfolio/lab2"
center(URL, fit(URL, REG, 21, SAFE_W), 602, MID)

img.resize((W, H), Image.LANCZOS).save(OUT, "PNG", optimize=True)
print("wrote", OUT)
