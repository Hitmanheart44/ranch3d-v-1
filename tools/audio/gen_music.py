#!/usr/bin/env python3
"""Original game music with ACE-Step 1.5 (MIT licence, commercial use allowed). Run with ACE-Step's own venv:
  cd ~/Applications/acestep/repo && uv run python ~/Projects/ranch3d/tools/audio/gen_music.py [track ...]
Writes assets/audio/music_<name>.ogg (seamless loops: tail crossfaded into head). Old files go to ~/.cache/ranch3d_tmp/audio_old/."""
import os, subprocess, sys, shutil, glob

GAME = os.path.expanduser("~/Projects/ranch3d")
OUT = os.path.join(GAME, "assets/audio")
WORK = os.path.expanduser("~/.cache/ranch3d_tmp/music_work")
OLD = os.path.expanduser("~/.cache/ranch3d_tmp/audio_old")
STYLE = "instrumental, no vocals, high quality studio production, warm, cinematic, Japanese countryside fantasy game soundtrack, "
TRACKS = {
    "title": (STYLE + "gentle koto and shakuhachi with soft strings, mysterious and hopeful, slow, sacred shrine at dawn", 70, 4.0),
    "ranch": (STYLE + "cozy pastoral, acoustic guitar, light percussion, flute, plucked strings, relaxed morning on a mountain farm, bouncy but calm", 100, 4.0),
    "shrine": (STYLE + "sacred and serene, shakuhachi, koto, deep temple bell, soft pads, spiritual, slow, ethereal", 60, 4.0),
    "town": (STYLE + "lively harbor town, shamisen, taiko, accordion, whistling, busy market, cheerful, medium tempo", 112, 4.0),
    "cave": (STYLE + "dark mysterious dungeon exploration, low drones, distant taiko, eerie plucked strings, tension, dripping atmosphere", 74, 4.0),
    "battle": (STYLE + "intense action battle, driving taiko drums, fast shamisen, epic brass and strings, heroic, energetic", 150, 4.0),
}


def main():
    names = sys.argv[1:] or list(TRACKS)
    sys.path.insert(0, os.getcwd())
    from acestep.handler import AceStepHandler
    from acestep.llm_inference import LLMHandler
    from acestep.inference import GenerationParams, GenerationConfig, generate_music
    root = os.getcwd()
    dit = AceStepHandler()
    llm = LLMHandler()
    dit.initialize_service(project_root=root, config_path="acestep-v15-turbo", device="cuda")
    llm.initialize(checkpoint_dir=os.path.join(root, "checkpoints"), lm_model_path="acestep-5Hz-lm-0.6B", backend="pt", device="cuda")
    os.makedirs(WORK, exist_ok=True); os.makedirs(OLD, exist_ok=True)
    for n in names:
        cap, bpm, _ = TRACKS[n]
        p = GenerationParams(caption=cap, lyrics="[Instrumental]", instrumental=True, bpm=bpm, duration=95, shift=3.0, seed=1000 + len(n))
        c = GenerationConfig(batch_size=1, audio_format="flac")
        d = os.path.join(WORK, n)
        r = generate_music(dit, llm, p, c, save_dir=d)
        if not r.success:
            print("FAILED", n, r.error); continue
        src = r.audios[0]["path"]
        dst = os.path.join(OUT, f"music_{n}.ogg")
        if os.path.exists(dst):
            shutil.copy(dst, os.path.join(OLD, os.path.basename(dst)))
        # seamless loop: the last 4 s fade out while the first 4 s fade in over them, then drop the tail
        import numpy as np, soundfile as sf
        x, sr = sf.read(src, always_2d=True)
        k = 4 * sr
        out = x[:-k].copy()
        t = np.linspace(0.0, 1.0, k)[:, None]
        out[:k] = x[:k] * np.sqrt(t) + x[-k:] * np.sqrt(1.0 - t)
        loop = os.path.join(WORK, n + "_loop.wav")
        sf.write(loop, out, sr)
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", loop, "-ac", "2", "-ar", "44100", "-c:a", "libvorbis", "-q:a", "5", dst], check=True)
        print("wrote", dst)


if __name__ == "__main__":
    main()
