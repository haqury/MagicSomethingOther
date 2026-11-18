"""Генерация placeholder-спрайтов в духе chibi-RPG (не ассеты Ragnarok Online)."""
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1] / "assets"


def save(img: Image.Image, rel: str) -> None:
    path = ROOT / rel
    path.parent.mkdir(parents=True, exist_ok=True)
    img.save(path, "PNG")


def outline(draw: ImageDraw.ImageDraw, pts, color=(20, 20, 28), width=1):
    for i in range(len(pts)):
        a, b = pts[i], pts[(i + 1) % len(pts)]
        draw.line([a, b], fill=color, width=width)


def player_mage() -> None:
    w, h = 48, 64
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    # Robe
    robe = [(10, 38), (38, 38), (34, 62), (14, 62)]
    d.polygon(robe, fill=(58, 72, 155))
    outline(d, robe)
    # Head (chibi)
    d.ellipse((10, 6, 38, 34), fill=(255, 220, 185))
    d.ellipse((10, 6, 38, 34), outline=(20, 20, 28))
    d.ellipse((16, 16, 22, 22), fill=(40, 30, 25))
    d.ellipse((26, 16, 32, 22), fill=(40, 30, 25))
    # Hat
    hat = [(8, 12), (40, 12), (24, 0)]
    d.polygon(hat, fill=(120, 90, 220))
    outline(d, hat)
    # Staff
    d.rectangle((36, 18, 40, 58), fill=(110, 70, 35))
    d.ellipse((33, 10, 43, 20), fill=(180, 220, 255))
    save(img, "sprites/player_mage.png")


def icon_element(name: str, inner) -> None:
    s = 40
    img = Image.new("RGBA", (s, s), (30, 32, 42, 255))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle((2, 2, s - 3, s - 3), radius=6, outline=(80, 85, 110), width=2)
    inner(d, s)
    save(img, f"ui/elements/{name}.png")


def icon_form(name: str, inner) -> None:
    s = 40
    img = Image.new("RGBA", (s, s), (32, 30, 38, 255))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle((2, 2, s - 3, s - 3), radius=6, outline=(100, 90, 120), width=2)
    inner(d, s)
    save(img, f"ui/forms/{name}.png")


def main() -> None:
    player_mage()

    elements = {
        "fire": lambda d, s: d.polygon([(s // 2, 8), (s - 10, s - 8), (10, s - 8)], fill=(232, 93, 4)),
        "water": lambda d, s: d.ellipse((8, 12, s - 8, s - 8), fill=(33, 158, 188)),
        "earth": lambda d, s: d.rectangle((10, 14, s - 10, s - 10), fill=(122, 106, 58)),
        "air": lambda d, s: d.arc((8, 8, s - 8, s - 8), 200, 340, fill=(197, 213, 228), width=4),
        "ice": lambda d, s: d.polygon([(s // 2, 8), (s - 8, s // 2), (s // 2, s - 8), (8, s // 2)], fill=(169, 222, 249)),
        "light": lambda d, s: d.ellipse((10, 10, s - 10, s - 10), fill=(255, 232, 163)),
        "lightning": lambda d, s: d.polygon([(s // 2 + 2, 6), (s - 12, s // 2), (s // 2, s // 2), (s // 2 - 6, s - 6), (14, s // 2), (s // 2, s // 2)], fill=(240, 225, 74)),
        "empty": lambda d, s: d.line((12, 12, s - 12, s - 12), fill=(90, 95, 110), width=3),
    }
    for k, fn in elements.items():
        icon_element(k, fn)

    forms = {
        "projectile": lambda d, s: d.polygon([(8, s // 2), (s - 8, s // 2 - 6), (s - 8, s // 2 + 6)], fill=(220, 220, 230)),
        "area": lambda d, s: d.ellipse((10, 10, s - 10, s - 10), outline=(220, 120, 80), width=3),
        "wall": lambda d, s: d.rectangle((8, 14, s - 8, s - 14), fill=(140, 130, 100)),
        "beam": lambda d, s: d.line((8, s // 2, s - 8, s // 2), fill=(255, 200, 120), width=5),
        "self": lambda d, s: d.ellipse((14, 14, s - 14, s - 14), fill=(180, 255, 200)),
        "around": lambda d, s: (d.ellipse((6, 6, s - 6, s - 6), outline=(200, 150, 255), width=2), d.ellipse((16, 16, s - 16, s - 16), fill=(200, 150, 255))),
        "mine": lambda d, s: d.ellipse((10, 16, s - 10, s - 10), fill=(90, 90, 95)),
        "empty": lambda d, s: d.line((12, 12, s - 12, s - 12), fill=(90, 95, 110), width=3),
    }
    for k, fn in forms.items():
        icon_form(k, fn)

    # Снаряд в бою
    p = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    pd = ImageDraw.Draw(p)
    pd.polygon([(2, 8), (14, 4), (14, 12)], fill=(255, 180, 80))
    save(p, "sprites/spell_projectile.png")

    print("Sprites written to", ROOT)


if __name__ == "__main__":
    main()