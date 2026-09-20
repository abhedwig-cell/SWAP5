# TAB-HYD functional audit closeout

Date: 2026-09-20

Status: **FUNCTIONAL_AUDIT_CLOSED / ACCELERATION CANDIDATE IDENTIFIED / NO PRODUCTION ADMISSION**

## Question

Does the existing SWAP tabulated soil-hydraulics option work correctly enough to use as the basis for a performance experiment?

## Answer

Not as one unqualified statement.

### Current public SWAP software

- Public `development`: tabulated hydraulics is deliberately dormant/non-operational.
- Public `main`: the typed schema accepts `SWSOPHY=1`, but does not provide the table state required by the solver. A 31-day Hupsel probe with only that switch changed timed out, while the analytical control completed normally.
- Current SWAP5 canonical: tabulated hydraulics is not an admitted production provider. The admitted default-MvG provider explicitly keeps `SWKIMPL=1` outside its interface authority.

Therefore the table option is **not currently a usable production feature of the typed/current software stack**.

### Legacy-input executable route

The underlying table machinery itself is viable:

- the actual TSPACK preprocessing/interpolator behaves accurately for smooth MvG data;
- 35 of 36 inspected BOFEK/Staring files satisfy the current strict table contract and show no interior monotonicity/derivative failure in the characterization grid;
- the one rejected source file, `starb4_cm.csv`, has a real theta decrease near saturation and is incompatible with the current reader contract;
- full 2002-2004 Hupsel `SWSOPHY=1, SWKIMPL=0` reproduces the analytical route extremely closely.

So the constitutive table concept is not the problem. The problems are integration, endpoint/Jacobian semantics and the legacy lookup implementation.

## Confirmed defects/findings

1. **TAB-HYD-001, table endpoint derivative mismatch.**
   The table K residual is constant outside the tabulated theta range, but legacy `dhconduc` returns `1e8` at the wet endpoint and can enter an invalid dry-side table index. A research-only zero derivative over the already-constant endpoint branches removes both failures.

2. **TAB-HYD-002, documentation-code interpolation mismatch.**
   The current guide describes PCHIP/SLATEC interpolation, while the active current-public table engine uses TSPACK tension splines. The two are behaviorally distinguishable in Hupsel, so documentation cannot be used as executable-algorithm authority.

3. **TAB-HYD-003, analytical default-MvG Ksat derivative mismatch.**
   The legacy/public analytical residual clamps K to Ksat above relative saturation `1-1e-6`, while the original implicit derivative continues differentiating the unclamped MvG branch. A research-only zero derivative over that constant Ksat branch removes the catastrophic Hupsel `SWKIMPL=1` divergence.

These findings are not yet exact-B0 correction admissions. Exact supplied SWAP 4.3.1 archive execution remains outside this workstream because the byte-authoritative source archive is not materialized here.

## Performance implication

The stock table implementation is not faster:

- dense legacy table lookup is about 8-11% slower than analytical MvG in the tested `SWKIMPL=0` Hupsel route;
- reducing row count alone does not remove that penalty.

The bottleneck is mainly the legacy interval lookup. A representation uniform in the existing transformed coordinate

`x = -ln(1-h)`

allows direct O(1) interval indexing while retaining the existing TSPACK interpolation.

Results:

- corrected `SWKIMPL=0`: direct-index table reaches approximately runtime parity with analytical MvG;
- corrected `SWKIMPL=1`: direct-index TSPACK becomes measurably faster.

For the corrected full-period Hupsel `SWKIMPL=1` benchmark:

| route | median runtime | relative to analytical |
| --- | ---: | ---: |
| analytical MvG | 1.61785 s | 1.000 |
| dense legacy TSPACK | 1.66786 s | +3.09% |
| direct TSPACK, 150 rows | 1.54259 s | -4.65% |
| direct TSPACK, 250 rows | 1.51763 s | -6.19% |

The 250-row route was faster than analytical MvG in all 12 paired benchmark rounds. Its hydrological agreement with the corrected analytical `SWKIMPL=1` route remained at about `4.3e-4 cm` maximum GWL difference and `1.55e-5 cm` GWL RMSE over 1096 daily outputs.

## Decision

The original acceleration hypothesis is **worth pursuing**, but not by switching on the existing table option as-is.

The candidate worth carrying forward is:

1. explicit typed tabulated-hydraulics provider in SWAP5;
2. direct arithmetic interval indexing on a uniform transformed-head grid;
3. existing high-fidelity cubic/TSPACK-style interpolation unless a simpler interpolator qualifies equally well;
4. derivative semantics derived from the actual residual relation, including zero derivative on constant endpoint/Ksat branches;
5. table generation and validation that enforces monotonic theta and K and rejects malformed source tables such as the current `starb4_cm.csv`.

## Next gate

Before any production implementation, qualify the candidate across a broader envelope:

- contrasting soil hydraulic parameter sets, especially coarse sand, loam and heavy clay;
- wet, intermediate and dry initial states;
- infiltration, drying, drainage and capillary-rise dominated periods;
- `SWKIMPL=0` and a scientifically admitted `SWKIMPL=1` authority;
- water balance, state trajectory, fluxes, iteration counts and CPU time;
- explicit failure tests at both table endpoints.

Only after that envelope is defined should the provider be migrated into the SWAP5 typed production architecture.
