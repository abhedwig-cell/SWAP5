# F-PE-TANGENT01 — accepted-trajectory tangent authority discrimination

Date: 2026-09-26

Status: `PREREGISTERED_RESEARCH`

Parent:

- F-PE-TEMPORAL06 / PR #650
- parent head at workunit creation: `2e2babe92f7aea823ac9de3961cbffab673d06ee`

## Trigger

TEMPORAL06 established for O14 mid dynamic origins that:

- c=0.50 and c=0.65 both produce physically close q responses;
- their published accepted-trajectory tangents differ by about 5.86%;
- an independent fine Reference finite-difference q(h) derivative is stable;
- c=0.50 differs from that derivative by about 6.85%;
- c=0.65 differs by about 12.31%;
- neither satisfies the preregistered 2% authority bound.

TEMPORAL06 therefore closed without production temporal-policy admission.

## Core ambiguity

The current participant publishes an accepted-trajectory directional derivative.

That derivative is composed over the actual accepted numerical path.

For the failing O14-mid cases:

- c=0.50 accepts two half-window substeps after one temporal retry;
- c=0.65 accepts one full-window substep with no retry.

The independent TEMPORAL06 authority instead used a much finer fixed-substep Reference path.

Therefore two distinct hypotheses remain:

### H1 — directional implementation defect

The published tangent is not even the derivative of the numerical response map that the participant actually evaluates.

If H1 is true, tangent publication itself requires repair.

### H2 — path-consistent but discretization-dependent derivative

The published tangent is the correct derivative of the accepted numerical trajectory, but that trajectory's q(h) derivative differs from the fine Reference q(h) derivative.

If H2 is true, the accepted-step directional implementation may be internally correct. The unresolved question then becomes which derivative the MODFLOW coupling contract requires when SWAP uses an approximate temporal trajectory.

TANGENT01 discriminates H1 versus H2 before any source repair is attempted.

## Scope

Primary matrix:

- O14;
- mid regime, h0 = -75 cm;
- accepted dynamic history imbalance -0.10 and +0.10;
- corrector offsets -0.01, -0.001, +0.001 and +0.01 cm.

Policies:

- HIST_HALF, c=0.50;
- SELECTED, c=0.65.

Tangent cache is disabled.

No production source change is allowed in P0.

## P0A — same-policy finite-difference derivative

For each origin, target head and policy:

1. evaluate the unperturbed candidate and record its fresh published tangent;
2. discard the candidate;
3. evaluate q at h-epsilon from the exact same captured origin and discard;
4. evaluate q at h+epsilon from the exact same captured origin and discard;
5. compute central finite difference:
   `D_policy(epsilon) = [q_policy(h+epsilon)-q_policy(h-epsilon)]/(2 epsilon)`;
6. record retry count, temporal rejection count and accepted-substep count for h, h-epsilon and h+epsilon.

Preregistered epsilon ladder:

- 1.0e-4 cm;
- 2.5e-4 cm;
- 5.0e-4 cm;
- 1.0e-3 cm.

Primary same-policy finite-difference value:

- epsilon = 2.5e-4 cm.

The primary value is frozen before execution.

## P0A smooth-path gate

A same-policy derivative is authority-resolved only when:

1. h-epsilon, h and h+epsilon all complete;
2. none has a solver rejection;
3. all three use identical retry count and accepted-substep count;
4. finite-difference values at epsilon 1.0e-4, 2.5e-4 and 5.0e-4 cm agree within 1% relative to the primary value.

The 1.0e-3 cm value is reported as a curvature/path-boundary diagnostic.

If the accepted path changes across +/- epsilon, the point is classified `POLICY_MAP_NONSMOOTH` and no directional correctness conclusion is drawn there.

## P0A directional correctness bound

For smooth resolved policy maps:

- published tangent versus same-policy finite-difference derivative relative error <= 1%.

This is intentionally tighter than the TEMPORAL06 2% fine-Reference comparison because both quantities here represent the same numerical response map.

Classification:

- `DIRECTIONAL_MATCH`: <= 1%;
- `DIRECTIONAL_MISMATCH`: > 1%;
- `POLICY_MAP_NONSMOOTH`: path gate fails.

If either c=0.50 or c=0.65 systematically mismatches its own response-map derivative, H1 is supported and a source repair becomes justified.

If both match their own response-map derivatives, H2 is supported.

## P0B — fixed-substep derivative ladder

Independently evaluate fixed-substep Reference q(h) finite-difference derivatives at:

- N=1;
- N=2;
- N=4;
- N=8;
- N=16;
- N=32;
- N=64.

Use epsilon = 2.5e-4 cm for the primary N-ladder.

Purpose:

- determine whether c=0.65 published tangent aligns with N=1 Reference behavior;
- determine whether c=0.50 published tangent aligns with N=2 Reference behavior;
- quantify convergence of dq/dh with temporal refinement;
- separate tangent-composition error from temporal-discretization derivative error.

No post-hoc N selection is allowed.

## Decision logic

### Outcome A — same-policy mismatch

If a published tangent differs by >1% from the finite-difference derivative of its own smooth policy response map:

- classify the tangent implementation as unqualified;
- localize the directional assembly defect;
- preregister a separate source repair inside TANGENT01 before changing production code.

### Outcome B — same-policy match, fixed-N alignment

If published tangents match their own policy maps and approximately align with the corresponding accepted-substep Reference derivative:

- directional composition is internally correct;
- the TEMPORAL06 discrepancy is temporal-discretization dependence of the derivative;
- no source repair is justified;
- proceed to a contract decision on whether MODFLOW linearization should use:
  - derivative of the actual approximate participant response, or
  - derivative of a finer/reference response surrogate.

TANGENT01 itself does not change that contract.

### Outcome C — same-policy match but no fixed-N alignment

If the tangent matches the candidate map but not the nominal N=1/N=2 fixed-substep arms:

- inspect transaction forcing/state differences before attributing the discrepancy;
- remain research-only.

## Scope exclusions

No change to:

- c=0.65;
- c=0.50 comparator definition;
- BALTOL02;
- Richards equations;
- retry scale;
- temporal error bounds;
- tangent-cache defaults;
- MODFLOW coupling semantics;
- production tangent implementation during P0.

Repository evidence, not expectation, decides whether a repair phase is warranted.
