# TRACE Exposure Batch 02 closeout

Date: 2026-09-19
Status: `CLOSED`

## Design

Exposure Batch 02 was selected and persisted before detailed inspection. It contained six scientific elements, three in SWAP and three in ANIMO, again spanning process, transfer/accounting and numerical-scientific surfaces.

Selection remained planned, stratified and non-random. Historical/pilot discrepancies were excluded from confirmatory counting by protocol.

## Prospective results

| Model | Elements exposed | Candidate triggers | Confirmed discrepancies | Excluded candidates | Elements without confirmed discrepancy |
|---|---:|---:|---:|---:|---:|
| SWAP | 3 | 1 | 1 | 0 | 2 |
| ANIMO | 3 | 3 | 1 | 2 | 2 |
| **Total** | **6** | **4** | **2** | **2** | **4** |

The confirmed prospective cases were:

- `TRACE-ANIMO-0003`: the TCD-017 reviewer-facing B3 closeout retained pre-validation conditional admission wording after B3D02 had become qualified and complete. No authoring-freeze contract justified the stale state. The documentation was corrected and the pre-existing validator was strengthened. Regression counterfactual: `REGRESSION_MISSED`.
- `TRACE-SWAP-0001`: current canonical retained the pre-admission F-DOC30 `VERIFY` status after PR #194 had already admitted the transactional technical reference. The work branch contained the correct post-merge `CLOSE / DOCUMENTATION_ADMITTED_AND_CLOSED` status, but it had not been propagated to canonical. The existing closeout object was restored to canonical lineage. Regression counterfactual: `REGRESSION_NOT_APPLICABLE`.

The excluded prospective candidates were:

- `TRACE-ANIMO-0004`: TCD-033 GHG02 pending-review prose belongs to an explicit immutable pre-review authoring object. Separate review/status and B3D40 admission authorities are intentional successors.
- `TRACE-ANIMO-0005`: TCD-019 NQ05 pending-review prose likewise belongs to an explicit immutable pre-review authoring object. Separate NQ05 review/status and B3D42 admission authorities are intentional successors.

## Scientific interpretation

The two confirmed cases are authority-state/documentation discrepancies. Neither case demonstrates an error in the underlying physical or numerical equation.

For `TRACE-ANIMO-0003`, the demonstrated consequence is interpretative: the reviewer-facing closeout understated the completed scientific admission state.

For `TRACE-SWAP-0001`, the demonstrated consequence is also interpretative: canonical metadata represented F-DOC30 as still pending verification/admission after admission had already occurred.

By contrast, the two excluded cases show why temporal provenance cannot be inferred from differing status words alone. In both NQ05 and GHG02, an explicit authoring-freeze contract intentionally preserves pre-review prose while mutable successor artifacts carry later qualification and admission state.

## Methodological consequence

Batch 02 strengthens two distinctions already present in TRACE:

1. **Stale current authority is not the same as frozen provenance.** A current reviewer/status surface that is meant to communicate present authority and remains stale after closure can be a discrepancy.
2. **Immutable reviewed authoring evidence is not stale merely because later successor status exists.** Where a freeze contract defines that temporal role and validators enforce it, the earlier wording is provenance rather than a competing current claim.

No protocol or codebook amendment is required. The existing v0.2 process already supports both outcomes through prospective freezing, authority reconstruction, exclusion and explicit confirmed-case closure.

Temporal provenance remains an observed exclusion mechanism. Stale authority-state propagation remains an observed discrepancy mechanism. Neither is promoted into a new structural relation class from Batch-02 results.

## No prevalence inference

The observed Batch-02 counts are descriptive workflow evidence only.

The batch is too small and too design-specific for population prevalence inference because:

- six elements were selected;
- the design is planned and stratified rather than random;
- SWAP and ANIMO use different governance/documentation structures;
- candidate triggers include both genuine discrepancies and intentionally frozen provenance;
- two confirmed cases concern authority/documentation state rather than underlying equations.

Therefore neither `4/6` candidate triggers nor `2/6` confirmed discrepancies may be interpreted as an estimated repository-wide error rate.

## Cumulative prospective record after Batches 01 and 02

| Quantity | Count |
|---|---:|
| Scientific elements exposed | 12 |
| Candidate triggers | 6 |
| Confirmed discrepancies | 2 |
| Excluded candidates | 4 |

This cumulative snapshot is also descriptive only. It records what TRACE has observed under the first two planned exposure batches, not the prevalence of discrepancies in SWAP, ANIMO or scientific software generally.

## Next exposure

Batch 03 must again be selected and persisted before detailed inspection.

Selection should advance to previously unexposed scientific surfaces using a deterministic filename/topic rule where possible. Candidate selection must not be driven by suspicion from Batch-02 findings.

The v0.2 protocol and codebook remain frozen for Batch 03.
