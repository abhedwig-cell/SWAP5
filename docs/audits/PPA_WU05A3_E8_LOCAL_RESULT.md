# PPA-WU05-A3 E8 local reject/retry result

Date: 2026-09-30

Status: `LOCAL_RESEARCH_PASS / TRANSACTIONAL_MEMORY_ISOLATION_SUPPORTED / NOT_YET_FULL_PHYSICS_QUALIFIED`

## Purpose

Test the combined physical-history state surface under an intentionally rejected macropore trial.

Unlike the earlier A2 structural DTO tests, this E8 harness is source-shaped: one trial mutates all seven A1 continuation-state groups in ways representing the classes of mutations observed in B1.11 geometry, storage and sorptivity history.

## State groups exercised

The trial changes:

- `ICpBtDm`;
- `SorpDmCp`;
- `ThtSrpRefDmCp`;
- `TimAbsCumDmCp`;
- `VlMpDmCp`;
- `WaUnMpDmCp`;
- `VlMpDyCp`.

## Experiment

1. construct one accepted state;
2. execute a clean trial and retain its candidate;
3. execute the same trial again and reject/discard that candidate;
4. execute a retry from the original accepted state;
5. compare retry candidate with the clean candidate.

## Result

- all seven semantic state groups changed in the candidate;
- the accepted state remained unchanged after the rejected attempt;
- retry candidate was exactly equal to the clean candidate;
- no rejected-history value was required to reproduce the clean result.

Verdict:

`PASS_REJECTED_MACROPORE_HISTORY_DOES_NOT_SURVIVE_RETRY`.

## Interpretation

This is the first combined A3 result that exercises sorptivity memory, geometry/history and water storage together under reject/retry semantics.

It supports H4 and the A2 ownership model:

- accepted state is authoritative;
- trial state is disposable;
- retry begins from accepted history;
- all seven continuation fields must move atomically as one candidate state.

## Bounds

This is still a reduced research harness. It does not yet execute the full R1/R2 macropore rate equations or coupled Richards solver.

## Next step

Build a small R1 `MACROSTATE` bookkeeping kernel using the refined E7 interface rule and verify internal vertical-flux reconstruction and storage identities across moving interface states.
