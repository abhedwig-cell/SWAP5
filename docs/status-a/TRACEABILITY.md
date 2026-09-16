# SWAP5 Status-A theory, code and evidence traceability

Date: 2026-09-16

SWAP5 does not have, and does not need, one artificial master theory file for all Status-A capabilities. Scientific and architectural authority is capability-distributed. This page makes that distributed authority navigable without replacing the underlying records.

## Pinned umbrella authorities

- current canonical / Status-A authority: `992a5c657bfe10a10100f92e0cb77c4825ae65b6`
- scientific production baseline: `50346642bd565f79134ea17d5462e544b354998c`
- scientific production tree: `3b085d7dea3d3f3fce42ad9d8f259a8350205846`
- current release-readiness acceptance record: [`STATUS_A_RELEASE_READINESS_BASELINE.md`](https://github.com/abhedwig-cell/SWAP5/blob/992a5c657bfe10a10100f92e0cb77c4825ae65b6/tests/qualification/status-a-baseline-20260916/STATUS_A_RELEASE_READINESS_BASELINE.md)
- current-canonical permanent preservation authority: [`F-TB11_CURRENT_CANONICAL_PERMANENT_PRESERVATION.md`](../testbank/F-TB11_CURRENT_CANONICAL_PERMANENT_PRESERVATION.md)

The release-readiness record fixes the Status-A denominator. Capability-specific records remain the evidence for how an individual scientific or architectural claim was established.

## How to read a capability chain

For a Status-A capability, trace authority in this direction:

**scientific/reference contract → admitted production implementation → qualification evidence → canonical admission/closure → permanent preservation/regression authority**

The records at each step may live in different repository locations. That is intentional. A later umbrella acceptance record can establish that a previously qualified capability belongs to the current baseline without becoming the theory source for that capability.

## Current capability traceability map

| Capability | Theory / scientific or architectural contract | Production implementation authority | Qualification and canonical admission | Preservation authority |
| --- | --- | --- | --- | --- |
| Reference preservation | Legacy/reference behaviour and capability-specific preservation contracts. Historical SWAP material is reference authority, not current runtime architecture authority. | Scientific postimage contained in production baseline `50346642…`. | Capability-specific reference/verification gates, followed by current Status-A acceptance `992a5c657…`. | Permanent current-canonical testbank plus the applicable capability-specific regression evidence. |
| Richards / soil-water admitted core | Existing soil-water scientific contracts and invariants within the admitted reference-preserving scope. No broader physics is created by Status-A. | Scientific postimage `50346642…`; exact source paths remain those named by the owning qualification/admission records. | Scientific/numerical qualification records and later canonical admission; current denominator fixed by the release-readiness record. | Permanent suites whose dependency surface includes the soil-water core. |
| Transaction architecture | State-ownership, trial/accept/retry/rollback and transaction invariants; see [Current Status-A architecture](CURRENT_ARCHITECTURE.md). | Transactional production postimage at `50346642…`. | Architecture/runtime qualification and canonical closure incorporated into current Status-A acceptance. | Transaction, restart, mass and execution-preservation tests applicable to the changed dependency surface. |
| Restart v1 | Bounded committed-state persistence/reconstruction contract. | Restart v1 production implementation within `50346642…`. | Restart qualification/admission records plus current Status-A acceptance. | Restart continuation/regression coverage in the permanent preservation surface. |
| Serialized MultiSWAP v1 | Serialized orchestration contract over qualified real-physics paths. Parallel/concurrent real-physics semantics are outside this row. | MultiSWAP v1 production implementation within `50346642…`. | MultiSWAP qualification/admission records plus current Status-A acceptance. | Current-canonical MultiSWAP/preservation tests relevant to the dependency change. |
| Drainage | Existing admitted drainage scientific/process contract. | Drainage production implementation within `50346642…`. | Drainage scientific/numerical qualification and canonical admission incorporated into current Status-A. | Applicable drainage, mass and reference-preservation regression evidence. |
| Surface evaporation | Existing admitted surface-evaporation scientific/process contract. | Surface-evaporation implementation in `50346642…`. | Scientific/preservation qualification plus canonical admission; F-PE11 later closes bounded performance evidence without changing scientific semantics. | Surface-evaporation preservation tests and current-canonical permanent suites. |
| WOFOST admitted runtime scope | Capability-specific WOFOST scientific/runtime contract for the bounded admitted path. | WOFOST production runtime contained in `50346642…`. | WOFOST runtime qualification/admission records plus current Status-A acceptance. | WOFOST preservation tests for the admitted path. A future SWAP 4.3.1/Python equivalence authority can be linked here as additional evidence after acceptance. |
| Restricted Snow | Qualified one-call-daily Snow scientific/runtime contract only. | Snow production implementation in `50346642…`. | Independent Snow scientific/runtime/MultiSWAP evidence and later canonical closure incorporated into Status-A. | Permanent Snow tests for the admitted one-call-daily dependency surface. |
| Groundwater Coupling v1 | Bounded groundwater coupling contracts including transaction ownership, accepted-state publication and the structural external gateway boundary. | Groundwater v1 production implementation in `50346642…`. | Capability-specific groundwater qualification/admission chain through the canonical Groundwater v1 closure represented in the release-readiness authority. | Groundwater coupling, rollback/publication and current-canonical preservation suites applicable to the dependency surface. |
| F-PE11 current performance closure | Surface-evaporation scientific semantics remain unchanged; the performance contract is bounded to the qualified call-local allocation/scaling evidence. | No new scientific production postimage is introduced by Status-A closure beyond baseline `50346642…`. | F-PE11 owner/independent/current-head evidence as incorporated in Status-A acceptance. | Existing scientific preservation tests plus bounded performance evidence; no blanket whole-model or MultiSWAP performance authority is implied. |

Where this table names an umbrella commit rather than a file, that is deliberate: it avoids inventing a single source file as the owner of a capability whose implementation/evidence is distributed. To audit an exact implementation path, follow the capability-specific qualification/admission record at the pinned commit.

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