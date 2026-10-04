"""Plot persisted C2D native head and flux profiles with mass ledgers."""
import json
from pathlib import Path

import matplotlib.pyplot as plt
import numpy as np

ROOT = Path(__file__).resolve().parents[3]
BASE = ROOT / "integration/f-gc/strip01/results/c2d-local"

def load(name):
    return json.loads((BASE / name / "result.json").read_text())

transparent = load("transparent_first")
finite = load("finite_resistance_first")
zero = load("zero_first")
cases = {"near-zero resistance": transparent, "finite resistance": finite}
x = np.arange(1, 51)
face_x = np.arange(1, 50) + 0.5
fig, ax = plt.subplots(2, 2, figsize=(12, 8), constrained_layout=True)

for label, data in cases.items():
    ax[0,0].plot(x, data["rows"][79]["head_m"], label=f"{label}, pulse end")
    ax[0,0].plot(x, data["rows"][-1]["head_m"], linestyle="--", label=f"{label}, recession end")
ax[0,0].plot(x, zero["rows"][0]["head_m"], color="black", linewidth=1, label="initial equilibrium")
ax[0,0].set(title="MODFLOW6 head profile", xlabel="Cell from drain (1 m cells)", ylabel="Head (m)")
ax[0,0].legend(fontsize=8, ncol=2)

for label, data in cases.items():
    for idx, step, style in ((1,79,"-"),(2,-1,"--")):
        ax[0,1].plot(x, data["rows"][step]["interface_flux_m3_per_day"], linestyle=style,
                    label=f"{label}, {'pulse end' if step==79 else 'recession end'}")
ax[0,1].axhline(0,color="black",linewidth=.6)
ax[0,1].set(title="Dummy-SWAP outward interface flux", xlabel="Column/cell", ylabel="m³/day per 1 m²")
ax[0,1].legend(fontsize=8)

for label, data in cases.items():
    for step, style in ((79,"-"),(-1,"--")):
        ax[1,0].plot(face_x, data["rows"][step]["native_modflow_lateral_face_flow_right_to_left_m3_per_day"],
                     linestyle=style, label=f"{label}, {'pulse end' if step==79 else 'recession end'}")
ax[1,0].axhline(0,color="black",linewidth=.6)
ax[1,0].set(title="Native MODFLOW6 lateral face flow", xlabel="Face between cells", ylabel="Right to left (m³/day)")
ax[1,0].legend(fontsize=8)

rows=transparent["rows"]
time=np.array([r["time_day"] for r in rows])
for key,label in (("input_m3","input"),("dummy_storage_change_m3","Dummy-SWAP storage"),
                  ("modflow_storage_change_m3","MODFLOW storage"),("drain_outflow_m3","DRN outflow")):
    ax[1,1].plot(time,[r["cumulative"][key] for r in rows],label=label)
ax[1,1].set(title="Cumulative external balance and owned storage", xlabel="Time (day)", ylabel="Cumulative volume (m³)")
ax[1,1].legend(fontsize=8)

fig.suptitle("F-GC-STRIP01 C2D, 50-column Dummy-SWAP / native MODFLOW6")
target=BASE/"profiles.svg"
fig.savefig(target,format="svg")
print(target)
