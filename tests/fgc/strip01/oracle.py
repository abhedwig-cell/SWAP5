"""Independent Dupuit and cell-centred finite-volume oracles, SI/day units.

No MODFLOW, SWAP or FloPy imports. Drain is a sink at the first cell centre.
"""
import argparse
import json
from pathlib import Path
import numpy as np


def continuum(x, length, recharge, conductivity, drain_thickness):
    return np.sqrt(drain_thickness**2 + recharge / conductivity *
                   (2 * length * np.asarray(x) - np.asarray(x)**2))


def discrete(n, dx, width, recharge, conductivity, stage, base, conductance):
    if min(n, dx, width, conductivity, conductance) <= 0 or recharge < 0:
        raise ValueError("invalid oracle geometry or parameters")
    total = recharge * n * dx * width
    h0 = stage - base + total / conductance
    if h0 <= 0:
        raise ValueError("dry drain outside oracle scope")
    i = np.arange(n)
    thickness = np.sqrt(h0*h0 + recharge*dx*dx/conductivity*i*(2*n-1-i))
    face_q = recharge * dx * width * np.arange(n-1, 0, -1)
    calculated = conductivity * width * (thickness[1:]**2-thickness[:-1]**2)/(2*dx)
    assert np.max(np.abs(face_q-calculated), initial=0) < 1e-12
    return thickness + base, total


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--output", type=Path, required=True)
    args = p.parse_args()
    rows = []
    for k in [0.1, 0.25, 0.5, 1, 2]:
        heads, q = discrete(50, 1, 1, .001, k, -5, -10, 100)
        ideal = float(continuum(50, 50, .001, k, 5)-5)
        fine, _ = discrete(100, .5, 1, .001, k, -5, -10, 100)
        rows.append(dict(k_m_per_day=k, ideal_midpoint_rise_m=ideal,
                         discrete_midpoint_rise_m=float(heads[-1]+5),
                         refined_midpoint_rise_m=float(fine[-1]+5),
                         recharge_m3_per_day=q, drain_head_excess_m=.0005,
                         heads_m=heads.tolist()))
    # Zero-forcing and zero-gradient checks are independent of tested K sweep.
    zero, q = discrete(50, 1, 1, 0, .5, -5, -10, 100)
    assert q == 0 and np.array_equal(zero, np.full(50, -5.0))
    assert all(rows[i]["ideal_midpoint_rise_m"] > rows[i+1]["ideal_midpoint_rise_m"]
               for i in range(len(rows)-1))
    # Cell-centred sink moves toward the physical edge with refinement.
    assert all(abs(r["refined_midpoint_rise_m"]-r["ideal_midpoint_rise_m"]) <
               abs(r["discrete_midpoint_rise_m"]-r["ideal_midpoint_rise_m"])
               for r in rows)
    args.output.mkdir(parents=True, exist_ok=True)
    result = dict(schema="swap5.strip01.oracle.v1", status="ORACLE_SELF_TEST_PASS",
                  native_modflow_executed=False, coupled_executed=False, rows=rows)
    (args.output/"oracle.json").write_text(json.dumps(result, indent=2)+"\n")
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    fig, ax = plt.subplots(figsize=(7, 4))
    for r in rows:
        ax.plot(np.arange(50)+.5, r["heads_m"], label=f'K={r["k_m_per_day"]} m/d')
    ax.set(xlabel="Distance from left edge (m)", ylabel="Head (m relative to land)",
           title="Independent Dupuit finite-volume oracle, not MODFLOW output")
    ax.legend(); ax.grid(alpha=.2); fig.tight_layout()
    fig.savefig(args.output/"oracle_profiles.svg")
    print("STRIP01_INDEPENDENT_ORACLE_SELF_TEST=PASS")


if __name__ == "__main__":
    main()
