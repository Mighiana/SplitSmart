from PIL import Image, ImageDraw
import os, shutil

RAW_DIR  = r"C:\Users\usman\Desktop\SplitSmart_App\screenshots\raw"
OUT_DIR  = r"C:\Users\usman\Desktop\SplitSmart_App\screenshots\final"
ICON_SRC = r"C:\Users\usman\Desktop\SplitSmart_App\android\app\src\main\res\mipmap-xxxhdpi\ic_launcher.png"
os.makedirs(OUT_DIR, exist_ok=True)

ALL_SCREENS = [
    "ss1_home.png",
    "ss2_groups.png",
    "ss3_group_detail.png",
    "ss4_add_expense.png",
    "ss5_overview.png",
    "ss6_planner.png",
    "ss7_goals.png",
    "ss8_overdue.png",
    # light-mode set
    "ss1_home_light.png",
    "ss2_groups_light.png",
    "ss3_group_detail_light.png",
    "ss4_add_expense_light.png",
    "ss5_overview_light.png",
    "ss6_planner_light.png",
    "ss7_goals_light.png",
    "ss8_overdue_light.png",
]

# Pre-load icon once — no alpha, square 192x192
_icon_raw = Image.open(ICON_SRC).convert("RGBA")


def make_circular_icon(size):
    """Return a circular-clipped RGBA version of the app icon at `size` px."""
    icon = _icon_raw.resize((size, size), Image.LANCZOS)
    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).ellipse([0, 0, size - 1, size - 1], fill=255)
    out = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    out.paste(icon, (0, 0), mask)
    return out


def add_badge(img_rgba, size=110, margin=28):
    """Paste a circular icon badge in the bottom-right corner."""
    icon_circle = make_circular_icon(size)
    x = img_rgba.width - size - margin
    y = img_rgba.height - size - margin
    img_rgba.paste(icon_circle, (x, y), icon_circle)


for filename in ALL_SCREENS:
    src = os.path.join(RAW_DIR, filename)
    dst = os.path.join(OUT_DIR, filename)
    if not os.path.exists(src):
        print(f"MISSING: {src}")
        continue

    img = Image.open(src).convert("RGBA")
    draw = ImageDraw.Draw(img)
    W, H = img.size

    if filename in ("ss1_home.png", "ss1_home_light.png"):
        # --- Home screen: erase personal-info strip then paste real app icon ---
        bg = img.getpixel((20, 350))[:3]   # sample bg below the strip
        draw.rectangle([0, 101, W, 295], fill=bg + (255,))

        # Place the circular app icon where the avatar was
        AVATAR_CX, AVATAR_CY, AVATAR_R = 135, 198, 68
        icon_size = AVATAR_R * 2          # 136 px diameter
        icon_circle = make_circular_icon(icon_size)
        paste_x = AVATAR_CX - AVATAR_R
        paste_y = AVATAR_CY - AVATAR_R
        img.paste(icon_circle, (paste_x, paste_y), icon_circle)
    else:
        # --- All other screens: small icon badge bottom-right ---
        add_badge(img)

    img.convert("RGB").save(dst, "PNG")
    print(f"OK: {filename}")

print("\nDone! Final screenshots in:", OUT_DIR)
