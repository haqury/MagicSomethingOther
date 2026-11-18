"""Chroma-key character sprites and install spell icons into assets/."""
from pathlib import Path

from PIL import Image, ImageDraw

SRC = Path(r"C:\Users\haqury\.cursor\projects\c-Users-haqury-Documents-magic-something-other\assets")
ROOT = Path(r"c:\Users\haqury\Documents\magic-something-other")
SPRITES = ROOT / "assets" / "sprites"
ELEMENTS = ROOT / "assets" / "ui" / "elements"
FORMS = ROOT / "assets" / "ui" / "forms"


def is_magenta(r: int, g: int, b: int) -> bool:
	return r > 170 and b > 170 and g < 140 and (r + b) > g * 3


def key_magenta(im: Image.Image) -> Image.Image:
	im = im.convert("RGBA")
	pix = im.load()
	w, h = im.size
	for y in range(h):
		for x in range(w):
			r, g, b, _a = pix[x, y]
			if is_magenta(r, g, b):
				pix[x, y] = (0, 0, 0, 0)
	return im


def crop_alpha(im: Image.Image, pad: int = 4) -> Image.Image:
	bbox = im.getbbox()
	if bbox is None:
		return im
	x0, y0, x1, y1 = bbox
	x0 = max(0, x0 - pad)
	y0 = max(0, y0 - pad)
	x1 = min(im.width, x1 + pad)
	y1 = min(im.height, y1 + pad)
	return im.crop((x0, y0, x1, y1))


def fit_height(im: Image.Image, height: int) -> Image.Image:
	w, h = im.size
	scale = height / float(h)
	nw = max(1, int(round(w * scale)))
	return im.resize((nw, height), Image.Resampling.LANCZOS)


def save_sprite(src_name: str, dest: Path, height: int) -> None:
	im = key_magenta(Image.open(SRC / src_name))
	im = fit_height(crop_alpha(im), height)
	dest.parent.mkdir(parents=True, exist_ok=True)
	im.save(dest)
	print(f"sprite {dest.name} {im.size}")


def save_icon(src_name: str, dest: Path, size: int = 256) -> None:
	im = Image.open(SRC / src_name).convert("RGBA")
	im = im.resize((size, size), Image.Resampling.LANCZOS)
	dest.parent.mkdir(parents=True, exist_ok=True)
	im.save(dest)
	print(f"icon {dest.name}")


def save_empty(dest: Path, size: int = 256) -> None:
	im = Image.new("RGBA", (size, size), (0, 0, 0, 0))
	draw = ImageDraw.Draw(im)
	margin = 10
	draw.rounded_rectangle(
		(margin, margin, size - margin, size - margin),
		radius=36,
		fill=(28, 30, 36, 255),
		outline=(70, 74, 84, 255),
		width=8,
	)
	dest.parent.mkdir(parents=True, exist_ok=True)
	im.save(dest)
	print(f"empty {dest.name}")


def main() -> None:
	save_sprite("player_mage.jpg", SPRITES / "player_mage.png", 72)
	save_sprite("enemy_orc.jpg", SPRITES / "enemy_orc.png", 72)
	save_sprite("enemy_slime.jpg", SPRITES / "enemy_slime.png", 56)
	save_sprite("enemy_skeleton.jpg", SPRITES / "enemy_skeleton.png", 72)
	save_sprite("spell_orb.jpg", SPRITES / "spell_projectile.png", 28)

	elements = {
		"icon_fire.jpg": "fire.png",
		"icon_water.jpg": "water.png",
		"icon_earth.jpg": "earth.png",
		"icon_air.jpg": "air.png",
		"icon_ice.jpg": "ice.png",
		"icon_light.jpg": "light.png",
		"icon_lightning.jpg": "lightning.png",
	}
	forms = {
		"icon_projectile.jpg": "projectile.png",
		"icon_area.jpg": "area.png",
		"icon_wall.jpg": "wall.png",
		"icon_beam.jpg": "beam.png",
		"icon_self.jpg": "self.png",
		"icon_around.jpg": "around.png",
		"icon_mine.jpg": "mine.png",
	}
	for src, name in elements.items():
		save_icon(src, ELEMENTS / name)
	for src, name in forms.items():
		save_icon(src, FORMS / name)
	save_empty(ELEMENTS / "empty.png")
	save_empty(FORMS / "empty.png")


if __name__ == "__main__":
	main()