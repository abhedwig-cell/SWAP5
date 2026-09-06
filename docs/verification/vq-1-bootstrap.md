# VQ-1: Verification and reference qualification bootstrap

**Status:** Active  
**Workstream:** `VQ`  
**Slice:** `VQ-1`  
**Baseline:** `40aef01c5c89dc9e02bba50d31c884dcdd2fd2d5`  
**Production code changed:** no

## Purpose

VQ-1 starts the independent verification and qualification layer for the immutable SWAP 4.3.1 audit baseline (`B0`), the corrected SWAP 4.3.1 reference line (`B1`) and SWAP5 full-accuracy reference mode (`B2`).

Git plus accepted versioned documentation remain the source of truth. VQ does not redefine model physics and does not repair production code. It supplies reproducible runners, comparison contracts, hard acceptance gates and evidence that other workstreams can use.

## Source-of-truth inputs

VQ-1 is anchored to:

- `docs/architecture/invariants.md`;
- `docs/decisions/ADR-0002-transactional-time-stepping.md`;
- `docs/decisions/ADR-0005-reference-baseline-chain.md`;
- `docs/verification/principles.md`;
- `docs/verification/reference-baselines.md` and `reference-baseline.json`;
- `docs/verification/legacy-differences.md`;
- `docs/development/workstreams.md`.

The current B0 distribution identity is fixed by SHA-256 and size. A file whose version label matches but whose cryptographic identity differs is not B0.

## Minimal qualification harness

The minimum useful harness has six independent layers.

| Layer | Responsibility | Must not do |
| --- | --- | --- |
| Reference identity | verify exact B0/B1/B2 source or executable identity before a run | infer identity from a version string |
| Runner adapter | invoke B0, B1 or B2 through a thin external adapter | embed legacy file parsing in the SWAP5 kernel |
| Case manifest | pin initial state, parameters, forcing, interval, numerical policy and expected outputs | rely on hidden working-directory state |
| Canonical result adapter | expose comparable state, integrated flux, storage and diagnostics fields | compare arbitrary text output as the primary oracle |
| Qualification gates | evaluate mass balance, reference equivalence and transactional properties | turn a hard failure into a warning |
| Difference registry | classify every admitted B0/B1/B2 difference | silently bless an unexplained divergence |

The harness is intentionally outside production physics. A model-specific adapter may know how to start a legacy executable or translate its output, but the comparison and acceptance logic must remain model-version neutral.

## Reference chain

The executable comparison chain is:

```text
B0 exact immutable audit baseline
  -> B1 exact corrected-reference tag + commit
  -> B2 exact SWAP5 reference-mode commit
```

Rules:

1. B0 identity is checked before its outputs are accepted as evidence.
2. B1 is unavailable as a formal oracle until the corrected-reference repository is seeded and an immutable B1 tag exists.
3. Every B2 qualification result pins the exact B1 tag and commit used as oracle.
4. An unexplained difference at either edge is a failed qualification.
5. A confirmed B0 defect is not recreated in B2 merely for compatibility. It must first enter the B1 difference ledger through the accepted admission path.

## Hard mass-conservation gate

Mass conservation is a blocking acceptance condition for every accepted path, including retry, fallback, coupled and performance-oriented execution.

Each case manifest must declare the accounting terms and a qualified numerical accounting tolerance. The harness evaluates a signed interval residual using one canonical convention and stores both the residual and the scale used for the tolerance check.

A case cannot be `QUALIFIED` when:

- the water-balance residual exceeds its declared accounting tolerance;
- required storage or flux terms are missing;
- the sign convention is ambiguous;
- an accepted retry or fallback route cannot show that integrated fluxes were committed exactly once.

VQ-1 does not invent one universal tolerance value. Tolerances must be justified for the case family and recorded as evidence. Missing tolerance evidence is `UNQUALIFIED`, not an implicit pass.

## Transactional qualification set

The first transaction gate contains the following properties.

| ID | Property | Acceptance condition |
| --- | --- | --- |
| `TX-ROLLBACK-01` | rejected trial rollback | committed physical state and committed accounting are unchanged after rejection |
| `TX-COMMIT-01` | accepted endpoint commit | committed endpoint equals the accepted trial endpoint within the declared representation tolerance |
| `TX-ACCOUNT-01` | exactly-once accounting | interval-integrated flux/source terms from rejected trials do not enter committed totals |
| `TX-RERUN-01` | rerun from same state | repeating from the same committed state with identical inputs is deterministic or tolerance-consistent |
| `TX-BC-REPLAY-01` | changed-boundary replay | a second trial can start from the identical committed physical state with changed boundary conditions |
| `TX-WARM-01` | warm-start independence | changing or removing numerical warm-start information does not change the accepted physical result outside qualified tolerance |

Numerical scratch or warm-start data may differ. Physical committed state may not be contaminated by a rejected path.

## Generic-time qualification set

Calendar-day equivalence is not sufficient evidence. The minimum time matrix contains:

| ID | Interval characteristic |
| --- | --- |
| `TIME-00` | midnight-to-midnight control case |
| `TIME-06` | non-midnight start, six-hour interval |
| `TIME-18` | non-midnight start, eighteen-hour interval crossing midnight |
| `TIME-36` | non-day interval crossing at least one calendar boundary |
| `TIME-SPLIT` | one interval compared with an equivalent partition into sub-intervals where no physical event requires a different result |

The test oracle compares physical endpoint state, integrated flux accounting and relevant event/reporting diagnostics. A calendar boundary may affect a result only where a documented physical or forcing/reporting rule requires it.

## Minimal regression inventory

VQ-1 distinguishes a small smoke set from later coverage expansion.

### B0 smoke candidates

The supplied B0 distribution contains four official case families that are useful as initial external-runner smoke cases:

- Hupselbrook;
- grass growth;
- macropore flow;
- salinity stress.

They are not by themselves a complete physics qualification suite. Their first purpose is to prove deterministic invocation, output capture, provenance and water-accounting extraction across materially different legacy configurations.

### Architecture-directed cases

Separate focused cases are required for properties that legacy official examples were not designed to prove:

- transaction rollback and exactly-once commit accounting;
- rerun from an identical committed state;
- warm-start independence;
- non-midnight and non-day intervals;
- difficult-column/reference-versus-fallback qualification;
- later, coupling residual and response-tangent checks.

These cases should be as small as possible. Large seasonal cases remain useful as regression evidence but should not be the only oracle for a state-transition contract.

## Expected-difference registration

Every comparison record identifies both sides explicitly: `B0->B1`, `B1->B2` or, for diagnosis only, `B0->B2`.

Each non-zero expected difference records at least:

```text
difference_id
comparison_edge
status
source finding / decision
first admitted tag or commit
affected variables or diagnostics
expected direction or bounded envelope
qualification evidence
known unchanged scope
```

Allowed statuses are inherited from the legacy difference policy where applicable: `OBSERVED`, `BUG_CONFIRMED`, `FIX_TESTED`, `ADMITTED_B1`, `MODEL_CHANGE` and `DOC_ONLY`. B2-specific model changes require their own accepted decision and qualification evidence. `OBSERVED` never counts as an expected passing difference.

## Current bootstrap facts and blockers

- The exact B0 archive available to this workstream has been checked locally against the documented B0 size and SHA-256 and matches.
- The supplied B0 Linux executable is an Intel Fortran build. In the current verification environment it does not start because `libimf.so` is unavailable. This is an environment/runtime dependency, not a model failure.
- No formal B1 snapshot exists yet according to the current reference documentation. VQ must not invent one.
- The current SWAP5 repository is documentation-led and does not yet contain an integrated B2 production reference executable/API. Transaction and generic-time tests can therefore be specified now, but end-to-end B2 qualification waits for an explicit integration point.

## Integration points

VQ-1 is deliberately split into small slices.

### `VQ-1a` — bootstrap contract

Deliverables:

- activate VQ on the exact Git baseline;
- record the minimal harness and acceptance matrix;
- provide executable B0 identity verification;
- register the known B1/B2 availability constraints.

No production code changes. This slice may merge independently.

### `VQ-1b` — runnable B0 adapter

Entry condition: a reproducible environment can run the exact B0 executable or a source build whose provenance is separately recorded.

Deliverables: smoke execution, canonical output extraction, water-balance extraction and repeat-run evidence.

### `VQ-1c` — formal B1 pin

Entry condition: `abhedwig-cell/SWAP-4.3.1-reference` is seeded and an immutable B1 tag exists.

Deliverables: B0/B1 edge comparison plus admitted difference records.

### `VQ-1d` — B2 reference adapter

Entry condition: an integrated SWAP5 reference-mode API or executable exists on an exact commit.

Deliverables: B1/B2 equivalence harness and canonical result adapter.

### `VQ-1e` — transactional and generic-time gates

Entry condition: the relevant TX/B2 interfaces are integrated and callable without private implementation access.

Deliverables: executable `TX-*` and `TIME-*` qualification records, including hard water-balance evidence.

## Workstream handoff record

```text
WORKSTREAM
VQ

BASELINE
40aef01c5c89dc9e02bba50d31c884dcdd2fd2d5

SCOPE
VQ-1 bootstrap of the independent B0/B1/B2 verification and qualification layer.

COMPONENTS/FILES TOUCHED
docs/verification and tools/vq only, plus documentation navigation/workstream status where required.

INTERFACES CHANGED
No production interface. VQ defines an external qualification contract only.

INVARIANTS AFFECTED
7, 8, 9, 10, 13, 23, 24, 25, 26, 29, 30.

TEST/QUALIFICATION STATUS
VQ-1a qualifies harness bootstrap and B0 identity checking only. Numerical model equivalence is not yet claimed.

DEPENDENCIES / REQUIRED INTEGRATION
B1 corrected-reference repository; integrated B2 reference-mode entry point; TX callable transaction boundary; reproducible B0 runtime.

NEXT SAFE STEP
Implement and test the B0 identity checker, then establish a runnable B0 adapter without touching production physics.
```
