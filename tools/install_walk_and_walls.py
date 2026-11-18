"""Slice walk sheets into 8 directions and key elemental wall textures."""
from pathlib import Path

from PIL import Image

SRC = Path(r"C:\Users\haqury\.cursor\projects\c-Users-haqury-Documents-magic-something-other\assets")
ROOT = Path(r"c:\Users\haqury\Documents\magic-something-other")
PLAYER = ROOT / "assets" / "sprites" / "player"
WALLS = ROOT / "assets" / "sprites" / "fx" / "walls"
FRAMES = ROOT / "resources" / "player_frames.tres"

DIRS = ["s", "se", "e", "ne", "n"]
MIRROR = {"se": "sw", "e": "w", "ne": "nw"}
WALL_NAMES = ["fire", "water", "earth", "air", "ice", "light", "lightning"]


def is_backdrop(r: int, g: int, b: int) -> bool:
	if g < 45 and r > 140 and b > 60 and r > g * 4:
		return True
	if r > 180 and g < 160 and b > g + 15 and r > g + 50:
		return True
	return False


def key(im: Image.Image) -> Image.Image:
	im = im.convert("RGBA")
	pix = im.load()
	for y in range(im.height):
		for x in range(im.width):
			r, g, b, _a = pix[x, y]
			if is_backdrop(r, g, b):
				pix[x, y] = (0, 0, 0, 0)
	return im


def crop_alpha(im: Image.Image, pad: int = 2) -> Image.Image:
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


def fit_height(im: Image.Image, height: int) -> Image.Image:
	scale = height / float(im.height)
	size = (max(1, int(round(im.width * scale))), height)
	return im.resize(size, Image.Resampling.LANCZOS)


def save_frame(im: Image.Image, direction: str, index: int) -> None:
	PLAYER.mkdir(parents=True, exist_ok=True)
	im.save(PLAYER / f"{direction}_{index}.png")


def slice_sheet(direction: str) -> list[Image.Image]:
	sheet = key(Image.open(SRC / f"walk_{direction}.jpg"))
	col_w = sheet.width // 4
	frames: list[Image.Image] = []
	for i in range(4):
		right = sheet.width if i == 3 else (i + 1) * col_w
		frames.append(crop_alpha(sheet.crop((i * col_w, 0, right, sheet.height))))
	fitted = [fit_height(frame, 68) for frame in frames]
	canvas_w = max(frame.width for frame in fitted)
	placed: list[Image.Image] = []
	for frame in fitted:
		canvas = Image.new("RGBA", (canvas_w, 76), (0, 0, 0, 0))
		x = (canvas_w - frame.width) // 2
		y = 76 - frame.height
		canvas.paste(frame, (x, y), frame)
		placed.append(canvas)
	for i, frame in enumerate(placed):
		save_frame(frame, direction, i)
	return placed


def write_sprite_frames() -> None:
	order = ["s", "se", "e", "ne", "n", "sw", "w", "nw"]
	exts: list[str] = []
	ids: dict[tuple[str, int], str] = {}
	n = 1
	for direction in order:
		for i in range(4):
			rid = f"{n}_{direction}{i}"
			ids[(direction, i)] = rid
			exts.append(
				f'[ext_resource type="Texture2D" path="res://assets/sprites/player/{direction}_{i}.png" id="{rid}"]'
			)
			n += 1
	anims: list[str] = []
	for direction in order:
		frames = []
		for i in range(4):
			frames.append(
				'{\n"duration": 1.0,\n"texture": ExtResource("%s")\n}' % ids[(direction, i)]
			)
		anims.append(
			'{\n"frames": [%s],\n"loop": true,\n"name": &"walk_%s",\n"speed": 8.0\n}'
			% (", ".join(frames), direction)
		)
	text = "\n".join([
		"[gd_resource type=\"SpriteFrames\" load_steps=%d format=3]" % (len(exts) + 1),
		"",
		*exts,
		"",
		"[resource]",
		"animations = [%s]" % ", ".join(anims),
		"",
	])
	FRAMES.parent.mkdir(parents=True, exist_ok=True)
	FRAMES.write_text(text, encoding="utf-8")
	print("frames", len(exts))


def save_walls() -> None:
	WALLS.mkdir(parents=True, exist_ok=True)
	for name in WALL_NAMES:
		im = fit_height(crop_alpha(key(Image.open(SRC / f"wall_{name}.jpg")), 4), 96)
		im.save(WALLS / f"{name}.png")
		print("wall", name, im.size)


def main() -> None:
	for direction in DIRS:
		frames = slice_sheet(direction)
		print("walk", direction, frames[0].size)
		if direction in MIRROR:
			mirrored = direction and MIRROR[direction]
			for i, frame in enumerate(frames):
				flipped = frame.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
				save_frame(flipped, mirrored, i)
	write_sprite_frames()
	save_walls()


if __name__ == "__main__":
	main()
