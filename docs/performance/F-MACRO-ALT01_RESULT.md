# F-MACRO-ALT01 — source-bound memory falsification result

Date: 2026-09-30

Status: `QUALIFIED_RESEARCH_RESULT / ONE-HISTORY-STATE_NOT_YET_SUPPORTED`

Baseline: `integration/f-ci-canonical@ddd218085afd363d22ce0b632d3ac893c7c9f40b`

Research branch: `research/f-macro-alt01-memory-falsification`

## Question

Can a reduced functional macropore model preserve relevant event-scale behaviour with only:

```text
S_p(z)
```

or at most:

```text
S_p(z) + one compact history state
```

rather than the larger legacy macropore continuation surface?

## New recovered authority

The Project Library contains exact retained historical artifacts that were not available to the earlier PPA-WU05-A review session:

- `S12o_macropore_column_state.patch`
- `S12o_test_summary.txt`
- `S12o_dependency_map.txt`
- `S12r_delta_after_S12q.patch`
- `A23AT_to_A23AU.patch`
- A23au qualification/contract records.

These artifacts do not by themselves materialize the byte-exact B1.11 `macropore.f90` and `macrorate.f90` postimages required for production migration authority, so the PPA-WU05-A1 production blocker remains formally open.

They are sufficient, however, to strengthen the research state/history census.

## Source-bound state findings

The exact S12o patch classifies seven active-sized column-owned physical/history fields:

```text
ICpBtDm
SorpDmCp
ThtSrpRefDmCp
TimAbsCumDmCp
VlMpDmCp
WaUnMpDmCp
VlMpDyCp
```

Their explicit meanings in the retained patch include:

- `ICpBtDm`: current bottom compartment of domain;
- `SorpDmCp`: Philip sorptivity at start of sorption event;
- `ThtSrpRefDmCp`: sorption reference water content;
- `TimAbsCumDmCp`: cumulative duration of a sorption event;
- `VlMpDmCp`: macropore volume per domain and compartment;
- `WaUnMpDmCp`: water stored in macropore domain per compartment;
- `VlMpDyCp`: dynamic macropore volume per compartment.

The same patch also proves that these seven fields are not the entire continuation/history surface.

Additional history/reference structure includes:

- `FlEndSrpEvt`: end-of-sorptivity-event flag, retained outside the seven-field S12o object;
- `FrMpWalWetOld`: accepted wet-wall history, already moved earlier into `MacroporeAcceptedHistory`;
- checkpoint/reference arrays such as `ICpBtDmM1`, `VlMpDmCpM1`, `WaUnMpDmCpM1`;
- trial/result and retry-control state outside the seven-field object.

Therefore the earlier research shorthand “legacy state = seven arrays” is incomplete.

## Consequence for reduced-state hypothesis

The original F-MACRO-ALT01 preregistration allowed a candidate lower bound:

```text
S_p(z) + zero or one compact exchange-history state
```

The recovered source evidence does not support assuming that a single scalar/history field can reproduce all legacy information roles.

At least four distinct information roles are visible:

1. fast-domain water/storage;
2. dynamic available macropore geometry;
3. sorption-event memory;
4. wet-wall/contact history.

Topology/connectivity is another role but may be reducible to immutable or slowly varying configuration rather than continuation state.

### Result

```text
R1b_MEMORYLESS = STILL_OPEN_AS_FALSIFICATION_TARGET
R1a_ONE_HISTORY_STATE = NOT_YET_SUPPORTED_AS_GENERAL_LOWER_BOUND
```

A one-history-state model remains a candidate, but it must now prove that multiple legacy history variables are observationally redundant for the target outputs.

## Stronger minimal-state research problem

The revised question is:

> What is the minimum sufficient statistic of the legacy macropore continuation state for the target SWAP outputs?

Instead of mapping legacy variables one-to-one, define candidate information groups:

```text
FAST_STORAGE
DYNAMIC_GEOMETRY
SORPTION_EVENT_MEMORY
WET_WALL_MEMORY
CONNECTIVITY_TOPOLOGY
```

and eliminate groups only through controlled conditional-response tests.

## Revised falsification sequence

### E01 — storage sufficiency

Hold matrix state, forcing and configuration fixed. Equalize current fast-domain water storage while allowing other legacy history to differ.

If future response differs, storage alone is insufficient.

### E02 — sorption-memory necessity

Equalize:

- matrix state;
- fast-domain storage;
- dynamic geometry;
- wet-wall history;
- forcing.

Vary only source-proven sorption-event state such as cumulative absorption duration/reference state.

A reproducible response difference proves irreducible sorption history.

### E03 — wet-wall-memory necessity

Equalize all current storage, geometry and sorption-event variables, then vary only accepted wet-wall history.

A response difference proves a separate wet-wall sufficient statistic is required.

### E04 — dynamic-geometry necessity

Equalize current water storage and history but vary source-proven dynamic macropore volume.

A response difference proves geometry cannot be reconstructed from matrix state and immutable configuration alone.

### E05 — compression

Only after E02-E04 determine which roles are independently causal, test whether two or more roles can be represented by one compact latent/effective history variable without loss across held-out events.

## Scratch separation strengthened

The A23au exact patch and qualification support a clean separation between continuation state and rate/Jacobian scratch.

The extracted helper scratch contains:

```text
sat_del_h
sat_flw_mtx
abs_del_h
abs_diffusivity
abs_fl_sorp
```

and is explicitly qualified as worker/job-local disposable scratch, not checkpoint state.

The recovered S12r patch similarly exposes a broader rate-scratch design covering SATFLOW, ABSORPTION and RAPIDDRAIN workspace.

This supports the reduced-model architecture rule:

```text
persistent reduced physical/history state != rate scratch
```

and means research state reduction should not count legacy execution workspace as physics.

## Production-authority boundary

This result does not close PPA-WU05-A1.

Still required before a production macropore migration claim:

1. byte-exact B0 source materialization;
2. B0 hash verification;
3. SWAP-001 application and B1.11 postimage verification;
4. complete mutable-field and mass-transfer census against exact B1.11 bytes;
5. exact restart/candidate/scratch schema.

F-MACRO-ALT01 is a research result about model-state sufficiency, not production reference admission.

## Current research conclusion

The reduced functional architecture remains promising, but the defensible current state hypothesis is broader than previously stated:

```text
matrix state
+ fast-domain storage
+ minimal history vector H_p(z)
+ dynamic/immutable connectivity representation
+ worker-local disposable scratch
```

where the dimension and semantics of `H_p` are now an empirical falsification target rather than assumed to be 0 or 1.

The next highest-value experiment is E02: isolate sorption-event memory from current storage, geometry, wet-wall state and matrix state.
