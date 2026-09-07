# F-CI17 canonical baseline supersession registry

Status at materialization: `PERSISTED_CANONICAL_BASELINE_REGISTRY_CI_PENDING`.

F-CI17 addresses CI-G10 only. It changes no production source and deletes no historical branch. Instead it records exactly one active development baseline, `integration/f-ci-canonical`, and marks every other audited integration line as `SUPERSEDED_HISTORICAL_ONLY` with its observed Git head pinned.

Historical branches remain available for lineage, evidence and postimage recovery, but they are explicitly prohibited as new production-development baselines. `integration/f-ci-canonical-copy` is explicitly not a fallback canonical branch.

F-CI17 also freezes the F-CI16 exit-gate assessment as `F-CI16_EXIT_GATES.json` and redirects the historical F-CI16 gate to that immutable snapshot. This prevents future exit-gate updates from invalidating previously qualified evidence.

CI-G10 must not be promoted from `BLOCKED` to `QUALIFIED` until this registry and the full canonical dependency chain pass on the materialized F-CI17 postimage.
