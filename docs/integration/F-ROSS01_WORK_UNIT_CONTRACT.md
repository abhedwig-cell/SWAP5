# F-ROSS01 — RossFast Non-Iterative MFP-Based Fast Richards Solver

## Workunit identity

- Workunit: `F-ROSS01`
- Candidate name: `RossFast`
- Type: literature audit + algorithm reconstruction + feasibility qualification
- Branch: `work/f-ross01-fast-mfp-feasibility`
- Exact base commit: `fafeebdece209abcc320b24a3c8c2757800b2e0e`
- Base tree: `6f47044a352717bb27c6e960a012ef828243eae3`
- Started: 2026-09-09
- Production implementation: forbidden in this workunit until explicit qualification gates have passed
- Current decision: `ROSSFAST_QUALIFICATION_INCOMPLETE`

## Scientific starting point

Primary method source identified at workunit start:

P. J. Ross (2003), “Modeling Soil Water and Solute Transport—Fast, Simplified Numerical Solutions”, *Agronomy Journal* 95(6), 1352–1361. DOI: `10.2134/agronj2003.1352`.

Independent / subsequent qualification source identified at workunit start:

D. Crevoisier, A. Chanzy, M. Voltz (2009), “Evaluation of the Ross fast solution of Richards' equation in unfavourable conditions for standard finite element methods”, *Advances in Water Resources* 32(6), 936–947. DOI: `10.1016/j.advwatres.2009.03.008`.

The 2009 study is particularly relevant because it evaluates the Ross approach against HYDRUS-1D and reports a generalisation beyond the Brooks-Corey hydraulic representation used by the original 2003 formulation. Exact mathematical details, code lineage and limits of that generalisation remain to be reconstructed before any SWAP5 admission claim.

A later Ross paper relevant to implementation choices is:

P. J. Ross (2011), “Numerical Solution of the Continuity Equation for Soil Water”, *Vadose Zone Journal*. DOI: `10.2136/vzj2010.0085`.

## Purpose

Determine whether a modern Ross-derived solver can provide a bounded-cost soil-water solution path for SWAP5 that remains sufficiently close to full Richards physics without a global Newton solve.

The historical Ross implementation is evidence and an algorithmic starting point, not a frozen design. SWAP5 hydraulics, conservation, generic time, groundwater coupling, transactionality and MultiSWAP constraints are authoritative.

## Required distinctions

The audit must keep separate:

1. mathematical method;
2. historical Ross code and numerical shortcuts;
3. hydraulic constitutive assumptions;
4. table/interpolation choices;
5. boundary-condition treatment;
6. scientific approximations;
7. implementation details that can be modernised without changing the method.

No hydraulic model may be silently substituted to make the candidate pass.

## Qualification gates

| Gate | Question | Initial state |
|---|---|---|
| A | Primary equations and update order reconstructed source-bound | `OPEN` |
| B | Brooks-Corey dependence separated from the mathematical core | `OPEN` |
| C | Generalisation to SWAP hydraulic catalog is mathematically valid | `OPEN` |
| D | Discrete mass conservation is exact to numerical roundoff | `OPEN` |
| E | Homogeneous and heterogeneous layer interfaces are qualified | `OPEN` |
| F | Recharge, zero flux and capillary rise are all supported without clipping | `OPEN` |
| G | Fixed-head, fixed-flux and free-drainage lower boundaries are consistent | `OPEN` |
| H | Moving groundwater table semantics are explicit | `OPEN` |
| I | Transactional checkpoint/trial/rollback is possible | `OPEN` |
| J | Runtime work is bounded and characterisable | `OPEN` |
| K | MODFLOW interface head/flux contract is supportable | `OPEN` |
| L | Bottom response tangent can be obtained at bounded marginal cost | `OPEN` |
| M | Full Richards comparison supports an explicit applicability envelope | `OPEN` |

A failure of Gate C or D blocks production admission.

## Experimental scope after theory gate

Only after Gates A-C are sufficiently reconstructed may an isolated harness be added. It must remain outside production runtime and support at minimum:

- multiple soil layers;
- heterogeneous hydraulic properties;
- fixed-head bottom boundary;
- fixed-flux bottom boundary;
- free drainage;
- infiltration;
- evaporation or imposed surface sink;
- distributed root uptake as external sink;
- rising and falling groundwater where methodically valid.

The harness must use the same SWAP hydraulic functions and parameters as the full Richards reference wherever mathematically possible.

## Required comparison quantities

- `theta(z,t)`;
- `h(z,t)` where defined and meaningful;
- total profile storage;
- face fluxes;
- bottom flux and capillary flux;
- drainage;
- sink uptake;
- groundwater exchange;
- per-step and cumulative water-balance residual;
- internal substeps/local solves;
- CPU cost and worst-case interval cost.

Structural bias must be reported separately from aggregate error metrics.

## Runtime contract

“Non-iterative” does not imply constant cost. The audit must count at least:

- work per layer;
- constitutive inversions;
- scalar root-finds, if any;
- table lookups/interpolation;
- local corrections;
- adaptive substeps;
- retries;
- state-dependent branches.

The target production form is a bounded model such as

`cost = O(N_layers * N_internal_steps * N_local_work)`

with explicit maxima for the bounded factors. An occasionally unbounded iterative trajectory fails the runtime objective even if mean CPU time is low.

## Groundwater / coupling contract

Direct coupling must be assessable against:

- `H_SWAP = H_MF`;
- `q_SWAP = -q_MF`;
- exact water transfer across the interface;
- predictor/corrector over generic coupling windows;
- rollback from unsuccessful trials;
- a response tangent such as `dq_b/dh_b` or `dh_b/dq_b` obtainable without a structural requirement for many full reruns.

## SWAP5 architecture constraints

All SWAP Core Architecture Invariants apply. In particular:

- one kernel, multiple solver implementations behind a common soil-water contract;
- kernel independent of files and parsing;
- parameters, dynamic state, forcing, numerical policy and results remain separate;
- persistent state compact and option-dependent;
- temporary numerical data worker-local;
- transaction-safe accepted-state semantics;
- generic `[t0,t1]` intervals;
- exact mass conservation;
- MultiSWAP-first batching and diagnostics;
- full Richards remains reference mode;
- physical options may not be changed by a performance policy.

## Planned evidence artifacts

1. source/provenance inventory;
2. mathematical reconstruction;
3. hydraulic-dependence matrix;
4. generalisation proof or counterexample for SWAP hydraulic families;
5. state and interface contract;
6. mass-ledger specification;
7. heterogeneous-interface qualification;
8. groundwater/bottom-boundary assessment;
9. isolated prototype only if theory gates justify it;
10. Richards comparison matrix;
11. runtime-cost evidence;
12. applicability and failure envelopes;
13. coupling-readiness assessment;
14. final decision.

## Final decision vocabulary

Exactly one of:

- `ROSSFAST_FEASIBLE`
- `ROSSFAST_FEASIBLE_WITH_RESTRICTED_ENVELOPE`
- `ROSSFAST_REQUIRES_FURTHER_RESEARCH`
- `ROSSFAST_NOT_SUITABLE_FOR_SWAP5`

## Current checkpoint

- investigated: duplicate branch check; primary Ross 2003 source; Crevoisier et al. 2009 independent evaluation/generalisation source; Ross 2011 follow-up source
- implemented: workunit contract only
- persisted: this contract
- tested: not applicable yet
- reproduced: no Ross numerical case reproduced yet
- qualified: nothing yet
- open: all Gates A-M

Current decision remains `ROSSFAST_QUALIFICATION_INCOMPLETE`.
