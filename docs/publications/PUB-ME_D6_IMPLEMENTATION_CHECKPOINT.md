# PUB-ME D6 implementation checkpoint

Status: **IMPLEMENTED_TEST_AND_RUNNER__AWAITING_FIRST_EXECUTION**

Publication owner: `PUB-ME`

Branch: `work/pub-me-d6-rejected-side-effect`

Current branch head:

`9c33815642e4c974e7d5a5a1e16656906b52800a`

Execution base:

`integration/f-ci-canonical@d67a96fd576dcd1c5a30eb766c5aa1a503e10cf0`

## Persisted artifacts

- `docs/publications/PUB-ME_D6_EXECUTION_CHECKPOINT.md`
- `docs/publications/PUB-ME_D6_PREREGISTERED_DESIGN.md`
- `tests/publication/test_pub_me_d6_rejected_side_effect.f90`
- `tests/publication/run_pub_me_d6_rejected_side_effect.sh`

## Frozen D6 route

The harness reuses the F-VQ71 ambiguity fixture concept:

1. candidate A and B are materialized from the same accepted origin;
2. candidate A obtains a valid candidate-bound surface-evaporation result;
3. qualification-only mutant may leak A's result to an external event sink before acceptance;
4. candidate B is atomically committed with the real accepted surface-publication seam;
5. B's accepted publication is sent to the sink;
6. stale A is rejected by the real production publication/transaction path.

Clean expected stream:

- one event, belonging to accepted B.

Mutant expected stream:

- early A event from non-authoritative candidate;
- accepted B event.

## Comparator freeze

B1:
- detects contamination from the final accepted-event-stream regression.

B2:
- detects the attempted side effect before observer mutation because no accepted receipt/publication authority exists yet.

Predeclared positive classification if executable results match:

`EARLIER_DETECTION`

This classification is not yet an observed result at this checkpoint.

## Scope guards

The runner fails if any `src/**` or `reference/**` file differs from the execution base.

No production observer API was added.

No production/reference semantics were changed.

## Next permitted action

1. add a dedicated D6 workflow only;
2. open a draft PR;
3. run the exact D6 gate;
4. if compile/setup fails, repair only harness/tooling without changing the frozen candidate sequence, rates, B1/B2 rules or expected interpretation;
5. persist first scientific execution result before launching or waiting on broad canonical qualification.

## Timeout recovery

Resume from branch/head above.

Do not re-read D1-D5 or the broader literature unless a direct D6 comparator inconsistency is found.


## Canonical reconciliation before first CI

Canonical advanced from the original execution base to:

`f2d472cb0e4d935ef39f002d6f21c8d90acf4dd8`

The exact delta is PUB-P2E10-only:

- one P2E10 workflow;
- P2E10 preregistration/result documents;
- P2E10 publication test and runner.

No `src/**` or `reference/**` file changed.

D6 dependency surface remains unchanged.

Draft PR:

`#216 — PUB-ME D6: preregister and execute rejected side-effect authority experiment`

This checkpoint update intentionally triggers the dedicated D6 workflow after the PR was created.


## Compile-fixture simplification after three pre-execution failures

The first three D6 workflow attempts did **not** execute the scientific D6 test.

They failed while compiling unrelated current serialized-backend dependencies:

1. missing accepted-trajectory directional sensitivity;
2. missing accepted-trajectory directional publication;
3. missing bottom-thermal carrier pulled by the full serialized reference backend.

No D6 observation was available before the following change.

To keep the experiment bounded, the qualification build now uses:

`tests/publication/pub_me_d6_fmr_state_stub.f90`

This test-only module provides only the public hydraulic base carrier required by the exact production:

- process hydraulic-view binding;
- candidate-bound surface-evaporation materializer;
- accepted commit receipt;
- accepted surface-evaporation publication.

The runner fail-closes if the current production `fmr_b110_physical_state_t` declaration drifts in any of:

- active-node field;
- pressure-head field;
- water-content field;
- ponding field;
- groundwater-level field;
- clone binding.

The real current-canonical kernel, transaction runtime, materializer, receipt and accepted-publication sources remain compiled unchanged.

Current minimized implementation head before scientific execution:

`f03cd172e58a45fbb51076d9e2c4c47dd1a9e55a`

Scientific design, candidate sequence, rates, B1/B2 comparator and classification rules are unchanged.
