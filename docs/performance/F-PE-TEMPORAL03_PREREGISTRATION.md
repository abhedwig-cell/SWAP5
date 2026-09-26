# F-PE-TEMPORAL03 — dynamic-history and refined-oracle qualification

Date: 2026-09-26

Status: `PREREGISTERED_RESEARCH`

Parent: `F-PE-TEMPORAL02` / PR #643

Parent head: `94adadde5038fd42553aa3b82b4157c5df3eb5cd`

## Trigger

TEMPORAL02 characterized the stationary/equilibrium difficult-origin temporal-budget frontier but deliberately stopped short of production policy admission.

Two missing authorities remain:

1. dynamic origins with a nonzero accepted predecessor right-derivative;
2. an independent refined Reference oracle for the next corrector window.

## Purpose

Determine whether the TEMPORAL02 budget frontier persists on dynamically evolving origins and quantify actual temporal state/flux error independently of the candidate temporal certificate.

Research-only. No production `src/**` changes.

## P0 — dynamic-origin construction

Construct a prior accepted physical step using a test-only Reference-floor route, not the candidate temporal certificate.

For each selected difficult material/regime:

- start from the same physical origin family as TEMPORAL02;
- impose a bounded top/bottom flux imbalance over one 1e-4 day history window;
- require a converged Reference-floor physical step and complete mass accounting;
- compute the accepted right derivative from `(h_end - h_start) / dt`;
- re-materialize the resulting physical state as a temporal-history committed state at the new origin time, seeded with that computed derivative.

Use at least two history directions where numerically feasible: storage-increasing and storage-decreasing.

Acceptance gate:

- nonzero finite predecessor derivative;
- deterministic physical state;
- complete mass accounting;
- no temporal certificate used to construct the origin.

## P1 — dynamic-origin budget frontier

On each admitted dynamic origin, apply same-origin mode-5 head correctors at signed displacements:

- +/-0.001 cm;
- +/-0.01 cm;
- +/-0.05 cm.

Compare temporal budgets centered on the stationary frontiers from TEMPORAL02.

Record completion, ordered retry path, q, terminal state and runtime.

## P2 — refined temporal oracle

For selected dynamic origins and correctors, construct an independent fixed-substep Reference oracle spanning the same 1e-4 day corrector window.

Oracle requirements:

- no candidate temporal certificate;
- fixed subdivision schedule frozen before candidate comparison;
- convergence demonstrated by at least two refinement levels, for example 8, 16 and 32 equal substeps where feasible;
- terminal state and integrated bottom exchange convergence quantified.

Candidate policy error metrics:

- max |dh|;
- max |dtheta|;
- terminal q difference;
- integrated bottom-exchange difference;
- mass residual;
- runtime.

## P3 — policy interpretation

Only after P0-P2 may a fixed, scaled or coupling-specific temporal policy be considered.

Any production default or algorithm change requires a separate admission workunit.

## Stop conditions

Split to a repair workunit if:

- fixed-substep refinement itself is nonconvergent or non-monotone because of a solver defect;
- dynamic-origin temporal history is not preserved by transaction cloning;
- mass authority becomes incomplete;
- the candidate indicator is inconsistent with independently refined error.
