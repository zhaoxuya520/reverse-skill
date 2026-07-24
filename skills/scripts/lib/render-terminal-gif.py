#!/usr/bin/env python3
"""Render a terminal-style GIF from ordered text scenes (stdlib + Pillow)."""
from __future__ import annotations

import argparse
import textwrap
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


def load_font(size: int) -> ImageFont.ImageFont:
    candidates = [
        "/System/Library/Fonts/Menlo.ttc",
        "/System/Library/Fonts/Monaco.ttf",
        "/System/Library/Fonts/Supplemental/Courier New.ttf",
        "/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf",
        "/usr/share/fonts/truetype/liberation/LiberationMono-Regular.ttf",
    ]
    for path in candidates:
        p = Path(path)
        if p.exists():
            try:
                return ImageFont.truetype(str(p), size=size)
            except Exception:
                continue
    return ImageFont.load_default()


def render_frame(
    lines: list[str],
    *,
    width: int,
    height: int,
    font: ImageFont.ImageFont,
    title: str,
) -> Image.Image:
    bg = (11, 18, 32)
    panel = (18, 28, 46)
    border = (42, 58, 88)
    fg = (220, 232, 252)
    dim = (140, 160, 190)
    green = (93, 222, 168)
    amber = (255, 196, 96)
    cyan = (120, 196, 255)

    img = Image.new("RGB", (width, height), bg)
    draw = ImageDraw.Draw(img)

    margin = 18
    draw.rounded_rectangle(
        [margin, margin, width - margin, height - margin],
        radius=14,
        fill=panel,
        outline=border,
        width=2,
    )

    # traffic lights
    for i, color in enumerate([(255, 95, 86), (255, 189, 46), (39, 201, 63)]):
        x = margin + 22 + i * 18
        y = margin + 18
        draw.ellipse([x, y, x + 10, y + 10], fill=color)

    draw.text((margin + 90, margin + 12), title, fill=dim, font=font)

    y = margin + 44
    x = margin + 22
    line_h = 22
    max_rows = max(1, (height - y - margin - 12) // line_h)

    visible = lines[-max_rows:]
    for raw in visible:
        line = raw.rstrip("\n")
        color = fg
        if line.startswith("$ ") or line.startswith("# "):
            color = cyan
        elif "OK" in line or "PASSED" in line or "ready_for_act=true" in line or "CASE-GUARD OK" in line:
            color = green
        elif "FAIL" in line or "ERROR" in line:
            color = amber
        # wrap long lines
        wrapped = textwrap.wrap(line, width=88) or [""]
        for part in wrapped:
            if y > height - margin - line_h:
                break
            draw.text((x, y), part, fill=color, font=font)
            y += line_h
    return img


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--scenes", required=True, help="scenes file: blocks separated by ---")
    ap.add_argument("--out", required=True, help="output .gif path")
    ap.add_argument("--width", type=int, default=960)
    ap.add_argument("--height", type=int, default=540)
    ap.add_argument("--fps", type=float, default=1.15)
    ap.add_argument("--title", default="reverse-skill · PRIMARY path")
    args = ap.parse_args()

    raw = Path(args.scenes).read_text(encoding="utf-8")
    blocks = [b.strip("\n") for b in raw.split("\n---\n")]
    blocks = [b for b in blocks if b.strip()]
    if not blocks:
        raise SystemExit("no scenes found")

    font = load_font(16)
    frames: list[Image.Image] = []
    cumulative: list[str] = []

    for block in blocks:
        # each block may be multi-line; append as new activity
        for line in block.splitlines():
            cumulative.append(line)
            frames.append(
                render_frame(cumulative, width=args.width, height=args.height, font=font, title=args.title)
            )
        # hold a beat at end of block
        frames.append(
            render_frame(cumulative, width=args.width, height=args.height, font=font, title=args.title)
        )

    # final hold
    for _ in range(4):
        frames.append(frames[-1].copy())

    duration = max(80, int(1000 / args.fps))
    out = Path(args.out)
    out.parent.mkdir(parents=True, exist_ok=True)
    frames[0].save(
        out,
        save_all=True,
        append_images=frames[1:],
        duration=duration,
        loop=0,
        optimize=False,
    )
    print(f"wrote {out} frames={len(frames)} duration_ms={duration}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
