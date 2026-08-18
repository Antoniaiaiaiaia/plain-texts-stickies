#!/usr/bin/env python3
from pathlib import Path
import sys

from PIL import Image, ImageDraw


SIZES = [16, 32, 64, 128, 256, 512, 1024]


def rounded(draw, box, radius, fill):
    draw.rounded_rectangle(box, radius=radius, fill=fill)


def make_icon(size):
    scale = size / 1024
    image = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)

    pad = int(128 * scale)
    box = [pad, pad, size - pad, size - pad]
    radius = int(116 * scale)

    rounded(draw, box, radius, (238, 243, 243, 255))
    draw.rectangle(
        [box[0], box[1] + int(92 * scale), box[2], box[1] + int(126 * scale)],
        fill=(214, 225, 226, 255),
    )

    for index in range(9):
        x = box[0] + int((82 + index * 78) * scale)
        y = box[1] + int(55 * scale)
        draw.ellipse(
            [x, y, x + int(18 * scale), y + int(18 * scale)],
            fill=(184, 199, 201, 255),
        )

    line_color = (93, 105, 108, 230)
    for index, width in enumerate([520, 430, 480]):
        y = box[1] + int((260 + index * 118) * scale)
        draw.rounded_rectangle(
            [box[0] + int(130 * scale), y, box[0] + int((130 + width) * scale), y + int(28 * scale)],
            radius=int(14 * scale),
            fill=line_color,
        )

    fold = [
        (box[2] - int(150 * scale), box[2]),
        (box[2], box[2] - int(150 * scale)),
        (box[2], box[2]),
    ]
    draw.polygon(fold, fill=(220, 229, 230, 255))
    draw.line(
        [fold[0], fold[1]],
        fill=(174, 190, 192, 255),
        width=max(1, int(8 * scale)),
    )

    return image


def main():
    out = Path(sys.argv[1])
    out.mkdir(parents=True, exist_ok=True)
    for size in SIZES:
        image = make_icon(size)
        image.save(out / f"icon_{size}x{size}.png")
        if size != 1024:
            image.resize((size * 2, size * 2), Image.Resampling.LANCZOS).save(
                out / f"icon_{size}x{size}@2x.png"
            )


if __name__ == "__main__":
    main()
