# F-VZAA01 — Vadose Zone Analytical Algorithm Assessment, Conservation Repair & SWAP5 Suitability

## Workunit identity

- Workunit: `F-VZAA01`
- Type: literature audit + algorithm reconstruction + feasibility qualification
- Production implementation: **forbidden in this workunit unless a later explicit gate authorizes a separate production workunit**
- Branch: `work/f-vzaa01-vadose-zone-analytical-assessment`
- Exact base commit: `fafeebdece209abcc320b24a3c8c2757800b2e0e`
- Base tree: `6f47044a352717bb27c6e960a012ef828243eae3`
- Started: 2026-09-09
- Current qualification decision: `VZAA_QUALIFICATION_INCOMPLETE`

## Live duplicate / overlap check

At workunit start, no branch matching `vzaa` was present in `abhedwig-cell/SWAP5` and no default-branch repository search result for `VZAA` was found.

Related reduced-order work already exists under the LayeredMFP sequence, including branches `work/f-lmfp01-layered-mfp-feasibility` through `work/f-lmfp09-hydraulic-envelope-geometry`. No `ross` or `fwc` branch name was found at workunit start. F-VZAA01 must therefore explicitly test whether any VZAA idea belongs as a donor concept in an existing reduced-order solver track rather than creating a redundant production solver family.

## Primary scientific source

Primary publication identified at workunit start:

M. Sadeghi, S. E. Boyce, E. C. Dogrul, G. Huang, L. Liang, U. Bandara, C. R. Altare, T. Hatch, S. A. Bradford (2026), “Vadose zone analytical algorithm (VZAA): a non-iterative algorithm for vadose zone soil moisture and groundwater recharge”, *Journal of Hydrology* 673, article 135467. DOI: `10.1016/j.jhydrol.2026.135467`.

The article reports MATLAB implementations in supplementary Appendix A and B. Exact supplementary artifacts, checksums, licensing, versioning, independent mirrors, errata/corrections and follow-up publications remain to be source-bound before Gate B can pass.

## Three distinct qualification questions

F-VZAA01 must keep these conclusions separate:

1. Is the **published VZAA formulation itself** suitable for SWAP5?
2. Can VZAA be made suitable by a **bounded, explicit, mass-conserving modification** that does not become a disguised full Richards/Newton solve?
3. If not, which VZAA mechanisms are useful as **algorithmic donor concepts** for LayeredMFP, RossFast, Finite Water Content, predictor generation, or another admitted reduced-order solver?

Passing question 3 does not imply passing question 1 or 2.

## Hard scientific constraints

The assessment is fail-closed against the SWAP5 architecture. In particular:

- exact water conservation is mandatory;
- lower boundary conditions may not be converted silently into unexplained mass terms;
- groundwater exchange must be bidirectional when the use case requires it;
- the solver must admit checkpoint -> trial -> commit/rollback semantics;
- time is a generic interval `[t0,t1]`, not inherently a day;
- direct groundwater coupling must be contractable in terms of head and flux, with the target interface `H_SWAP = H_MF` and `q_SWAP = -q_MF`;
- response sensitivities such as `dq_b/dh_b` or an equivalent inverse response should be obtainable without structurally requiring many complete reruns;
- persistent column state must remain compact and immutable constitutive data shareable;
- scratch belongs per worker/job, not permanently per logical column;
- MultiSWAP batching, bounded work, diagnostics and branch-dependent cost must be assessed explicitly;
- hydraulic constitutive models are separate from the VZAA algorithm;
- other SWAP physics must consume a generic soil-water interface and may not know VZAA internals;
- numerical performance policy may not silently alter physical options.

## Initial source-bound scientific warning

The primary paper explicitly states that the current VZAA formulation is surface-driven and does not explicitly enforce a prescribed lower boundary such as zero flux. It also reports non-zero discrete mass-balance residuals, especially for coarse spatial/temporal discretizations, and artificial gain/loss through the lower boundary in some cases.

This means that the published formulation does **not** receive any presumption of acceptance from claims of “mass conservative” governing equations. SWAP5 qualification concerns the discrete algorithm actually executed over a finite interval and its complete ledger, including the lower boundary.

Consequently, Gate C and Gate D are fail-closed from workunit start and can only be opened by source-bound reconstruction plus reproducible evidence. A bounded conservation repair remains an open research question rather than an assumed solution.

## Qualification gates

| Gate | Question | Initial state |
|---|---|---|
| A | Scientific reconstruction complete enough for independent understanding | `IN_PROGRESS` |
| B | Published result / official code reproducible | `OPEN` |
| C | Exact discrete conservation with no unexplained residual | `PROVISIONAL_FAIL_PUBLISHED_FORMULATION` |
| D | Head/flux/groundwater lower boundaries physically consistent | `PROVISIONAL_FAIL_PUBLISHED_FORMULATION` |
| E | Heterogeneous material interfaces qualified | `OPEN` |
| F | Recharge and capillary rise both qualified | `OPEN` |
| G | Transactional trial/rollback semantics possible | `OPEN` |
| H | Runtime/work can be predictably bounded | `OPEN` |
| I | MODFLOW coupling interface and response are contractable | `OPEN` |
| J | Essential SWAP physics can use the solver without silent disablement | `OPEN` |

Production integration is prohibited while Gate C or D fails.

## Evidence hierarchy

Technical claims must prefer, in order:

1. publisher article and DOI-linked supplementary material;
2. official author/institution code or data archive;
3. exact source of any preprint or correction;
4. independent peer-reviewed evaluations or reproductions;
5. secondary pages only for navigation or context.

No source, code, license, erratum or benchmark result may be invented when unavailable.

## Reconstruction scope

The source-bound reconstruction must cover at minimum:

- persistent state, derived constitutive quantities and scratch separately;
- required parameters and forcing;
- surface, inter-layer and bottom/groundwater fluxes;
- update order and information direction;
- local equation solve/root-find behaviour;
- clipping, limiting, saturation treatment and adaptive time stepping;
- complete layer and column water ledgers;
- moving water-table storage semantics;
- heterogeneous layers and constitutive interfaces;
- distributed sinks/sources and compatibility with SWAP physics;
- actual cost model, including local solve work and substeps;
- transaction semantics and coupling response.

## “Non-iterative” terminology

F-VZAA01 will not use “non-iterative” as a synonym for constant work. It will distinguish:

- absence of global Newton/profile iteration;
- local scalar equation solving;
- sequential layer sweeps;
- adaptive substepping;
- bounded correction/retry;
- clipping or flux limiting.

A useful runtime model is expected to take the form

`cost ~ N_layers * N_local_operations * N_substeps * N_bounded_corrections`,

with each factor characterized rather than assumed constant.

## Planned evidence artifacts

Before any production implementation, this branch should contain source-bound evidence for:

1. provenance inventory;
2. theory and algorithm reconstruction;
3. independent pseudocode;
4. state model;
5. water-ledger specification;
6. bottom-boundary analysis;
7. conservation findings;
8. runtime complexity;
9. SWAP hydraulics compatibility matrix;
10. groundwater-coupling assessment;
11. MultiSWAP assessment;
12. comparison with LayeredMFP, RossFast and Finite Water Content;
13. applicability envelope;
14. failure envelope;
15. open scientific uncertainties;
16. final explicit qualification decision.

An isolated experimental harness may be added only after the theory and conservation audit shows enough promise to justify it. Such a harness is not production integration.

## Status semantics

Every checkpoint must distinguish:

- `investigated`
- `implemented`
- `persisted`
- `tested`
- `reproduced`
- `qualified`
- `open`

A passing testcase is evidence, not automatically qualification.

## Current checkpoint

- investigated: live duplicate/overlap check; primary article identification; first-pass lower-boundary and mass-balance warning
- implemented: workunit contract only; no solver implementation
- persisted: this contract
- tested: not applicable yet
- reproduced: no published VZAA run reproduced yet
- qualified: nothing beyond the workunit start decision
- open: supplementary source capture, exact algorithm/code reconstruction, conservation proof/audit, boundary repair feasibility, all Gates B-J

Current workunit decision remains exactly:

`VZAA_QUALIFICATION_INCOMPLETE`
