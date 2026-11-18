"""Ключует статичные позы мага и добавляет их в SpriteFrames."""
from pathlib import Path

from PIL import Image

SRC = Path(r"C:\Users\haqury\.cursor\projects\c-Users-haqury-Documents-magic-something-other\assets")
ROOT = Path(r"c:\Users\haqury\Documents\magic-something-other")
PLAYER = ROOT / "assets" / "sprites" / "player"
FRAMES = ROOT / "resources" / "player_frames.tres"
DIRS = ["s", "se", "e", "ne", "n"]
MIRROR = {"se": "sw", "e": "w", "ne": "nw"}


def is_backdrop(r: int, g: int, b: int) -> bool:
	if g < 45 and r > 140 and b > 60 and r > g * 4:
		return True
	if r > 180 and g < 160 and b > g + 15 and r > g + 50:
		return True
	return False


def key(im: Image.Image) -> Image.Image:
	im = im.convert("RGBA")
	w, h = im.size
	pix = im.load()
	seen = [[False] * w for _ in range(h)]
	stack: list[tuple[int, int]] = []
	for x in range(w):
		stack.append((x, 0))
		stack.append((x, h - 1))
	for y in range(h):
		stack.append((0, y))
		stack.append((w - 1, y))
	while stack:
		x, y = stack.pop()
		if x < 0 or y < 0 or x >= w or y >= h or seen[y][x]:
			continue
		seen[y][x] = True
		r, g, b, a = pix[x, y]
		if a == 0 or is_backdrop(r, g, b):
			pix[x, y] = (0, 0, 0, 0)
			stack.extend(((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)))
	return im


def crop_alpha(im: Image.Image, pad: int = 1) -> Image.Image:
	bbox = im.getbbox()
	if bbox is None:
		return im
	x0, y0, x1, y1 = bbox
	return im.crop((
		max(0, x0 - pad),
		max(0, y0 - pad),
		min(im.width, x1 + pad),
		min(im.height, y1 + pad),
	))


def place(im: Image.Image, canvas_size: tuple[int, int]) -> Image.Image:
	cw, ch = canvas_size
	fitted = crop_alpha(im)
	scale = min((ch - 8) / float(fitted.height), (cw - 2) / float(fitted.width))
	size = (max(1, int(round(fitted.width * scale))), max(1, int(round(fitted.height * scale))))
	fitted = fitted.resize(size, Image.Resampling.NEAREST)
	canvas = Image.new("RGBA", canvas_size, (0, 0, 0, 0))
	x = (cw - fitted.width) // 2
	y = ch - fitted.height - 2
	canvas.paste(fitted, (x, y), fitted)
	return canvas


def main() -> None:
	made: dict[str, Image.Image] = {}
	for direction in DIRS:
		src = Image.open(SRC / f"idle_{direction}.jpg")
		ref = Image.open(PLAYER / f"{direction}_0.png")
		made[direction] = place(key(src), ref.size)
		made[direction].save(PLAYER / f"idle_{direction}.png")
	for source, dest in MIRROR.items():
		flipped = made[source].transpose(Image.Transpose.FLIP_LEFT_RIGHT)
		ref = Image.open(PLAYER / f"{dest}_0.png")
		if flipped.size != ref.size:
			flipped = place(flipped, ref.size)
		flipped.save(PLAYER / f"idle_{dest}.png")
		made[dest] = flipped
	text = FRAMES.read_text(encoding="utf-8")
	if 'name": &"idle_s"' in text:
		print("animations already present")
		return
	order = ["s", "se", "e", "ne", "n", "sw", "w", "nw"]
	exts = []
	anims = []
	for i, direction in enumerate(order, start=33):
		rid = f"{i}_idle{direction}"
		exts.append(
			f'[ext_resource type="Texture2D" path="res://assets/sprites/player/idle_{direction}.png" id="{rid}"]'
		)
		anims.append(
			'{\n"frames": [{\n"duration": 1.0,\n"texture": ExtResource("%s")\n}],\n"loop": true,\n"name": &"idle_%s",\n"speed": 5.0\n}'
			% (rid, direction)
		)
	text = text.replace("load_steps=33", "load_steps=41", 1)
	marker = "\n\n[resource]\n"
	text = text.replace(marker, "\n" + "\n".join(exts) + marker, 1)
	text = text.replace("\n}]", "\n}, " + ", ".join(anims) + "]", 1)
	FRAMES.write_text(text, encoding="utf-8")
	print("idle frames", {k: v.size for k, v in made.items()})


if __name__ == "__main__":
	main()
