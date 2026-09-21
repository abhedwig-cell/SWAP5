from __future__ import annotations

import math
import os
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "tests" / "research"))

from test_gc_dummy_swap_dsw01_live_modflow import run_case, require
from test_gc_dummy_swap_dsw08_finite_resistance import (
    H0,
    S_DUMMY,
    S_MF,
    RAIN,
    DT,
    closed_form,
)

STORAGE_VALUES=(0.02,0.20,0.80)
CONDUCTANCES=(0.001,0.1,1000.0)
MASS_TOL=1.0e-12
HEAD_TOL=1.0e-10


def main()->None:
    libmf6=Path(os.environ["LIBMF6"]).resolve()
    require(libmf6.is_file(),"missing libmf6")

    storage_heads=[]
    for storage in STORAGE_VALUES:
        result=run_case(
            libmf6,
            f"dsw18_storage_{storage:g}",
            hcof_m2_per_day=0.0,
            rhs_m3_per_day=-RAIN,
            sy=storage,
            newton=False,
        )
        require(bool(result["converged"]),f"S={storage}: {result}")
        head=float(result["head_m"])
        expected=H0+RAIN*DT/storage
        mass=storage*(head-H0)
        require(math.isclose(head,expected,rel_tol=0.0,abs_tol=HEAD_TOL),f"S={storage} head")
        require(math.isclose(mass,RAIN*DT,rel_tol=0.0,abs_tol=MASS_TOL),f"S={storage} mass")
        storage_heads.append(head)
        print(f"GC_DSW18_STORAGE_S_{storage:g}_HEAD_M={head:.17g}")
        print(f"GC_DSW18_STORAGE_S_{storage:g}_HEAD_RISE_M={head-H0:.17g}")

    for prev,current in zip(storage_heads[:-1],storage_heads[1:],strict=True):
        require(current < prev,f"head rise did not decrease with storage: {storage_heads}")

    gaps=[]
    mf_heads=[]
    dummy_heads=[]
    for conductance in CONDUCTANCES:
        h_dummy,h_mf_expected,q_expected,hcof,rhs=closed_form(conductance)
        result=run_case(
            libmf6,
            f"dsw18_qlink_{conductance:g}",
            hcof_m2_per_day=hcof,
            rhs_m3_per_day=rhs,
            sy=S_MF,
            newton=False,
        )
        require(bool(result["converged"]),f"C={conductance}: {result}")
        h_mf=float(result["head_m"])
        a=S_DUMMY/DT
        h_dummy_live=(a*H0+RAIN+conductance*h_mf)/(a+conductance)
        q_live=conductance*(h_dummy_live-h_mf)
        total_storage=(
            S_DUMMY*(h_dummy_live-H0)+S_MF*(h_mf-H0)
        )
        require(math.isclose(h_mf,h_mf_expected,rel_tol=0.0,abs_tol=1.0e-8),f"C={conductance} mf head")
        require(math.isclose(h_dummy_live,h_dummy,rel_tol=0.0,abs_tol=1.0e-8),f"C={conductance} dummy head")
        require(math.isclose(q_live,q_expected,rel_tol=0.0,abs_tol=1.0e-10),f"C={conductance} q")
        require(math.isclose(total_storage,RAIN*DT,rel_tol=0.0,abs_tol=MASS_TOL),f"C={conductance} mass")
        gap=abs(h_dummy_live-h_mf)
        gaps.append(gap); mf_heads.append(h_mf); dummy_heads.append(h_dummy_live)
        print(f"GC_DSW18_QLINK_C_{conductance:g}_H_DUMMY_M={h_dummy_live:.17g}")
        print(f"GC_DSW18_QLINK_C_{conductance:g}_H_MF_M={h_mf:.17g}")
        print(f"GC_DSW18_QLINK_C_{conductance:g}_HEAD_GAP_M={gap:.17g}")

    for prev,current in zip(gaps[:-1],gaps[1:],strict=True):
        require(current < prev,f"q-link gap did not decrease with conductance: {gaps}")
    require(abs(mf_heads[-1]-8.05)<1.0e-5,"large-C MODFLOW head")
    require(abs(dummy_heads[-1]-8.05)<1.0e-5,"large-C dummy head")

    # Distinct limiting signatures: increasing storage suppresses motion of one
    # shared head; increasing q-link conductance collapses two physical heads
    # toward the combined-storage head. These are not interchangeable.
    require(
        abs(storage_heads[-1]-H0) < abs(storage_heads[1]-H0),
        "large storage did not suppress shared-head response",
    )
    require(
        gaps[-1] < 1.0e-5,
        "large conductance did not collapse the two-head q-link",
    )
    require(
        not math.isclose(storage_heads[-1],mf_heads[-1],rel_tol=0.0,abs_tol=1.0e-3),
        "storage and q-link limits became numerically indistinguishable in the chosen controls",
    )

    print("GC_DSW18_STORAGE_HEAD_RISE_MONOTONE=PASS")
    print("GC_DSW18_STORAGE_MASS=PASS")
    print("GC_DSW18_QLINK_GAP_MONOTONE=PASS")
    print("GC_DSW18_QLINK_TOTAL_MASS=PASS")
    print("GC_DSW18_DISTINCT_LIMIT_SIGNATURES=PASS")
    print("GC_DSW18_LIVE_GATE=PASS")


if __name__=="__main__":
    main()
