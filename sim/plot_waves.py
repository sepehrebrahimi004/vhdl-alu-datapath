"""Render timing diagrams from the VCD files written by `run_tests.py --vcd`.

    python sim/plot_waves.py
"""

import os
import re

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt  # noqa: E402

WIDTHS = {}
DOCS = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "docs")


def read_vcd(path):
    """Minimal VCD reader -> {signal name: [(time_ps, value_str), ...]} (top scope only).
    Signal widths are stored in WIDTHS."""
    ids, waves, depth, t = {}, {}, 0, 0
    with open(path) as fh:
        header = True
        for line in fh:
            tok = line.split()
            if not tok:
                continue
            if header:
                if tok[0] == "$scope":
                    depth += 1
                elif tok[0] == "$upscope":
                    depth -= 1
                elif tok[0] == "$var" and depth == 1:
                    name = tok[4]
                    WIDTHS[name] = int(tok[2])
                    ids[tok[3]] = name
                    waves[name] = []
                elif tok[0] == "$enddefinitions":
                    header = False
                continue
            if tok[0].startswith("#"):
                t = int(tok[0][1:])
            elif tok[0][0] in "bB":
                if tok[1] in ids:
                    waves[ids[tok[1]]].append((t, tok[0][1:]))
            elif tok[0][0] in "01xzXZUu":
                if tok[0][1:] in ids:
                    waves[ids[tok[0][1:]]].append((t, tok[0][0]))
    return waves


def value_at(wave, t):
    v = None
    for ti, vi in wave:
        if ti > t:
            break
        v = vi
    return v


def plot(waves, signals, t0, t1, title, path, fmt=None):
    fmt = fmt or {}
    fig, ax = plt.subplots(figsize=(11, 0.55 * len(signals) + 1.0))
    for row, sig in enumerate(signals):
        y0 = len(signals) - 1 - row
        wave = waves[sig]
        points = [(t0, value_at(wave, t0))] + [(t, v) for t, v in wave if t0 < t < t1] + [(t1, None)]
        bus = WIDTHS.get(sig, 1) > 1
        for (ta, va), (tb, _) in zip(points[:-1], points[1:]):
            xa, xb = ta / 1000, tb / 1000
            if bus:
                ax.fill([xa, xa + 2, xb - 2, xb, xb - 2, xa + 2], [y0 + .4, y0 + .75, y0 + .75, y0 + .4, y0 + .05, y0 + .05],
                        color="#dfe9f5", ec="#3a6ea5", lw=0.8)
                if va and re.fullmatch("[01]+", va) and xb - xa > 25:
                    label = fmt.get(sig, lambda s: f"{int(s, 2):X}")(va)
                    ax.text((xa + xb) / 2, y0 + .4, label, ha="center", va="center", fontsize=7)
            else:
                level = y0 + (0.75 if va == "1" else 0.05)
                ax.plot([xa, xb], [level, level], color="#1f4e79", lw=1.3)
                if tb < t1:
                    nxt = value_at(wave, tb)
                    ax.plot([xb, xb], [y0 + 0.05, y0 + 0.75], color="#1f4e79", lw=1.3) if nxt != va else None
        ax.text(t0 / 1000 - 4, y0 + .4, sig, ha="right", va="center", fontsize=9, family="monospace")
    ax.set_xlim(t0 / 1000, t1 / 1000)
    ax.set_ylim(-0.2, len(signals))
    ax.set_yticks([])
    ax.set_xlabel("time (ns)")
    ax.set_title(title)
    for s in ("left", "right", "top"):
        ax.spines[s].set_visible(False)
    fig.tight_layout()
    fig.savefig(path, dpi=130)
    plt.close(fig)


def first_rise(wave, after=0):
    for t, v in wave:
        if t > after and v == "1":
            return t
    return None


def main():
    w = read_vcd(os.path.join(DOCS, "tb_seq_detector.vcd"))
    # second scan in the testbench = assignment example 2 (overlapping codes)
    s1 = first_rise(w["start"])
    s2 = first_rise(w["start"], s1 + 20_000)
    plot(w, ["start", "y_in", "detected", "out_valid", "data_out"], s2 - 10_000, s2 + 420_000,
         "Sequence detector - assignment example 2 (0x7DF5FB42): 2-cycle pulse, then 4-cycle pulse "
         "for the overlapping code", os.path.join(DOCS, "wave_seq_detector.png"))

    w = read_vcd(os.path.join(DOCS, "tb_multiplier16.vcd"))
    s = first_rise(w["start"])
    plot(w, ["start", "a", "b", "busy", "ready", "y"], s - 500, s + 185_000,
         "Shift-and-add multiplier: 6 x 3 = 18 after 16 cycles", os.path.join(DOCS, "wave_multiplier.png"),
         fmt={"a": lambda v: str(int(v, 2) & 0xFFFF), "b": lambda v: str(int(v, 2) & 0xFFFF),
              "y": lambda v: str(int(v, 2))})

    w = read_vcd(os.path.join(DOCS, "tb_datapath_top.vcd"))
    s = first_rise(w["start"])
    plot(w, ["start", "alu_ready", "alu_y", "detected", "ram_en", "ram_address", "ram_data", "error"],
         s - 500, s + 400_000,
         "Full datapath: ALU result 0xC7D0342A -> code found -> packet written to RAM[0x42] = 0x7D03",
         os.path.join(DOCS, "wave_datapath.png"))
    print("written docs/wave_*.png")


if __name__ == "__main__":
    main()
