# F-WOF-PP01 — qualified donor/oracle mapping contract

## Purpose

This document defines the scientific boundary used to compare the independent PCSE 6.0.13
WOFOST 8.1 Spring Barley oracle with the verified SWAP 4.3.1 WOFOST81 Fortran donor.

It supersedes the earlier provisional attempt to map the complete oracle directly onto the partial
current SWAP5 crop seam. No production semantics are introduced here.

## Immutable endpoints

Oracle:
- `tests_Wofost81_PP.zip`
- SHA-256 `99a67a0e5f6bd0881b97950a2ff3fe0f387c0a9e0553f2e36197077fbc15d145`
- PCSE 6.0.13 / WOFOST 8.1
- ten Spring Barley potential-production cases
- YAML `Precision` values are authoritative and unchanged.

Fortran donor:
- `SWAP_4.3.1_WOFOST81_WORKING_FINAL_13B.zip`
- SHA-256 `4e0bf97bca7f3f8716e5bcf46a5dc9bb6b08436304b032d60adc3757491d94dc`
- historical source closeout `839c34a657c2cee202b55d9ee85253d867a3d47a`
- crop mapping `Spring_barley_301 / barley_wofost81.crp`.

The donor's own qualification named full-season independent PCSE regression as the remaining next
gate. F-WOF-PP01 closes that gate for the crop-model boundary described below.

## External-state boundary

The oracle supplies `SM=0.3` and `NAVAIL=100` each day to make water and nitrogen non-limiting.

The SWAP donor normally obtains those supplies from SWAP hydrology and Soil-N. For the independent
crop-model comparison, a qualification-only source copy replaces only those two external boundary
responses:

1. WOFOST81 actual-crop `RELTR=1.0`;
2. `NsupplySoil = NdemandSoil` immediately before the existing
   `apply_wofost81_n_runtime_supply()` call.

This does not replace any WOFOST81 crop equation. The donor still owns and executes assimilation,
partitioning, respiration, organ growth/death, leaf cohorts, crop-N demand, `RNUPTAKEMAX`,
translocation, organ-N state transitions and N balance closure.

Because daily demand remains bounded by the donor's request contract, the oracle's `NAVAIL=100` is
non-limiting for these cases.

## Weather, parameter and timing binding

The donor already carries the source-bound Spring Barley WOFOST81 parameterization, so no new
parameter reconstruction is used.

Oracle weather is supplied to the historical SWAP shell with the donor's documented units:
- `IRRAD` J m-2 d-1 -> SWAP radiation kJ m-2 d-1 by `/1000`;
- `VAP` hPa -> kPa by `/10`;
- `RAIN` cm -> mm by `*10`;
- `ET0` cm -> mm by `*10`;
- `TMIN`, `TMAX`, wind, latitude, longitude and elevation directly.

The oracle year 2025 is mapped to 2002 preserving month/day. Both are non-leap years; this avoids
unrelated historical shell date-table constraints while preserving day-of-year astronomy.

PCSE crop-start state aligns with the donor `INIT` state. PCSE state on each later day aligns with
the donor's preceding-day `POST` commit. This is an output-timing convention, not a numerical shift:
the aligned trajectories match at floating-point roundoff.

## WOFOST81-owned conformance surface

The following outputs are admitted as direct or derived crop-model observations and all pass in all
ten cases:

| Oracle output | Donor observation | Qualification status |
|---|---|---|
| DVS | WOFOST development stage | PASS |
| LAI | WOFOST actual LAI | PASS |
| NamountLV | committed WOFOST81 leaf N | PASS |
| NamountRT | committed WOFOST81 root N | PASS |
| NamountSO | committed WOFOST81 storage N | PASS |
| NamountST | committed WOFOST81 stem N | PASS |
| NuptakeTotal | cumulative WOFOST81 soil-N uptake | PASS |
| TWLV | living + dead retained leaf dry matter as PCSE TWLV | PASS |
| TWRT | root dry matter total | PASS |
| TWST | stem dry matter total | PASS |
| TWSO | storage-organ dry matter | PASS |
| TAGP | TWLV + TWST + TWSO | PASS |

The maximum absolute discrepancy anywhere on this 12-output surface is `7.276e-12` (`TAGP`), far
inside the immutable oracle precision.

## Explicit non-equivalent interface outputs

### RD

`RD` in the PCSE fixture is WOFOST root-depth state. In the donor, rooting is intentionally retained
as a SWAP-specific extension. `MOD_cropdevelopment::update_rootextension` owns SWAP `rd`/`rdpot`
and conditions extension on SWAP transpiration/root-interface state and soil rooting limits.

Direct PCSE-RD versus SWAP-rd comparison therefore compares different owners and fails in all ten
cases. This is **not** counted as a crop-model PASS and is not silently omitted.

### TRA

PCSE `TRA` is produced by the PCSE evapotranspiration route. The donor retains SWAP
hydrology/Penman-Monteith/root-extraction and feeds relative transpiration into WOFOST. There is no
donor-owned WOFOST81 crop-state `TRA` equivalent. Direct comparison to SWAP `iptra_day` fails in
all ten cases.

This is **not** counted as a crop-model PASS and is not silently omitted.

## Qualification verdict

`QUALIFIED_WOFOST81_DONOR_POTENTIAL_PRODUCTION_CROP_STATE_PASS_FULL_14_FIELD_YAML_NOT_EQUIVALENT`

Meaning:
- the translated Fortran WOFOST81 crop-production and crop-N state is independently equivalent to
  PCSE for all ten supplied cases;
- the complete 14-field YAML cannot be labeled one conformance PASS because `RD` and `TRA` cross
  separately owned SWAP interfaces;
- no tolerance was relaxed and no production code was changed to obtain the result.

## SWAP5 migration rule

Future SWAP5 WOFOST81 migration work may use the 12-output qualified donor/oracle surface as its
immutable preservation reference. SWAP5 must not be required to mimic the historical donor's
SWAP-specific `RD`/`TRA` interfaces under this crop-model qualification. Those interfaces require
their own explicit contracts and evidence.
