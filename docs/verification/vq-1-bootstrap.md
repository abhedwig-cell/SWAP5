# VQ-1: Verification and reference qualification bootstrap

**Status:** Active  
**Workstream:** `VQ`  
**Slice:** `VQ-1`  
**Original baseline:** `40aef01c5c89dc9e02bba50d31c884dcdd2fd2d5`  
**Latest integration baseline re-read:** `5c549e950df98d0cf0c0ef22ac1b682ec2d3bef1`  
**Production code changed by VQ:** no

## Purpose

VQ-1 builds the independent verification and qualification layer for the immutable SWAP 4.3.1 audit baseline (`B0`), the corrected SWAP 4.3.1 reference lineage (`B1`) and SWAP5 full-accuracy reference mode (`B2`).

Git plus accepted versioned documentation remain the source of truth. VQ does not redefine production physics and does not repair production code. It supplies reproducible runners, comparison contracts, hard acceptance gates and qualification evidence.

## Source-of-truth inputs

VQ-1 is anchored to:

- `docs/architecture/invariants.md`;
- `docs/architecture/data-ownership.md`;
- `docs/decisions/ADR-0002-transactional-time-stepping.md`;
- `docs/decisions/ADR-0005-reference-baseline-chain.md`;
- `docs/verification/principles.md`;
- `docs/verification/reference-baselines.md` and `reference-baseline.json`;
- `reference/swap-4.3.1/b1-manifest.yml` and immutable B1 snapshot definitions;
- `docs/verification/legacy-differences.md`;
- `docs/development/workstreams.md`.

The B0 distribution identity is fixed by size and SHA-256. A file whose version label matches but whose cryptographic identity differs is not B0.

## Minimal qualification harness

The minimum useful harness has six independent layers.

| Layer | Responsibility | Must not do |
| --- | --- | --- |
| Reference identity | verify exact B0/B1/B2 source, snapshot or executable identity | infer identity from a version string |
| Runner adapter | invoke B0, B1 or B2 through a thin external adapter | embed legacy file parsing in the SWAP5 kernel |
| Case manifest | pin initial state, parameters, forcing, interval, numerical policy and expected outputs | rely on hidden working-directory state |
| Canonical result adapter | expose comparable state, integrated flux, storage and diagnostics | compare arbitrary text output as the primary oracle |
| Qualification gates | evaluate mass balance, reference equivalence and transactional properties | turn a hard failure into a warning |
| Difference registry | classify every admitted B0/B1/B2 difference | silently bless an unexplained divergence |

The harness is outside production physics. Model-specific adapters may know how to invoke legacy programs or translate legacy output, while comparison and acceptance logic remain version-neutral.

## Reference chain

The comparison chain is:

```text
B0 exact immutable audit baseline
  -> B1.x immutable corrected-reference snapshot
  -> B2 exact SWAP5 reference-mode commit
```

Rules:

1. B0 identity is verified before its outputs are admitted as evidence.
2. A B1 comparison pins the exact immutable snapshot definition, accepted patch hashes and integration commit used.
3. Every B2 qualification result pins the exact B1 snapshot used as corrected legacy oracle.
4. An unexplained difference at either comparison edge is a failed qualification.
5. A confirmed B0 defect is not recreated in B2 for compatibility; corrected behaviour is admitted through B1 first.

## Current B1 reference

Parallel reference work has now established an integrated corrected-reference workspace in `reference/swap-4.3.1/`.

At integration commit:

```text
5c549e950df98d0cf0c0ef22ac1b682ec2d3bef1
```

`b1-manifest.yml` identifies:

```text
snapshot: B1.3
status: CORRECTED_REFERENCE
patches: SWAP-001, SWAP-005, SWAP-006
published B1 snapshots: immutable
```

`reference/swap-4.3.1/snapshots/B1.3.yml` separately pins the B0 source identity and exact accepted patch hashes. This satisfies the VQ-1c entry condition. A dedicated external B1 repository is not required by the current accepted architecture.

## Hard mass-conservation gate

Mass conservation is a blocking acceptance condition for every accepted path, including retry, fallback, coupled and performance-oriented execution.

The VQ logical contract is specified in:

```text
docs/verification/mass-accounting-contract.md
tools/vq/contracts/mass-accounting-record.schema.json
```

VQ recomputes the interval residual from unrounded start/end storage and signed interval-integrated external water terms. A production-reported residual is diagnostic only.

A case cannot be `QUALIFIED` when:

- the independently recomputed water-balance residual exceeds its qualified accounting tolerance;
- required storage or external flux/source terms are missing;
- the sign or component/interface identity is ambiguous;
- rejected trials contribute to committed accounting;
- an accepted retry or fallback route cannot show exactly-once committed accounting.

VQ does not invent one universal tolerance value. Tolerances require named qualification evidence and may not be loosened by numerical execution policy.

Legacy `.BAL/.BLC` files remain regression evidence only because their water values are rounded to `0.01 cm`.

## Transactional qualification set

| ID | Property | Acceptance condition |
| --- | --- | --- |
| `TX-ROLLBACK-01` | rejected trial rollback | committed physical state and accounting unchanged after rejection |
| `TX-COMMIT-01` | accepted endpoint commit | committed endpoint equals accepted trial endpoint within representation tolerance |
| `TX-ACCOUNT-01` | exactly-once accounting | rejected-trial flux/source integrals never enter committed totals |
| `TX-RERUN-01` | rerun from same state | identical committed state and inputs give deterministic or tolerance-consistent physical results |
| `TX-BC-REPLAY-01` | changed-boundary replay | a new trial starts from the identical committed physical state with changed boundaries |
| `TX-WARM-01` | warm-start independence | numerical warm-start changes do not change accepted physical result outside qualified tolerance |

Numerical scratch or warm-start data may differ. Physical committed state may not be contaminated by rejected work.

## Generic-time qualification set

| ID | Interval characteristic |
| --- | --- |
| `TIME-00` | midnight-to-midnight control |
| `TIME-06` | non-midnight start, six-hour interval |
| `TIME-18` | non-midnight start, eighteen-hour interval crossing midnight |
| `TIME-36` | non-day interval crossing a calendar boundary |
| `TIME-SPLIT` | one interval versus an equivalent split where no physical event changes the contract |

The oracle compares physical endpoint state, integrated accounting and relevant event/reporting diagnostics. Calendar boundaries may affect results only where documented physics, forcing or reporting semantics require it.

## Minimal regression inventory

The B0 package supplies four useful official case families:

- Hupselbrook;
- grass growth;
- macropore flow;
- salinity stress.

They are smoke/regression inputs, not a complete physics qualification suite. Current detailed qualification status is recorded in `docs/verification/vq-1b-evidence.md` and `tools/vq/cases/b0-official-case-matrix.json`.

Separate architecture-directed cases remain required for transaction rollback, exactly-once accounting, rerun, warm-start independence, generic time, difficult-column fallback, coupling conservation and later response-tangent checks.

## Expected-difference registration

Every comparison record identifies the edge explicitly: `B0->B1`, `B1->B2` or, for diagnosis only, `B0->B2`.

Each expected non-zero difference records at least:

```text
difference_id
comparison_edge
status
source finding / decision
first admitted snapshot / commit
affected variables or diagnostics
expected direction or bounded envelope
qualification evidence
known unchanged scope
```

Allowed legacy statuses include `OBSERVED`, `BUG_CONFIRMED`, `FIX_TESTED`, `ADMITTED_B1`, `MODEL_CHANGE` and `DOC_ONLY`. `OBSERVED` never counts as an expected passing difference.

## Current bootstrap facts

- exact B0 archive identity: qualified;
- packaged native Linux B0 execution in current environment: blocked by missing `libimf.so`;
- provisional GNU exact-source runner: available but capability-limited and not native-equivalent;
- official grass-growth input: full unchanged GNU-runner smoke/repeatability pass;
- Hupselbrook: published balance cross-check passes through an explicit CSV-disabled runner-portability workaround;
- full official macropore case: not yet qualified within the current bounded execution window; bounded process-path smoke passes;
- salinity: bundled R preprocessing unavailable in the environment; reconstructed process smoke remains provisional;
- hard B2 mass-accounting verification contract: defined, production exposure not yet integrated;
- B1.3: available as immutable corrected-reference snapshot;
- integrated B2 production reference entry point: not yet available;
- TX/generic-time tests: specified but not yet executable against the final B2/TX interface.

## Integration points

### `VQ-1a` — bootstrap contract

Delivered:

- minimal harness and acceptance matrix;
- executable exact-B0 identity verification;
- initial B0/B1/B2 reference-chain rules.

### `VQ-1b` — runnable B0 adapter and accounting contract

Delivered/progressed:

- provisional exact-source B0 runner with explicit capability boundary;
- canonical legacy balance extraction;
- official-case hardening matrix and repeatability evidence;
- correction of the GNU vector-CSV issue to runner/compiler portability, not a confirmed B0 defect;
- proposed unrounded mass-accounting verification contract and machine-readable schema.

Remaining runner limitation: native Intel cross-execution or a separately qualified portability build is still desirable for paths not qualified under GNU.

### `VQ-1c` — formal B1 pin and B0/B1 edge

**Entry condition: met.** Current accepted reference is B1.3 at the exact integration baseline recorded above.

Next deliverables:

- pin B1.3 snapshot definition and exact integration commit in a VQ case/run record;
- derive/build B1.3 reproducibly from B0 plus the ordered accepted patch set;
- compare B0/B1 on focused affected and unaffected cases;
- reconcile every expected difference with the accepted legacy difference ledger;
- fail on unexplained divergence.

### `VQ-1d` — B2 reference adapter

Entry condition: an integrated SWAP5 reference-mode API or executable exists on an exact commit.

Deliverables: B1/B2 equivalence harness and canonical result adapter.

### `VQ-1e` — transactional and generic-time gates

Entry condition: relevant TX/B2 interfaces are integrated and callable without private implementation access.

Deliverables: executable `TX-*` and `TIME-*` qualification records, including the hard unrounded mass-accounting gate.

## Workstream handoff record

```text
WORKSTREAM
VQ

ORIGINAL BASELINE
40aef01c5c89dc9e02bba50d31c884dcdd2fd2d5

LATEST INTEGRATION BASELINE RE-READ
5c549e950df98d0cf0c0ef22ac1b682ec2d3bef1

SCOPE
Independent B0/B1/B2 verification and qualification infrastructure.

COMPONENTS/FILES TOUCHED
docs/verification, tools/vq, documentation navigation/workstream status only.

INTERFACES CHANGED
No production interface. VQ defines external verification contracts only.

INVARIANTS AFFECTED
7, 8, 9, 10, 11, 12, 13, 17, 18, 19, 23, 24, 25, 26, 28, 29, 30.

TEST/QUALIFICATION STATUS
B0 identity and selected B0 regression/repeatability paths qualified within documented capability limits. B1.3 is now available; B0/B1 edge comparison has not yet been executed. B2/TX end-to-end qualification is not yet available.

DEPENDENCIES / REQUIRED INTEGRATION
Controlled integration of the VQ branch with current main; B2 reference-mode entry point; TX callable transaction boundary; production mapping to the VQ mass-accounting contract.

NEXT SAFE STEP
Start VQ-1c by pinning B1.3 and executing the first controlled B0 -> B1 comparison, while keeping the VQ branch integration explicit and leaving production physics unchanged.
```
