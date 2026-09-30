#!/usr/bin/env python3
from __future__ import annotations
import argparse
from pathlib import Path

def main():
    ap=argparse.ArgumentParser()
    ap.add_argument("--root",required=True)
    ap.add_argument("--output",required=True)
    a=ap.parse_args()
    root=Path(a.root).resolve()
    src=(root/"tests/publication/test_pub_p2e08_reference_valid_calibration_domain.f90").read_text(encoding="utf-8")

    src=src.replace(
        "program test_pub_p2e08_reference_valid_calibration_domain",
        "program test_fpe_elastic58_mode7_reference_budget",1)
    src=src.replace(
        "end program test_pub_p2e08_reference_valid_calibration_domain",
        "end program test_fpe_elastic58_mode7_reference_budget",1)

    old="k0=conductivity(1); top_flux=top_factor*k0; bottom_flux=bottom_factor*k0"
    new="k0=conductivity(1); top_flux=(-1.0_real64+top_factor)*k0; bottom_flux=0.0_real64"
    if old not in src:
        raise SystemExit("F_PE_ELASTIC58_FAIL forcing anchor")
    src=src.replace(old,new,1)

    old="req%boundary%top_mode=FSI_TOP_MODE_EXPLICIT_FLUX; req%boundary%bottom_mode=2"
    new="req%boundary%top_mode=FSI_TOP_MODE_EXPLICIT_FLUX; req%boundary%bottom_mode=7"
    if old not in src:
        raise SystemExit("F_PE_ELASTIC58_FAIL bottom-mode anchor")
    src=src.replace(old,new,1)

    # Keep bottom_flux argument structurally present but explicitly non-authoritative.
    src=src.replace(
        "req%boundary%bottom_flux=qbot; req%boundary%bottom_head=-999999.0_real64",
        "req%boundary%bottom_flux=0.0_real64; req%boundary%bottom_head=-999999.0_real64",1)

    # Rename all public qualification markers for independent authority.
    src=src.replace("PUB_P2E08_","ELASTIC58_")
    src=src.replace("PUB-P2E08","F-PE-ELASTIC58")

    Path(a.output).write_text(src,encoding="utf-8")
    print("F_PE_ELASTIC58_MATERIALIZE=PASS")

if __name__=="__main__":
    main()
