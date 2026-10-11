# Verification principles

Verification is part of the architecture, not a final packaging activity.

## Reference chain

SWAP 5 verification uses the explicit reference chain defined in ADR-0005:

```text
B0  immutable SWAP 4.3.1 audit baseline
 -> B1 corrected SWAP 4.3.1 reference
 -> B2 SWAP 5 reference mode
```

A confirmed legacy bug is corrected and qualified in the B1 line before SWAP 5 is required to reproduce the corrected behaviour. SWAP 5 is not required to recreate a demonstrated B0 defect merely for numerical compatibility.

Every release or qualification result that depends on B1 should pin an exact B1 tag and commit. Unexplained B0/B1/B2 differences are verification failures until classified.

## Hard requirement: water balance

Mass conservation is non-negotiable. Every accepted standalone, coupled, fallback and performance-oriented path must produce a closed water balance within a defined numerical accounting tolerance.

A performance mode may trade solver effort for bounded state or flux accuracy, but it may not trade away water.

## Reference mode

A full-accuracy reference mode remains available. New numerical methods, response tangents, reduced-order approaches and performance policies are qualified against it before they can become normal production paths.

## Qualification dimensions

A useful qualification matrix includes at least:

| Dimension | Question |
| --- | --- |
| State accuracy | Are pressure head, water content, ponding and relevant module states within the qualified envelope? |
| Flux accuracy | Are interval-integrated surface, root-zone, drainage and bottom fluxes within the qualified envelope? |
| Mass balance | Does storage change equal net integrated flux plus qualified source or sink terms? |
| Solver route | Were retries, fallback classes and nonlinear iterations recorded? |
| Coupling residual | For coupled runs, are head and flux interface contracts satisfied? |
| Sensitivity accuracy | Are reported interface tangents consistent with finite-difference reference checks? |
| Cost | Is work bounded and predictable for difficult columns? |

## Transaction tests

Transactional stepping requires dedicated tests for:

- rollback after a rejected trial;
- commit of the accepted endpoint only;
- no double counting of integrated fluxes;
- deterministic or tolerance-consistent reruns from the same committed state;
- warm-start independence of the physical result.

## MultiSWAP tests

Batch execution must be checked for order independence. A column result may not depend on which column previously used the same worker scratch.

Problem columns that move to relaxed or fallback classes must carry diagnostics that make the execution route visible.

## Coupling tests

For direct groundwater coupling, tests should monitor both interface conditions:

```text
r_h = H_SWAP - H_MF
r_q = q_SWAP + q_MF
```

The accepted interface state must satisfy the qualified head residual while flux accounting remains conservative.

## Evidence rule

A numerical or architecture optimization is not considered qualified solely because a benchmark output looks similar. The evidence should state the baseline, tested cases, tolerances, mass-balance result, solver route and performance effect.
