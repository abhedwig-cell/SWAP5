#!/usr/bin/env python3
from __future__ import annotations

import importlib.util
import pathlib

import numpy as np

HERE=pathlib.Path(__file__).resolve().parent

def load(name, filename):
    spec=importlib.util.spec_from_file_location(name,HERE/filename)
    module=importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module

c2=load("c2a","analyze_lare_bc2_c2a_actual_drift_gain.py")

def require(condition, message):
    if not condition:
        raise AssertionError(message)

def main():
    for width in (2.5,5.0):
        H=120.0
        L=c2.thicknesses(H,width)
        require(len(L)==11,"expected 11 physical reduced compartments")

        # A spatially uniform mean-theta perturbation is storage-only and must
        # vanish from the primary mass-neutral shape coordinate.
        eps=2.5e-4
        dw=eps*L
        row=c2.error_coordinates(dw,H,width)
        require(abs(row["total_storage_cm"]-eps*float(np.sum(L)))<1e-14,
                "uniform perturbation total-storage mismatch")
        require(row["shape_theta_rms"]<1e-15,
                "uniform perturbation leaked into primary shape norm")
        require(abs(row["mass_neutral_weighted_residual_cm"])<1e-14,
                "uniform perturbation shape residual not mass neutral")
        require(abs(row["raw_theta_rms"]-eps)<1e-15,
                "raw-theta diagnostic mismatch")

        # Adjacent transfer with thickness weighting must conserve mass while
        # remaining visible to the shape coordinate.
        i,j=8,9
        eps2=1e-5
        dtheta=np.zeros_like(L)
        dtheta[i]=eps2
        dtheta[j]=-eps2*L[i]/L[j]
        dw2=dtheta*L
        require(abs(float(np.sum(dw2)))<1e-14,
                "adjacent transfer not mass neutral")
        row2=c2.error_coordinates(dw2,H,width)
        require(abs(row2["total_storage_cm"])<1e-14,
                "mass-neutral transfer changed total storage")
        require(row2["shape_theta_rms"]>0.0,
                "mass-neutral shape transfer not detected")
        require(abs(row2["mass_neutral_weighted_residual_cm"])<1e-14,
                "mass-neutral transfer projection residual")

        # The primary shape coordinate is invariant to adding an arbitrary
        # uniform theta offset; only total storage/raw-theta diagnostics change.
        base=np.linspace(-4e-4,5e-4,len(L))*L
        a=c2.error_coordinates(base,H,width)
        offset=3e-4*L
        b=c2.error_coordinates(base+offset,H,width)
        require(np.max(np.abs(np.asarray(a["shape_theta"])-np.asarray(b["shape_theta"])))<2e-15,
                "shape coordinate changed under uniform theta offset")
        require(abs((b["total_storage_cm"]-a["total_storage_cm"])-3e-4*float(np.sum(L)))<1e-14,
                "uniform offset total-storage separation mismatch")

    print("LARE_BC2_C2_SHAPE_METRIC_STATIC=PASS")
    return 0

if __name__=="__main__":
    raise SystemExit(main())
