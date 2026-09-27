# F-PE-DIR01 repair target 01 — move-based accepted trajectory ownership

Date: 2026-09-26

Status: `PREREGISTERED_REPAIR_TARGET`

Evidence authority:
- PROFILE04 bottom-head directional increment: approximately 86-88%;
- DIR01 heap attribution: +32 malloc, +4 calloc and +36 free per application interval;
- DIR01 callsite attribution shows repeated vector allocation in:
  - `build_trajectory_step_request`;
  - `solve_with_accepted_step_direction`;
  - `stage_trajectory_step_result`;
  - `begin_or_continue_trajectory`;
  - accepted-trajectory publication;
  - transaction attempt-context capture/restore.

## Selected first repair

Optimize only the local accepted-step ownership chain:

`soil_water_accepted_step_direction_result_t -> pending trajectory -> accepted trajectory`

Replace value-copy ownership transfer with move semantics where exact ownership is already single-use.

The first repair must not alter transaction attempt-context semantics.

## Why this target first

The selected layer:
- is exercised three times per full-half application interval;
- allocates two outgoing direction vectors per accepted directional solve;
- allocates/copies those vectors again into pending trajectory state;
- copies pending vectors again into accepted trajectory state;
- does not own physical state, mass accounting or rollback policy.

It is therefore a narrower and lower-risk target than changing transaction rollback ownership.

## Required preservation

The repair must preserve:
- identical physical solve and candidate;
- identical accepted bottom-exchange derivative;
- identical final pressure-head and water-content direction vectors;
- identical accepted-step count;
- identical generation/provenance;
- zero additional nonlinear solves;
- default non-directional path behavior;
- fail-closed behavior for unavailable directional results.

## Admission evidence

Require:
1. heap allocation reduction on DIR01 bottom-head fixture;
2. stable paired runtime improvement beyond CI noise;
3. existing directional qualification and production preservation gates green.

If this local move-based repair does not materially reduce runtime, do not broaden it implicitly. Reassess the remaining heap attribution before selecting a second repair target.
