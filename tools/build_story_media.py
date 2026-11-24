"""Prepare the 32-direction sheets and small synthesized story sounds."""
from pathlib import Path
import wave
import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets/story"
OUT.mkdir(exist_ok=True)
for path in sorted((ROOT / "Арты").iterdir()):
    if path.suffix.lower() not in {".jpg", ".png"}:
        continue
    rgb = np.asarray(Image.open(path).convert("RGB")).astype(int)
    bg = np.median(rgb[:4], axis=(0, 1))
    foreground = np.max(np.abs(rgb-bg), axis=2) > 45
    labels, count = ndimage.label(foreground)
    ids = np.argsort(np.bincount(labels.ravel())[1:])[-32:] + 1
    boxes = ndimage.find_objects(labels)
    ids = sorted(ids, key=lambda i: boxes[i-1][0].start + boxes[i-1][0].stop)
    sheet = Image.new("RGBA", (24*8, 30*4))
    for row in range(4):
        ordered = sorted(ids[row*8:row*8+8], key=lambda i: boxes[i-1][1].start)
        for col, i in enumerate(ordered):
            box = boxes[i-1]
            mask = ndimage.binary_fill_holes(labels[box] == i)
            part = Image.fromarray(rgb[box].astype("uint8"))
            part.putalpha(Image.fromarray((mask*255).astype("uint8")))
            part.thumbnail((22, 25), Image.Resampling.LANCZOS)
            sheet.paste(part, (24*col+(24-part.width)//2, 30*row+27-part.height))
    sheet.save(OUT / (path.stem+".png"))
    if path.stem == "Постоялец_5":
        injured = sheet.copy()
        draw = ImageDraw.Draw(injured)
        for row in range(4):
            for col in range(8):
                x, y = col*24, row*30
                draw.line((x+10,y+5,x+14,y+4), fill="#d8ceb7", width=2)
                draw.line((x+10,y+12,x+13,y+17), fill="#892d36", width=3)
        injured.save(OUT / "Раненый.png")

def sound(name, samples):
    with wave.open(str(OUT / (name+".wav")), "wb") as wav:
        wav.setparams((1, 2, 22050, 0, "NONE", "not compressed"))
        wav.writeframes((np.clip(samples, -1, 1)*32767).astype("<i2").tobytes())

t = np.arange(1200)/22050
sound("voice", .27*np.sin(2*np.pi*(165*t+950*t*t))*np.sin(np.pi*t/t[-1])**2)
t = np.arange(22050*5)/22050
noise = ndimage.gaussian_filter1d(np.random.default_rng(333).normal(size=len(t)), 6)
sound("breath", (noise*.9+.12*np.sin(2*np.pi*48*t))*np.sin(np.pi*t/2.5)**2)
