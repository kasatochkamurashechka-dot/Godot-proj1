"""Layer heel impact, sole contact and grit at different weights and pitches."""
from pathlib import Path
import wave
import numpy as np
from scipy.signal import butter, sosfilt

OUT = Path(__file__).resolve().parents[1] / "assets" / "sounds"
rate = 22050
rng = np.random.default_rng(333)
for heavy, prefix in [(False, "step"), (True, "boot")]:
    for variant in range(1, 4):
        t = np.arange(int(rate * (.39 if heavy else .29))) / rate
        track = np.zeros_like(t)
        for delay, gain in [(0, 1), (rng.uniform(.055,.092), .55)]:
            age = np.maximum(0, t-delay)
            envelope = (1-np.exp(-age*550)) * np.exp(-age*(20 if heavy else 34))
            grain = rng.normal(size=len(t))
            low = sosfilt(butter(3, 500 if heavy else 850, fs=rate, output="sos"),grain)
            scuff = sosfilt(butter(2,[750,3900],btype="band",fs=rate,output="sos"),grain)
            thud = np.sin(2*np.pi*((48 if heavy else 75)*age + 0.9*(1-np.exp(-age*55))))
            track += gain * envelope * (.55*thud + 1.3*low + .24*scuff)
        with wave.open(str(OUT / f"{prefix}_{variant}.wav"),"wb") as wav:
            wav.setparams((1,2,rate,0,"NONE","not compressed"))
            wav.writeframes((track/max(np.abs(track))*24000).astype("<i2").tobytes())
