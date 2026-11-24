"""Генератор тайлов-заглушек («серые коробки») для карт.

Рисует одну картинку assets/tiles/greybox_tiles.png: ряд квадратов 16×16,
каждый квадрат — свой вид поверхности. Порядок тайлов важен: по нему
их находят scripts/room.gd и набор тайлов resources/greybox_tileset.tres.

Запуск из папки проекта:
    python3 tools/generate_tiles.py

Нужна библиотека Pillow (pip install pillow).
"""

import random
from pathlib import Path

from PIL import Image

TILE = 16
OUT = Path(__file__).resolve().parent.parent / "assets" / "tiles" / "greybox_tiles.png"

# Одинаковый «шум» при каждом запуске, чтобы картинка не менялась без причины
rng = random.Random(42)

# Цвет верха стены (такой же задан в scripts/room.gd как WALL_TOP_COLOR)
WALL_TOP = (226, 216, 232)


def floor(img, ox):
    """0. Пол в помещениях: фиолетовая «шахматка» 8×8 (ковролин)."""
    for y in range(TILE):
        for x in range(TILE):
            light = (x // 8 + y // 8) % 2 == 0
            img.putpixel((ox + x, y), (118, 74, 150) if light else (92, 56, 120))


def wall(img, ox):
    """1. Стена: однотонная, без рамки — соседние клетки сливаются в сплошную стену.
    Контур и «высоту» (тёмную грань снизу) рисует scripts/room.gd при запуске уровня.
    Блокирует движение, взгляд и свет."""
    for y in range(TILE):
        for x in range(TILE):
            img.putpixel((ox + x, y), WALL_TOP)


def concrete(img, ox):
    """2. Бетон (галерея, двор): серо-синие плиты со швами."""
    for y in range(TILE):
        for x in range(TILE):
            seam = x == 0 or y == 0
            base = (84, 84, 108) if seam else (104, 104, 128)
            d = rng.randint(-4, 4)
            img.putpixel((ox + x, y), tuple(c + d for c in base))


def asphalt(img, ox, base=(62, 58, 74)):
    """3. Асфальт (парковка): тёмный, с крапинками."""
    for y in range(TILE):
        for x in range(TILE):
            d = rng.choice([0, 0, 0, -6, 8])
            img.putpixel((ox + x, y), tuple(c + d for c in base))


def pool(img, ox):
    """4. Дно пустого бассейна: голубой кафель 4×4."""
    for y in range(TILE):
        for x in range(TILE):
            grout = x % 4 == 0 or y % 4 == 0
            img.putpixel((ox + x, y), (52, 104, 122) if grout else (70, 140, 160))


def low(img, ox):
    """5. Низкий бетонный бортик (бассейн, забор, отбойник).
    Сквозь него не пройти, но видно и светит поверх. Мебель и машины — отдельные
    предметы (scripts/furniture.gd), а не тайлы. Серо-бежевый, темнее стены."""
    for y in range(TILE):
        for x in range(TILE):
            if x in (0, TILE - 1) or y in (0, TILE - 1):
                color = (70, 66, 78)       # тёмная рамка
            elif x == 1 or y == 1:
                color = (178, 172, 160)    # блик сверху и слева
            else:
                color = (138, 132, 124)
            img.putpixel((ox + x, y), color)


def road(img, ox):
    """6. Шоссе: асфальт темнее парковочного."""
    asphalt(img, ox, base=(44, 42, 54))


def road_line(img, ox):
    """7. Шоссе с жёлтой прерывистой разметкой посередине."""
    road(img, ox)
    for y in (7, 8):
        for x in range(2, 14):
            img.putpixel((ox + x, y), (200, 170, 60))


def basement(img, ox):
    """8. Пол подвала: тёмный сырой бетон с пятнами."""
    for y in range(TILE):
        for x in range(TILE):
            seam = x == 0 or y == 0
            base = (48, 52, 50) if seam else (60, 64, 60)
            d = rng.choice([0, 0, 0, -5, 4])
            img.putpixel((ox + x, y), tuple(c + d for c in base))
    for _ in range(3):  # тёмные пятна сырости
        cx, cy = rng.randint(2, 13), rng.randint(2, 13)
        for y in range(cy - 1, cy + 2):
            for x in range(cx - 1, cx + 2):
                img.putpixel((ox + x, y), (44, 48, 46))


def puddle(img, ox):
    """9. Лужа на полу подвала: тёмная вода с бликами. Под ногами хлюпает (шумно)."""
    # Вода заливает клетку целиком: соседние клетки-лужи сливаются в одну лужу
    for y in range(TILE):
        for x in range(TILE):
            d = rng.choice([0, 0, 0, 2, -2])
            img.putpixel((ox + x, y), (32 + d, 44 + d, 58 + d))
    for x, y in [(3, 4), (4, 4), (5, 4), (10, 10), (11, 10), (7, 13)]:
        img.putpixel((ox + x, y), (80, 100, 122))  # блики


# Порядок = координата тайла в наборе (0, 1, 2, ...)
PAINTERS = [floor, wall, concrete, asphalt, pool, low, road, road_line, basement, puddle]


def main():
    img = Image.new("RGB", (TILE * len(PAINTERS), TILE))
    for i, paint in enumerate(PAINTERS):
        paint(img, i * TILE)
    OUT.parent.mkdir(parents=True, exist_ok=True)
    img.save(OUT)
    print(f"Сохранено: {OUT} ({len(PAINTERS)} тайлов)")


if __name__ == "__main__":
    main()
