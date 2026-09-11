# F-TB04 Transaction, Restart, Determinism & MultiSWAP Qualification Case Catalog

## Authority and scope

F-TB04 is a post-RB1 testbank buildout. It does not reopen RB1 and it does not modify production source. Its composition baseline is `5c7b76655c910046f574753a39278d9a3cc3dbf3`, whose first parent is current canonical `0aeb0a2ed4096e1f9493d3dabc70962ea5270182` and whose second parent is qualified F-TB03 `65d5e5202446212390dbdd84b06e6b2a80e7121c`.

The permanent machine-readable catalog is `testbank/manifests/F-TB04_CASE_CATALOG.tsv`. It contains 35 stable cases: 10 transaction, 9 restart, 6 determinism and 10 MultiSWAP cases. F-TB01/02/03 registries remain unchanged authorities; F-TB04 generalizes relevant evidence rather than rewriting it.

No new nonzero scientific tolerance is introduced. `EXACT` means logical, integer or bit identity. The only nonzero binding is the existing `1e-12` hard water-mass gate inherited unchanged from current qualified restart/parallel authorities. Worker-local scheduling metadata is explicitly excluded only in cases classified `NUMERICAL_EQUIVALENCE_REQUIRED`.

## Transaction bank

The bank makes checkpoint, accepted commit, rejected candidate, explicit rollback, retry, repeated rejection, exactly-once commit, committed revision progression, mass-ledger provenance and stale-candidate rejection permanent concepts. The cheap FAST oracle uses the current FMR18 commit-receipt fixture and source-level contract checks. DEEP retains the more expensive historical temporal-history retry replay. Rejected or stale candidates must never mutate committed physical state.

## Restart bank

The primary executable authority is current-canonical FCI28. It covers uninterrupted versus committed-boundary split continuation, physical/process continuation state, exact lineage/revision/time preservation, interval mass, reverse record/runtime ordering, and negative schema/state-family/template/parameter/malformed-state attacks. Restore is atomic: all decoded records are validated into fresh candidate states before `state_registry = candidate_states` publishes them.

The restart record remains serialization-neutral. It contains stable identities, committed provenance and physical continuation state. Forcing, Newton/Jacobian data, worker scratch and warm starts are not persistent restart state. Registered optional continuation families are explicit and fail closed.

## Determinism bank

F-TB04 distinguishes two contracts.

`BIT_IDENTITY_REQUIRED` applies when the existing authority already compares exact state/result values or full transcripts. It covers repeated execution, qualified O0/O2 identity, deterministic batch decomposition and canonical collection.

`NUMERICAL_EQUIVALENCE_REQUIRED` applies when execution-local metadata may legitimately differ, for example worker assignment. In these cases physical state/results and hard mass must remain equivalent under the inherited qualified criteria. This classification is explicit per case and is not a tolerance relaxation.

## MultiSWAP bank

The permanent matrix includes N=1, small regular, irregular N/batch combinations, bounded medium cases, standalone/serialized/parallel equivalence, rejection isolation, worker scratch ownership, per-column plus aggregate mass, and optional-module noncontamination.

Current FCI30 already provides serialized, 2-worker and 4-worker equivalence over N=2,7,8,17,31,32, including input-order attacks, rejection isolation, real physical overlap, deterministic replay and unsupported-profile fail-closed behavior. Current FCI35 adds held-out N=3,5,9,16,23,33 committed-boundary restart composition across serialized and 2/4-worker routes.

The existing FCI30 matrix uses one `parameter_ref`. F-TB04 therefore adds one test-only qualification fixture derived at runtime from immutable FMQ26 blob `26cc6e0ace986dc40db7635de7192958a1c0b868`. It alternates two immutable parameter references inside one template and compares serialized, 2-worker and 4-worker execution at O0 and O2. The transform is temporary; owner evidence and production source are never rewritten.

## Profile placement

FAST contains only cheap registry, immutability and transaction-contract checks. CANONICAL adds current-canonical restart qualification. RELEASE adds the expensive parallel, heterogeneous-parameter and cross-worker restart matrices. DEEP additionally runs the historical temporal-history retry composition replay. Expensive adversarial matrices are therefore not placed on every ordinary push.

Profile membership is fixed in the catalog: FAST 9, CANONICAL 18, RELEASE 34, DEEP 35. DEEP is explicit-dispatch only because its historical replay creates a test-only overlay commit in its isolated checkout; it is not used as the exact-head release gate.

## Architecture mapping

The catalog explicitly covers invariants 3, 4, 5, 6, 7, 8, 9, 13, 16, 23, 24, 26, 27, 29 and 30. The validator additionally proves that current `src/**`, the immutable RB1 archive and all three predecessor testbank registries remain unchanged.

## Defect policy and exit

A source defect discovered by these tests is evidence, not an invitation to patch inside F-TB04. It must be persisted, classified and handed to a separate owner workunit. Testbank-only harness defects may be repaired on the F-TB04 branch.

The only successful closeout decision is:

`QUALIFIED_TRANSACTION_RESTART_DETERMINISM_MULTISWAP_TESTBANK_CATALOG_READY_FOR_CONTINUOUS_QUALIFICATION`

Closeout additionally requires exact-head RELEASE CI and proof that production source and RB1 remained immutable.
