#!/usr/bin/env python3
"""Make reproducible F-GC-STRIP01 figures from a native standalone result JSON."""
import argparse
import json
from pathlib import Path

import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np


def main():
    p = argparse.ArgumentParser()
    p.add_argument("result", type=Path, help="standalone_result.json from run_standalone.py")
    p.add_argument("--output", type=Path, required=True)
    a = p.parse_args()
    data = json.loads(a.result.read_text(encoding="utf-8"))
    if data.get("status") != "STANDALONE_AB_PASS" or data.get("coupled_executed") is not False:
        raise SystemExit("refusing to plot absent or non-passing native standalone result")
    a.output.mkdir(parents=True, exist_ok=True)

    fig, ax = plt.subplots(figsize=(8.4, 5.2), constrained_layout=True)
    for row in data["steady"]:
        if row["n"] == 50:
            x = (np.arange(row["n"]) + .5) * (50.0 / row["n"])
            ax.plot(x, row["heads_m"], marker=".", ms=3, label=f"MODFLOW K={row['k']:g} m/d")
    ax.set(xlabel="Distance from drain boundary (m)", ylabel="MODFLOW head (m)",
           title="50-cell steady recharge strip (R = 1 mm/d)")
    ax.grid(True, alpha=.25)
    ax.legend(ncol=2, fontsize=8)
    fig.savefig(a.output / "steady_k_sweep.svg")
    plt.close(fig)

    fig, axes = plt.subplots(1, 2, figsize=(11, 4.6), constrained_layout=True)
    rows = [r for r in data["steady"] if r["k"] == .5]
    for row in sorted(rows, key=lambda r: r["n"]):
        x = (np.arange(row["n"]) + .5) * (50.0 / row["n"])
        axes[0].plot(x, row["heads_m"], marker=".", ms=3, label=f"MODFLOW {row['n']} cells")
    axes[0].set(xlabel="Distance from drain boundary (m)", ylabel="MODFLOW head (m)",
                title="Mesh refinement at K = 0.5 m/d")
    axes[0].grid(True, alpha=.25)
    axes[0].legend()
    dd = data["drain_down"]
    times = np.array([r["day"] for r in dd], dtype=float)
    storage = np.array([r["storage_m3"] for r in dd], dtype=float)
    drainage = np.array([r["cumulative_drain_m3"] for r in dd], dtype=float)
    axes[1].plot(times, storage, label="aquifer storage")
    axes[1].plot(times, drainage, label="cumulative DRN outflow")
    axes[1].set(xlabel="Elapsed time (d)", ylabel="Water volume (m³)",
                title="Drain-down storage and outflow")
    axes[1].grid(True, alpha=.25)
    axes[1].legend()
    fig.savefig(a.output / "mesh_and_drain_down.svg")
    plt.close(fig)

    fig, ax = plt.subplots(figsize=(8.4, 5.2), constrained_layout=True)
    wanted = [.25, 1., 7., 30., 120.]
    for target in wanted:
        row = min(dd, key=lambda r: abs(r["day"] - target))
        x = (np.arange(len(row["heads_m"])) + .5)
        ax.plot(x, row["heads_m"], label=f"day {row['day']:g}")
    ax.set(xlabel="Distance from drain boundary (m)", ylabel="MODFLOW head (m)",
           title="Transient drain-down profiles (initial head = -3 m)")
    ax.grid(True, alpha=.25)
    ax.legend(ncol=2)
    fig.savefig(a.output / "drain_down_profiles.svg")
    plt.close(fig)


if __name__ == "__main__":
    main()
