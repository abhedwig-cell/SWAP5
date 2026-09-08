# F-WOF08 reallocation request versus applied-transfer contract

## Motivation

F-WOF04 correctly qualifies the WOFOST-style cap and requested daily reallocation amount. F-WOF05 safely composes stem-only transfers when the requested transfer can be fully applied. F-WOF07 shows that production organ integration additionally needs to distinguish requested transfer from biomass that is actually available after same-day organ dynamics.

Mass conservation prohibits committing storage inflow for biomass that was not withdrawn from a donor organ.

## Contract phases

### 1. Request phase

The reallocation policy computes non-negative requested transfers from:

- immutable reallocation parameters;
- DVS;
- activation caps;
- committed cumulative applied transfer.

At first activation, the cap is fixed from the relevant activation biomass according to the WOFOST parameterization.

The request phase must not authoritatively increase cumulative transferred biomass merely because a transfer was requested.

### 2. Organ availability phase

The crop organ implementation determines same-day biomass that can physically be transferred.

For leaves, the source-bound ordering from the N-aware PCSE leaf route is:

1. apply same-day leaf death to the old living cohorts;
2. age surviving cohorts;
3. determine surviving living leaf biomass available for reallocation;
4. apply reallocation to those survivors;
5. add new leaf growth.

Therefore same-day new leaf growth is not donor biomass for that day's leaf reallocation.

For stems, the PCSE state equation is equivalent to:

`WST_end = WST_start + GRST - DRST - APPLIED_ST`

so the donor availability before reallocation is the non-negative stem biomass remaining after same-day stem growth and death.

### 3. Applied-transfer phase

For each donor organ `o`:

`APPLIED_o = min(REQUESTED_o, AVAILABLE_o)`

with all quantities non-negative.

A limited transfer is a physical availability limiter, not a numerical solver failure.

Diagnostics must record both requested and applied transfer and whether availability limiting occurred.

### 4. Bookkeeping and receiving organ

Only the applied transfer updates cumulative reallocation:

`CUM_o,new = CUM_o,committed + APPLIED_o`

The unfulfilled part of a request does not consume the cap and can remain available for later days if the crop still provides donor biomass.

Receiving storage-organ inflow is calculated from applied transfers:

`STORAGE_IN = (APPLIED_LV + APPLIED_ST) * EFFICIENCY`

and conversion loss is:

`CONVERSION_LOSS = APPLIED_LV + APPLIED_ST - STORAGE_IN`

The reallocation-only dry-matter balance is therefore:

`-APPLIED_LV - APPLIED_ST + STORAGE_IN + CONVERSION_LOSS = 0`

### 5. Leaf cohort application

For surviving cohorts after leaf death with total biomass `S` and applied leaf transfer `A`, where `0 <= A <= S`:

- if `S == 0`, then `A` must be zero and no scaling is performed;
- otherwise `f = (S - A) / S`;
- every surviving cohort biomass is multiplied by `f`;
- SLA and cohort age remain unchanged;
- `A == S` is valid and gives `f == 0`.

This extends the source-bound proportional interior semantics to the equality boundary while preserving mass. It does not copy the unsafe historical strict-`<` edge.

### 6. Transaction semantics

Request state, donor-organ candidate state, cumulative applied transfer, receiver-organ state, conversion loss and diagnostics belong to one physical trial.

If the composed crop trial is rejected, none of these physical candidates become committed history.

### 7. Relationship to F-WOF04 and F-WOF05

The existing F-WOF04 reference-call remains valid and qualified for characterizing WOFOST requested transfer and for cases where `REQUESTED == APPLIED`.

F-WOF05 remains qualified in its stated stem-only scope because it accepts the normal full-application path and fails closed rather than allowing a negative stem endpoint.

A future production-capable organ-availability route should not silently modify the existing F-WOF04 reference-call. It should introduce an explicit request/apply split, or an equivalently explicit contract, and qualify that new path separately.

## Numerical contract verification

A deterministic 100,000-case random property test over caps, previous cumulative transfer, rates, donor availability and efficiency produced:

- invariant violations: `0`;
- maximum absolute reallocation balance residual: `0.0` in the tested arithmetic grouping;
- availability-limited cases: `72,432`;
- explicit equality/full-depletion edge cases: safe.

## Verdict

The architecture and conservation semantics are resolved.

Status: `QUALIFIED_MASS_CONSERVING_REALLOCATION_REQUEST_APPLY_CONTRACT`.

This is an architecture/physics contract qualification. It does not yet admit production leaf reallocation or replace the F-WOF04 API.
