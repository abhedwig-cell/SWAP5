# GC-RZM06 real-SWAP falsification bridge

Date: 2026-09-22  
Status: PREREGISTERED OBSERVATION PLAN  
Production source: read-only

## Why the analytical ladder stops here

RZM01-RZM05 have isolated memory, forcing order, signed bidirectionality,
minimal nonlinearity and management. Adding further dummy physics would no
longer answer the principal transfer question. RZM06 therefore uses real SWAP
as a falsification target.

Existing real-SWAP work already establishes two constraints that RZM06 must
respect:

1. the fixed lower-interface head is not automatically the phreatic elevation;
2. the measured real-SWAP physical outward tangent has opposite sign to the
   historical +u/dt production-facing affine slope in the qualified fixture.

RZM06 does not reopen either result.

## Claims transferred from the analytical ladder

The following are hypotheses to test, not assumptions about real SWAP:

H1. Equal fixed-plane interface head does not uniquely determine the next
whole-window real-SWAP interface exchange when accepted internal soil states
differ.

H2. Equal interface head and equal scalar total profile water do not
necessarily determine the next response when vertical water distribution
differs.

H3. A local interface-response derivative is conditional on the committed
internal state and coupling window.

H4. Accepted whole-window bottom exchange remains a ledger quantity distinct
from any predictor coefficient used by the outer coupler.

H5. Root-zone management can alter future interface response through accepted
soil state without creating a second MODFLOW hydraulic interface.

## Observable mapping

Analytical W_r maps to an integrated real-SWAP root-zone/profile water
inventory computed from accepted nodal water contents over a prospectively
fixed depth interval. Analytical lower state maps only to accepted lower-profile
state descriptors; it is not identified with phreatic elevation.

H_c maps to the already qualified fixed lower-boundary hydraulic-head control.
E_c maps to accepted integrated physical bottom exchange using the native
qbot-to-outward sign conversion already audited by MAP02/MAP03.

The experiment must retain the full accepted SWAP restart/checkpoint state.
Scalar water inventories are observables for pairing and interpretation, not
replacement restart states.

## Paired-state experiment design

A. Same H_c, different antecedent forcing. Prepare two accepted SWAP states
with distinct root/profile distributions, then run an identical forcing-free
probe window at the same fixed H_c. Compare accepted E_c.

B. Same H_c and matched total profile water, different vertical distribution.
Construct states by distinct antecedent forcing sequences and select a pair
whose integrated profile-water difference is within a prospectively declared
matching tolerance while a vertical-distribution metric remains distinct.
Run identical probe windows.

C. Local tangent from different committed states. Around the same H_* execute
fresh immutable trials at H_*-dH and H_*+dH from each committed checkpoint.
Compare central finite-difference physical E_c tangents.

D. Management-memory probe. Prepare equal H_c states differing through a
managed root-zone input, then compare a later no-management probe. Management
water is external SWAP input; bottom E_c remains the only groundwater exchange.

## Admission rules

No pair may be selected after looking at its probe E_c. Pair selection uses
only antecedent-state observables. Every probe starts from an immutable accepted
checkpoint. Failed real-SWAP trials remain evidence and are not silently
discarded. Numerical convergence is necessary but cannot substitute for the
paired physical comparison.

A concrete fixture, depth interval, tolerances, perturbation dH and durations
must be frozen from existing real-SWAP authority before execution. If the
current fixture cannot independently vary the required internal state while
holding H_c, RZM06 records that limitation rather than changing production
physics.

## Decision boundary

Confirmation of H1-H5 would support the architecture in which H_c remains the
physical MODFLOW interface state while real SWAP retains richer private state
and exposes state/window-bound response information. Falsification of any
hypothesis narrows that architecture. Neither outcome by itself authorizes a
production coupling change.
