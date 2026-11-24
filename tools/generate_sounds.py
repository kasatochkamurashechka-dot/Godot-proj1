"""
Генератор звуков-заглушек для игры. Каждый звук синтезируется формулой
(синусоиды, шум, фильтры) и сохраняется в assets/sounds/*.wav.

Запуск из корня проекта:
    python3 tools/generate_sounds.py

Нужны библиотеки numpy и scipy (pip install numpy scipy).
Случайность зафиксирована (SEED), поэтому при повторном запуске получаются те же звуки.
Чтобы поменять звук — правь его функцию ниже и запусти скрипт снова.
"""

import wave
from pathlib import Path

import numpy as np
from scipy.signal import butter, lfilter

RATE = 22050  # частота дискретизации: невысокая, для «лоу-фай» звучания в духе VHS
SEED = 1987
OUT_DIR = Path(__file__).resolve().parent.parent / "assets" / "sounds"

rng = np.random.default_rng(SEED)


# ---------------------------------------------------------------------------
# Строительные блоки
# ---------------------------------------------------------------------------

def t_axis(duration):
    """Массив моментов времени (в секундах) длиной duration."""
    return np.arange(int(duration * RATE)) / RATE


def noise(duration):
    """Белый шум."""
    return rng.uniform(-1.0, 1.0, int(duration * RATE))


def env(duration, attack=0.005, decay=0.1):
    """Огибающая громкости: быстрый подъём и экспоненциальное затухание."""
    t = t_axis(duration)
    up = np.clip(t / max(attack, 1e-6), 0.0, 1.0)
    down = np.exp(-np.maximum(t - attack, 0.0) / decay)
    return up * down


def sweep(f_start, f_end, duration):
    """Синусоида, частота которой плавно меняется от f_start к f_end (Гц)."""
    t = t_axis(duration)
    freq = f_start * (f_end / f_start) ** (t / duration)  # экспоненциально — звучит естественнее
    phase = 2 * np.pi * np.cumsum(freq) / RATE
    return np.sin(phase)


def saw(freq, duration):
    """Пилообразная волна — «жужжащий» синтезаторный звук."""
    t = t_axis(duration)
    return 2.0 * ((t * freq) % 1.0) - 1.0


def lowpass(x, cutoff):
    """Срезать высокие частоты выше cutoff (Гц) — звук становится глуше."""
    b, a = butter(2, cutoff / (RATE / 2), btype="low")
    return lfilter(b, a, x)


def highpass(x, cutoff):
    """Срезать низкие частоты ниже cutoff (Гц) — звук становится тоньше."""
    b, a = butter(2, cutoff / (RATE / 2), btype="high")
    return lfilter(b, a, x)


def bandpass(x, low, high):
    b, a = butter(2, [low / (RATE / 2), high / (RATE / 2)], btype="band")
    return lfilter(b, a, x)


def distort(x, amount=3.0):
    """Перегруз: делает звук грязнее и агрессивнее."""
    return np.tanh(x * amount)


def echo(x, delay=0.12, feedback=0.4, repeats=4):
    """Простое эхо: несколько затухающих повторов."""
    shift = int(delay * RATE)
    out = np.concatenate([x, np.zeros(shift * repeats)])
    for i in range(1, repeats + 1):
        out[shift * i: shift * i + len(x)] += x * feedback ** i
    return out


def mix(*parts):
    """Сложить звуки разной длины."""
    length = max(len(p) for p in parts)
    out = np.zeros(length)
    for p in parts:
        out[: len(p)] += p
    return out


def crossfade_loop(x, fade):
    """Сделать звук бесшовно зацикленным: конец плавно перетекает в начало."""
    n = int(fade * RATE)
    body, tail = x[:-n].copy(), x[-n:]
    ramp = np.linspace(0.0, 1.0, n)
    body[:n] = body[:n] * ramp + tail * (1.0 - ramp)
    return body


def save(name, x, peak=0.8):
    """Нормализовать громкость и сохранить в WAV (16 бит, моно)."""
    x = np.asarray(x, dtype=np.float64)
    m = np.max(np.abs(x))
    if m > 0:
        x = x / m * peak
    data = (x * 32767).astype(np.int16)
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    with wave.open(str(OUT_DIR / f"{name}.wav"), "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(RATE)
        f.writeframes(data.tobytes())
    print(f"  {name}.wav  ({len(x) / RATE:.2f} с)")


# ---------------------------------------------------------------------------
# Звуки героя
# ---------------------------------------------------------------------------

def step(variant):
    """Шаг: глухой удар по полу + шорох."""
    d = 0.09
    pitch = [95, 85, 105][variant]
    thump = sweep(pitch, pitch * 0.6, d) * env(d, 0.002, 0.025)
    scuff = lowpass(noise(d), 900 + variant * 150) * env(d, 0.001, 0.02) * 0.7
    return mix(thump, scuff)


def swing():
    """Взмах: свист воздуха (шум с «плывущим» фильтром)."""
    d = 0.18
    t = t_axis(d)
    x = bandpass(noise(d), 700, 2600)
    shape = np.sin(np.pi * t / d) ** 2  # нарастает и стихает
    return x * shape


def punch():
    """Удар кулаком: короткий глухой удар с щелчком."""
    d = 0.12
    body = sweep(140, 55, d) * env(d, 0.001, 0.04)
    click = highpass(noise(0.015), 2000) * env(0.015, 0.0005, 0.004) * 0.6
    return distort(mix(body, click), 2.0)


def hit_heavy():
    """Тяжёлый удар оружием: низкий удар + хруст."""
    d = 0.25
    body = sweep(110, 35, d) * env(d, 0.001, 0.07)
    crack = highpass(noise(0.05), 1500) * env(0.05, 0.0005, 0.012)
    crunch = lowpass(distort(noise(0.12), 5.0), 1800) * env(0.12, 0.002, 0.04) * 0.5
    return distort(mix(body, crack, crunch), 2.5)


def gore():
    """Брызги крови: влажный хлюпающий шум."""
    d = 0.35
    t = t_axis(d)
    wobble = 1.0 + 0.6 * np.sin(2 * np.pi * 23 * t)
    x = lowpass(noise(d), 700) * env(d, 0.003, 0.09) * wobble
    return x


def land():
    """Брошенный предмет упал: металлический звон (неровные гармоники) + стук."""
    d = 0.45
    t = t_axis(d)
    ring = sum(np.sin(2 * np.pi * f * t) * a for f, a in [(820, 1.0), (1263, 0.6), (1877, 0.4), (2540, 0.25)])
    ring = ring * env(d, 0.001, 0.09)
    knock = lowpass(noise(0.03), 1200) * env(0.03, 0.0005, 0.008) * 1.5
    return mix(ring * 0.5, knock)


def wardrobe():
    """Дверца шкафа: скрип (дрожащая частота) + стук."""
    d = 0.35
    t = t_axis(d)
    freq = 380 + 90 * np.sin(2 * np.pi * 7 * t) + rng.normal(0, 25, len(t))
    creak = np.sin(2 * np.pi * np.cumsum(freq) / RATE)
    creak = bandpass(creak * (1 + 0.5 * noise(d)), 250, 1800) * np.sin(np.pi * t / d) * 0.6
    knock = lowpass(noise(0.04), 600) * env(0.04, 0.0005, 0.01)
    return mix(creak, np.concatenate([np.zeros(int(0.28 * RATE)), knock]))


def death():
    """Смерть героя: глубокий удар + гул, уходящий в тишину."""
    d = 1.6
    boom = sweep(70, 25, d) * env(d, 0.002, 0.45)
    rumble = lowpass(noise(d), 250) * env(d, 0.01, 0.6) * 0.8
    hit = hit_heavy()
    return echo(distort(mix(boom, rumble, hit), 2.0), delay=0.18, feedback=0.3, repeats=3)


# ---------------------------------------------------------------------------
# Звуки врагов
# ---------------------------------------------------------------------------

def growl():
    """Рык постояльца перед ударом: низкая «пила» с дрожанием."""
    d = 0.4
    t = t_axis(d)
    vibrato = 75 + 12 * np.sin(2 * np.pi * 9 * t)
    raw = 2.0 * ((np.cumsum(vibrato) / RATE) % 1.0) - 1.0
    x = lowpass(raw + 0.4 * noise(d), 700) * np.sin(np.pi * t / d) ** 0.5
    return distort(x, 3.0)


def transform():
    """Превращение сторожа (1.5 с): нарастающий визг, перегруз и треск."""
    d = 1.5
    t = t_axis(d)
    scream = sweep(110, 720, d)
    scream = np.sign(scream) * np.abs(scream) ** 0.3  # «жёсткая» форма волны
    tremolo = 0.6 + 0.4 * np.sin(2 * np.pi * (6 + 18 * t / d) * t)
    crackle = highpass(noise(d), 3000) * (rng.random(len(t)) > 0.97) * 2.0
    body = lowpass(noise(d), 400) * 0.6
    rise = (t / d) ** 1.5
    return distort((scream * tremolo + crackle + body) * rise, 4.0)


def creature_hit():
    """Удар по существу: рык + мокрый удар."""
    return mix(distort(lowpass(saw(55, 0.3) + noise(0.3) * 0.5, 600) * env(0.3, 0.005, 0.1), 4.0), punch())


def owner_step():
    """Шаг хозяина: тяжелее и глуше, чем у героя, с лёгким скрипом половицы."""
    d = 0.2
    thump = sweep(70, 40, d) * env(d, 0.003, 0.05)
    scuff = lowpass(noise(d), 500) * env(d, 0.002, 0.04) * 0.6
    t = t_axis(d)
    creak = np.sin(2 * np.pi * (520 + 40 * np.sin(2 * np.pi * 11 * t)) * t) * env(d, 0.02, 0.06) * 0.08
    return mix(thump, scuff, creak)


def spotted():
    """Хозяин заметил героя: резкий диссонирующий аккорд с эхом."""
    d = 1.0
    chord = sum(saw(f, d) for f in (220.0, 233.1, 311.1, 466.2))
    chord = lowpass(chord, 2500) * env(d, 0.004, 0.35)
    hit = lowpass(noise(0.1), 300) * env(0.1, 0.001, 0.03) * 2.0
    return echo(distort(mix(chord, hit), 1.8), delay=0.15, feedback=0.35, repeats=4)


# ---------------------------------------------------------------------------
# Звуки мира
# ---------------------------------------------------------------------------

def key_pickup():
    """Звон ключей: два «колокольчика»."""
    d = 0.6
    t = t_axis(d)
    bell = lambda f: np.sin(2 * np.pi * f * t) * env(d, 0.001, 0.15)
    jingle = np.concatenate([np.zeros(int(0.06 * RATE)), (bell(1318) + bell(1976) * 0.5)[: -int(0.06 * RATE)]])
    return mix(bell(1568) * 0.7 + bell(2349) * 0.3, jingle * 0.8)


def escape():
    """Побег: восходящее арпеджио, но в миноре — радость с привкусом тревоги."""
    notes = [220.0, 261.6, 329.6, 392.0, 440.0]
    out = np.zeros(int(2.0 * RATE))
    for i, f in enumerate(notes):
        d = 1.6 - i * 0.1
        tone = (saw(f, d) * 0.4 + np.sin(2 * np.pi * f * t_axis(d))) * env(d, 0.01, 0.4)
        start = int(i * 0.12 * RATE)
        out[start: start + len(tone)] += lowpass(tone, 3000)[: len(out) - start]
    return echo(out, delay=0.2, feedback=0.3, repeats=3)


def neon_hum():
    """Гул неоновой лампы (1 с, зациклен): гудение сети + треск."""
    d = 1.0
    t = t_axis(d)
    # Частоты кратны 1 Гц — за 1 секунду укладывается целое число периодов, шва нет
    buzz = sum(np.sin(2 * np.pi * f * t) / k for k, f in enumerate((100, 200, 300, 400, 600), start=1))
    crackle = highpass(noise(d), 4000) * (rng.random(len(t)) > 0.995) * 0.6
    return buzz * 0.5 + crackle


# ---------------------------------------------------------------------------
# Фоновые лупы
# ---------------------------------------------------------------------------

def ambient_stealth():
    """Петля-«жертва»: низкий тревожный гул + ветер (12 с, зациклен)."""
    d = 12.0
    t = t_axis(d + 1.0)
    # Частоты подобраны так, чтобы за 12 с укладывалось целое число периодов
    drone = sum(saw(f, d + 1.0) for f in (41.25, 55.0, 55.25)) / 3
    lfo = 0.5 + 0.5 * np.sin(2 * np.pi * t / 6.0)  # медленное «дыхание» фильтра
    drone = lowpass(drone, 180) * (0.6 + 0.4 * lfo)
    wind = bandpass(noise(d + 1.0), 300, 900) * (0.25 + 0.2 * np.sin(2 * np.pi * t / 4.0 + 1.0))
    high = np.sin(2 * np.pi * 1760.0 * t) * 0.015 * (0.5 + 0.5 * np.sin(2 * np.pi * t / 3.0))  # тонкий «звон в ушах»
    return crossfade_loop(drone + wind * 0.6 + high, 1.0)


def ambient_combat():
    """Боевая петля: пульсирующий бас в духе darksynth (100 BPM, 4 такта = 9.6 с)."""
    bpm = 100
    eighth = 60.0 / bpm / 2
    bars = 4
    d = eighth * 8 * bars
    out = np.zeros(int(d * RATE))
    # Бас восьмыми: по ноте на такт (Ля, Ля, До, Соль)
    roots = [55.0, 55.0, 65.41, 49.0]
    for bar, root in enumerate(roots):
        for i in range(8):
            f = root * (2 if i in (3, 7) else 1)  # октавные «подскоки»
            note = lowpass(saw(f, eighth) + saw(f * 1.005, eighth), 500 + 400 * (i % 2))
            note *= env(eighth, 0.003, eighth * 0.45)
            start = int((bar * 8 + i) * eighth * RATE)
            out[start: start + len(note)] += note * 0.5
    # Удар «бочки» на каждую долю
    for beat in range(bars * 4):
        kick = sweep(120, 40, 0.18) * env(0.18, 0.001, 0.06)
        start = int(beat * eighth * 2 * RATE)
        out[start: start + len(kick)] += kick * 0.8
    # Пэд: частоты кратны 1/9.6 Гц, поэтому луп бесшовный
    pad = sum(saw(f, d) for f in (110.0, 110.3125, 164.791667)) / 3
    out += lowpass(pad, 900) * 0.12
    return distort(out, 1.5)


def door():
    """Дверь номера: долгий низкий скрип петель + глухой стук в конце."""
    d = 0.6
    t = t_axis(d)
    freq = 210 + 60 * np.sin(2 * np.pi * 3.5 * t) + 40 * t / d + rng.normal(0, 18, len(t))
    creak = np.sin(2 * np.pi * np.cumsum(freq) / RATE)
    creak = bandpass(creak * (1 + 0.6 * noise(d)), 150, 1400) * np.sin(np.pi * t / d) ** 0.7 * 0.55
    knock = lowpass(noise(0.05), 400) * env(0.05, 0.0005, 0.012)
    return mix(creak, np.concatenate([np.zeros(int(0.52 * RATE)), knock]))


def door_locked():
    """Заперто: ручку дёргают — три коротких металлических щелчка."""
    out = np.zeros(int(0.4 * RATE))
    for i, start in enumerate((0.0, 0.11, 0.2)):
        d = 0.06
        t = t_axis(d)
        click = sum(np.sin(2 * np.pi * f * t) * a for f, a in [(1400 + 90 * i, 1.0), (2310, 0.5)])
        click = click * env(d, 0.0005, 0.012) + highpass(noise(d), 1500) * env(d, 0.0005, 0.005) * 0.6
        s = int(start * RATE)
        out[s: s + len(click)] += click
    return out


def rustle():
    """Шорох: герой лезет под кровать или машину (ткань, гравий)."""
    d = 0.45
    out = np.zeros(int(d * RATE))
    for start in (0.0, 0.12, 0.25):
        part = bandpass(noise(0.16), 900, 5000) * np.sin(np.pi * t_axis(0.16) / 0.16) * 0.5
        s = int(start * RATE)
        out[s: s + len(part)] += part
    return out


def bin_lid():
    """Крышка мусорного бака или железного шкафчика: гулкий лязг."""
    d = 0.5
    t = t_axis(d)
    ring = sum(np.sin(2 * np.pi * f * t) * a for f, a in [(310, 1.0), (517, 0.7), (893, 0.4), (1420, 0.2)])
    ring = ring * env(d, 0.001, 0.12)
    knock = lowpass(noise(0.05), 900) * env(0.05, 0.0005, 0.01) * 1.5
    return mix(ring * 0.5, knock)


def flashlight_click():
    """Щелчок кнопки фонарика: короткий пластиковый «клик»."""
    d = 0.05
    t = t_axis(d)
    click = np.sin(2 * np.pi * 2600 * t) * env(d, 0.0003, 0.006)
    return mix(click, highpass(noise(d), 2000) * env(d, 0.0003, 0.004) * 0.5)


def splash():
    """Шаг по луже: мокрый шлепок с брызгами."""
    d = 0.25
    t = t_axis(d)
    slap = lowpass(noise(d), 900) * env(d, 0.001, 0.03)
    drops = bandpass(noise(d), 1500, 6000) * env(d, 0.01, 0.08) * 0.5
    bubble = np.sin(2 * np.pi * (700 + 900 * t / d) * t) * env(d, 0.02, 0.04) * 0.2
    return mix(slap, drops, bubble)


# ---------------------------------------------------------------------------

SOUNDS = {
    "step_1": lambda: step(0),
    "step_2": lambda: step(1),
    "step_3": lambda: step(2),
    "swing": swing,
    "punch": punch,
    "hit_heavy": hit_heavy,
    "gore": gore,
    "land": land,
    "wardrobe": wardrobe,
    "death": death,
    "growl": growl,
    "transform": transform,
    "creature_hit": creature_hit,
    "owner_step": owner_step,
    "spotted": spotted,
    "key": key_pickup,
    "escape": escape,
    "neon_hum": neon_hum,
    "ambient_stealth": ambient_stealth,
    "ambient_combat": ambient_combat,
    # Новые звуки — в конце списка: случайность идёт по порядку, и старые звуки не меняются
    "door": door,
    "door_locked": door_locked,
    "rustle": rustle,
    "bin_lid": bin_lid,
    "flashlight": flashlight_click,
    "splash": splash,
}

if __name__ == "__main__":
    print(f"Генерирую звуки в {OUT_DIR}:")
    for name, make in SOUNDS.items():
        save(name, make())
    print("Готово.")
