"""Спрайты героя (Сэма) из картинки-разворота.

Исходник: assets/sprites/source/sam_turnaround.webp — сетка 8×4 = 32 кадра на белом фоне.
Каждый кадр — Сэм, повёрнутый на 1/32 круга (11,25°):
  кадр 0 — лицом к нам (вниз), 8 — вправо, 16 — спиной (вверх), 24 — влево.

Скрипт:
  1. убирает белый фон (только тот, что связан с краем картинки — белые блики внутри остаются);
  2. выравнивает все кадры по ногам, чтобы при повороте Сэм не «прыгал»;
  3. уменьшает до HEIGHT пикселей в высоту;
  4. делает кадры ходьбы: ноги сдвигаются на 1 пиксель (в исходнике шагов нет);
  5. собирает лист assets/sprites/sam.png: столбцы — 4 кадра ходьбы, строки — 32 направления.

Запуск из папки проекта:
    python3 tools/make_sam_sprites.py

Нужны библиотеки Pillow, numpy и scipy.
"""

import math
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "assets" / "sprites" / "source" / "sam_turnaround.webp"
OUT = ROOT / "assets" / "sprites" / "sam.png"

HEIGHT = 24        # рост Сэма в игре, пикселей
CELL_W = 20        # размер клетки листа (с запасом под шаги)
CELL_H = 26
FOOT_Y = CELL_H - 2  # строка, на которой стоят ноги (в клетке листа)
DIRECTIONS = 32
WALK_FRAMES = 4    # 0 — стоит, 1 — шаг одной ногой, 2 — стоит, 3 — шаг другой
LEG_PART = 0.36    # нижняя доля роста — ноги


def remove_background(img):
    """RGBA-массив без белого фона. Фон — светлые бесцветные пиксели, связанные с краем."""
    rgb = img[..., :3].astype(int)
    light = (rgb.min(axis=2) >= 222) & (rgb.max(axis=2) - rgb.min(axis=2) <= 30)
    labels, _ = ndimage.label(light)
    border = set(np.unique(np.concatenate([labels[0], labels[-1], labels[:, 0], labels[:, -1]]))) - {0}
    bg = np.isin(labels, list(border))
    # Светлая «бахрома» по краю силуэта (сглаживание исходника) — тоже фон
    fringe = ndimage.binary_dilation(bg, iterations=2) & (rgb.min(axis=2) >= 190) & \
        (rgb.max(axis=2) - rgb.min(axis=2) <= 40)
    out = img.copy()
    out[bg | fringe, 3] = 0
    return out


def runs(profile, gap=2):
    """Отрезки, где profile > gap (столбцы/строки с персонажами)."""
    result, start = [], None
    for i, v in enumerate(profile):
        if v > gap and start is None:
            start = i
        if v <= gap and start is not None:
            result.append((start, i - 1))
            start = None
    if start is not None:
        result.append((start, len(profile) - 1))
    return result


def cut_frames(rgba):
    """32 кадра (в порядке строк) с их рамками."""
    solid = rgba[..., 3] > 0
    cols = runs(solid.sum(axis=0))
    rows = runs(solid.sum(axis=1))
    assert len(cols) == 8 and len(rows) == 4, (len(cols), len(rows))
    frames = []
    for (y0, y1) in rows:
        for (x0, x1) in cols:
            part = rgba[y0:y1 + 1, x0:x1 + 1]
            ys, xs = np.nonzero(part[..., 3] > 0)
            frames.append(part[ys.min():ys.max() + 1, xs.min():xs.max() + 1])
    return frames


def downscale(frame, scale):
    """Кадр в клетку CELL_W × CELL_H: ноги на FOOT_Y, по центру по горизонтали."""
    h, w = frame.shape[:2]
    alpha = frame[..., 3] > 0
    # Точка опоры — середина нижних строк силуэта (ступни)
    feet_rows = alpha[int(h * 0.92):]
    feet_x = np.nonzero(feet_rows)[1].mean()
    big_w, big_h = int(math.ceil(CELL_W / scale)), int(math.ceil(CELL_H / scale))
    canvas = np.zeros((big_h, big_w, 4), dtype=np.float32)
    ox = int(round(CELL_W / 2 / scale - feet_x))
    oy = int(round(FOOT_Y / scale - h))
    canvas[oy:oy + h, ox:ox + w] = frame.astype(np.float32)
    # Уменьшаем с предумножением на прозрачность: края не светлеют
    a = canvas[..., 3:4] / 255.0
    premul = np.concatenate([canvas[..., :3] * a, a * 255.0], axis=2)
    channels = [np.array(Image.fromarray(premul[..., i]).resize((CELL_W, CELL_H), Image.BOX))
                for i in range(4)]
    small = np.stack(channels, axis=2)
    alpha_small = small[..., 3] / 255.0
    out = np.zeros((CELL_H, CELL_W, 4), dtype=np.uint8)
    solid = alpha_small >= 0.5   # пиксель-арт: пиксель либо есть, либо нет
    rgb = small[..., :3] / np.maximum(alpha_small[..., None], 1e-6)
    out[..., :3] = np.clip(rgb, 0, 255).astype(np.uint8)
    out[..., 3] = np.where(solid, 255, 0)
    return out


def shift_part(frame, mask, dx, dy):
    """Сдвинуть пиксели под маской mask на (dx, dy), освободив старое место."""
    out = frame.copy()
    part = np.zeros_like(frame)
    part[mask] = frame[mask]
    out[mask] = 0
    moved = np.zeros_like(frame)
    h, w = frame.shape[:2]
    ys, xs = np.nonzero(mask & (frame[..., 3] > 0))
    ny, nx = ys + dy, xs + dx
    ok = (ny >= 0) & (ny < h) & (nx >= 0) & (nx < w)
    moved[ny[ok], nx[ok]] = part[ys[ok], xs[ok]]
    has = moved[..., 3] > 0
    out[has] = moved[has]
    return out


def walk_frames(frame, direction):
    """4 кадра ходьбы из стоящего кадра. direction — номер направления (0 — к нам)."""
    angle = math.radians(90.0 - direction * 360.0 / DIRECTIONS)  # 0 — вправо, 90 — вниз
    side = abs(math.cos(angle))   # 1 — профиль, 0 — лицом/спиной
    facing_x = math.cos(angle)    # куда смотрит по горизонтали
    alpha = frame[..., 3] > 0
    ys, xs = np.nonzero(alpha)
    top, bottom = ys.min(), ys.max()
    leg_top = int(round(bottom - (bottom - top + 1) * LEG_PART))
    legs = np.zeros_like(alpha)
    legs[leg_top:bottom + 1] = alpha[leg_top:bottom + 1]
    split = np.nonzero(legs)[1].mean()
    columns = np.arange(frame.shape[1])[None, :]
    left = legs & (columns < split)
    right = legs & (columns >= split)
    # Какая нога «впереди» по направлению взгляда (для профиля)
    front, back = (right, left) if facing_x >= 0 else (left, right)
    step_x = 1 if facing_x >= 0 else -1

    def step(lift_leg, front_leg, back_leg):
        f = frame
        if side < 0.85:
            f = shift_part(f, lift_leg, 0, -1)          # нога приподнята
        if side > 0.35:
            f = shift_part(f, front_leg, step_x, 0)     # нога вперёд
            f = shift_part(f, back_leg, -step_x, 0)     # другая назад
        return f

    return [frame, step(left, front, back), frame, step(right, back, front)]


def main():
    rgba = remove_background(np.array(Image.open(SRC).convert("RGBA")))
    frames = cut_frames(rgba)
    tallest = max(f.shape[0] for f in frames)
    scale = HEIGHT / tallest
    sheet = np.zeros((CELL_H * DIRECTIONS, CELL_W * WALK_FRAMES, 4), dtype=np.uint8)
    for d, frame in enumerate(frames):
        small = downscale(frame, scale)
        for k, f in enumerate(walk_frames(small, d)):
            sheet[d * CELL_H:(d + 1) * CELL_H, k * CELL_W:(k + 1) * CELL_W] = f
    OUT.parent.mkdir(parents=True, exist_ok=True)
    Image.fromarray(sheet).save(OUT)
    print(f"Сохранено: {OUT} ({WALK_FRAMES}×{DIRECTIONS} кадров по {CELL_W}×{CELL_H}, рост {HEIGHT} px,"
          f" масштаб {scale:.3f}, ноги на строке {FOOT_Y})")


if __name__ == "__main__":
    main()
