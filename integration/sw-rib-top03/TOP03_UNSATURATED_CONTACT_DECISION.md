# TOP03 unsaturated-contact prerequisite decision

Date: 2026-10-02.
Status: STATIONARY_CONTACT_ORACLE_BLOCKED_BY_ORIGIN_FROZEN_INTERIOR_K__NO_PRODUCTION_ADMISSION.

## Decision

The zero-storage explicit-layer construction is not yet a fully nonlinear
stationary contact oracle. At SWKIMPL=0 the real solver freezes interior
conductivities at the solve origin. Algebraic layer rows conserve flux under
that lagged numerical law; they do not enforce equal physical face fluxes
when every K is reconstructed from final candidate pressures. Adding zero
capacity alone is therefore insufficient to implement the proposed nonlinear
stationary layer elimination.

The independent audit distinguishes this limitation from a solver mass defect:
the source-bound origin-K scheme passes both local and cumulative interface
mass checks, while the current-K stationary prerequisite fails. No production
solver repair, tolerance relaxation, conductivity cutoff change or mode1
admission is authorized by this finding.

## Executed scope and hard evidence

The preregistered L=0.20 cm, R=0.50/1.00 day factorial covers three space and
three time levels, dry/prewetted layer origins, physical versus fixed-Ksat
layer conductivity, and physical versus zero layer storage. The underlying
soil, forcing, head datum, free-drainage bottom and real numerical policy
remain fixed. A separate constant-R comparator preserves the previous law.

- Primary source: b51def6e552db4a129371c80359a7f723dfa4d89.
- Candidate-K audit source: 1276dbc2e8a6c165842cac048d51d07ee993e599.
- Source-scheme audit source: 3ae05b280aef2850280426662e889c1bf7ed6f45.
- Each phase runs 192 cases at O0 and O2: 162 complete dynamic trajectories
  and 30 saturated analytical controls per build. Three phases total 1152
  executed cases, 192 distinct configurations. Every trajectory completes.
- O0/O2 outputs agree exactly in every phase. Diagnostic-only edits preserve
  all preceding raw trajectories exactly after removing their added lines.
- All 54 overlapping original explicit/constant-R trajectories reproduce
  the archived preceding extension exactly in each phase.
- All 21 compiled repository files per phase match their pinned Git source
  SHA-256 identities. The generated reference stub preserves FVQ89 Thomas
  and distance-weighted harmonic algebra. GNU Fortran 13.3.0 runs with
  bounds checks and floating-point traps.
- Saturated controls: maximum head error 1.777e-15 cm and flux error
  1.875e-13 cm/day, within their unchanged hard gates.
- Maximum whole-soil integrated mass discrepancy: 3.906e-14 cm.
  Request origins remain exactly unchanged, including rejected-solve checks.
- Independent origin-K local integrated layer residual: at most
  7.370e-15 cm. Cumulative interface-ledger discrepancy: at most
  4.086e-14 cm. Both pass the fixed 1e-10 cm mass bound.
- Independent candidate-K audit: maximum local integrated residual
  0.1620064 cm and cumulative interface discrepancy 0.1095150 cm across
  the fixed matrix. All 144 explicit-layer dynamic cases fail at least one
  audit. This is not the residual of the implemented origin-K scheme.

## Physical interpretation remains bounded

The initial fixed-budget classifications are preserved as provisional
observations. Stationary-versus-full-layer comparisons gave 5 ready budget
failures, 9 budget passes and 10 unavailable refinement comparisons. The
five failures are dry-start top-transfer deficits; all ready prewetted
comparisons passed those budgets. At the final event, dry layer storage is
approximately 0.0232 cm, while the algebraic diagnostic owns no change.

The conductivity factorial shows 15 ready discrepancies with storage retained
and 15 without storage; each has 9 unready comparisons. Matching the explicit
Ksat algebraic layer against the old constant-R face law gives 24 provisional
budget passes. These observations motivate the nonlinear conductivity plus
owned-storage design. They do not qualify a stationary physical reduction:
the stronger independent stationary-contact prerequisite failed, so every one
of the 120 new physical classifications is null in the final result. Do not
select a closure on final heads or solver completion alone.

This does not erase the prior explicit-layer decision under its declared
numerical policy and joint refinement budgets. It establishes a new limitation
of the proposed stationary oracle and prevents promoting its provisional
factorial separation into a qualified boundary-only law. The origin-K audit
also explains why different algebraic starting guesses can leave small
transient cumulative differences without defining physical layer memory.

## Concrete next design and authority boundary

`TOP03_UNSATURATED_CONTACT_ELIMINATION_DESIGN.md` defines the local nonlinear
layer residual, matched interface head/conductance, saturated limit and the
separate external/matrix transfer identity:

Iexternal - Imatrix = DeltaWlayer.

The next test-only implementation must solve local layer pressures with K at
the same candidate pressures, independently of the global SWKIMPL=0 loop.
It needs candidate-K face closure and two-sided interface-head controls before
serving as a stationary oracle. A stateful reduction must also retain the
immutable layer origin and owned candidate storage. The current dynamic-top
result has no explicit layer-state/storage ownership contract; hidden mutable
provider storage is not a valid substitute. Production integration requires
that shared contract and its accepted/rejected-branch, receipt and restart
qualification. This is the real architectural boundary reached by this study.

Canonical moved from 800f6a9b to 0c18a9ff while the dedicated research ran.
The inspected delta adds LOW03-A implicit Cauchy application ownership and
mode3 temporal bottom stiffness, plus unrelated oxygen performance work and
LOW08-P0 preregistration. The exact research source remains pinned. Do not
inherit current-canonical solver/runtime/transaction qualification. No merge,
new branch or Actions run is part of this work; PR #956 remains draft.
BASE exact-state acceptance, surface-storage ownership and real top-active
receipt/replay/exactly-once commit remain unqualified.

## Evidence and replay

`TOP03_UNSATURATED_CONTACT_RESULT.json` stores final null physical verdicts,
provisional budget observations, readiness chains, both independent audits and
all mode/origin layer diagnostics. `evidence/unsaturated_contact/raw_records.tar.gz`
contains the three O0/O2 phases, cases, source manifests, generated stubs, logs,
source reconciliation, inherited records and verification evidence. Its manifest
records source pins and SHA-256 identities.

Run `run_sw_rib_top03_stationary_layer.py` at each pinned source, with an empty
build directory and GNU Fortran 13.3.0. The final analyzer takes the final build,
`--previous` inherited extension, `--primary` primary phase and `--audit`
candidate-K audit phase, plus exact `--source` and `--canonical` identities.
Diagnostic line removal is enforced before inherited or earlier-phase replay
comparisons. Documentation source checks and strict MkDocs build pass.
