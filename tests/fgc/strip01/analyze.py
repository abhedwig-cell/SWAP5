"""Reproduce figures and summary from real standalone MODFLOW results."""
import argparse
import hashlib
import json
from pathlib import Path
import numpy as np
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt


def main():
    p=argparse.ArgumentParser()
    p.add_argument("--results",type=Path,required=True)
    a=p.parse_args()
    j=json.loads((a.results/"standalone_result.json").read_text())
    fig,ax=plt.subplots(figsize=(7,4))
    for r in j["steady"]:
        if r["n"]==50:
            ax.plot(np.arange(50)+.5,r["heads_m"],label=f'K={r["k"]} m/d')
    ax.set(xlabel="Distance from drain edge (m)",ylabel="Head (m relative to land)",
           title="MODFLOW6 steady strip, R = 1 mm/d")
    ax.legend(); ax.grid(alpha=.2); fig.tight_layout()
    fig.savefig(a.results/"steady_profiles.svg"); plt.close(fig)
    fig,ax=plt.subplots(figsize=(7,4))
    ax.plot(np.arange(50)+.5,np.full(50,-3.),label="initial")
    for day in [1,5,20,60,120]:
        r=min(j["drain_down"],key=lambda r:abs(r["day"]-day))
        ax.plot(np.arange(50)+.5,r["heads_m"],label=f'{r["day"]:g} d')
    ax.set(xlabel="Distance from drain edge (m)",ylabel="Head (m relative to land)",
           title="MODFLOW6 drain-down, no recharge or ET")
    ax.legend(); ax.grid(alpha=.2); fig.tight_layout()
    fig.savefig(a.results/"drain_down_profiles.svg"); plt.close(fig)
    fig,ax=plt.subplots(figsize=(7,4))
    t=[r["day"] for r in j["drain_down"]]
    ax.plot(t,[70-r["storage_m3"] for r in j["drain_down"]],label="Storage loss")
    ax.plot(t,[r["cumulative_drain_m3"] for r in j["drain_down"]],"--",label="Cumulative drain")
    ax.set(xlabel="Time (d)",ylabel="Water volume per 1 m strip width (m3)",
           title="Independent storage reconstruction versus native DRN budget")
    ax.legend(); ax.grid(alpha=.2); fig.tight_layout()
    fig.savefig(a.results/"drain_down_balance.svg"); plt.close(fig)
    manifest={str(path.relative_to(a.results)):hashlib.sha256(path.read_bytes()).hexdigest()
              for path in sorted(a.results.rglob("*")) if path.is_file() and
              path.name!="manifest.json"}
    (a.results/"manifest.json").write_text(json.dumps(manifest,indent=2)+"\n")
    print("STRIP01_NATIVE_FIGURES_AND_HASHES=PASS")


if __name__=="__main__":
    main()
