# SW-RIB-SWM01 research closeout

**Date:** 2026-09-23  
**Baseline:** `integration/f-ci-canonical@a2d99ddd149ffaa422d9c422f96bd66e92c8555d`  
**Status:** **RESEARCH CLOSED, PRODUCTION ADMISSION PENDING**

## Central conclusion

For an explicit SWAP5 + Ribasim application profile, the old SWAP surface-water subsystem does not need to remain the owner of the represented surface-water store.

The qualified target split is:

- **Ribasim** owns accepted surface-water storage, level, network hydraulics, supply, allocation and system-level discharge realization.
- **SWAP5** owns the soil and drainage process physics that determine exchange with that surface water.
- **The coupler/management layer** owns soil-state-driven management policy, accepted `WLSTAR` memory, management events, cross-model feasibility and exactly-once transfer identity.

This is not equivalent to deleting everything in legacy `surfacewater.f90`. The file mixed several ownership domains. The research result is a decomposition.

## What has now been demonstrated

The evidence chain is materially complete for the ownership question:

1. **Surface-water state can be external.** Q1A-R3/R3L reproduces the frozen linear fixed-weir cases with real Ribasim as the only surface-water store and closes the direct connector mass ledger.
2. **Supply can be external.** Q1B reproduces the fixed-weir lower-level supply envelope using a Ribasim level demand plus bounded supply route.
3. **Automatic soil-state management does not belong inside the surface-water store.** Q2A preserves the exact bounded SWMAN=2 phase-selection, `WLSTAR`, rollback/replay and `DROPR` semantics as an accepted-state coupler policy.
4. **Ribasim can realize the requested managed band.** Q2B1 demonstrates bounded bidirectional management with explicit unmet deficit/surplus when capacity is insufficient.
5. **Signed drainage/infiltration remains SWAP physics.** Q3A demonstrates positive drainage and negative infiltration against a Ribasim-owned store. If Ribasim availability reduces a requested withdrawal, the coupled trial must be recomposed from accepted origins. One-sided clipping is prohibited.
6. **Transfer identities survive aggregation.** Q3B keeps lower drainage, rapid drainage, runoff, lower infiltration and top inundation scientifically distinguishable even where Ribasim uses aggregate balance endpoints.
7. **The retained legacy exchange law has been extracted.** Q4A isolates the restricted signed extended exchange law as a stateless process candidate.
8. **That process fits the existing transaction architecture.** Q4B passes the real serialized runtime binding under O0 and O2, including positive and negative transfer, exactly-once mass booking and invalid-process rollback.

## Two important non-parities

### Rating-curve semantics

Native Ribasim TabulatedRatingCurve exactness to the hard-kink legacy SWQHR1 law was falsified for the pinned release because of its interpolation semantics. The linear `BETAW=1` law can be represented in the qualified envelope by ContinuousControl plus a one-way connector, but this is not a generic nonlinear alpha/beta proof.

For coupled production there are therefore two legitimate contracts, but they must be named:

- adopt Ribasim-native hydraulic realization and accept/qualify the representation difference; or
- require a separately qualified exact legacy-law representation for the needed domain.

Full legacy numerical parity must not be claimed merely because the ownership split is valid.

### Storage geometry

Q1G falsified direct exact mapping of SWAP's piecewise-linear `STTAB` storage relation into the pinned Ribasim Basin storage-profile semantics between knots. Q1H then demonstrated a continuous-area construction with an explicitly controllable error that scales with a chosen transition width.

So `STTAB` can leave SWAP-owned dynamic state in a coupled profile, but production still has to freeze an accepted geometry representation. Exact direct relabelling is not allowed.

## Coupled-mode retirement disposition

Under the explicit external-Ribasim profile, the following legacy responsibilities are **research-qualified retirement candidates** from SWAP ownership:

- conserved secondary surface-water store `SWST` and derived simulated `WLS`;
- local surface-water balance realization;
- local actual supply/discharge realization;
- automatic target selection inside the surface-water component;
- `WLSTAR` storage inside that component, once transferred to accepted coupler policy state;
- legacy surface-water oscillation/history treatment as if it were physical state;
- file/calendar/container plumbing after typed mapping.

The following are **not retirement candidates as physics**:

- signed drainage/infiltration response;
- multilevel drainage geometry/resistance and distribution;
- runoff/top-boundary process physics;
- rapid/macropore drainage generation;
- the independently qualified standalone F-CI52 fixed-weir profile.

The operative architecture rule remains:

```text
for one physical surface-water store:

SWAP_FIXED_WEIR_STATE_OWNER XOR EXTERNAL_RIBASIM_STATE_OWNER
```

## Current authority boundary

This closes the **research ownership/decomposition question**. It does **not** authorize a production merge that simply deletes `surfacewater.f90`, and it does not admit a new Ribasim-coupled production profile yet.

The next authority step is deliberately narrower: production-admit the coupled application profile on current canonical, including owner-mode fail-closed behavior, external accepted surface-water-head binding, Q4B-qualified signed exchange, chosen storage-geometry representation, restart/retry and end-to-end mass closure.

Until that gate exists, `surfacewater.f90` remains a legacy source authority and whole-file deletion remains unauthorized.
