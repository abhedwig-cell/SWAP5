"""Reproduce native C0 component figures from persisted JSON."""
import argparse
import json
from pathlib import Path
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import numpy as np


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('result', type=Path)
    ap.add_argument('--output', type=Path, required=True)
    args = ap.parse_args()
    data = json.loads(args.result.read_text())
    assert data['state'] in ('NATIVE_C0_COMPONENT_PASS','NATIVE_C1_COMPONENT_PASS')
    stage = data.get('stage_m', -5)
    transmissivity = data.get('transmissivity_m2_per_day', 2)
    fig, axes = plt.subplots(2, 1, figsize=(8, 6), constrained_layout=True)
    x = np.arange(50) + 0.5
    for row in data['cases']:
        label = 'Uniform source: 1 mm/d' if row['name'] == 'uniform' else 'Far cell only: 0.001 m³/d'
        axes[0].plot(x, np.array(row['heads_m']) - stage, label=label)
        q = np.full(50, 0.001) if row['name'] == 'uniform' else np.r_[np.zeros(49), 0.001]
        recurrence = q.sum() / 100 + np.r_[0, np.cumsum(np.cumsum(q[:0:-1])[::-1] / transmissivity)]
        axes[0].plot(x[::5], recurrence[::5], 'o', mfc='none', color='black', ms=4)
        flow = np.r_[q.sum(), np.cumsum(q[::-1])[::-1][1:], 0]
        axes[1].plot(np.arange(51), flow, label=label)
    axes[0].set(ylabel='Head above drain stage (m)', title=data.get('profile','C0') + ': confined saturated lower layer, no STO')
    axes[0].legend()
    axes[0].text(0.02, 0.9, 'Open circles: independent finite-volume oracle', transform=axes[0].transAxes, fontsize=8)
    axes[1].set(xlabel='Distance from left boundary (m)', ylabel='Leftward face flow (m³/d)')
    for ax in axes:
        ax.grid(alpha=0.25)
        ax.set_xlim(0, 50)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    fig.savefig(args.output)
    plt.close(fig)


if __name__ == '__main__':
    main()
