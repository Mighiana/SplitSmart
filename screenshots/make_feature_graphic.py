"""
Generate the Play Store Feature Graphic (1024x500) for Splitzee.
Recreates the dark-teal branded banner with the new app name.
"""
from PIL import Image, ImageDraw, ImageFont
import os

BASE = r"C:\Users\usman\Desktop\SplitSmart_App\screenshots"
RAW = os.path.join(BASE, "raw")
OUT = os.path.join(BASE, "feature_graphic.png")

W, H = 1024, 500

# ---- Colours (sampled to match the original teal banner) ----
TEAL_DARK = (10, 61, 55)     # top-left
TEAL_MID = (16, 78, 70)      # bottom-right
GREEN = (45, 212, 145)       # accent green
WHITE = (245, 248, 247)
MUTED = (170, 200, 194)      # muted tagline / bullets

# ---- Fonts ----
def font(path, size):
    return ImageFont.truetype(path, size)

F_BOLD = r"C:\Windows\Fonts\segoeuib.ttf"
F_REG = r"C:\Windows\Fonts\segoeui.ttf"
F_SEMI = r"C:\Windows\Fonts\seguisb.ttf"

f_title = font(F_BOLD, 92)
f_tag = font(F_SEMI, 30)
f_bullet = font(F_REG, 26)

# ---- Background: diagonal teal gradient ----
img = Image.new("RGB", (W, H), TEAL_DARK)
px = img.load()
for y in range(H):
    for x in range(W):
        t = (x / W * 0.5 + y / H * 0.5)
        r = int(TEAL_DARK[0] + (TEAL_MID[0] - TEAL_DARK[0]) * t)
        g = int(TEAL_DARK[1] + (TEAL_MID[1] - TEAL_DARK[1]) * t)
        b = int(TEAL_DARK[2] + (TEAL_MID[2] - TEAL_DARK[2]) * t)
        px[x, y] = (r, g, b)

draw = ImageDraw.Draw(img, "RGBA")

# ---- Decorative concentric arcs (top-right + bottom-left), subtle ----
def rings(cx, cy, radii, color):
    for rr in radii:
        draw.ellipse([cx - rr, cy - rr, cx + rr, cy + rr], outline=color, width=2)

rings(990, 40, [40, 70, 100, 130], (255, 255, 255, 18))
rings(60, 470, [40, 70, 100], (45, 212, 145, 22))

# ---- Left content block ----
LX = 56  # left margin

# Green accent bar beside the title
draw.rounded_rectangle([LX, 70, LX + 10, 70 + 150], radius=5, fill=GREEN)

# Title "Split" (white) + "zee" (green), stacked two lines like original
tx = LX + 34
draw.text((tx, 58), "Split", font=f_title, fill=WHITE)
draw.text((tx, 150), "zee", font=f_title, fill=GREEN)

# Tagline
draw.text((LX + 2, 270), "Split bills. Track money.", font=f_tag, fill=WHITE)
draw.text((LX + 2, 306), "Live smarter.", font=f_tag, fill=GREEN)

# Bullets
bullets = [
    "Bill splitting & group expenses",
    "Personal expense tracker",
    "Budgets & saving goals",
    "No ads  -  Free  -  Encrypted",
]
by = 360
for b in bullets:
    # small check box
    draw.rounded_rectangle([LX + 2, by + 4, LX + 22, by + 24], radius=4,
                           outline=GREEN, width=2)
    draw.line([(LX + 7, by + 14), (LX + 11, by + 19)], fill=GREEN, width=2)
    draw.line([(LX + 11, by + 19), (LX + 18, by + 8)], fill=GREEN, width=2)
    draw.text((LX + 36, by), b, font=f_bullet, fill=MUTED)
    by += 33

# ---- Right side: three phone mockups ----
def phone_mock(screenshot_path, target_h):
    """Return RGBA phone with rounded corners + dark bezel."""
    shot = Image.open(screenshot_path).convert("RGB")
    sw, sh = shot.size
    scale = target_h / sh
    tw = int(sw * scale)
    shot = shot.resize((tw, target_h), Image.LANCZOS)

    # rounded screen mask
    radius = 26
    mask = Image.new("L", (tw, target_h), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, tw, target_h], radius=radius, fill=255)

    # bezel frame
    bez = 8
    fw, fh = tw + bez * 2, target_h + bez * 2
    frame = Image.new("RGBA", (fw, fh), (0, 0, 0, 0))
    fd = ImageDraw.Draw(frame)
    fd.rounded_rectangle([0, 0, fw, fh], radius=radius + bez, fill=(20, 28, 26, 255))
    frame.paste(shot, (bez, bez), mask)
    return frame

# Use light-mode shots for the bright look in the original
mock_files = ["ss2_groups_light.png", "ss5_overview_light.png", "ss6_planner_light.png"]
mock_files = [os.path.join(RAW, m) for m in mock_files]

# Center phone tallest, side phones shorter (staggered)
heights = [330, 400, 330]
phones = [phone_mock(p, h) for p, h in zip(mock_files, heights)]

# Positions: right cluster, center one forward
cx = 760  # cluster center x
positions = [
    (cx - 215, 130),  # left phone
    (cx - 90, 70),    # center phone (front, higher)
    (cx + 95, 130),   # right phone
]
# Paste side phones first, then center on top
order = [0, 2, 1]
for i in order:
    ph = phones[i]
    img.paste(ph, positions[i], ph)

img.save(OUT, "PNG")
print("Saved:", OUT, img.size)
