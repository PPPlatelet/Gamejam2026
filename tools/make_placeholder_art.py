#!/usr/bin/env python3
"""生成塔防的占位素材：敌人 / 塔 / 障碍物 / 基地。

用法：
    python tools/make_placeholder_art.py [输出目录]

默认输出到 assets/占位素材/。
每张图 256x256、透明底，代表棋盘上 2x2 个单位
（1 单位 = 一个六边形的半径，所以格子高度正好是 2 单位）。
"""

import math
import os
import sys

from PIL import Image, ImageDraw

SIZE = 256
SS = 4  # 超采样倍数，画完再缩小，边缘更干净
U = SIZE / 2.0  # 1 个单位 = 128 像素
CENTER = SIZE * SS / 2.0  # 画面中心


def px(value: float) -> float:
    return value * U * SS


def canvas() -> Image.Image:
    return Image.new("RGBA", (SIZE * SS, SIZE * SS), (0, 0, 0, 0))


def hexagon(cx: float, cy: float, radius: float) -> list[tuple[float, float]]:
    points = []
    for i in range(6):
        angle = math.radians(60 * i + 30)
        points.append((cx + radius * math.cos(angle), cy + radius * math.sin(angle)))
    return points


def draw_enemy() -> Image.Image:
    img = canvas()
    d = ImageDraw.Draw(img)
    cx, cy = CENTER, CENTER
    r = px(0.40)
    d.ellipse([cx - r, cy - r, cx + r, cy + r],
              fill=(238, 84, 69, 255), outline=(158, 38, 32, 255), width=int(px(0.055)))
    # 两只眼睛朝 +X（前进方向）
    for side in (-1, 1):
        ex, ey = cx + px(0.14), cy + px(0.15) * side
        er = px(0.095)
        d.ellipse([ex - er, ey - er, ex + er, ey + er], fill=(255, 255, 255, 255))
        pr = px(0.048)
        pxx = ex + px(0.035)
        d.ellipse([pxx - pr, ey - pr, pxx + pr, ey + pr], fill=(40, 22, 20, 255))
    return img


def draw_tower_base() -> Image.Image:
    """塔的底座（静止）。"""
    img = canvas()
    d = ImageDraw.Draw(img)
    cx, cy = CENTER, CENTER
    plate = hexagon(cx, cy, px(0.66))
    d.polygon(plate, fill=(56, 115, 199, 255))
    d.line(plate + [plate[0]], fill=(31, 71, 140, 255), width=int(px(0.065)), joint="curve")
    d.ellipse([cx - px(0.42), cy - px(0.42), cx + px(0.42), cy + px(0.42)],
              outline=(31, 71, 140, 110), width=int(px(0.03)))
    return img


def draw_tower_turret() -> Image.Image:
    """塔的炮塔（会朝目标旋转，炮管朝 +X）。"""
    img = canvas()
    d = ImageDraw.Draw(img)
    cx, cy = CENTER, CENTER
    # 炮管
    d.rectangle([cx + px(0.05), cy - px(0.085), cx + px(0.80), cy + px(0.085)], fill=(41, 87, 160, 255))
    d.rectangle([cx + px(0.70), cy - px(0.10), cx + px(0.82), cy + px(0.10)], fill=(31, 71, 140, 255))
    # 炮塔圆
    body = px(0.30)
    d.ellipse([cx - body, cy - body, cx + body, cy + body],
              fill=(82, 153, 235, 255), outline=(31, 71, 140, 255), width=int(px(0.045)))
    core = px(0.14)
    d.ellipse([cx - core, cy - core, cx + core, cy + core], fill=(199, 228, 255, 255))
    return img


def draw_obstacle() -> Image.Image:
    img = canvas()
    d = ImageDraw.Draw(img)
    cx, cy = CENTER, CENTER
    body = hexagon(cx, cy, px(0.72))
    d.polygon(body, fill=(145, 154, 163, 255))
    d.line(body + [body[0]], fill=(87, 94, 104, 255), width=int(px(0.070)), joint="curve")
    top = hexagon(cx, cy - px(0.08), px(0.50))
    d.polygon(top, fill=(173, 182, 192, 255))
    d.line([(cx - px(0.18), cy - px(0.26)), (cx - px(0.02), cy - px(0.02)), (cx - px(0.12), cy + px(0.26))],
           fill=(97, 105, 115, 255), width=int(px(0.045)), joint="curve")
    d.line([(cx + px(0.10), cy + px(0.06)), (cx + px(0.28), cy + px(0.20))],
           fill=(97, 105, 115, 255), width=int(px(0.045)))
    return img


def draw_base() -> Image.Image:
    img = canvas()
    d = ImageDraw.Draw(img)
    cx, cy = CENTER, CENTER
    body = hexagon(cx, cy, px(0.74))
    d.polygon(body, fill=(61, 135, 237, 255))
    d.line(body + [body[0]], fill=(26, 77, 158, 255), width=int(px(0.070)), joint="curve")
    # 旗杆 + 旗子
    d.line([(cx - px(0.10), cy + px(0.30)), (cx - px(0.10), cy - px(0.30))],
           fill=(255, 255, 255, 255), width=int(px(0.06)))
    d.polygon([(cx - px(0.09), cy - px(0.30)), (cx + px(0.34), cy - px(0.19)), (cx - px(0.09), cy - px(0.06))],
              fill=(255, 255, 255, 255))
    return img


SPRITES = {
    "enemy.png": draw_enemy,
    "tower_base.png": draw_tower_base,
    "tower_turret.png": draw_tower_turret,
    "obstacle.png": draw_obstacle,
    "base.png": draw_base,
}


def main() -> int:
    out_dir = sys.argv[1] if len(sys.argv) > 1 else os.path.join("assets", "占位素材")
    os.makedirs(out_dir, exist_ok=True)
    for name, draw in SPRITES.items():
        img = draw().resize((SIZE, SIZE), Image.LANCZOS)
        path = os.path.join(out_dir, name)
        img.save(path)
        print(f"已生成 {path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
