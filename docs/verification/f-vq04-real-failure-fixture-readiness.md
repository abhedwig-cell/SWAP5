# F-VQ04 - Real B1.10 terminal-failure fixture readiness

F-VQ04 is qualification-only. It does not alter production source, SWAP physics, solver tolerances or retry policy.

## Exact basis

- oracle: B1.10
- F-CI13 source: `538d51df4be3780a5bb092767304749dfc800899`
- F-CI13 qualification commit: `f56c5fe7cdbca36c3403fcd027c5998b0c7578f4`
- canonical F-CI13 run/job: `34104845258` / `101687946143`
- F-VQ03 final head: `0956a2f4b4a3a9b2318a1254b2e972f7138c5182`
- B1.10 source manifest: `2dfc004f1bae3fc249f384d4f947a07ed4627e83e251ce6557d03092f0b4d1b1`

## Why this unit is fail-closed

F-CI13 qualified the source-bound status seam and rollback semantics with a deterministic legacy testdouble. It explicitly did not force a real Hupsel/B1.10 hydrological case into persistent Richards nonconvergence at minimum timestep.

A real full-B1.10 route exists in `tests/fci/run_fci07_full_b1_10_gate.sh`, but it requires three external inputs: an exact reconstructed B1.10 source tree, a TTUTIL source root and a Hupsel qualification case. Earlier F-CI evidence records successful exact B1.10/Hupsel physical runs, but those external source/case trees were not persisted as canonical Git content. The canonical F-CI11 and F-CI13 workflow runs expose no downloadable artifacts containing them.

Therefore F-VQ04 must not synthesize or substitute these inputs. In particular, an arbitrary local SWAP archive is not an admissible replacement for the canonical B0/B1.10 provenance chain.

## Admission contract

`integration/f-vq/F-VQ04_REAL_FAILURE_FIXTURE_REQUIREMENTS.json` defines the prerequisites. `tools/vq/cases/fvq04-real-failure-fixture-candidate.json` records the current state as `BLOCKED_MISSING_EXTERNAL_EXECUTION_INPUTS`.

Promotion to a real terminal-failure physics qualification requires all of the following:

1. Exact B1.10 source identity, verified against the canonical 63-member manifest or reconstructed from the canonical B0 archive.
2. TTUTIL with immutable source provenance sufficient to reproduce the full build.
3. The immutable Hupsel 2002-2004 case with a complete input manifest.
4. A real F-CI13 canonical-worker execution that naturally reaches persistent Richards nonconvergence at minimum dt without changing production source, solver tolerances, retry policy or the physical case merely to force failure.
5. Observed retryable status, restoration of the failed trial state, invalid trial mass and exclusion of the rejected trial from committed accounting.
6. Reproduction at least twice. O0/O2 terminal timing identity is deliberately not required because no such numerical equivalence policy is qualified.
7. A persisted execution-evidence file whose SHA-256 matches the admission record.

The admission gate rejects a metadata-only `QUALIFIED` claim, a testdouble substituted for real physics, missing evidence files, and any fixture that changes solver policy or physical inputs merely to induce failure.

## What F-VQ04 can qualify

F-VQ04 can qualify the fixture admission/readiness infrastructure itself. It cannot qualify real terminal-failure hydrology while the external fixture is unavailable.

The F-CI13 source-bound retryable-status contract remains qualified. The real terminal-failure observation remains blocked. Temporal-error policy, `execute_reference_interval`, end-to-end B1.10 reference execution, production result routing, snow/macropore completeness and legacy parallel reentrancy remain separate blockers.
