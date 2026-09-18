# PUB-ME D1 execution checkpoint

Status: **D1_A_ADMITTED__D1_B_ACTIVE_ON_SEPARATE_PR**

Checkpoint date: 2026-09-18

## Publication authority

- publication PR: #199
- publication branch: `work/pub-me-literature-pass2`
- frozen preregistration head: `b2ebe5825b3c54d9d4eaefe44c33f4c859fa20aa`
- D1-D6 design blob: `61f7133f19cc900971aa454b7bdb16a254468eda`

The preregistered D1-D6 design, B0/B1/B2 comparator hierarchy, interpretation classes and falsification rule remain frozen.

## Reconciled live repository state

Current canonical at this checkpoint:

`integration/f-ci-canonical@7b864853ca22baa73141b2dec9ed2f3915ef520d`

### D1-A — admitted result

PR #202 — `PUB-ME D1: test candidate-to-accepted structural authority`

- state: merged
- qualified head: `26901ff09ec2825fb7d8941d4720b3b9b56b196d`
- merge commit: `dba238b4b20551dcc36e9121ffe25f19a5b1ac0e`
- classification: **STRUCTURAL_PREVENTION**

Preregistered probes established:

1. the real P1E02 Reference route executed full and two-half physical trajectories before temporal rejection;
2. public-API direct write-through to authoritative committed physical storage is structurally unavailable because that storage is private;
3. public state snapshots are clone-isolated; mutating the snapshot does not mutate authoritative committed state;
4. revision/time and accepted publication remained unchanged in the bounded rejection control.

Important boundary:

D1-A does **not** establish B2 `UNIQUE_DETECTION` or `EARLIER_DETECTION` against B1 because the invalid write-through operation is structurally unrepresentable through the admitted interface.

## D1-B — active prospective mutant study

PR #220 — `PUB-ME D1: rejected-state leakage prospective experiment`

- state: open draft
- base: `integration/f-ci-canonical@7b864853ca22baa73141b2dec9ed2f3915ef520d`
- active head at reconciliation: `f174dca6c1e9d0729901fafd5933146f7635dc4f`
- purpose: execute an explicit qualification-only rejected-state contamination mutant while preserving production/reference authority
- production/reference changes: none intended

The D1-B runner is designed to compare:

- matched clean transaction execution;
- a qualification-only mutant that makes the rejected transaction state differ;
- B1 observations such as accepted ledger/mass and downstream continuation;
- B2 immediate rejection-boundary state-authority detection;
- replay of the same mutant through the existing full-stack P1E02 route to test whether the admitted production architecture structurally contains the fault.

The runner predeclares classification as:
- `EARLIER_DETECTION` if downstream accepted endpoint later diverges while B2 detects contamination immediately;
- `UNIQUE_DETECTION_WITHIN_BOUNDED_CONTINUATION` if the immediate B2 oracle detects contamination but the bounded downstream B1 observation remains indistinguishable;
- plus full-stack structural-prevention evidence from the admitted production route.

No D1-B scientific result is frozen in this checkpoint. The open PR must be read from its CI/result records before interpretation.

## Timeout-safe next action

Do **not** rebuild D1.

Only:

1. inspect PR #220 current head and workflow/result state;
2. if a stable result already exists, persist a short D1-B result checkpoint on this publication branch;
3. if the PR is still running or blocked, record that exact state and stop at that boundary;
4. do not begin D2 until D1-B has an immutable result/nonclaim record.

## Recovery rule

After every meaningful D1-B stage, update this checkpoint before any further tool-heavy action.

A timeout must resume from this file and inspect only PR #220 delta since the recorded head.


## D1-B live checkpoint — head fe7aa271

Reconciled PR #220 head:

`fe7aa27124562bc9a4969056a33876d094ca6e5a`

Changed files remain qualification-only:

- `.github/workflows/pub-me-d1-rejected-state-leakage.yml`
- `docs/publications/PUB-ME_D1_COMPARATOR_AND_MUTATION_FREEZE.md`
- `tests/publication/mutants/d1_rejected_candidate_write_through.patch`
- `tests/publication/run_pub_me_d1_rejected_state_leakage.sh`
- `tests/publication/test_pub_me_d1_rejected_state_leakage.f90`

No `src/**` or `reference/**` delta is present.

Workflow state at this checkpoint:

- Documentation run `35291383008`: **SUCCESS**
- PUB-ME D1 rejected-state leakage run `35291383247`: **IN_PROGRESS**
- F-CI canonical qualification run `35291383093`: **IN_PROGRESS**

No immutable D1-B result record is present yet. Therefore no scientific classification from D1-B is authorized at this checkpoint.

Next permitted action:

- re-read only PR #220 head and these two in-progress workflows;
- if the D1-B gate completes, capture its raw classification markers before consulting downstream interpretation;
- persist the result before any D2 work.


## D1-B failure checkpoint — run 35291383247

PR #220 experiment workflow completed **FAILURE** at job `105434762847`.

Classification: **INVALID_EXPERIMENT_SETUP / TOOLING_BINDING_ERROR**

The failure occurs during compilation before clean/mutant scientific execution.

Observed errors:

- `fmr_serialized_reference_backend_t` does not expose `configure_parameters`;
- it does not expose `prepare_interval`;
- it is not directly a `transaction_model_t` accepted by `execute_reference_interval`.

Therefore:

- no D1 mutant executed;
- no B1/B2 comparison executed;
- no D1-B scientific classification is authorized;
- the preregistered hypothesis remains untouched.

This is a fixture-composition error in the qualification-only test.

Next permitted action:

1. read only the current canonical `tests/publication/test_pub_p1e02_postsolver_rollback.f90` and its immediate transaction-model wrapper dependency;
2. bind D1-B to that already-qualified production composition instead of inventing a direct backend interface;
3. do not change D1 semantics, comparator definitions or mutation intent;
4. persist the corrected binding design before rerunning.
