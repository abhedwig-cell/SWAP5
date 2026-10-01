# SW-RIB-TOP01-E — production sign binding and admission decision

Date: 2026-10-01

Status: QUALIFIED_PRODUCTION_READINESS_DESIGN

Baseline:
`integration/f-ci-canonical@8bfff34e5bf06817f63a571282f70436cd90ede2`

## Production top-flux sign authority

Current production
`src/runtime/mod_fmr_serialized_reference_backend.f90::account_external_fluxes`
binds solver top flux as:

- `solver_top_flux < 0`: external top inflow, added to `total_in`;
- `solver_top_flux > 0`: external top outflow, added to `total_out`.

Specifically the admitted runtime uses:

`total_in += max(0,-external_top_flux)*dt`

and:

`total_out += max(0,external_top_flux)*dt`.

Therefore for the TOP01 surface control volume, when water moves from the
surface into the soil:

`D = max(0,-solver_top_flux)*dt`

for the bounded no-snow top-surface profile.

If upward soil-to-surface flux is later admitted in the same flooding profile,
it must be represented as a separate surface-control-volume inflow rather than
clamped away. TOP01 production scope should initially fail closed on that
unqualified case.

## Existing reference mass authority

`src/adapter/mod_b1_10_trial_mass.f90` already classifies signed runoff:

- runoff >= 0 -> runoff / total_out;
- runoff < 0 -> inundation / total_in.

This is compatible with composed:

`RUNOTS = O-X`.

No new fundamental mass category is required.

## Smallest production architecture

The smallest defensible candidate has three changes:

1. extend the dynamic-top typed request/provider with an optional external
   surface-water hydraulic view;
2. on strict flooding activation, return/evaluate a head-regime candidate at
   the imposed external head rather than the internally solved ponding head;
3. after the accepted soil trial, materialize the signed top-surface exchange
   from the surface control volume and publish it through the existing
   runoff/inundation mass family and a distinct coupling transfer identity.

The transfer materializer must remain outside the nonlinear solver.

## Why existing head-regime infrastructure is reusable but insufficient alone

The dynamic-top solver ABI already supports `SW_TOP_BOUNDARY_REGIME_HEAD`,
surface head, surface-face conductivity and candidate ponding.

Therefore no new fundamental solver regime is needed.

However the current provider computes its own head from atmospheric/ponding
logic. There is no typed external-head input and no post-trial external-transfer
publication. Both additions are required.

## Bounded first production profile

Admit only:

- finite external head in the same datum as local ponding head;
- strict classifier `h_ext > h_sill && h_ext > h_local`;
- zero field-surface resistance;
- no snow in the first admission;
- no macropore top-transfer composition in the first admission;
- no upward soil exfiltration while external flooding is active unless
  separately qualified;
- linear existing runoff profile outside flooding;
- exactly one accepted top transfer per outer coupling window.

This keeps the candidate narrow enough to qualify independently.

## Required admission evidence

1. external view absent => bitwise/current-behavior preservation;
2. below/equality seams => current behavior preservation;
3. strict flooding => imposed head exactly equals external head;
4. solver top flux negative under the chosen infiltration fixture;
5. surface control-volume closure;
6. rainfall offsets Ribasim supply without double booking;
7. evaporation increases Ribasim supply;
8. runoff-to-inundation direction switch;
9. rejected trial publishes no transfer;
10. same-origin replay identity;
11. simultaneous F-APP09 subsurface exchange keeps distinct transfer IDs;
12. O0/O2 identity.

## Decision

`PRODUCTION_CANDIDATE_ARCHITECTURE_READY`.

This is not production admission. It authorizes a narrow implementation work
unit derived from TOP01 with independent qualification before canonical merge.
