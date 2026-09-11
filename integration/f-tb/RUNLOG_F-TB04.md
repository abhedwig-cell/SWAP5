# F-TB04 runlog

## Live precheck

- No pre-existing F-TB04 branch or equivalent workunit was found.
- F-TB03 live closeout remained exactly `65d5e5202446212390dbdd84b06e6b2a80e7121c`.
- Current canonical source authority is `0aeb0a2ed4096e1f9493d3dabc70962ea5270182`; repository `main` is not the current canonical authority.
- F-TB01, F-TB02 and F-TB03 testbank registries were inspected and retained unchanged.
- Immutable RB1 archive and historical evidence remain read-only.

## Composition baseline

F-TB04 starts from merge commit `5c7b76655c910046f574753a39278d9a3cc3dbf3`. First parent is current canonical; second parent is F-TB03 closeout. The composed tree takes production/runtime source from current canonical and testbank authority from F-TB03.

The work-unit contract was deliberately persisted before qualification execution at `7496dd11bc0a65846fd24f6794dc51f039454c7d`.

## Evidence inspected before catalog buildout

Current transaction contracts show checkpoint cloning, candidate provenance, stale-revision rejection, explicit rollback, exactly-once revision increment and accepted-commit receipts.

Current restart contracts expose schema, template, parameter-set, per-column parameter, state-family and target-initialization fail-closed paths, with atomic publication only after full reconstruction succeeds.

Current FCI28 provides real process split-run plus negative restart qualification. Current FCI30 provides serialized/2-worker/4-worker equivalence, ordering, rejection isolation, worker overlap, deterministic replay and hard mass. Current FCI35 provides held-out parallel committed-boundary restart composition.

The FCI30 FMQ26 parallel fixture uses one parameter reference. FMR18 confirms multiple parameter references are a supported serialized runtime pattern. F-TB04 therefore adds a test-only temporary transform of immutable FMQ26 blob `26cc6e0ace986dc40db7635de7192958a1c0b868` to exercise two immutable parameter references inside one template under serialized, 2-worker and 4-worker execution. No owner evidence or production source is changed.

## Persisted catalog

- 35 stable cases: transaction 10, restart 9, determinism 6, MultiSWAP 10.
- Profiles: FAST 9, CANONICAL 18, RELEASE 34, DEEP 35.
- Determinism is explicitly split between `BIT_IDENTITY_REQUIRED` and `NUMERICAL_EQUIVALENCE_REQUIRED`.
- No new scientific nonzero tolerance was introduced. Existing `1e-12` hard water-mass qualification is inherited unchanged where applicable.
- Required architecture-invariant mapping includes 3, 4, 5, 6, 7, 8, 9, 13, 16, 23, 24, 26, 27, 29 and 30.

## Defect status before execution

No production-source defect has been established by the F-TB04 buildout itself. Any defect found by qualification will be persisted and routed to a separate owner workunit rather than patched here.
