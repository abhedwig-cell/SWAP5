#!/usr/bin/env python3
"""Generate PUB-GC E3 manuscript figures from persisted JSON evidence.

This script intentionally creates separate figures rather than multi-panel
composites so numerical interface closure and hydrological impact remain
visually distinct.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path

import matplotlib.pyplot as plt


def load(path: Path) -> dict:
    return json.loads(path.read_text())


def grouped_converged(result: dict) -> dict[float, list[dict]]:
    grouped: dict[float, list[dict]] = {}
    for case in result["cases"]:
        if case.get("status") != "CONVERGED":
            continue
        grouped.setdefault(float(case["k_m_per_day"]), []).append(case)
    for cases in grouped.values():
        cases.sort(key=lambda x: float(x["window_day"]))
    return dict(sorted(grouped.items()))


def save(fig, out: Path) -> None:
    fig.tight_layout()
    fig.savefig(out, bbox_inches="tight")
    plt.close(fig)


def plot_loose_residual_ratio(result: dict, outdir: Path) -> None:
    fig, ax = plt.subplots()
    for k, cases in grouped_converged(result).items():
        x=[float(c["window_day"]) for c in cases]
        y=[abs(float(c["loose"]["residual_m_per_s"]))/1.0e-15 for c in cases]
        ax.plot(x,y,marker="o",label=f"K={k:g} m/day")
    ax.axhline(1.0,linestyle="--",label="coupled qualification tolerance")
    ax.set_xscale("log")
    ax.set_yscale("log")
    ax.set_xlabel("Coupling-window duration (day)")
    ax.set_ylabel("|loose interface residual| / 1e-15 m s-1")
    ax.legend()
    save(fig,outdir/"pub_gc_e3_loose_interface_residual_ratio.svg")


def plot_iterations(result: dict, outdir: Path) -> None:
    fig, ax = plt.subplots()
    for k, cases in grouped_converged(result).items():
        x=[float(c["window_day"]) for c in cases]
        y=[int(c["iterative"]["coupling_outer_iterations"]) for c in cases]
        ax.plot(x,y,marker="o",label=f"K={k:g} m/day")
    ax.set_xscale("log")
    ax.set_xlabel("Coupling-window duration (day)")
    ax.set_ylabel("Strong-coupling outer iterations")
    ax.legend()
    save(fig,outdir/"pub_gc_e3_outer_iterations.svg")


def plot_head_correction(result: dict, outdir: Path) -> None:
    fig, ax = plt.subplots()
    for k, cases in grouped_converged(result).items():
        x=[float(c["window_day"]) for c in cases]
        y=[max(abs(float(c["delta_h_iter_minus_loose_m"])),1e-18) for c in cases]
        ax.plot(x,y,marker="o",label=f"K={k:g} m/day")
    ax.set_xscale("log")
    ax.set_yscale("log")
    ax.set_xlabel("Coupling-window duration (day)")
    ax.set_ylabel("|H_strong - H_loose| (m)")
    ax.legend()
    save(fig,outdir/"pub_gc_e3_head_correction.svg")


def plot_exchange_correction(result: dict, outdir: Path) -> None:
    fig, ax = plt.subplots()
    for k, cases in grouped_converged(result).items():
        x=[float(c["window_day"]) for c in cases]
        y=[max(abs(float(c["delta_qswap_iter_minus_loose_m_per_s"])),1e-22) for c in cases]
        ax.plot(x,y,marker="o",label=f"K={k:g} m/day")
    ax.set_xscale("log")
    ax.set_yscale("log")
    ax.set_xlabel("Coupling-window duration (day)")
    ax.set_ylabel("|q_SWAP,strong - q_SWAP,loose| (m s-1)")
    ax.legend()
    save(fig,outdir/"pub_gc_e3_exchange_correction.svg")


def plot_predictor_envelope(envelope: dict, outdir: Path) -> None:
    fig, ax = plt.subplots()
    windows=sorted({float(c["window_day"]) for c in envelope["cases"]})
    for w in windows:
        cases=sorted(
            (c for c in envelope["cases"] if float(c["window_day"])==w),
            key=lambda c: float(c["predictor_qbot_cm_per_day"]),
        )
        ready=[c for c in cases if c["ready"]]
        failed=[c for c in cases if not c["ready"]]
        if ready:
            ax.scatter(
                [float(c["predictor_qbot_cm_per_day"]) for c in ready],
                [w]*len(ready),
                marker="o",
                label=f"READY, W={w:g} d",
            )
        if failed:
            ax.scatter(
                [float(c["predictor_qbot_cm_per_day"]) for c in failed],
                [w]*len(failed),
                marker="x",
                label=f"incomplete, W={w:g} d",
            )
    ax.set_xscale("log")
    ax.set_yscale("log")
    ax.set_xlabel("Predictor bottom flux (cm day-1)")
    ax.set_ylabel("Coupling-window duration (day)")
    ax.legend()
    save(fig,outdir/"pub_gc_e3d_predictor_envelope.svg")


def main() -> None:
    p=argparse.ArgumentParser()
    p.add_argument("--e3",type=Path,required=True)
    p.add_argument("--e3d",type=Path,required=True)
    p.add_argument("--outdir",type=Path,required=True)
    args=p.parse_args()
    args.outdir.mkdir(parents=True,exist_ok=True)

    e3=load(args.e3)
    e3d=load(args.e3d)
    plot_loose_residual_ratio(e3,args.outdir)
    plot_iterations(e3,args.outdir)
    plot_head_correction(e3,args.outdir)
    plot_exchange_correction(e3,args.outdir)
    plot_predictor_envelope(e3d,args.outdir)


if __name__=="__main__":
    main()
