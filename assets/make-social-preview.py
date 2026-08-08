from PIL import Image, ImageDraw, ImageFont
import sys

W, H = 1280, 640
OUT = sys.argv[1] if len(sys.argv) > 1 else "/tmp/social-preview.png"
S = 3                      # supersample factor
w, h = W * S, H * S

BOLD = "/System/Library/Fonts/Supplemental/Arial Bold.ttf"
REG = "/System/Library/Fonts/Supplemental/Arial.ttf"
font = lambda p, sz: ImageFont.truetype(p, int(sz * S))

BLUE, WHITE = (63, 158, 255), (255, 255, 255)
SUB, MID, DIM, RULE = (198, 211, 230), (156, 174, 199), (112, 130, 155), (52, 65, 88)

# ---------- background ----------
top, bot = (12, 17, 32), (20, 27, 46)
img = Image.new("RGB", (w, h), top)
d = ImageDraw.Draw(img)
for y in range(h):
    t = y / (h - 1)
    d.line([(0, y), (w, y)],
           fill=(int(top[0] + (bot[0] - top[0]) * t),
                 int(top[1] + (bot[1] - top[1]) * t),
                 int(top[2] + (bot[2] - top[2]) * t)))

# ---------- helpers (all coords in 1x logical space) ----------
def text_w(s, fnt, tracking=0):
    if tracking:
        return sum(d.textlength(c, font=fnt) for c in s) + tracking * S * (len(s) - 1)
    return d.textlength(s, font=fnt)

def draw_center(s, fnt, y, fill, tracking=0):
    """y = logical top of the text box."""
    tw = text_w(s, fnt, tracking)
    x = (w - tw) / 2
    yy = y * S
    if tracking:
        for c in s:
            d.text((x, yy), c, font=fnt, fill=fill)
            x += d.textlength(c, font=fnt) + tracking * S
    else:
        d.text((x, yy), s, font=fnt, fill=fill)

# ---------- layout ----------
f_eyebrow = font(BOLD, 31)
f_title   = font(BOLD, 128)
f_sub     = font(REG, 39)
f_name    = font(BOLD, 51)
f_certs   = font(REG, 31)
f_tags    = font(REG, 25)

draw_center("IDENTITY & ACCESS MANAGEMENT", f_eyebrow, 84, BLUE, tracking=4)
draw_center("IAM Portfolio", f_title, 132, WHITE)
draw_center("Hands-On Labs, Documented as Case Studies", f_sub, 296, SUB)

rw = 600 * S
ry = 384 * S
d.line([((w - rw) / 2, ry), ((w + rw) / 2, ry)], fill=RULE, width=max(1, int(1.5 * S)))

draw_center("Mukhtar Houry", f_name, 420, WHITE)
draw_center("CompTIA Security+   ·   ISC2 CC", f_certs, 494, MID)
draw_center("Microsoft Entra ID  ·  Conditional Access  ·  PIM  ·  Identity Governance  ·  Lifecycle Workflows",
            f_tags, 550, DIM)

img.resize((W, H), Image.LANCZOS).save(OUT, "PNG", optimize=True)
print("wrote", OUT)
