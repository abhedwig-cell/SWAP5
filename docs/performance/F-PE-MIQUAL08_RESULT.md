# F-PE-MIQUAL08 result — serialized dynamic reference-workload acquisition

Date: 2026-10-01

Status:

`MIQUAL08_NO_EXISTING_DYNAMIC_ELIGIBLE_REFERENCE`

Canonical authority:

`integration/f-ci-canonical@412592b874111f35404171f223d3f2518bcad32e`

## Search result

The repository-backed serialized test inventory was inspected for an existing dynamic Reference Richards workload compatible with the bounded MIQUAL06 manager envelope.

No such workload exists.

## Candidate assessment

### FMR44R prescribed-qbot runtime

This is the nearest relevant existing reference authority.

Its equilibrium mode-2 case is serialized Reference Richards and production-shaped, but it is steady rather than dynamic.

Its positive-bottom-inflow case is genuinely dynamic and already qualified, but it requires:

- prescribed nonzero qbot;
- Richards temporal-history continuation;
- model-certificate temporal acceptance.

Those semantics are outside the current MIQUAL06 manager envelope, which intentionally permits only qbot=0 and excludes the temporal-history side service.

Therefore FMR44R dynamic inflow is not directly eligible for MIQUAL07-style timing without a separate manager qualification.

### FKT22 serialized trajectory runtime

The underlying hydraulic configuration is Reference Richards and optional physical processes are off.

However the qualified workload uses:

- prescribed bottom flux;
- accepted-trajectory direction service when enabled.

The current manager envelope excludes both nonzero qbot and active trajectory-direction side services.

The default-off equilibrium case is not a nontrivial dynamic benchmark.

### ROSS12 serialized production wiring

This is dynamic and production-shaped, but its solver route is RossFast with a model-certificate contract.

RossFast is explicitly outside the MIQUAL06 manager seam.

### Other FMR serialized tests

The remaining FMR serialized tests are receipt/process/restart or optional-process tests rather than an eligible dynamic base-Richards benchmark.

## Classification

No existing repository fixture satisfies all of:

- serialized Reference Richards;
- nontrivial dynamic physical evolution;
- existing independent qualification;
- MIQUAL06 manager eligibility.

Therefore:

`MIQUAL08_NO_EXISTING_DYNAMIC_ELIGIBLE_REFERENCE`.

## Interpretation

This is a genuine benchmark-authority blocker, not a manager physics failure.

The current manager has strong single-column physical qualification and a qualified serialized runtime seam, but the repository does not yet contain an independently qualified dynamic serialized reference workload inside that seam's intentionally narrow envelope.

The closest unbiased successor authority is FMR44R positive prescribed-qbot inflow.

That case is strategically preferable to inventing a new top-flux benchmark because it is:

- already repository-qualified;
- transactionally production-shaped;
- dynamic;
- directly relevant to groundwater coupling.

## Consequence

Open a targeted successor:

`F-PE-MIQUAL09 — prescribed-qbot / temporal-history manager compatibility`.

The goal should be to determine whether the moving-interface manager can safely compose with the existing FMR44R positive-qbot reference contract.

Do not broaden to arbitrary optional processes.

If qbot/temporal-history composition proves incompatible, preserve MIQUAL06 as the bounded production seam and treat dynamic end-to-end benchmarking as blocked until a new independently qualified base workload exists.

## Production boundary

No production-default change.

`LEGACY_NUMERICS` remains production default.
