"""Chroma-key spell VFX and write PNGs into assets/sprites/fx."""
from pathlib import Path

from PIL import Image

SRC = Path(r"C:\Users\haqury\.cursor\projects\c-Users-haqury-Documents-magic-something-other\assets")
OUT = Path(r"c:\Users\haqury\Documents\magic-something-other\assets\sprites\fx")


def is_backdrop(r: int, g: int, b: int) -> bool:
	# Горячий розовый фон и тёмное пятно внутри кольца.
	if g < 45 and r > 140 and b > 60 and r > g * 4:
		return True
	if g < 35 and r < 100 and b < 120 and max(r, g, b) < 90:
		return True
	# Розовая кайма после сжатия JPEG.
	if r > 180 and g < 160 and b > g + 15 and r > g + 50:
		return True
	return False


def key(im: Image.Image, drop_dark: bool = False) -> Image.Image:
	im = im.convert("RGBA")
	pix = im.load()
	w, h = im.size
	for y in range(h):
		for x in range(w):
			r, g, b, _a = pix[x, y]
			if is_backdrop(r, g, b):
				pix[x, y] = (0, 0, 0, 0)
	return im


def crop(im: Image.Image, pad: int = 2) -> Image.Image:
	bbox = im.getbbox()
	if bbox is None:
		return im
	x0, y0, x1, y1 = bbox
	return im.crop((max(0, x0 - pad), max(0, y0 - pad), min(im.width, x1 + pad), min(im.height, y1 + pad)))


def fit(im: Image.Image, height: int) -> Image.Image:
	w, h = im.size
	scale = height / float(h)
	return im.resize((max(1, int(round(w * scale))), height), Image.Resampling.LANCZOS)


def save(name: str, dest: str, height: int, drop_dark: bool = False) -> None:
	im = fit(crop(key(Image.open(SRC / name), drop_dark)), height)
	path = OUT / dest
	path.parent.mkdir(parents=True, exist_ok=True)
	im.save(path)
	print(dest, im.size)


def main() -> None:
	save("fx_orb.jpg", "orb.png", 64)
	save("fx_ring.jpg", "ring.png", 128, drop_dark=True)
	save("fx_burst.jpg", "burst.png", 128)
	save("fx_beam.jpg", "beam.png", 32)
	save("fx_aura.jpg", "aura.png", 128)
	save("fx_glyph.jpg", "glyph.png", 64)
	save("fx_wall.jpg", "wall.png", 32)


if __name__ == "__main__":
	main()
