#!/usr/bin/env python3

from pathlib import Path
import sys

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
HELP_ASSETS = ROOT / "assets" / "help"


def encode_runs(values: list[int]) -> str:
    output: list[str] = []
    index = 0
    while index < len(values):
        end = index + 1
        while end < len(values) and values[end] == values[index]:
            end += 1
        count = end - index
        char = chr(values[index] + 63)
        output.append(f"!{count}{char}" if count >= 4 else char * count)
        index = end
    return "".join(output)


def write_sixel(image: Image.Image, destination: Path, colors: int) -> None:
    indexed = image.convert("RGB").quantize(
        colors=colors,
        method=Image.Quantize.MEDIANCUT,
        dither=Image.Dither.NONE,
    )
    width, height = indexed.size
    pixels = indexed.load()
    palette = indexed.getpalette()
    flattened = (
        indexed.get_flattened_data()
        if hasattr(indexed, "get_flattened_data")
        else indexed.getdata()
    )
    used = sorted(set(flattened))
    parts = ["\x1bPq", f'"1;1;{width};{height}']

    for color in used:
        offset = color * 3
        red, green, blue = palette[offset : offset + 3]
        parts.append(
            f"#{color};2;{round(red * 100 / 255)};"
            f"{round(green * 100 / 255)};{round(blue * 100 / 255)}"
        )

    for top in range(0, height, 6):
        band_colors = sorted(
            {pixels[x, y] for y in range(top, min(top + 6, height)) for x in range(width)}
        )
        for color in band_colors:
            masks: list[int] = []
            for x in range(width):
                mask = 0
                for bit in range(6):
                    y = top + bit
                    if y < height and pixels[x, y] == color:
                        mask |= 1 << bit
                masks.append(mask)
            while masks and masks[-1] == 0:
                masks.pop()
            if masks:
                parts.extend((f"#{color}", encode_runs(masks), "$"))
        parts.append("-")
    parts.append("\x1b\\")
    destination.write_bytes("".join(parts).encode("ascii"))


def fit_on_canvas(source: Path, size: tuple[int, int], background: str) -> Image.Image:
    image = Image.open(source).convert("RGB")
    image.thumbnail(size, Image.Resampling.LANCZOS)
    canvas = Image.new("RGB", size, background)
    left = (size[0] - image.width) // 2
    top = (size[1] - image.height) // 2
    canvas.paste(image, (left, top))
    return canvas


def write_ansi(image: Image.Image, destination: Path) -> None:
    if image.height % 2:
        padded = Image.new("RGB", (image.width, image.height + 1), "white")
        padded.paste(image, (0, 0))
        image = padded
    pixels = image.load()
    lines: list[str] = []
    for y in range(0, image.height, 2):
        line: list[str] = []
        for x in range(image.width):
            top = pixels[x, y]
            bottom = pixels[x, y + 1]
            line.append(
                f"\x1b[38;2;{top[0]};{top[1]};{top[2]};"
                f"48;2;{bottom[0]};{bottom[1]};{bottom[2]}m▀"
            )
        line.append("\x1b[0m")
        lines.append("".join(line))
    destination.write_text("\n".join(lines) + "\n", encoding="utf-8")


def build() -> None:
    qr_source = HELP_ASSETS / "renamamiya-qr.png"
    xianyu_source = HELP_ASSETS / "xianyu-renamamiya.jpg"
    for source in (qr_source, xianyu_source):
        if not source.is_file():
            raise FileNotFoundError(source)

    qr_modules = Image.open(qr_source).convert("L").resize((41, 41), Image.Resampling.NEAREST)
    for suffix, qr_size, xianyu_size in (
        ("-compact", 123, (168, 123)),
        ("", 205, (280, 205)),
        ("-large", 287, (392, 287)),
    ):
        qr = qr_modules.convert("RGB").resize((qr_size, qr_size), Image.Resampling.NEAREST)
        xianyu = fit_on_canvas(xianyu_source, xianyu_size, "white")
        write_sixel(qr, HELP_ASSETS / f"renamamiya-qr{suffix}.sixel", 2)
        write_sixel(xianyu, HELP_ASSETS / f"xianyu-renamamiya{suffix}.sixel", 96)

    qr_modules = qr_modules.crop((3, 3, 38, 38)).convert("RGB")
    write_ansi(qr_modules, HELP_ASSETS / "renamamiya-qr.ansi")
    xianyu_ansi = fit_on_canvas(xianyu_source, (35, 34), "white")
    write_ansi(xianyu_ansi, HELP_ASSETS / "xianyu-renamamiya.ansi")


if __name__ == "__main__":
    try:
        build()
    except Exception as error:
        print(f"生成帮助页终端图片失败：{error}", file=sys.stderr)
        raise SystemExit(1)
