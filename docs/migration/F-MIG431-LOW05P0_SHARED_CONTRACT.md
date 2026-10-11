# F-MIG431-LOW05-P0 shared application and sampling contract

Date: 2026-10-01
Status: CENTRAL_CONTRACT_RESOLVED_FOR_BOUNDED_IMPLEMENTATION
Reconciled canonical: `029453104b98d835790f2e09eb9e804aa3eaff4a`
Owner: central F-MIG431 lower-boundary regie
Production admission: NONE

## Decision and scope

LOW05-A may implement the ordinary DATE5/HBOT5 prescribed-lower-face-pressure-head application on the existing Reference mode-5 solver. The shared prerequisite is resolved as the following explicit contract. This resolution is design authority, not production qualification.

The original source review remains historical evidence; its production hold is superseded by this contract and the LOW05-A issuance record. No changes are authorized to Richards ABI, native qbot sign, bottom-row equations, transaction acceptance/retry policy, committed-state schema, groundwater datum mapping, predictor/corrector orchestration or accepted mass ownership.

## Application ownership

Add an explicit opt-in designation `ordinary_prescribed_head` to the Fortran production application tile configuration, default false.

- False preserves existing bootstrap classification and all current groundwater-owned mode-5 defaults.
- True requires typed bottom_mode=5 and a valid immutable DATE5/HBOT5 control. It identifies an ordinary prescribed-pressure-head application, not coupled groundwater.
- The initial admitted candidate must be homogeneous ordinary mode 5; mixed application ownership/modes remain fail-closed.
- Ordinary tiles require no groundwater ledger or datum. To avoid ambiguous ownership, reject positive groundwater ledger IDs, an available groundwater datum, multiple groundwater workers, and any simultaneous coupling head authority.
- Mode 5 without the ordinary opt-in retains all existing groundwater validation and allocation.
- Ordinary applications must allocate no groundwater registry, materializer or interface ledger and must fail closed when asked to materialize a groundwater context.
- A groundwater forcing materializer must reject a base forcing containing an ordinary DATE5/HBOT5 control; it must not overwrite or silently compete with that control.
- Existing non-mode-5 bootstrap behavior remains unchanged.

No public C ABI extension is admitted by LOW05-A. The designation belongs to the existing typed Fortran application configuration. Groundwater storage, drainage and topology authority remains untouched.

## Immutable forcing versus worker-local attempt data

The typed control contains the populated DATE5/HBOT5 arrays, explicit canonical elapsed-day origin and legacy t1900 origin, and source-valid simulation coverage. It is immutable forcing/configuration, not compact committed physical state.

A resolved proposal record contains:
- valid flag;
- canonical transaction origin and original proposed endpoint;
- mapped legacy sample time;
- resolved lower-face pressure head in cm.

This is worker-local attempt-context data. Include it in the Reference backend's existing capture/restore attempt context when ordinary mode 5 is active. Clear it on every new outer backend trial and on invalid preparation. It must not persist across columns, unrelated A/B/A calls or restarted applications.

## Existing seam and exact ordering

The existing optional `canonical_subinterval_target_selector` is propagated by `fmr_trial_from_checkpoint` through `kernel_executor%advance_interval` into `run_canonical_interval`. Inside the canonical loop it is invoked before `execute_reference_interval`. The latter captures model attempt context before the first physical advance and restores that context before full, half and retry candidates.

LOW05-A may pass a backend-local internal selector through this EXISTING optional argument only when ordinary mode 5 is active. It must:
1. retain the existing target choice and retry cap; no new numerical-policy rule;
2. resolve the immutable table at the original proposed transaction endpoint;
3. place the resolved proposal in the local model before transaction context capture;
4. mark invalid tables/mapping/proposals unavailable so the canonical request fails closed.

Do not sample once at an arbitrary outer application interval and assume it covers all accepted transactions. The callback must be invoked for each actual canonical transaction proposal. Do not mutate global/module-saved state from the callback.

The initial implementation uses the same default transaction target as the current no-selector path: the remaining requested interval endpoint, with the existing configured retry cap. If later numerical-policy composition requires a different selector, it must resolve LOW05 after that selected target is known; silently installing a competing selector is forbidden.

## Candidate, full/two-half and retry rule

Every physical advance inside one proposed transaction consumes the same resolved head. Full and two-half trajectories are numerical assessments of one frozen-boundary problem; their different endpoints must not resample the table.

A reduced-dt retry restores the original proposal record, then uses its head unchanged. This preserves the B1.11 source loop's frozen head across reduced-dt retry. The source has no SWAP5 full/two-half assessment route; the sibling rule is an explicit architecture composition choice, not a claim of a byte-identical legacy full/two-half algorithm.

After the transaction is accepted, the canonical cursor advances to the accepted endpoint. The next selector invocation constructs a NEW proposal and a new sample. A half-candidate intermediate state is not a new externally accepted transaction origin.

A backend advance must reject a missing/invalid proposal or a physical interval lying outside its proposal bounds. It must not fallback to forcing%bottom_head or per-retry table interpolation when the ordinary control is active.

## Restart and failure

Accepted-boundary restart retains the existing physical state/time/provenance schema. The surrounding application reconstructs the exact immutable table and time origins. A new proposal is sampled from the restored accepted time under the same requested continuation and numerical policy.

Rejected candidate state and proposal scratch are not restart authority. Whole requested-interval failure leaves external committed state unchanged. Re-entry from the same checkpoint with the same request/configuration recreates the same proposal sequence. A/B/A must not retain the B table or sample.

## Table and science contract

Preserve the exact B1.11 DATE5/HBOT5 law and head range [-1e10,1000] cm. Use populated arrays, piecewise-linear interpolation and endpoint clamping equivalent to AFGEN; require finite values, equal non-empty array lengths and strictly increasing dates. Support one-point clamping subject to exact checkdate coverage. Enforce the source checkdate rule and 1e-6 day comparison margins against the declared simulation window.

Map time explicitly: legacy_t1900 = legacy_origin + (canonical_endpoint-canonical_origin), with both axes in days. Reject non-finite time/mapping and non-positive proposal duration. No general calendar parser migration is claimed.

The prescribed quantity is pressure head at the lower face. Existing retention/conductivity, Darcy row and accepted-flux publication remain their admitted physics owner's responsibility. The provider does not prescribe qbot or create a new mass ledger.

## Required implementation proof

Preregister before production mutation:
- independent exact-source interpolation/domain/coverage oracle;
- observable sample/proposal provenance sufficient to distinguish frozen head from per-retry recomputation;
- actual production callback-to-checkpoint-to-advance wiring;
- full/two-half sibling equality and reduced-dt retry freezing;
- resampling after accepted transaction progress;
- failure/exhaustion external-state immutability;
- accepted-boundary restart and A/B/A;
- O0/O2 identity and hard unrounded accepted mass closure;
- ordinary application creates no groundwater-owned resources;
- groundwater context/materializer rejects ordinary head control;
- default groundwater mode 5 and admitted modes 2, 4, 6, 7 preservation.

If implementation cannot meet this contract through the existing selector/attempt-context seams, return that concrete finding to central regie. Do not alter generic transaction/kernel interfaces locally.

Affected invariants: 2,3,4,7,8,9,12,13,22,23,25,28,29,30.
