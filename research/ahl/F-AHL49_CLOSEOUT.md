# F-AHL49 — production-shaped direct-retention extraction closeout

Date: 2026-09-25

Status: `READY_ADMISSION_CANDIDATE`

PR: #619

Qualification evidence head: `0797888f57ebf2eec422db3d28dad7d7dcf6a7ce`

The final closeout documentation commit may advance the branch head beyond this SHA. The qualification evidence below is from `0797888f57ebf2eec422db3d28dad7d7dcf6a7ce`; the closure change after it is documentation-only.

Parent authority: F-AHL48 closed shared immutable ownership, resolution 128 intervals per decade.

## Verdict

`F-AHL49 = READY_ADMISSION_CANDIDATE_OPT_IN`

The production-shaped direct-retention architecture is qualified for an explicit opt-in admission decision inside its bounded envelope.

It is not default-enabled and this closeout does not broaden the qualified physics envelope.

## Production architecture

Representation:

- 128 intervals per decade over |h| = 1..1e6 cm;
- direct decade selection and direct interval arithmetic;
- cubic Hermite theta representation;
- C is the exact derivative of the same interpolant;
- full hydraulic evaluation remains analytical;
- K and point conductivity remain analytical;
- analytical fallback outside the represented head domain.

Routing:

- explicit opt-in only;
- default OFF;
- unsupported compositions fail closed.

## Ownership lifecycle

The representation pool is shared by exact homogeneous hydraulic authority.

Build/acquire occurs during persistent parameter preprocessing. The prepared integer slot is stored with the physical parameters. Trial-time provider binding receives that slot directly and performs no authority search or table build in the solve hot path.

Supported production lifecycle:

`single application owner -> serial acquire/build -> freeze -> immutable reads -> close`

The first extraction admits at most one active direct-retention production application owner at a time.

A second opt-in owner while the first is active fails closed. Closing the active owner releases and clears the pool so a later application can initialize safely.

Concurrent immutable reads are inherited from F-AHL48; concurrent pool mutation is not admitted.

## Qualified envelope

Required:

- default B1.10 MvG hydraulic authority;
- hydraulically homogeneous active profile;
- prescribed-head bottom mode 5;
- SWKIMPL = 0;
- no tabulated hydraulics;
- no hysteresis;
- no KSATEXM extension.

Explicitly outside F-AHL49:

- prescribed qbot;
- standalone mode 7;
- layered/heterogeneous hydraulic authorities;
- SWKIMPL = 1;
- KSATEXM composition;
- tabulated hydraulics;
- hysteresis;
- default-on behavior;
- replacement of analytical K;
- practical/approximate tolerance changes.

## Derivative consistency and MODFLOW response tangent

The production direct-retention provider now exposes accepted-step directional capability consistent with the actual constitutive route.

Within the represented domain:

`dtheta = C_direct * dh`

where `C_direct` is the exact derivative of the same cubic Hermite theta interpolant used by the physical solve.

K remains analytical in F-AHL49, so conductivity directional sensitivity continues to use the analytical B1.10 MvG capability.

Outside the represented theta/C domain, the directional route falls back to the analytical B1.10 capability.

The accepted-trajectory directional service explicitly recognizes the direct-retention provider for:

- base-state constitutive direction;
- accepted-state water-content direction;
- MODFLOW-coupling response tangent publication.

This closes the production application response-tangent boundary discovered during F-GC49D qualification.

## Production provider qualification

Provider extraction: PASS.

Current authority payload:

- entries = 1;
- builds = 1;
- exact-key reuse hit = 1 in the provider gate;
- raw theta+C payload = 12,384 bytes per unique hydraulic authority.

The provider gate also qualifies the direct-retention directional capability.

## 12-case production matrix

Matrix:

- materials: B01, B12, O05, O14;
- states: wet, mid, dry;
- total: 12 cases.

Result:

- fidelity/path PASS: 12/12;
- nonlinear iteration deltas: 0/12;
- backtracking deltas: 0/12;
- speed-positive: 12/12;
- speed-negative: 0/12.

Representative maximum observed deltas across the current matrix remain very small:

- max |dh| approximately 1.05e-6 cm;
- max |dtheta| approximately 7.25e-11;
- mass residuals remain near machine precision.

Current-postimage paired timing:

- median candidate/analytical ratio: `0.836649753`;
- minimum case ratio: `0.819536668`;
- maximum case ratio: `0.879662915`;
- positive cases: 12;
- negative cases: 0.

Interpretation:

- median solver reduction is approximately 16.3%;
- every matrix case remains speed-positive;
- exact nonlinear/backtracking path is retained.

## Large-N application setup / ownership qualification

The scale gate measures production application initialization, shared representation ownership and memory scaling at:

- N=1;
- N=100;
- N=1,000;
- N=10,000.

Paired median direct/analytical initialization ratios:

- N=1: `4.115531093`;
- N=100: `1.385333022`;
- N=1,000: `1.100183655`;
- N=10,000: `1.034537972`.

Interpretation:

- N=1 is dominated by the one-time table build;
- setup overhead rapidly amortizes;
- at N=10,000 the direct-retention setup overhead is approximately 3.18%.

For a repeated single hydraulic authority:

- unique representation entries = 1;
- builds = 1;
- hits = N-1;
- payload = 12,384 bytes;
- pool frozen before execution.

Memory therefore scales with unique hydraulic authorities, not number of columns.

## Default-off and fail-closed behavior

PASS:

- default-off production behavior is preserved;
- unsupported opt-in combinations leave no valid prepared direct-retention slot;
- second concurrent application owner is rejected;
- active-owner reset is blocked;
- first-owner slot remains stable;
- a later owner can initialize after close.

## Production groundwater application qualification

The final application gate uses the existing F-GC49D production application context rather than an invalid standalone mode-5 execution path.

Qualified behavior includes:

- real production participant handles;
- F-GC49D plan/context materialization;
- direct-retention preprocessing and frozen ownership;
- accepted-trajectory response tangent available;
- two coupling iterations in the deterministic service;
- real SWAP trial/corrector execution;
- relinearization;
- SWAP preflight;
- external ledger preflight;
- three real SWAP commits;
- three real ledger commits;
- one-window context reuse fails closed;
- stale context handle fails closed;
- O0/O2 stable output identity.

Current-head application opt-in workflow: PASS.


## Current-head gate reconciliation

On qualification evidence head `0797888f57ebf2eec422db3d28dad7d7dcf6a7ce`:

- F-AHL49 provider extraction: PASS;
- F-AHL49 production provider matrix: PASS;
- F-AHL49 default-off preservation: PASS;
- F-AHL49 fail-closed envelope: PASS;
- F-AHL49 multi-application ownership: PASS;
- F-AHL49 application scale qualification: PASS;
- F-AHL49 application opt-in / F-GC49D production application context: PASS;
- inherited PPA-WU01 production application bootstrap: PASS;
- inherited F-PE-ZERO-WASTE01 parameter configuration reuse, including FKT22 serialized runtime: PASS.

The inherited parameter-configuration-reuse red run was a compile-list closure defect, not a production numerical failure. FKT22 compiled `mod_reference_richards_temporal_indicator` after that module had gained a dependency on the direct-retention provider, but the runner had not yet compiled the direct-retention core/provider. The runner was corrected to compile those dependencies first and the inherited gate then passed without production-code changes.

## Reconciled qualification failures

Several intermediate red runs were harness or qualification-boundary defects and are not production failures:

1. mode-5 groundwater applications were initially exercised incorrectly through `run_standalone()`;
2. a generated runner lost its repository root after relocation;
3. the F-GC49D Python test dependency `python3-numpy` was initially absent;
4. compile lists initially ordered the direct-retention provider before its new directional dependency;
5. the opt-in wrapper wrote and grepped different temporary output filenames;
6. the inherited FKT22 runner initially omitted the direct-retention core/provider from its compile-order closure after the temporal-indicator dependency was added.

The real application-level gap discovered during this process was missing accepted-step directional support for the direct-retention constitutive provider. That gap was repaired in production code and subsequently qualified by provider and F-GC49D application gates.

## Admission boundary

F-AHL49 is ready for an admission decision as an opt-in production feature inside the exact bounded envelope above.

This closeout does not authorize:

- default-on activation;
- qbot routing;
- heterogeneous/layered hydraulic authorities;
- SWKIMPL=1;
- KSATEXM;
- hysteresis;
- tabulated hydraulics;
- replacement of analytical K;
- practical/approximate error budgets.

Recommended admission state:

`F-AHL49 = READY_ADMISSION_CANDIDATE_OPT_IN`

A separate canonical admission step should preserve the same envelope and default-OFF policy.

## Next work unit

The logical successor is F-AHL50: controlled opt-in production admission and canonical integration with preservation. F-AHL50 should not make the feature default-on and should not broaden the qualified envelope. F-AHL47/F-AHL48/F-AHL49 should only be reopened if a concrete admission failure demonstrates that this is necessary.
