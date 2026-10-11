# F-MIG431-LOW03-A application binding contract

Status: persisted pre-implementation design for the sole issued LOW03-A branch. This document does not establish implementation, qualification or canonical admission.

## Bounded application profile

LOW03-A admits only ordinary, non-groundwater-owned SWBOTB=3 with `SwBotb3Impl=1`, Reference Richards `SWKIMPL=0`, `SHAPE_3=1`, homogeneous hydraulic material, bare/non-macropore process composition and the already admitted LOW03-P0 typed mode-3 boundary. Explicit mode 3 remains outside this unit.

The application config owns one immutable typed Cauchy control. It never interprets an external MODFLOW datum and never owns groundwater storage or a groundwater ledger. The control contains:

- head source: DATE3/HAQUIF table or legacy sinusoid;
- canonical-to-t1900 origin mapping;
- for a sinusoid, an explicit strictly increasing calendar-year-start table;
- `AQAVE`, `AQAMP`, `AQTMAX`, `AQPER` for the sinusoid;
- optional independent DATE4/QBOT4 table;
- `RIMLAY` in days;
- the legacy vertical-resistance switch represented as `include_half_cell`: true means denominator `d/Kb + RIMLAY`, false means denominator `RIMLAY`.

Raw SWP/BBC parsing is not part of the adapter. The serialized forcing receives the already typed immutable control.

## Proposal head versus trial Q4

The application must preserve the two distinct B1.11 clocks.

At the canonical subinterval selector, before the transaction retry loop, the control resolves one immutable proposal head:

- DATE3: sample at `legacy_origin + (original_target_t1 - canonical_origin)`;
- sinusoid: locate the calendar year containing the proposal start, use `t = proposal_start_t1900 - year_start_t1900`, then
  `Haq = AQAVE + AQAMP*cos(2*pi/AQPER*(t-AQTMAX))`.

The resulting proposal carrier records `t0`, `original_t1`, the sampled/phase time and the external total aquifer head. Attempt-context capture/restore preserves that carrier. Full, half and shortened retry solves may use it only while their interval lies inside the proposal window.

Q4 is deliberately not stored in that proposal carrier. Immediately before each individual solver call, the control samples DATE4/QBOT4 at that solve's actual trial endpoint:
`legacy_origin + (trial_t1 - canonical_origin)`.
The sampled Q4 is copied once into `request%boundary%bottom_flux` and stays immutable for that solve. Therefore a shortened retry changes Q4 while retaining the proposal Haq. The first half and second half of a sibling trajectory may also have different Q4 samples because they are separate solves.

## Typed binding

For an admitted trial the serialized Reference backend binds exactly:

```text
request.boundary.bottom_mode                     = 3
request.boundary.bottom_head                     = frozen proposal Haq [cm total head]
request.boundary.bottom_flux                     = current-trial Q4 [cm/day, upward positive]
request.boundary.bottom_external_resistance_days = RIMLAY [day]
request.boundary.bottom_include_half_cell         = include_half_cell
```

LOW03-P0 remains the sole solver law:
`qbot = (Haq - (hN + zN)) / (d/Kb + RIMLAY) + Q4`,
or denominator `RIMLAY` when half-cell resistance is disabled.

No solver residual, Jacobian, common boundary type, public C ABI, transaction policy, ledger owner or restart schema changes are authorized.

## Input law and fail-closed domain

All scalar and table inputs must be finite. DATE3 and DATE4 are independent axes. Each supplied table must be non-empty, consistently dimensioned and strictly increasing. AFGEN semantics are exact-knot linear interpolation with constant endpoint extension.

Bounds are source-bound:

- resolved or tabulated Haq: [-10000, 1000] cm total head;
- `RIMLAY`: [0, 100000] day;
- Q4: [-100, 100] cm/day;
- `AQAVE`: [-10000, 1000] cm;
- `AQAMP`: [0, 1000] cm;
- `AQTMAX`: [0, 366] day;
- `AQPER`: [0, 366] day at input, but LOW03-A rejects `AQPER=0` because evaluation is singular.

A sinusoid whose evaluated Haq leaves [-10000,1000] fails; it is never clipped. `RIMLAY=0` is admissible only with half-cell resistance enabled; without the half-cell, `RIMLAY` must be strictly positive. Missing or non-covering proposal history, nonfinite time conversion, unsupported Reference profile, RossFast, macropores, `SWKIMPL=1`, sensitivity requests, groundwater ownership, mixed application profiles and explicit `SwBotb3Impl=0` fail closed.

## Transaction, mass and restart ownership

The proposal carrier is worker-local attempt context, not committed hydrologic state. Rejected trials restore it from the transaction checkpoint. Accepted internal progress creates a new proposal from the new private accepted cursor. External state is published only when the requested canonical interval completes.

The solver result's physical `bottom_flux` already contains Cauchy exchange plus Q4. Existing `account_external_fluxes` books that total physical flux once, and bottom-interface publication uses the same solver flux. LOW03-A must not add a separate Q4 mass term.

Restart remains Restart v1. Only committed state/history is serialized. Continuation creates a fresh backend and reattaches the same immutable LOW03-A configuration. If the numerical continuation layout requires proposal/temporal history and that history is absent, continuation fails closed rather than inventing it.

## Production application admission shape

A production tile explicitly selects an `ordinary_implicit_cauchy` owner. Such a tile must have mode 3, Reference SWKIMPL0, no groundwater ledger/datum, no competing legacy bottom control, no direct-retention owner and a homogeneous admitted material profile. A configuration cannot mix this owner with ordinary mode5, groundwater-owned mode5, prescribed-qbot, free drainage or another application ownership profile in the same bootstrap instance.

The existing admitted modes and owners remain unchanged.

## Qualification obligations

The qualification postimage must demonstrate:

1. exact carrier hashes plus DATE3, sine/calendar, DATE4, knots/endpoints and independent axes;
2. fixed proposal head with Q4 resampled at actual full/half/retry endpoints;
3. reject/replay, accepted private progress and external rollback;
4. fresh-backend Restart-v1 continuation with the same immutable config and changed forcing;
5. A/B/A isolation;
6. independently recomputed compartment and whole-profile mass closure and equality between accepted physical qbot amount and transaction bottom exchange;
7. no second Q4 accounting term;
8. fail-closed domain and unsupported-profile matrix;
9. preservation of admitted 2/internal -2, 4, ordinary and groundwater-owned 5, 6 and 7, LOW03-P0 and its accepted DEP01 semantic successor.

The claim ceiling remains ordinary implicit mode 3 only. SWBOTB=1 is parked, explicit mode 3 remains open, and mode 8 remains open.
