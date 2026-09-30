# PPA-WU05-A3 E6 local interface-index adjudication

Date: 2026-09-30

Status: `LOCAL_RESEARCH_PASS / ICGWL_CANDIDATE_STRONGLY_SUPPORTED / NOT_YET_R1_SELECTED`

## Problem

A1 proved that exact B1.11 `MACROSTATE` uses local `icgwl` in the standard macropore internal-flux path without assigning it in that path.

A3 must determine the intended physical meaning before defining a corrected R1 reference.

## Candidate under test

`icgwl := ICpTpWaSrDm(id)`

Interpretation:

the saturated/unsaturated macropore interface index is the same compartment already constructed by `MACROSTATE` as the top compartment containing stored macropore water.

## Independent source constructions

Two source-bound constructions were compared.

### Construction A — kinematic branch

Exact reduction of `macropore.f90:1333-1342`:

scan upward from the domain bottom until the first compartment with `WaUnMpDmCp/VlMpDmCp < 1`.

This is the only branch in B1.11 that explicitly computes `icgwl`.

### Construction B — standard storage branch

Exact reduction of `macropore.f90:1369-1385`:

build the bottom-connected stored-water body from total `WaSrMpDm`; the resulting top/partially wet compartment is `ICpTpWaSrDm(id)`.

## Local profile matrix

The constructions were compared for:

- partial interface in compartment 2;
- deeper partial interface in compartment 3;
- water only in the bottom compartment;
- all compartments full;
- all compartments dry.

Result:

`Construction A == Construction B`

for every profile.

The dry edge case was explicitly checked. In the standard source algorithm `ICpTpWaSrDm` remains the bottom compartment with zero wet fraction, matching the kinematic `icgwl` construction.

## Interpretation

For physically admissible bottom-connected macropore storage profiles, the two independently implemented B1.11 constructions identify the same interface index.

This gives strong source-bound support that the undefined standard-path `icgwl` was intended to equal the already available `ICpTpWaSrDm(id)`.

## Current adjudication

Preferred R1 candidate:

`icgwl = ICpTpWaSrDm(id)`

Confidence:

`STRONG_SOURCE_AND_GEOMETRY_SUPPORT`

Not yet final because E6/E7 still need to test:

- internal-flux mass continuity across the interface;
- groundwater-level sweep;
- changing bottom-domain depth;
- exact behaviour when the interface compartment volume is near zero;
- no new discontinuity in whole-column balance.

## Next step

Use this candidate in a research-only corrected `MACROSTATE` reduction and run E7 groundwater/interface sweeps before freezing the R1 correction.


## E7 correction

E7 found one discrete edge case that narrows this result.

At an exact compartment-fill boundary, `ICpTpWaSrDm(id)` still points to the fully filled top compartment of the stored-water body, while the kinematic `icgwl` construction points one compartment higher to the first compartment that is not fully saturated.

Therefore the unconditional E6 statement `icgwl = ICpTpWaSrDm(id)` is superseded by the refined E7 rule documented in `PPA_WU05A3_E7_LOCAL_RESULT.md`.

The broader E6 conclusion remains valid: `ICpTpWaSrDm` is the correct source quantity from which the missing interface index can be deterministically derived.
