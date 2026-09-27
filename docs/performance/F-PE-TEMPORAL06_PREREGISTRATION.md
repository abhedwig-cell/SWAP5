# F-PE-TEMPORAL06 — production-shaped c=0.65 coupling qualification

Date: 2026-09-26

Status: `PREREGISTERED_RESEARCH`

Parent: `F-PE-TEMPORAL05` / PR #649

Parent head: `46fe4e76bfca1c7a840360d6085b0fb9045dff0f`

## Trigger

TEMPORAL05 blind validation froze and qualified:

`budget = max(1e-5 cm, 0.65 * dt * ||h_dot_previous||_inf)`

on difficult dynamic-history single-corrector points.

The selected policy:

- preserved the fixed oracle-error envelope;
- reduced retry incidence versus c=0.50;
- passed blind holdout;
- showed only modest whole-matrix median runtime gain because many holdout points retained the same retry path.

## Purpose

Determine whether the frozen c=0.65 policy remains correct and useful under production-shaped repeated same-origin corrector sequences and MODFLOW-facing response use.

Research-only. No production temporal-policy source change in P0-P1.

## Comparators

- CURRENT_FIXED: fixed 1e-5 cm budget;
- HIST_HALF: c=0.50;
- SELECTED: c=0.65.

## P0 — repeated same-origin corrector sequences

Use all six difficult dynamic-origin families and both +/-10% accepted history directions.

For each origin execute repeated correctors from the same captured origin, discarding every candidate.

Sequence block:

1. origin +0.001 cm;
2. origin +0.01 cm;
3. origin -0.001 cm;
4. origin -0.01 cm;
5. origin +0.001 cm;
6. origin -0.001 cm;
7. origin +0.01 cm;
8. origin -0.01 cm.

Repeat the block eight times for 64 corrector requests.

Enable the existing exact same-origin tangent cache with its admitted head-limit/age controls so the sequence exercises production-shaped A1 reuse as well as temporal acceptance.

## P0 measurements

- completed requests;
- temporal and solver rejection counts;
- transaction retries;
- tangent fresh/reuse counts;
- q checksum;
- tangent checksum;
- total and per-corrector runtime;
- deterministic repetition.

Where both c=0.50 and c=0.65 complete, the repeated-sequence responses must remain within a preregistered bounded overlap envelope: relative q difference <= 1% and relative tangent difference <= 1%. Bit identity is not required because the policies may accept different exact substep trajectories.

CURRENT_FIXED is allowed to fail; failures are part of the current-policy baseline.

## P1 — MODFLOW-facing response qualification

If c=0.65 passes P0:

- use the same accepted q/tangent responses to construct the MODFLOW-facing linear response terms;
- verify sign, units, reference head and response identity against c=0.50 on overlapping successful requests;
- compare aggregate coupled response over the sequence;
- preserve exact mass/candidate ownership.

## P2 — end-to-end runtime interpretation

Only after P0-P1 may the policy advance toward admission.

Report:

- runtime gain versus c=0.50;
- completion gain versus CURRENT_FIXED;
- retry reduction;
- whether the gain survives tangent reuse and realistic changing corrector heads.

## Stop conditions

Stop without admission if:

- any new solver rejection appears;
- q/tangent or MODFLOW response semantics drift on overlapping successful requests;
- candidate/state ownership changes;
- runtime gain disappears under the repeated sequence.

No production temporal-policy change is allowed in TEMPORAL06.