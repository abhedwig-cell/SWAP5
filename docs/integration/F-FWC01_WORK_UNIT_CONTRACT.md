# F-FWC01 — Finite Water Content Soil-Water Solver Assessment

## Workunit identity

- Workunit: `F-FWC01`
- Candidate name: `Finite Water Content` / `FWC`
- Type: literature audit + representation audit + feasibility qualification
- Branch: `work/f-fwc01-finite-water-content-assessment`
- Exact base commit: `fafeebdece209abcc320b24a3c8c2757800b2e0e`
- Base tree: `6f47044a352717bb27c6e960a012ef828243eae3`
- Started: 2026-09-09
- Production implementation: forbidden until explicit qualification gates justify a later implementation workunit
- Current decision: `FWC_QUALIFICATION_INCOMPLETE`

## Scientific starting point

Primary lineage identified at workunit start:

C. A. Talbot and F. L. Ogden (2008), “A method for computing infiltration and redistribution in a discretized moisture content domain”, *Water Resources Research* 44. DOI: `10.1029/2008WR006815`.

F. L. Ogden, W. Lai, R. C. Steinke, J. Zhu, C. A. Talbot and J. L. Wilson (2015), “A new general 1-D vadose zone flow solution method”, *Water Resources Research* 51, 4282–4300. DOI: `10.1002/2015WR017126`.

F. L. Ogden, W. Lai, R. C. Steinke and J. Zhu (2015), “Validation of finite water-content vadose zone dynamics method using column experiments with a moving water table and applied surface flux”, *Water Resources Research* 51. DOI: `10.1002/2014WR016454`.

F. L. Ogden, M. B. Allen, W. Lai, J. Zhu, M. Seo, C. C. Douglas and C. A. Talbot (2017), “The Soil Moisture Velocity Equation”, *Journal of Advances in Modeling Earth Systems* 9. DOI: `10.1002/2017MS000931`.

The 2017 paper is scientifically important because it separates an advection-like and diffusion-like contribution in the Soil Moisture Velocity Equation and clarifies the mathematical relationship of the finite-water-content formulation to Richards-type flow. The exact approximation introduced when the diffusion-like term is omitted or represented indirectly is a first-order qualification issue for SWAP5.

## Purpose

Determine whether an FWC-derived soil-water solver can provide a bounded-cost, machine-checkably conservative alternative behind the SWAP5 soil-water interface for a qualified subset of the full Richards applicability domain.

Historical FWC formulations are evidence and algorithmic donors, not immutable implementations. SWAP5 physics, conservation, coupling and architecture are authoritative.

## Core representation questions

The workunit must compare at least two representation families:

1. dynamic water-content fronts / slugs;
2. fixed or semi-fixed water-content bins.

For each, quantify:

- persistent state size per column;
- maximum possible number of active fronts/bins;
- creation/merge/sort events;
- numerical work per interval;
- branch divergence and batchability;
- pressure-head reconstruction quality;
- water-content reconstruction quality;
- compatibility with sinks and other SWAP processes;
- rollback complexity.

Unbounded front-state growth is a hard architecture concern for MultiSWAP and must not be hidden behind average-case behaviour.

## Qualification gates

| Gate | Question | Initial state |
|---|---|---|
| A | Primary FWC/SMVE equations and approximations reconstructed source-bound | `OPEN` |
| B | Exact relation to Richards and omitted/approximated physics is explicit | `OPEN` |
| C | State representation admits a strict bounded-size or otherwise qualified memory contract | `OPEN` |
| D | Every accepted step closes the water ledger to numerical roundoff | `OPEN` |
| E | Infiltration, redistribution, drying and rewetting are qualified | `OPEN` |
| F | Evaporation and distributed root uptake are compatible without hidden physics changes | `OPEN` |
| G | Heterogeneous layers and hydraulic contrasts are qualified | `OPEN` |
| H | Shallow, rising and falling groundwater are qualified | `OPEN` |
| I | Fixed-head, fixed-flux and free-drainage bottom conditions are consistent | `OPEN` |
| J | Pressure-head/hydraulic information can be exposed through a generic soil-water interface | `OPEN` |
| K | Drainage, oxygen stress, macropore exchange and solute-facing contracts are assessable without exposing front internals | `OPEN` |
| L | Transactional checkpoint/trial/rollback is practical | `OPEN` |
| M | Runtime and event counts have explicit upper bounds or fail-closed limits | `OPEN` |
| N | MODFLOW interface and bottom response tangent are contractable | `OPEN` |
| O | Full Richards comparison supports an explicit applicability/failure envelope | `OPEN` |

Failure of Gate C or D blocks production admission.

## Mass ledger

Every experimental step must emit a machine-checkable identity of the form

`storage_change = inflow - outflow - sinks + sources`

with all surface, internal, bottom, groundwater and externally imposed sink/source terms explicitly attributed.

A residual is a defect or unresolved discrepancy until source-bound analysis demonstrates otherwise. No conservation error may be traded for runtime.

## Experimental scope after theory gate

An isolated harness may be built only after the primary algorithm has been reconstructed. It must initially support:

- homogeneous soil;
- layered soil;
- infiltration pulse;
- drying;
- rewetting;
- evaporation;
- distributed root uptake;
- free drainage;
- shallow groundwater;
- rising groundwater;
- falling groundwater.

Strong hydraulic contrasts, heavy clay and coarse sand must be included before any broad applicability claim.

## Generic soil-water interface requirement

Other SWAP modules may consume fields or queries such as:

- water content;
- pressure head or a qualified equivalent;
- conductivity;
- storage;
- root-zone extraction capacity;
- drainage-driving state;
- oxygen-stress-driving state;
- evaporation-facing surface hydraulic state;
- macropore exchange quantities;
- solute-transport-facing water volumes/fluxes;
- groundwater interface head/flux.

They may not depend on FWC front/bin internals.

Any quantity that cannot be reconstructed with adequate fidelity must be treated as a limitation of the applicability envelope, not silently approximated.

## Runtime and state contract

Required diagnostics include:

- active fronts/bins;
- maximum allocated fronts/bins;
- creation events;
- merge/sort/relaxation events;
- internal substeps;
- local root-finds, if any;
- branch count/divergence proxy;
- worst-case interval runtime;
- memory bytes per column;
- shared immutable constitutive-table bytes;
- worker scratch bytes.

Target complexity must be expressible with explicit bounds, for example

`cost = O(N_bins_or_fronts * N_events_or_substeps)`

with maximum admitted values specified by solver policy or the physical representation itself.

## Groundwater / MODFLOW contract

Direct coupling must be assessable against:

- `H_SWAP = H_MF`;
- `q_SWAP = -q_MF`;
- no lost or double-counted water during moving-water-table transitions;
- imposed groundwater head;
- imposed bottom flux;
- recharge, zero flux and capillary rise;
- predictor/corrector over generic coupling windows;
- rollback;
- a bounded-cost response tangent such as `dq_b/dh_b` or `dh_b/dq_b`.

## SWAP5 architecture constraints

All SWAP Core Architecture Invariants apply. In particular:

- one common kernel and solver interface;
- kernel independent of I/O;
- compact persistent state;
- scratch per worker;
- generic time;
- transaction-safe trials;
- full Richards reference preserved;
- MultiSWAP as primary scaling case;
- exact mass conservation;
- physical options separate from numerical policy;
- diagnostics for normal, bounded and fallback paths.

## Planned evidence artifacts

1. provenance/source inventory;
2. theory reconstruction and Richards/SMVE relation;
3. dynamic-front state model;
4. fixed/semi-fixed-bin state model;
5. state-growth and memory bounds;
6. water-ledger specification;
7. pressure-head/interface reconstruction assessment;
8. heterogeneous-layer treatment;
9. groundwater/moving-water-table assessment;
10. isolated prototype(s) if warranted;
11. full Richards comparison matrix;
12. runtime and batchability evidence;
13. coupling-readiness assessment;
14. applicability envelope;
15. failure envelope;
16. final decision.

## Final decision vocabulary

Exactly one of:

- `FWC_FEASIBLE`
- `FWC_FEASIBLE_FOR_RESTRICTED_ENVELOPE`
- `FWC_RESEARCH_CONTINUES`
- `FWC_REJECTED_FOR_SWAP5`

## Current checkpoint

- investigated: duplicate branch check; Talbot-Ogden 2008 lineage; Ogden et al. 2015 general 1-D method; 2015 moving-water-table validation; 2017 SMVE paper
- implemented: workunit contract only
- persisted: this contract
- tested: not applicable yet
- reproduced: no FWC numerical case reproduced yet
- qualified: nothing yet
- open: all Gates A-O

Current decision remains `FWC_QUALIFICATION_INCOMPLETE`.
