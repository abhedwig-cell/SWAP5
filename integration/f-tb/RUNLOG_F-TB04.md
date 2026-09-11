# F-TB04 runlog

## Live precheck

- No pre-existing F-TB04 branch or equivalent workunit was found.
- F-TB03 live closeout remained exactly `65d5e5202446212390dbdd84b06e6b2a80e7121c`.
- The F-TB04 work-unit contract pins canonical source authority `0aeb0a2ed4096e1f9493d3dabc70962ea5270182`; repository `main` is not the canonical authority used by this workunit.
- F-TB01, F-TB02 and F-TB03 testbank registries were inspected and retained unchanged.
- Immutable RB1 authorities and historical evidence remain read-only.

## Composition baseline

F-TB04 starts from merge commit `5c7b76655c910046f574753a39278d9a3cc3dbf3`. First parent is the pinned canonical authority; second parent is F-TB03 closeout. The composed tree takes production/runtime source from the pinned canonical authority and testbank authority from F-TB03.

The work-unit contract was deliberately persisted before qualification execution at `7496dd11bc0a65846fd24f6794dc51f039454c7d` and pins `0aeb0a2ed4096e1f9493d3dabc70962ea5270182` as the immutable canonical source authority for this workunit.

## Evidence inspected before catalog buildout

Current transaction contracts at the pinned authority show checkpoint cloning, candidate provenance, stale-revision rejection, explicit rollback, exactly-once revision increment and accepted-commit receipts.

Current restart contracts at the pinned authority expose schema, template, parameter-set, per-column parameter, state-family and target-initialization fail-closed paths, with atomic publication only after full reconstruction succeeds.

FCI28 provides real process split-run plus negative restart qualification. FCI30/FMQ26 evidence provides serialized/2-worker/4-worker equivalence, ordering, rejection isolation, worker overlap, deterministic replay and hard mass. FCI35/FMQ29 evidence provides held-out parallel committed-boundary restart composition.

The FMQ26 parallel fixture uses one parameter reference. FMR18 confirms multiple parameter references are a supported serialized runtime pattern. F-TB04 therefore adds a test-only temporary transform of immutable FMQ26 blob `26cc6e0ace986dc40db7635de7192958a1c0b868` to exercise two immutable parameter references inside one template under serialized, 2-worker and 4-worker execution. No owner evidence or production source is changed.

## Persisted catalog

- 35 stable cases: transaction 10, restart 9, determinism 6, MultiSWAP 10.
- Profiles: FAST 9, CANONICAL 18, RELEASE 34, DEEP 35.
- Determinism is explicitly split between `BIT_IDENTITY_REQUIRED` and `NUMERICAL_EQUIVALENCE_REQUIRED`.
- No new scientific nonzero tolerance was introduced. Existing `1e-12` hard water-mass qualification is inherited unchanged where applicable.
- Required architecture-invariant mapping includes 3, 4, 5, 6, 7, 8, 9, 13, 16, 23, 24, 26, 27, 29 and 30.
- A separate 30-invariant no-adverse-delta audit is persisted at `integration/f-tb/F-TB04_INVARIANT_AUDIT.json`.

## First execution and harness remediation

The first FAST push run, `34602863572` at `f1b4e1298be992f41d06939980747af51b3d6af0`, failed before any scientific or production test because the new F-TB04 validator referred to a non-existent `testbank/rb1` subtree on the immutable F-TB03 closeout.

Live inspection of F-TB03 showed that RB1 permanence is represented by exact scientific, qualification and release-metadata authorities, not by a copied `testbank/rb1` directory. The validator alone was corrected at `0a77bc04061d2bf3dc267d073770ea2203781ac4` to lock the exact RB1 source/reference trees, qualification tree, release-metadata tree, closeout blob, testbank crosswalk blob and architecture-audit blob. No production or reference source changed.

The corrected FAST run `34609684896` on `0a77bc04061d2bf3dc267d073770ea2203781ac4` concluded `success`. It established catalog schema/counts, invariant mapping, determinism-class separation, no-new-tolerance policy, pinned-canonical source immutability, RB1 authority immutability, prior-testbank authority immutability, transaction semantics and O0/O2 transaction transcript identity.

## First exact-head RELEASE attempt and replay-governance remediation

The first exact-head closeout attempt was `a44494e982bf45842b89f350a1f8548a0f193f04`, workflow run `34610037573`. FAST succeeded. RELEASE failed before the FCI28 scientific/restart matrix executed because the historical FCI28 wrapper asserted that no production source anywhere in `src` could have evolved after its original restart candidate. That historical admission-time guard is not a valid preservation condition on the later pinned canonical authority, where unrelated subsequently admitted production capabilities legitimately exist.

This was classified as `FTB04_HISTORICAL_REPLAY_GOVERNANCE_INCOMPATIBILITY`, not as a source defect. The immutable FCI28 replay blob remains hash-locked. F-TB04 now runs a temporary copy in which only the obsolete post-candidate whole-source drift guard is rebound to the exact pinned-canonical `src` and `reference` trees. All restart module blob locks, fixtures, numerical tests, O0/O2 comparisons, negative cases, mass gates and expected markers remain unchanged.

The same preservation principle is applied to the parallel and parallel-restart evidence. The obsolete FCI30 admission wrapper is not used as a preservation authority because it locks an older serialized-runtime postimage. Instead, its immutable FMQ26 parallel matrix blob `26cc6e0ace986dc40db7635de7192958a1c0b868` and publication-order blob `f2584b0236e85d4f6e8b687cee97981eaaa909c9` are compiled and executed directly against the exact pinned-canonical source at O0 and O2. FCI35 is retained as the cross-worker restart authority through a temporary governance rebound; both its outer historical whole-source guard and the same guard inside its rehydrated immutable FMQ29 runner are rebound to the exact pinned-canonical source/reference trees, while all critical restart/parallel blob locks and held-out matrices remain intact.

The resulting replay adapter was added at `testbank/runners/run_ftb04_current_canonical_replays.sh`. FAST remained green after the adapter integration on `a39df0fb8b725ce79cf290a6b56578d9cfc08ed8`, run `34610533357`.

## Second exact-head RELEASE attempt and replay-root remediation

The second exact-head candidate was `65699416faf8448b4f5fdda6e2cfbc24dd26a21c`, workflow run `34610668938`. The RELEASE job reached the rebound FCI28 path but failed immediately with `fatal: not a git repository` before any restart oracle executed. The temporary FCI28 script had been copied under `/tmp`; the immutable historical script derives repository root relative to its own script path, so moving the copy outside `tests/fci` changed only harness path semantics.

This was classified as `FTB04_HISTORICAL_REPLAY_ROOT_SEMANTICS_ERROR`, not as a production or scientific failure. At `1cf21b3174a8caa207de3e0d5db80e12b01a09d1` the adapter was corrected so temporary FCI28 and FCI35 copies remain under `tests/fci/.ftb04-*` and therefore preserve their original repository-root semantics. No production/reference source, historical evidence blob, numerical oracle or tolerance changed. The push run on this remediation head, `34610783746`, has FAST `success`; RELEASE was intentionally skipped because the remediation commit was not marked as an exact-head closeout trigger.

## Canonical advancement during the workunit

After the F-TB04 contract had already frozen authority `0aeb0a2ed4096e1f9493d3dabc70962ea5270182`, the live `integration/f-ci-canonical` branch advanced to `d201904a85f3b595e028242978e52c02f5122a09` through F-CI43/F-CI43P. The delta is the separately admitted restricted soil-temperature capability and its qualification/governance evidence.

F-TB04 does not silently retarget this moving branch. Its closeout remains bound to the immutable source authority recorded before execution, as required for reproducible qualification. Therefore this workunit makes no claim that the 35-case catalog has already been rerun against `d201904a85f3b595e028242978e52c02f5122a09`. Continuous qualification can apply the catalog to later canonical authorities through an explicitly rebound/pinned run without rewriting this closeout.

## Defect status

No production-source defect has been discovered. All observed failures were F-TB04 harness/preservation-governance defects and were remediated strictly outside production source. No separate production owner workunit is required on the evidence observed so far.

## Final exact-head rule

F-TB04 follows the established F-TB03 closeout pattern. The final decision is valid only if the F-TB04 workflow concludes success with `head_sha` equal to the exact commit containing the final qualification status. That exact-head run must execute both FAST and RELEASE. RELEASE executes the pinned-canonical rebound FCI28 restart matrix, immutable FMQ26 serialized/parallel and publication-order matrices, the F-TB04 heterogeneous-parameter-reference MultiSWAP case, and pinned-canonical rebound FCI35/FMQ29 held-out cross-worker committed-boundary restart qualification. DEEP remains explicit and is not required for closeout because the historical VQ31 replay performs a test-only overlay commit in its isolated checkout.
