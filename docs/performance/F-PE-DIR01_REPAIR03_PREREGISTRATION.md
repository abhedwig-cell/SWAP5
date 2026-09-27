# F-PE-DIR01 repair target 03 — reusable incoming directional request workspace

Date: 2026-09-26

Status: `PREREGISTERED_EXPERIMENT_ONLY`

Evidence authority:
- PROFILE04: bottom-head directional adds approximately 86-88% over Reference;
- DIR01 post-Repair01 heap map: directional adds 26 malloc, 4 calloc and 30 free per application interval;
- Repair02 transaction-core shortcut is rejected because generic transaction preservation fails;
- `build_trajectory_step_request` remains responsible for 6 directional-only allocations per application interval, two vectors for each full/half/half internal step.

## Exact hypothesis

The incoming pressure-head and water-content direction vectors are worker-local numerical scratch.

Today `build_trajectory_step_request` allocates and copies both vectors for every accepted-step directional request, even though:
- shape is stable for a worker/template;
- the trajectory state already owns the authoritative input vectors;
- the request is consumed synchronously by one directional solve;
- request vectors do not participate in physical state ownership or mass accounting.

A reusable worker-local request workspace may therefore remove repeated heap allocation while preserving value semantics.

## Experiment boundary

Before any production edit:
1. build a test-local backend variant with a persistent directional request scratch object;
2. reuse its incoming pressure-head and water-content allocatables when shape is unchanged;
3. overwrite every element before each solve;
4. preserve optional source/sink absence semantics exactly;
5. do not alter transaction attempt-context or accepted-trajectory state ownership.

## Required preservation

Require exact agreement for:
- physical checksum;
- accepted bottom-exchange derivative;
- accepted pressure-head/water-content directions where exposed;
- accepted-step count;
- backsolve count;
- nonlinear/Jacobian/linear diagnostics;
- transaction status, retry and mass behavior;
- default non-directional route.

## Admission rule

Production changes are allowed only if:
- the experiment removes the predicted request allocations;
- paired runtime improvement is stable beyond noise;
- generic transaction and directional preservation gates pass.

If a persistent request workspace requires broad ABI changes or hidden state coupling, reject this repair and move to another local target.
