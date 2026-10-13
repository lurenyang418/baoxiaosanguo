"""Render tracks from the supplied NSF using libgme, preserving ROM audio provenance.

Usage: python3 research/tools/render/render_nsf.py /path/to/original.nsf
Requires Homebrew game-music-emu and ffmpeg. Outputs short Ogg files for Godot.
"""

import ctypes
import subprocess
import sys
from pathlib import Path


def main() -> None:
    source = Path(sys.argv[1]).resolve()
    out = Path(__file__).resolve().parents[3] / "assets/audio"
    out.mkdir(parents=True, exist_ok=True)
    lib = ctypes.CDLL("/opt/homebrew/lib/libgme.dylib")
    ptr = ctypes.c_void_p
    lib.gme_open_file.argtypes = [ctypes.c_char_p, ctypes.POINTER(ptr), ctypes.c_int]
    lib.gme_open_file.restype = ctypes.c_char_p
    lib.gme_track_count.argtypes = [ptr]
    lib.gme_track_count.restype = ctypes.c_int
    lib.gme_start_track.argtypes = [ptr, ctypes.c_int]
    lib.gme_start_track.restype = ctypes.c_char_p
    lib.gme_play.argtypes = [ptr, ctypes.c_int, ctypes.POINTER(ctypes.c_short)]
    lib.gme_play.restype = ctypes.c_char_p
    lib.gme_track_ended.argtypes = [ptr]
    lib.gme_track_ended.restype = ctypes.c_int
    lib.gme_delete.argtypes = [ptr]
    emulator = ptr()
    error = lib.gme_open_file(str(source).encode(), ctypes.byref(emulator), 22050)
    if error:
        raise RuntimeError(error.decode())
    try:
        count = lib.gme_track_count(emulator)
        print(f"{count} NSF tracks")
        for track in range(count):
            error = lib.gme_start_track(emulator, track)
            if error:
                raise RuntimeError(error.decode())
            seconds = 42 if track < 12 else 12
            chunks = 0
            audio_path = out / f"nsf_{track:02}.mp3"
            if audio_path.exists():
                print(f"{track:02}: keeping existing {audio_path.name}")
                continue
            process = subprocess.Popen(
                ["ffmpeg", "-hide_banner", "-loglevel", "error", "-f", "s16le", "-ar", "22050",
                 "-ac", "2", "-i", "pipe:0", "-c:a", "libmp3lame", "-q:a", "5", str(audio_path)],
                stdin=subprocess.PIPE,
            )
            assert process.stdin is not None
            for _ in range(seconds * 10):
                samples = (ctypes.c_short * 4410)()
                error = lib.gme_play(emulator, 4410, samples)
                if error:
                    raise RuntimeError(error.decode())
                process.stdin.write(bytes(samples))
                chunks += 1
                if lib.gme_track_ended(emulator):
                    break
            process.stdin.close()
            if process.wait() != 0:
                raise RuntimeError(f"ffmpeg failed for track {track}")
            print(f"{track:02}: {chunks / 10:.1f}s -> {audio_path.name}")
    finally:
        lib.gme_delete(emulator)


if __name__ == "__main__":
    main()
