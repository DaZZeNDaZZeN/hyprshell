#!/usr/bin/env python3
"""Real-time 32-band audio spectrum analyzer for Hyprshell's Audio Visualizer widget.
Captures desktop monitor audio via parec/pw-cat and streams JSON arrays of 32 floats (0..1) at ~30 FPS.
"""
import json
import math
import os
import select
import struct
import subprocess
import sys
import time

try:
    import numpy as np
    HAS_NUMPY = True
except ImportError:
    HAS_NUMPY = False

RATE = 22050
CHUNK = 735  # ~33.3ms at 22050 Hz (30 FPS)
BYTES_PER_CHUNK = CHUNK * 2
NUM_BANDS = 32


def get_monitor_source():
    try:
        out = subprocess.check_output(
            ["pactl", "get-default-sink"], text=True, stderr=subprocess.DEVNULL, timeout=2
        ).strip()
        if out:
            return out + ".monitor"
    except Exception:
        pass
    return "@DEFAULT_MONITOR@"


def start_capture(source):
    for cmd in (
        ["parec", "--raw", "--format=s16le", f"--rate={RATE}", "--channels=1", "--latency-msec=30", "-d", source],
        ["pw-cat", "--record", "--raw", "--format=s16", f"--rate={RATE}", "--channels=1", "--latency=30ms", "-"],
    ):
        try:
            proc = subprocess.Popen(
                cmd, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, bufsize=BYTES_PER_CHUNK * 2
            )
            return proc
        except Exception:
            continue
    return None


def compute_bands_numpy(samples, window, bin_edges):
    arr = np.frombuffer(samples, dtype=np.int16).astype(np.float32) / 32768.0
    if len(arr) < CHUNK:
        arr = np.pad(arr, (0, CHUNK - len(arr)))
    elif len(arr) > CHUNK:
        arr = arr[-CHUNK:]
    rms = float(np.sqrt(np.mean(arr * arr)))
    if rms < 0.0008:
        return [0.0] * NUM_BANDS
    spec = np.abs(np.fft.rfft(arr * window)) / (CHUNK * 0.25)
    bands = []
    for i in range(NUM_BANDS):
        lo, hi = bin_edges[i], bin_edges[i + 1]
        if hi <= lo:
            hi = lo + 1
        val = float(np.mean(spec[lo:hi]))
        # Boost higher frequencies slightly for visual balance
        boost = 1.0 + (i / NUM_BANDS) * 2.2
        norm = min(1.0, math.pow(max(0.0, val * boost * 4.5), 0.65))
        bands.append(norm)
    return bands


def compute_bands_fallback(samples):
    count = len(samples) // 2
    if count == 0:
        return [0.0] * NUM_BANDS
    vals = struct.unpack(f"<{count}h", samples[: count * 2])
    step = max(1, count // NUM_BANDS)
    bands = []
    for i in range(NUM_BANDS):
        seg = vals[i * step : (i + 1) * step]
        if not seg:
            bands.append(0.0)
            continue
        energy = sum(abs(x) for x in seg) / (len(seg) * 32768.0)
        bands.append(min(1.0, math.pow(energy * 4.0, 0.7)))
    return bands


def main():
    if HAS_NUMPY:
        window = np.hanning(CHUNK).astype(np.float32)
        max_bin = CHUNK // 2
        # Logarithmic bin edges from bin 1 to max_bin
        edges = np.logspace(0, math.log10(max(2, max_bin)), NUM_BANDS + 1)
        bin_edges = [max(1, min(max_bin, int(round(x)))) for x in edges]
        for i in range(1, len(bin_edges)):
            if bin_edges[i] <= bin_edges[i - 1]:
                bin_edges[i] = min(max_bin, bin_edges[i - 1] + 1)
    else:
        window = None
        bin_edges = None

    source = get_monitor_source()
    proc = start_capture(source)
    if not proc or not proc.stdout:
        sys.exit(1)

    fd = proc.stdout.fileno()
    os.set_blocking(fd, False)

    smoothed = [0.0] * NUM_BANDS
    was_silent = False
    last_sink_check = time.monotonic()
    buf = b""

    try:
        while True:
            r, _, _ = select.select([fd], [], [], 0.04)
            if r:
                try:
                    chunk = os.read(fd, BYTES_PER_CHUNK * 4)
                except BlockingIOError:
                    chunk = b""
                if not chunk:
                    time.sleep(0.1)
                    if proc.poll() is not None:
                        source = get_monitor_source()
                        proc = start_capture(source)
                        if not proc or not proc.stdout:
                            break
                        fd = proc.stdout.fileno()
                        os.set_blocking(fd, False)
                    continue
                buf += chunk
                if len(buf) >= BYTES_PER_CHUNK:
                    frame = buf[-BYTES_PER_CHUNK:]
                    buf = b""
                    if HAS_NUMPY:
                        target = compute_bands_numpy(frame, window, bin_edges)
                    else:
                        target = compute_bands_fallback(frame)
                else:
                    continue
            else:
                target = [0.0] * NUM_BANDS
                now = time.monotonic()
                if now - last_sink_check > 5.0:
                    last_sink_check = now
                    new_src = get_monitor_source()
                    if new_src != source:
                        source = new_src
                        try:
                            proc.terminate()
                        except Exception:
                            pass
                        proc = start_capture(source)
                        if not proc or not proc.stdout:
                            break
                        fd = proc.stdout.fileno()
                        os.set_blocking(fd, False)

            max_v = 0.0
            for i in range(NUM_BANDS):
                t = target[i]
                cur = smoothed[i]
                if t > cur:
                    cur = cur + (t - cur) * 0.62
                else:
                    cur = cur * 0.78
                if cur < 0.005:
                    cur = 0.0
                smoothed[i] = round(cur, 3)
                if cur > max_v:
                    max_v = cur

            if max_v > 0.0 or not was_silent:
                was_silent = (max_v == 0.0)
                sys.stdout.write(json.dumps(smoothed) + "\n")
                sys.stdout.flush()
    except (KeyboardInterrupt, BrokenPipeError):
        pass
    finally:
        try:
            proc.terminate()
        except Exception:
            pass


if __name__ == "__main__":
    main()
