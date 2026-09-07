# F-MQ07 Synthetic coupling contracts

Status: `PASS_SYNTHETIC_COUPLING_CONTRACTS / REAL_COUPLING_NOT_QUALIFIED`

## Scope

F-MQ07 qualifies the synthetic/testdouble parts of MultiSWAP properties P20, P21 and P22. The work is qualification-only. No SWAP production source, solver physics, numerical policy, production MultiSWAP runtime or MODFLOW coupling implementation is added or changed.

The purpose is to make the coupling invariants executable before a real production coupler exists, so later F-SI/F-MR work can be tested against a fixed behavioral contract rather than defining semantics implicitly during implementation.

## P20: tile aggregation

`coupling_contract_harness.py` represents tile fractions with exact rational arithmetic. The gate requires:

1. tile IDs are unique;
2. all fractions are positive;
3. fractions sum exactly to one;
4. every tile closes its own synthetic water balance before aggregation;
5. cell storage change equals the exact area-weighted tile storage change;
6. cell external boundary flux equals the exact area-weighted tile boundary flux;
7. the cell residual is exactly zero;
8. reordering tiles cannot change the aggregate or canonical tile-set identity.

This is the synthetic contract corresponding to invariants 13, 17 and 28. It deliberately does not assume that every tile is a SWAP column. A future runtime/coupler may combine SWAP and non-SWAP tiles provided all tile records obey the common mass-accounting contract.

## P21: predictor/corrector rollback

The synthetic coupling transaction has an externally committed checkpoint, a predictor trial and a corrector trial.

The important semantics are:

- predictor work is never an external physical commit;
- a predictor result may conceptually serve as a numerical hint, but it cannot become the physical origin of the corrector;
- the corrector is physically evaluated from the same committed checkpoint;
- a rejected predictor cannot alter committed state or committed mass;
- a rejected corrector leaves the complete committed state unchanged;
- an accepted corrector commits exactly once;
- committed water change equals the accepted corrector interface flux exactly.

The tests deliberately vary the predictor candidate while keeping the corrector unchanged. The committed endpoint must remain identical. This directly protects invariant 8: warm-start information may be reused numerically, while physical correction remains based on the right committed state.

## P22: direct coupling interface contract

The synthetic interface gate implements the sign convention required by the SWAP architecture:

`q_SWAP + q_MF = 0`

Flux conservation is a hard exact gate in the synthetic contract. It is evaluated independently from the head residual.

Head matching is represented as:

`h_SWAP - h_MF`

A qualified tolerance may be applied to that head residual. It may not be applied to the water-flux residual and cannot make a nonconservative interface pass. A test explicitly uses perfect head equality with a one-unit flux defect and requires rejection.

This separation implements invariants 12 and 13: a small qualified head residual may be acceptable; disappearing interface water is not.

## Gate evidence

Repository gate command:

`python3 tests/multiswap/run_fmq07_gate.py`

Construction-time execution of the same harness/test content produced:

- tests: 10;
- failures: 0;
- errors: 0.

This is local construction evidence, not a GitHub Actions CI claim.

The test set covers:

- exact two-tile area-weighted closure;
- tile-order independence;
- rejection of fraction gaps and overlaps;
- rejection of a nonconserving tile before aggregation;
- rejected predictor isolation;
- corrector origin independence from predictor candidate;
- complete rollback when the corrector is rejected;
- exact interface flux conservation with an accepted head residual;
- rejection of a flux defect even under perfect head equality;
- separate rejection when flux is conservative but the head residual exceeds its qualified tolerance.

## Qualification boundary

F-MQ07 does not claim:

- real SWAP/MODFLOW coupled equivalence;
- a production tile data structure;
- a production predictor/corrector implementation;
- a production coupling scheduler;
- physical response tangents;
- convergence policy for the coupled nonlinear system;
- qualified real head tolerance values;
- real coupled mass conservation over a physical coupling window.

Those final claims remain dependent on F-SI, F-MR and the canonical physical continuation seam in F-CI/F-KT.

## Architectural assessment

F-MQ07 directly exercises or protects invariants 7, 8, 10, 11, 12, 13, 17, 28 and 30. The test layer remains independent of legacy files, calendar-day assumptions and any particular Richards implementation.

## Next qualification step

After P20-P22 have a fixed synthetic contract, the next independent F-MQ step should consolidate the executable qualification surface and identify exactly which remaining properties are blocked only by the real canonical physical continuation seam versus which are blocked by the future production MultiSWAP runtime. This prevents duplicate test construction while F-CI/F-KT and F-MR continue to mature.
