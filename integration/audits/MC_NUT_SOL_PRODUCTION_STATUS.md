# MC-NUT01 / MC-SOL01 production successor

Status: **IMPLEMENTATION_CLOSED_PENDING_PERSISTED_QUALIFICATION**

Active binding branch: `work/swap431-nut-sol-binding-20261007`

## Current closeout authority

The authoritative implementation tree is the head of
`work/swap431-nut-sol-binding-20261007`. Persisted qualification must use an
immutable qualification branch cut from that exact tree; do not reuse the
historical #1112 head or an older closeout SHA.

MC-NUT01 and the supported MC-SOL01 capabilities have no remaining
implementation gap on this branch. Remaining work is persisted O0/O2
qualification, canonical admission, and master-census reconciliation.
`SW431-SALT-AQUIFER` is definitively `UNSUPPORTED_SOURCE_DEFECT` and is not
remaining implementation work.

## Transaction owners now present

- Soil-N owner: FOM, biomass OM, humus OM, NH4-N and NO3-N are one
  transaction state with whole-N storage accounting, candidate-only mutation,
  rejected-overdraw rollback, and restart reconstruction.
- Solute owner: dissolved mobile mass plus sorbed matrix, pond, aquifer storage
  and age amount are carried atomically. Chemical mass excludes age amount.
- A combined reactive transaction now executes exact-order chemical sorption/decay/pond transfer and AgeTracer transport/production on the same accepted carrier and commits or rolls back both together.
- Runtime now has a distinct reactive solute layout identity (`505005`) with a typed initializer and restart validator; existing mobile-only layouts reject reactive companion state.
- Aquifer mutation is fail-closed in the current solute transaction model.

## Source-bound operators present

- B1.11 fixation policy, separate from admitted WOFOST81 semantics.
- Shared Soil-N management-event binding for amendments and crop residues: persistent event id, once-only application, duplicate rejection, and restart-preserved event lineage.
- B1.11 grouped amendment calendar binding: sorted source-order groups, same-date atomic materials, exact `TimeAmend+1` trigger and monotone restart cursor.
- Ordinary and harvest crop residue continuation: retained dead crop N remains storage; root/leaf/stem/storage harvest residues persist separately and are consumed once by the next Soil-N day.
- Coupled Soil-N/crop-N state now persists previous-day root/leaf residue DM+N and consumes that residue before the next-day Soil-N process, matching the B1.11 day ordering for ordinary senescence.
- Soil-N source rate factors plus source-coupled mineral reaction bridges: NH4 disappearance from aggregate transport is converted into equal NO3 production, while NO3 first-order disappearance is booked as explicit external denitrification loss. Both use the interval-average transported concentration and preserve whole-N accounting.
- Aggregate Soil-N transport plus a one-day B1.11 mineral exchange caller and an integrated Soil-N candidate composing organic turnover, Cdissi-dependent rates, NH4/NO3 transport, nitrification and denitrification on one owner.
- Amendments and crop residues, including distinct B1.11 OM activation
  thresholds (1e-6 and 1e-12 respectively).
- Freundlich sorption, solute decay, pond exchange and age production.

## Not yet canonical admission

These owners/operators and the new reactive carrier layout are not by themselves proof of application-level
production reachability. Census capabilities remain open until the relevant
runtime/application route, restart identity and persisted qualification are
bound and reviewed.

## Explicit decision boundaries

- `SW431-NUT-ORGANIC`: the exact-source inconsistency is resolved by an accepted mass-consistent reference correction; production qualification still has to admit the integrated daily route. See `MC_NUT01_ORGANIC_SOURCE_DECISION.md`.
- `SW431-SALT-AQUIFER`: definitive `UNSUPPORTED_SOURCE_DEFECT`; exact B1.11 has a reproduced out-of-bounds SWBR coefficient access and no defensible aquifer bulk-density parameterization. See `MC_SOL01_AQUIFER_SOURCE_DECISION.md`.

An atomic B1.11 Soil-N/crop-N transaction candidate now prepares crop soil demand, runs the Soil-N day, feeds the accepted Soil-N supply into the separate B1.11 crop-N owner, books soil uptake once as an internal transfer, books biological fixation once as external N input, and persists accepted interval lineage. WOFOST81 remains unchanged and N-unlimited on its already admitted route.

## 2026-10-07 nonlinear reactive SOL qualification recovery

- Canonical CI fanout fix was merged independently via PR #1116, merge
  `7e35749e8348f6d4ef0b35b96c8b06cb216ea036`. This does not qualify SOL.
- The matrix reactive substep, the combined chemical/age transaction and
  the accepted water-carrier adapter predate this update on the binding branch.
- A previously uncovered nonlinear Freundlich conflict was found: the
  inverse partition used a 1e-3 relative iterate stopping criterion while
  whole-chemical mass closure requires roundoff-scale closure. This could
  reject otherwise physically valid nonlinear substeps as unbalanced.
- The nonlinear inversion now uses a monotone bracket/bisection, retains
  the linear fast path, and returns NOCONV rather than silently admitting a
  result outside the mass tolerance. Current code recovery commit:
  `31db12cb1ebd5e2de89e6cd1b55e7ab400665834`.
- The multi-node test now checks `frexp=2`, total chemical conservation,
  concentration-dependent sorbed storage and rejected overdraw rollback.
  Test recovery commit: `d9078c6ce88fbc36fd83d7f93b11b0934f124361`.
- Locally exercised the **isolated mathematical bisection algorithm** on
  10,000 nonlinear storage values, O0 and O2, with bounds/FPE checks. This
  is **not** a compile/test of the committed Fortran module or integrated
  transaction. The repository was accessed via the GitHub connector because
  local GitHub DNS access was unavailable.
- Existing qualification run `37644330458` remains queued and covers an
  outdated pre-binding postimage; do not count it as qualification for these
  commits. No new Actions run was started.
- Required next gate: run `tests/physics/run_b111_reactive_solute_substep.sh`
  and `tests/physics/run_fmr_b111_reactive_solute_transaction.sh` on the
  exact binding HEAD at O0/O2; retain restart/layout and accepted-water-carrier
  tests, then integrated qualification. Do not admit any SOL01 capability
  before that evidence is persisted.

### Follow-up focused operator qualification

The nonlinear inverse correction also exposed the previous near-linear
`abs(frexp-1)<1e-3` fast-path defect. That shortcut did not close chemical
mass for `frexp=1.0005`; its observed regression residual was
`-1.8389259114584555E-005`. The fast path is now restricted to exponents
within machine epsilon of unity. Fix commit: `4593cd1039ebe8b33951d9de658d59afe66ef96a`.

The exact committed Fortran source, test and runner blobs were reconstructed
locally and each was verified with `git hash-object` against the connector
blob SHA. The actual standalone repository runner passed at `-O0` and
`-O2` using gfortran 14.2, with bounds/FPE checks, for 30,000 values per
optimization (`frexp=2, 0.5, 1.0005`). Evidence:
`integration/audits/evidence/MC_SOL01_FREUNDLICH_MASS_CLOSURE_LOCAL_QUALIFICATION.json`.
This establishes **only** the focused partition operator. The coupled
matrix/age substep, accepted water trace, restart, integrated O0/O2 and
canonical admission remain unqualified on this updated binding postimage.

## 2026-10-08 legacy qualification failure reconciliation

Superseded PR #1112 qualification run `37644330458` completed **FAILED**. The
first six content steps succeeded; exact B1.11 NUT/SOL source gate rejected
its expected temperature-dependent `r1` equation, so subsequent integrated
qualification steps did not execute. The negative evidence is preserved at
`integration/audits/evidence/MC_NUT_SOL_OLD_QUALIFICATION_RUN_37644330458.json`.
It qualifies neither the old PR nor the substantially expanded binding HEAD.

Source-gate review identified an additional deterministic defect: the script
referenced `SWAP/management_soil.f90` and `SWAP/cropgrowth.f90` but did not
extract them into its `members` map. Fixed at commit
`62e2d2f6b51969def0752e0b0ec00f7f9427967d`. The gate still checks
pinned SHA-256 for its previously pinned set of B1.11 source files; the two
additional files are read from the same repository-bound authority archive.

The temperature-rate equation mismatch is **not** waived or rewritten on
speculation. The fail-closed error now includes line-numbered assignments
from the archive's exact `wofost_soil_rateconstants.f90` to distinguish a
text-oracle formatting mismatch from real physical disagreement. Diagnostic
commit: `9470de377a69b3e6a039eb2b3e21337a609539cb`.

No fresh full-head qualification was executed for this recovery increment.
The next safe test is to execute the exact-source probe on the current
binding postimage, inspect any printed exact-source equation, and only then
change equation matching or physical code with a justified oracle. No
capability status was upgraded to ADMITTED.

## 2026-10-08 exact-head qualification #1117 outcome

Run `37726458263` on binding head `b57e5729d73088affbe9256f06c847678f5c66c9` **FAILED** in the exact-source gate before integrated physics tests. Its exception was `KeyError: filename 'SWAP/cropgrowth.f90' not found` while extracting the declared additional members. This is a missing exact-authority source, not a demonstrated physics regression and not a PASS. The gate was repaired to fail with an explicit missing-source inventory (`845bb53a65a5b0c58984f35015cf99c70b8adce4`), but no successor gate was run.

The current bundle demonstrably does not contain `SWAP/cropgrowth.f90`; source-oracle qualification for crop orchestration cannot be completed by merely widening the lookup dictionary. Supply a byte-exact, separately hash-pinned B1.11 cropgrowth source authority and verify all required management/crop members before rerunning integrated qualification. Keep all NUT/SOL capabilities unadmitted, and avoid new Actions until the source bundle boundary is resolved locally.

## 2026-10-08 source-location correction

GitHub tree inspection confirms `cropgrowth.f90` and `management_soil.f90` are available in `SWAP-model/SWAP` at `src/crop/` on `main` (Git blobs `41e407a952c9654c1babf0840da17aaecbb7e3c5` and `e890863a953be3d6c34a602fd08b052d86196c95`). The NUT/SOL CI `KeyError` does **not** mean the files are missing from GitHub. It means `SWAP/cropgrowth.f90` was not a member of the workstream's **partial** `SWAP431_B111_AUTHORITY.tar.gz.b64` evidence bundle. Public SWAP `main` must not silently replace exact B1.11 source authority; its presence proves a GitHub location, not byte identity with B1.11. Qualification must either acquire/pin the matching B1.11 source revision and its hashes, or scope the exact-source probe to the B1.11 files already byte-pinned while leaving crop-orchestration qualification explicitly open. No capability admission is inferred from this discovery.

## 2026-10-08 exact B1.11 authority resolution

The missing-`cropgrowth.f90` error in run `37726458263` resulted from
an incorrect **archive membership assumption**, not missing historical
sources. Independent extraction of the pinned 63-member authority bundle
identifies crop demand/fixation/harvest expressions in the present
`SWAP/wofostnut.f90` (SHA-256
`071e65763be9e771b32b417252584d50874715d9ff11d3482c131826cc80bbb2`).
The exact archive's `SWAP/management_soil.f90` SHA-256 is
`0edba713f71840fca320d17162fd3d3e59ff2acf702df3393188fe4a2fd6c43b`.
Its unsorted-date rejection and strict zero grouping differ materially
from public SWAP source and from the proposed SWAP5 tolerant-grouping
calendar. The original `ACCEPTED_REFERENCE_CORRECTION` calendar claim
is suspended in `MC_NUT01_AMENDMENT_CALENDAR_SOURCE_DECISION.md` pending
a distinct source-policy decision. No new Actions run was started.

The exact-source probe still requires carefully bounded correction of its
literal needles and archive manifest before it can qualify any integrated
NUT/SOL scope. In particular, no fallback to mutable public `main` is
permitted; `1.d0`/`1.0d0` normalization may preserve numeric meaning,
but the physical predicate `<0.d-3` may not be normalized into `<1e-3`.


## 2026-10-08 restricted rate oracle repair

The source gate now accepts only equivalent decimal spellings of Fortran
D-exponent *integer-valued* literals (e.g., `1.0d0` versus `1.d0`).
It does not change powers, coefficients, arithmetic operations, or physical
predicates; the archived source SHA validation still precedes comparison.
The previous double-escaped rate-assignment diagnostic was also corrected.
Commit: `77ab26bcb310a059a004432251d295efdc146a12`.

A three-case local lexical smoke test passed. This is not a replay of the
complete exact B1.11 archive probe, and it is not O0/O2 integrated
qualification. Full archive replay and any remaining source-equation
discrepancies remain open. No Action was requested.

## 2026-10-08 source-oracle reconciliation checkpoint

The source-bound Soil-N organic witnesses were corrected against the independent byte-exact B1.11 archive audit: organic FOM turnover includes an explicit `-1.d0` factor, and the historical defective `Nminer` expression multiplies the FOM mass change `(FOM_t0(fn)-FOM_t(fn))`, not a free `help` token. Numeric D-literal spelling is normalized only lexically for these witnesses. Commits: `0b7c843f5b07bc8964138acd31b1021944be7087`, `045dee6522ab36f4ec6d2f746881dd7369b0ddc1`.

**Qualification ceiling:** These edits are source-oracle repairs informed by the previously recorded exact-source audit. Full `probe_b111_nut_sol_exact_source.py` replay and combined O0/O2 have not been executed for this postimage, because the local shell has `gfortran` but no DNS route to GitHub; the GitHub connector can read/write the repository independently. No new Actions run was requested. Any further mismatch must be verified against the archive's actual bytes, never accepted on the strength of textual resemblance alone. The amendment-calendar semantic decision remains open and no NUT/SOL capability is admitted.

## 2026-10-08 local execution boundary and regex regression

A local compiler and Git are available. Direct `github.com` and
`api.github.com` DNS requests from the local shell failed. GitHub connector
access is functional, but its read response is not an automatically mounted
local filesystem. Accordingly, a **full** local source-archive replay or
integrated O0/O2 test on the current branch was **not** executed here.

A concrete latent bug was repaired in the source gate: the raw regular
expressions for normalized Fortran D-literals and the assignment diagnostic
were double-escaped, preventing actual normalization. The corrected gate was
re-read at Git blob `c85e98a8c5b493301b61505b7cf34a66ce9ffb96`.
A local Python smoke test of the corrected normalizer passed seven focused
inputs, including nonzero decimals, near-linear exponents, negative literals,
identifier boundaries, and the `0.d-3` predicate. This is **lexical-only**
evidence, not an archive-source PASS.

A regression script is committed at
`tests/physics/test_b111_source_literal_normalization.py`, commit
`51c0d3f7d39dcd8dae69c49db2b23ef68864b35a`. It extracts only the
pure normalization function AST from the gate so it does not require the
full B1.11 bundle to run. No new GitHub Actions run was requested. Preserve
the source-policy decision for NUT-AMEND and do not upgrade any disposition.
