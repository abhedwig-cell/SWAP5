# SWAP5 Status-A theory, code and evidence traceability

Date: 2026-09-16

SWAP5 does not have, and does not need, one artificial master theory file for all Status-A capabilities. Scientific and architectural authority is capability-distributed. This page makes that distributed authority navigable without replacing the underlying records.

## Pinned umbrella authorities

- current canonical / Status-A authority: `992a5c657bfe10a10100f92e0cb77c4825ae65b6`
- scientific production baseline: `50346642bd565f79134ea17d5462e544b354998c`
- scientific production tree: `3b085d7dea3d3f3fce42ad9d8f259a8350205846`
- current release-readiness acceptance record: [`STATUS_A_RELEASE_READINESS_BASELINE.md`](https://github.com/abhedwig-cell/SWAP5/blob/992a5c657bfe10a10100f92e0cb77c4825ae65b6/tests/qualification/status-a-baseline-20260916/STATUS_A_RELEASE_READINESS_BASELINE.md)
- permanent-testbank architecture/snapshot: [`F-TB11_CURRENT_CANONICAL_PERMANENT_PRESERVATION.md`](../testbank/F-TB11_CURRENT_CANONICAL_PERMANENT_PRESERVATION.md), explicitly bound to canonical `379afd11…`, not to the later Status-A head

The release-readiness record fixes the Status-A denominator and the current preservation conclusion. Capability-specific records remain the evidence for how an individual scientific or architectural claim was established. [Reference preservation](../capabilities/reference-preservation.md) explains how frozen identity, immutable qualification and dependency-aware replay fit together.

!!! info "Post-Status-A traceability"
    Later canonically admitted development must be traced without rewriting this frozen Status-A map. The current post-Status-A groundwater chain through F-GC49D is summarized in [Post-Status-A current canonical state](POST_STATUS_A_CURRENT_STATE.md) and remains grounded in its capability-specific `integration/f-gc/F-GC*_STATUS.json` records, owner qualification and independent F-VQ evidence.

## How to read a capability chain

For a Status-A capability, trace authority in this direction:

**scientific/reference contract → admitted production implementation → qualification evidence → canonical admission/closure → permanent preservation/regression authority**

The records at each step may live in different repository locations. That is intentional. A later umbrella acceptance record can establish that a previously qualified capability belongs to the current baseline without becoming the theory source for that capability.

## Current capability traceability map

| Capability | Theory / scientific or architectural contract | Production implementation authority | Qualification and canonical admission | Current preservation authority |
| --- | --- | --- | --- | --- |
| Reference preservation | Legacy/reference behaviour and capability-specific preservation contracts; see [Reference preservation](../capabilities/reference-preservation.md). Historical SWAP material is reference authority, not current runtime architecture authority. | Scientific postimage contained in production baseline `50346642…`. | Capability-specific reference/verification gates, followed by current Status-A acceptance `992a5c657…`. | Same-tree checksum/closure reconciliation reported by the Status-A release-readiness authority, plus concrete permanent-testbank authorities under `testbank/runners/` and capability-specific qualification evidence. |
| Richards / soil-water admitted core | Existing soil-water scientific contracts and invariants within the admitted reference-preserving scope. No broader physics is created by Status-A. | Scientific postimage `50346642…`; exact source paths remain those named by the owning qualification/admission records. | Scientific/numerical qualification records including F-SI33/F-SI35 and later canonical admission; current denominator fixed by the release-readiness record. | Same-tree scientific/numerical preservation reported by release readiness, including the F-SI33 Full Richards authority and F-TB11 `FTB11-FR-001`/solver-seam roles. |
| Transaction architecture | State-ownership, trial/accept/retry/rollback and transaction invariants; see [Current Status-A architecture](CURRENT_ARCHITECTURE.md). | Transactional production postimage at `50346642…`. | Architecture/runtime qualification and canonical closure incorporated into current Status-A acceptance. | Same-tree preservation plus F-TB11 transaction/mass roles and the independently qualified current-source oracle materialized by `testbank/runners/run_ftb11_current_source_replays.sh`. |
| Restart v1 | Bounded committed-state persistence/reconstruction contract. | Restart v1 production implementation within `50346642…`. | Restart qualification/admission records plus current Status-A acceptance. | Same-tree restart observable and mass-preservation replay. Earlier F-TB11 Restart evidence remains historical immutable support, not an automatic rebind to the Status-A head. |
| Serialized MultiSWAP v1 | Serialized orchestration contract over qualified real-physics paths. Parallel/concurrent real-physics semantics are outside this row. | MultiSWAP v1 production implementation within `50346642…`. | MultiSWAP qualification/admission records plus current Status-A acceptance. | Same-tree observable and aggregate-mass replay plus relevant permanent/mixed-smoke authority. |
| Drainage | Existing admitted drainage scientific/process contract. | Drainage production implementation within `50346642…`. | Drainage scientific/numerical qualification and canonical admission incorporated into current Status-A. | Moving-current preservation legs A and B reported PASS by the release-readiness same-tree reconciliation. This supersedes the older F-TB11 snapshot limitation where Drainage was not yet credited. |
| Surface evaporation | Existing admitted surface-evaporation scientific/process contract. | Surface-evaporation implementation in `50346642…`. | Scientific/preservation qualification plus canonical admission; F-PE11 later closes bounded performance preservation without changing scientific semantics. | Same-tree inner-step free-water-head provenance preservation plus applicable permanent and mixed-smoke authority. |
| WOFOST admitted runtime scope | Capability-specific WOFOST scientific/runtime contract for the bounded admitted path. | WOFOST production runtime contained in `50346642…`. | F-CI89 runtime qualification/admission and closure, plus current Status-A acceptance. | Same-tree scientific WOFOST smoke/extended gates inherited by the release-readiness record. A future SWAP 4.3.1/Python equivalence authority can be linked here as additional evidence after acceptance. |
| Restricted Snow | Qualified one-call-daily Snow scientific/runtime contract only. | Snow production implementation in `50346642…`. | Independent Snow scientific/runtime/MultiSWAP evidence and F-PM02 canonical admission/closure incorporated into Status-A. | Same-tree Snow preservation plus successful exact-head `F-PM02 Canonical Snow Preservation` workflow on `50346642…`. |
| Groundwater Coupling v1 | Bounded groundwater coupling contracts including transaction ownership, accepted-state publication and the structural external gateway boundary. | Groundwater v1 production implementation in `50346642…`. | F-GC qualification chain through F-GC27/F-GC28 canonical closure and current Status-A acceptance. | Same-tree targeted Groundwater tests, mixed smoke and accepted-state publication/rollback preservation. |
| F-PE11 current performance closure | Surface-evaporation scientific semantics remain unchanged; the performance contract is bounded to qualified call-local allocation/scaling evidence. | Equivalent production semantics were already admitted by F-CI42/F-CI42P. F-PE11 close commit `f928f309…` performs no canonical production or reference mutation. | Current-head replay records functional preservation, O0/O2 identity, committed-state immutability, A/B/A determinism, dry/ponded identity, local performance non-regression and checksum identity. Admission action is `NO_OP`. | Dependency-aware current-head preservation. No blanket whole-model or MultiSWAP speedup and no portable speed guarantee are implied. |

Where this table names an umbrella reconciliation rather than a file, that is deliberate: it avoids inventing a single source file as the owner of a capability whose implementation/evidence is distributed. To audit an exact implementation path, follow the capability-specific qualification/admission record at the pinned commit.

For later development, F-GC49D is the controlling production-orchestration authority for the concrete SWAP5-MODFLOW6 application path. Its canonical closure is `96f7547b9e618863bc162266137abc872c376734`; its production ABI admission is backed by owner qualification run `35352680601` and independent F-VQ124 run `35352680593`. This is post-Status-A evidence and therefore supplements rather than alters the frozen table above.

The historical release-readiness narrative uses “F-GC29” as an umbrella label for its same-tree residual/preservation reconciliation. That label must not be equated with `integration/f-gc/F-GC29_*`, which is the separate Optional Groundwater Response Sensitivity Service Extension. The controlling preservation authority is the release-readiness record and the exact capability evidence it names.

## Permanent testbank and current-head preservation

The permanent testbank is an architecture of stable regression roles plus immutable capability authorities. It must not be confused with automatic coverage of every later canonical head.

The historical F-TB11 snapshot is valuable because it records stable IDs and preservation roles for transactions/mass, Restart, serialized MultiSWAP, Richards, the solver seam and ET/surface evaporation. It also explicitly states that its binding does not extend to a later canonical head without rebind/requalification, and at that snapshot Drainage was not yet credited.

Concrete permanent-testbank infrastructure on the frozen scientific tree is under `testbank/runners/`, including:

- `testbank/runners/run_ftb11_current_source_replays.sh`
- `testbank/runners/validate_ftb11_current_canonical_preservation.py`
- `testbank/runners/run_ftb12_drainage_v1_permanent_preservation.sh`
- `testbank/runners/run_ftb12p_postimage_reconciliation.sh`

Capability-specific executable tests and independent oracles live under their owning `tests/<workstream>/` directories. The historical Status-A release-readiness record also uses labels such as `tests/run-baseline.sh`, `tests/run-smoke.sh`, `tests/run-kernel.sh`, `tests/run-transactional.sh`, `tests/run-independent-oracle.sh`, `tests/run-mixed-smoke.sh` and `tests/run-numerical.sh` when describing retained suites. Those literal root-level files are not present in the frozen scientific tree or Status-A authority tree; current documentation therefore treats them as historical/umbrella suite labels rather than navigable paths. The historical evidence record itself is left unchanged.

Capability-specific moving-current or exact-head evidence is added where required, such as the restricted Snow preservation workflow. This preserves the distinction between immutable historical evidence, a moving-current regression role and exact current-head acceptance.


### F-TA04R bounded transaction/restart locator registration

The Status-A release-readiness record uses several historical suite labels that are not literal root-level repository paths. That historical evidence remains valid for its recorded acceptance conclusion, but independent reconstruction must use real locators.

F-TA04R therefore registers two bounded transaction/restart chains in `docs/verification/test-bank-catalog.yaml`:

- `TB-TRANSACTION-A23BL-HISTORICAL`: the real A23BL transaction-reference test and runner. It remains historical regression evidence and is **not** promoted to the current mass-completeness oracle.
- `TB-PRESERVATION-F-TB11-TXN-RST`: the pinned F-TB11 transaction/mass/rejected-publication/Restart preservation chain through its manifest, validator, replay runner and workflow.

The concrete dependencies used by these registrations are unchanged from historical PR #172 to the F-TA04R current-canonical reconciliation base `e07cea29725d822cfdb15e956a0c7b7bb0955843`.

F-TB11 remains pinned to `379afd11e9a1d7fbef5ec74c9e05b0ec55884f4b`. This registration does not rebind F-TB11 to Status-A or to a later canonical head.

The documentation checker now validates every bounded catalog record marked `complete`: required traceability fields must be present, duplicate stable IDs are rejected, and exact repository test/runner locators must exist. This is a static-process guard on the catalog, not a new scientific qualification.

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


## Later bounded lower-boundary admission: LOW05-A

PR#974 canonically admits the homogeneous typed Fortran ordinary Reference DATE5/HBOT5 prescribed lower-face pressure-head adapter at `e88af3da54b743958b887d9cc15647227388333a`. Existing typed physics, transaction/restart/mass ownership and default groundwater-owned mode5 semantics are unchanged. Original proposal endpoint is frozen through sibling/retry staging; ordinary ownership is explicit and excludes GWledger/datum. [Closeout and claim ceiling](../migration/F-MIG431-LOW05A_CLOSEOUT.md) bind source, qualification and admission. Qualification run36964835178 proves bounded progress, rollback, restart and existing2/4/6/7/defaultGW5 preservation at O0/O2. It does not assert global green CI, a generic parser, mixed ownership, broad transient accuracy or migration of1/3/8.

## MC-NUT01 historical closure review, 19 October 2026

Use [MC_NUT01_FINAL_CLOSURE](../science/MC_NUT01_FINAL_CLOSURE.md) for the nine-row report derived from existing master PR1072, pinned source identities, process and whole-element accounting, actual versus fixture results, O0/O2/restart evidence, admitted PR lineage and the separate scientific gross-atmospheric-carrier blocker. The owning status remains `integration/mc-nut01/MC-NUT01-HIST-COMPLETE_STATUS.json`; its `closure_review_20261019` records this read-only review and its local execution limits. The report is not a second capability registry and is not full historical admission. Existing immutable source/evidence archives and their registered validators remain authority.

## Later MC-SOL01 closure traceability, 2026-10-19

[MC_SOL01_FINAL_CLOSURE.md](https://github.com/abhedwig-cell/SWAP5/blob/integration/f-ci-canonical/MC_SOL01_FINAL_CLOSURE.md) is the consolidated audit entry for the eight existing solute capability rows. Scientific authority remains distributed: immutable B1.11 `SWAP/solute.f90`; accepted nonlinear inverse and Reference surface-chemistry decisions; existing trajectory3, surface-input and surface-age status/capsule records; actual canonical PR admissions; current source/evidence validators. The closure does not replace those authorities or create a second capability ledger. Full-envelope ACTIVE_MIGRATION rows retain exact parked restrictions rather than acquiring a blanket admission. Positive pond and atomic S5AT0001 restart evidence supersede earlier statements that only dry pond was qualified.

MC-SOL01 closure native CI follow-up: `integration/audits/MC_SOL01_SURFACE_AGE03_CI_STATUS.json` owns the eight original native route results, exact recipe/source successor and `MC_SOL01_CLOSURE_CI_REPAIR_20261019.tar.xz.b64`. `MC_SOL01_FINAL_CLOSURE.md` distinguishes completed test infrastructure from unchanged physical admission and negative Thomas-Gladwell research outcomes.

MC-SOL01 final preservation: the existing AGE03-CI `remaining_compile_routes` record binds `MC_SOL01_CLOSURE_PRESERVATION_20261019.tar.xz.b64`, original paired provider/5000-call/ten-pair proofs, F-KT22 compilation, eight negative controls and failed energy/hosted diagnostics. PR1327 terminal observations and Git containment supply the final admission receipt; no energy or solver research admission is inferred.

MC-SOL01 opt-in column input: the [application contract](../science/MC_SOL01_COLUMN_INPUT_CONTRACT.md),
`app/solute_column`, `tools/solute`, and `tests/nut-sol/test_column_input.py` trace
file input to existing production pond/matrix ownership and exact native restart.
The trajectory3 `column_input_20261020` record binds the 26 actual GNU O0/O2 process
observations and immutable capsule. Existing AGE03-CI postimages register only the
three exact additive tool/test files. Production/reference source and all old
scientific assertions remain unchanged. Local qualification and canonical
admission remain distinct. Actual bounded admission is PR1329 at `21cc8098`, with
all15 final-head workflows and postmerge native39464479365 successful. Master
receipt `371e92f2` adds two bounded application locators without disposition changes.

MC-NUT01 historical gross-positive PR1330: [contract, actual730-day results and original negative-source counterexample](../science/MC_NUT01_HISTORICAL_GROSS_TOP_CONTRACT_20261020.md), owning `historical_gross_top_successor` in the existing status record, immutable4432-member numerical capsule and20-member control/diagnostic capsule. Actual canonical merge `d118bcf1cacf7462cf62c27141cf306d7a4a52fb`, source treea60ac1d9; all10 original endpoints exact and48 transition processes. The strict14-file successor guard reexecutes the unchanged original canonical authority at21cc8098 and proves the three independently compiled CI footprints exclude changed NUT providers. Whole HIST/master disposition remains open.
