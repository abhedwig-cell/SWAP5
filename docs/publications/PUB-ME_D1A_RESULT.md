# PUB-ME D1-A transition-authority result

Status: **QUALIFIED_STRUCTURAL_PREVENTION_PENDING_FULL_POSTIMAGE_REPLAY**

Publication owner: `PUB-ME`

Experiment family: `D1 — rejected candidate mutates committed physical state`

## Authorities

- preregistration head: `b2ebe5825b3c54d9d4eaefe44c33f4c859fa20aa`
- preregistration blob: `61f7133f19cc900971aa454b7bdb16a254468eda`
- execution base: `integration/f-ci-canonical@d0a41c39d7ff95db99bcf8360ac9b474fdf164d7`
- qualified D1-A head before this result record: `0e737f47d06eab17094d48834da9a41820bcad29`

## Executed probes

### P0 — matched real post-solver rejection control

The current-canonical PUB-P1E02 route was replayed. The Reference physical solver executed full and two-half trajectories before temporal rejection. The committed state/revision/time and accepted mass publication remained unchanged.

This is a matched physical rejection control and is not counted as B1-only evidence.

### P1 — public-API direct write-through

A qualification-only consumer attempted to address `kernel_committed_state_t%physical_state` directly.

Result:

- compilation failed at both O0 and O2 because the authoritative physical component is private;
- the admitted API exposes no mutable physical-state reference.

### P2 — public snapshot clone isolation

A public committed-state snapshot was obtained and deliberately mutated by the test consumer.

Result at O0 and O2:

- extracted clone changed to the injected mutant value;
- committed value remained unchanged;
- committed revision remained 0;
- committed time remained unchanged;
- O0/O2 output was identical.

Qualified output SHA256:

`0a92d8019934ffd3dd0188cf6d98dd92c424e396708bf2a29b84ce92f88d3409`

## CI evidence

- workflow: `PUB-ME D1 transition authority`
- run: `35283864926`
- job: `105411722987`
- conclusion: `success`

Observed final markers:

- `PUB_ME_D1_P0_REAL_POSTSOLVER_REJECTION=PASS`
- `PUB_ME_D1_P1_PRIVATE_WRITE_THROUGH_O0=PASS`
- `PUB_ME_D1_P1_PRIVATE_WRITE_THROUGH_O2=PASS`
- `PUB_ME_D1_P2_CLONE_ISOLATION_O0=PASS`
- `PUB_ME_D1_P2_CLONE_ISOLATION_O2=PASS`
- `PUB_ME_D1_STRUCTURAL_PREVENTION_EVIDENCE=PASS`
- `PUB_ME_D1_TRANSITION_AUTHORITY_GATE=PASS`

Documentation workflow on the same head also passed.

The broad F-CI canonical qualification was still running when this result record was written and is therefore not claimed here.

## D1-A classification

**STRUCTURAL_PREVENTION**

Within the admitted public execution surface, candidate/model code cannot obtain mutable access to authoritative committed physical storage:

- committed physical storage is private;
- trial execution receives a clone rather than the committed carrier;
- public snapshots are deep clones;
- publication is owned by the explicit commit boundary.

This classification is bounded to the tested canonical interfaces and does not claim that private data, cloning or transactions are novel concepts.

## What this result does not establish

D1-A does **not** establish:

- that B2 uniquely detects a runtime defect that B1 misses;
- a quantitative B1-versus-B2 detection advantage;
- that all possible implementation defects are structurally impossible;
- D2-D6 protection;
- the standalone PUB-ME paper hypothesis.

## Next permitted action

Create a separate D1-B qualification-only mutant study, without changing production authority, to measure **detection timing** under an explicit rejected-state contamination fault.

D1-B must:

1. remain bound to the same preregistered D1 semantics;
2. use a matched clean and mutant execution;
3. define B1 observations before inspecting the mutant result;
4. define the direct B2 transition-authority oracle separately;
5. classify only `NO_INCREMENTAL_VALUE`, `EARLIER_DETECTION`, `UNIQUE_DETECTION`, or `STRUCTURAL_PREVENTION`;
6. never merge mutant behavior into `src/**` or `reference/**`.

D1-A remains valid even if D1-B later finds no incremental detection advantage.
