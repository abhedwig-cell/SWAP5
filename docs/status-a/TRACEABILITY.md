# SWAP5 Status-A theory, code and evidence traceability

Date: 2026-09-17

SWAP5 does not have, and does not need, one artificial master theory file for all Status-A capabilities. Scientific and architectural authority is capability-distributed. This page makes that distributed authority navigable without replacing the underlying records.

## Pinned umbrella authorities

- Status-A acceptance authority: `992a5c657bfe10a10100f92e0cb77c4825ae65b6`
- scientific production baseline: `50346642bd565f79134ea17d5462e544b354998c`
- scientific production tree: `3b085d7dea3d3f3fce42ad9d8f259a8350205846`
- living canonical checked by F-TA02: `e9859b82ffa0d0776c340ef7d550ac8791e28dab`
- Status-A release-readiness acceptance record: [`STATUS_A_RELEASE_READINESS_BASELINE.md`](https://github.com/abhedwig-cell/SWAP5/blob/992a5c657bfe10a10100f92e0cb77c4825ae65b6/tests/qualification/status-a-baseline-20260916/STATUS_A_RELEASE_READINESS_BASELINE.md)
- permanent-testbank architecture/snapshot: [`F-TB11_CURRENT_CANONICAL_PERMANENT_PRESERVATION.md`](../testbank/F-TB11_CURRENT_CANONICAL_PERMANENT_PRESERVATION.md), explicitly bound to canonical `379afd11…`, not to the later Status-A head

The release-readiness record fixes the Status-A denominator and acceptance conclusion at its pinned authority. Capability-specific records remain the evidence for how an individual scientific or architectural claim was established. The later living canonical is not automatically covered by an older immutable preservation artifact.

## How to read a capability chain

For a Status-A capability, trace authority in this direction:

**scientific/reference contract → admitted production implementation → qualification evidence → canonical admission/closure → permanent preservation/regression authority**

The records at each step may live in different repository locations. That is intentional. A later umbrella acceptance record can establish that a previously qualified capability belongs to the current baseline without becoming the theory source for that capability.

## Current capability traceability map

| Capability | Theory / scientific or architectural contract | Production implementation authority | Qualification and canonical admission | Preservation authority / role |
| --- | --- | --- | --- | --- |
| Reference preservation | Legacy/reference behaviour and capability-specific preservation contracts. Historical SWAP material is reference authority, not current runtime architecture authority. | Scientific postimage contained in production baseline `50346642…`. | Capability-specific reference/verification gates, followed by Status-A acceptance `992a5c657…`. | Same-tree F-GC29 O0/O2 checksum equality and closure replay, plus applicable permanent scientific suites recorded by the release-readiness authority. Historical suite labels in that record are not executable repository locators; see the locator correction below. |
| Richards / soil-water admitted core | Existing soil-water scientific contracts and invariants within the admitted reference-preserving scope. No broader physics is created by Status-A. | Scientific postimage `50346642…`; exact source paths remain those named by the owning qualification/admission records. | Scientific/numerical qualification records and later canonical admission; Status-A denominator fixed by the release-readiness record. | Same-tree scientific and numerical replay recorded by the owning qualification chain. The historical `tests/run-kernel.sh` and `tests/run-numerical.sh` strings in release-readiness are suite labels, not repository paths at `992a5c…`. |
| Transaction architecture | State-ownership, trial/accept/retry/rollback and transaction invariants; see [Current Status-A architecture](CURRENT_ARCHITECTURE.md). | Transactional production postimage at `50346642…`. | Architecture/runtime qualification and canonical closure incorporated into Status-A acceptance. | Status-A same-tree preservation is owned by the applicable qualification/replay chain. The older pinned F-TB11 transaction/mass replay remains executable historical support through `testbank/runners/run_ftb11_current_source_replays.sh`; it is bound to `379afd11…` and is not an automatic rebind to `992a5c…` or `e9859b82…`. |
| Restart v1 | Bounded committed-state persistence/reconstruction contract. | Restart v1 production implementation within `50346642…`. | Restart qualification/admission records plus Status-A acceptance. | Same-tree F-GC29 restart observable and mass-preservation replay. Earlier F-TB11 Restart evidence remains historical immutable support, with executable replay through `testbank/runners/run_ftb11_current_source_replays.sh`, not an automatic rebind to the Status-A or later canonical head. |
| Serialized MultiSWAP v1 | Serialized orchestration contract over qualified real-physics paths. Parallel/concurrent real-physics semantics are outside this row. | MultiSWAP v1 production implementation within `50346642…`. | MultiSWAP qualification/admission records plus Status-A acceptance. | Same-tree F-GC29 observable and aggregate-mass replay plus relevant permanent/mixed-smoke evidence. Historical release-readiness suite labels are not executable locators. |
| Drainage | Existing admitted drainage scientific/process contract. | Drainage production implementation within `50346642…`. | Drainage scientific/numerical qualification and canonical admission incorporated into Status-A. | Moving-current preservation legs A and B reported PASS by the same-tree F-GC29 reconciliation. This supersedes the older F-TB11 snapshot limitation where Drainage was not yet credited. |
| Surface evaporation | Existing admitted surface-evaporation scientific/process contract. | Surface-evaporation implementation in `50346642…`. | Scientific/preservation qualification plus canonical admission; F-PE11 later closes bounded performance preservation without changing scientific semantics. | Same-tree inner-step free-water-head provenance preservation plus applicable permanent and mixed-smoke evidence. |
| WOFOST admitted runtime scope | Capability-specific WOFOST scientific/runtime contract for the bounded admitted path. | WOFOST production runtime contained in `50346642…`. | F-CI89 runtime qualification/admission and closure, plus Status-A acceptance. | Same-tree scientific WOFOST smoke/extended gates inherited by the release-readiness record. A future SWAP 4.3.1/Python equivalence authority can be linked here as additional evidence after acceptance. |
| Restricted Snow | Qualified one-call-daily Snow scientific/runtime contract only. | Snow production implementation in `50346642…`. | Independent Snow scientific/runtime/MultiSWAP evidence and F-PM02 canonical admission/closure incorporated into Status-A. | Same-tree F-GC29 Snow preservation plus successful exact-head `F-PM02 Canonical Snow Preservation` workflow on `50346642…`. |
| Groundwater Coupling v1 | Bounded groundwater coupling contracts including transaction ownership, accepted-state publication and the structural external gateway boundary. | Groundwater v1 production implementation in `50346642…`. | F-GC qualification chain through F-GC27/F-GC28 canonical closure and Status-A acceptance. | Same-tree F-GC29 targeted Groundwater tests, mixed smoke and accepted-state publication/rollback preservation. |
| F-PE11 current performance closure | Surface-evaporation scientific semantics remain unchanged; the performance contract is bounded to qualified call-local allocation/scaling evidence. | Equivalent production semantics were already admitted by F-CI42/F-CI42P. F-PE11 close commit `f928f309…` performs no canonical production or reference mutation. | Current-head replay records functional preservation, O0/O2 identity, committed-state immutability, A/B/A determinism, dry/ponded identity, local performance non-regression and checksum identity. Admission action is `NO_OP`. | Dependency-aware current-head preservation. No blanket whole-model or MultiSWAP speedup and no portable speed guarantee are implied. |

Where this table names an umbrella commit rather than a file, that is deliberate: it avoids inventing a single source file as the owner of a capability whose implementation/evidence is distributed. To audit an exact implementation path, follow the capability-specific qualification/admission record at the pinned commit.

## Permanent testbank and preservation

The permanent testbank is an architecture of stable regression roles plus immutable capability authorities. It must not be confused with automatic coverage of every later canonical head.

The historical F-TB11 snapshot is valuable because it records stable IDs and preservation roles for transactions/mass, Restart, serialized MultiSWAP, Richards, the solver seam and ET/surface evaporation. It also explicitly states that its binding does not extend to a later canonical head without rebind/requalification, and at that snapshot Drainage was not yet credited.

### F-TA02 locator correction

The Status-A release-readiness record contains these seven strings in its permanent-suite summary:

- `tests/run-baseline.sh`
- `tests/run-smoke.sh`
- `tests/run-kernel.sh`
- `tests/run-transactional.sh`
- `tests/run-independent-oracle.sh`
- `tests/run-mixed-smoke.sh`
- `tests/run-numerical.sh`

F-TA02 checked the exact Status-A authority tree at `992a5c657bfe10a10100f92e0cb77c4825ae65b6` and the later living canonical tree at `e9859b82ffa0d0776c340ef7d550ac8791e28dab`. None of these seven strings resolves to a repository file on either tree. They must therefore be interpreted as historical/narrative suite labels in the immutable release-readiness record, not as executable repository locators.

This locator correction does not rewrite or invalidate the historical PASS record. It narrows what those strings can support: they are evidence labels, not paths from which an independent reviewer can reproduce a test.

For the pinned F-TB11 transaction/restart preservation snapshot, the actual repository entry points are:

- workflow: `.github/workflows/f-tb11-current-canonical-permanent-preservation.yml`
- manifest: `testbank/manifests/F-TB11_CURRENT_CANONICAL_100_PERCENT_CAPABILITY_PRESERVATION.json`
- authority validator: `testbank/runners/validate_ftb11_current_canonical_preservation.py`
- independent current-source replay: `testbank/runners/run_ftb11_current_source_replays.sh`
- explanatory authority: [`F-TB11_CURRENT_CANONICAL_PERMANENT_PRESERVATION.md`](../testbank/F-TB11_CURRENT_CANONICAL_PERMANENT_PRESERVATION.md)

The replay materializes F-VQ65 and F-VQ71 independent oracles at their pinned authorities and replays transaction/mass, restart and accepted-publication invariants against F-TB11's exact source generation. The central test-bank catalog records this as a complete bounded historical preservation chain. It does not promote F-TB11 into a moving-current authority for `992a5c…`, `e9859b82…` or later heads.

The older `tests/transaction/run_a23bl_gate.sh` remains a real executable repository test. Its central catalog record is deliberately historical because A23BL predates the mandatory mass-completeness contract later owned by F-VQ65/F-TB11. A passing A23BL run is therefore useful regression evidence but is not the current transaction/mass preservation oracle.

## Canonical admission and evidence inheritance

Canonical admission establishes that a bounded capability belongs to the accepted baseline. It does not require every unrelated capability to be requalified after every repository change.

Previously valid immutable evidence remains usable while the dependencies relevant to that evidence remain unchanged. When a relevant dependency changes:

1. identify which admitted capability contracts depend on that changed surface;
2. rerun the permanent/qualification suites that protect those contracts, including explicitly transitive dependencies where the recorded contract requires them;
3. record new evidence against the changed postimage;
4. do not reopen unrelated capabilities without dependency evidence or an acceptance-authority reason.

A failure in an adjacent capability is recorded and routed to its owning scope; it is not silently repaired by broadening the active workstream.

## Scientific claim discipline

A claim should be no broader than the authority that supports it. In particular:

- an architecture admission does not create new scientific physics;
- a successful regression test does not prove untested future modes;
- an external adapter boundary does not prove a concrete backend;
- a performance measurement does not establish a universal speedup;
- a historical design document does not establish present implementation status;
- absence from the Status-A denominator does not itself establish a defect.

## Adding later SWAP 4.3.1 equivalence evidence

The parallel SWAP 4.3.1 to SWAP5 equivalence campaign can be added as an additional verification authority under the applicable capability rows once its evidence is accepted. The core Status-A description does not need to be rewritten unless that campaign changes an accepted scientific or scope conclusion.
