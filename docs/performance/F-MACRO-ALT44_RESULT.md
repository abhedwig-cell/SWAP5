# F-MACRO-ALT44 — Rosetta v3 reproduction and hydraulic parameter authority

Date: 2026-10-01

Status: QUALIFIED_RESEARCH_HYDRAULIC_SENSITIVITY_AUTHORITY / AUTHORS_KSAT_REPRODUCED

Canonical authority: integration/f-ci-canonical@ebea588070f7a44dbaea78169f2548c745061c48

## Purpose

Resolve the ALT43 constitutive-hydraulics blocker without silently introducing an unrelated pedotransfer model.

The NEON PF v1.1 authors explicitly use Rosetta3-derived Ksat products. ALT44 therefore tests whether the current official `rosetta-soil` implementation of Rosetta v3 reproduces the authors' published `rosetta_new_model_updates.csv` values from the same sand/silt/clay inputs.

## One-off execution

Workflow run:

    36837239148

Job:

    rosetta = SUCCESS

Installed package:

    rosetta-soil 0.3.2

Input mode:

    Rosetta v3 model code 2
    sand + silt + clay only

The one-off workflow is justified because the local execution environment cannot install the package or POST to the official Rosetta API.

## Reproduction result

Across 3008 rows with an authors Ksat target:

    median relative Ksat error = 8.16e-09
    maximum relative Ksat error = 6.68e-08

Both Rosetta `geo` output and exponentiated `log` ensemble mean reproduce the authors' Ksat values to ordinary serialization precision.

Therefore:

    AUTHORS_ROSETTA_MEAN_KSAT_REPRODUCTION = PASS

## Parameter convention

The frozen hydraulic sensitivity layer uses:

    theta_r  = Rosetta v3 ensemble mean
    theta_s  = Rosetta v3 ensemble mean
    alpha    = 10**mean(log10 alpha)
    n        = 10**mean(log10 n)
    Ksat     = 10**mean(log10 Ksat)
    K0       = 10**mean(log10 K0)
    L        = Rosetta v3 ensemble mean

The Rosetta bootstrap standard deviations for alpha/n/Ksat/K0 are retained in log10 space.

This distinction matters because the authors' `ksat_T` is the geometric mean while their later PF-table Ksat fields include depth/spatial aggregation and are not simple horizon Ksat copies.

## SWAP5 compatibility

The canonical default MvG conductivity provider uses:

    K = Ksat * Se**L * [1 - (1 - Se**(1/m))**m]**2

for the ordinary no-air-entry branch.

Therefore Rosetta's Ksat and L can be used directly for a research hydraulic sensitivity provider without substituting Rosetta K0 for the SWAP Ksat scale.

## Scope boundary

These are pedotransfer estimates, not measured site retention curves.

ALT44 qualifies them only as an authors-workflow-consistent hydraulic sensitivity layer for NEON empirical screening.

They do not become SWAP5 production hydraulic parameters and do not alter the frozen RFM physical parameter contract.

## Decision

    ROSETTA_V3_MEAN_REPRODUCTION = PASS
    FULL_VG_PARAMETER_VECTOR = AVAILABLE
    HYDRAULIC_SENSITIVITY_LAYER = AUTHORIZED
    PRODUCTION_HYDRAULIC_AUTHORITY = NOT CLAIMED
