# F-ROMV2 D6 quasi-steady manifold preflight adjudication

**Workstream:** F-ROM  
**Work unit:** F-ROMV2-D6  
**Decision:** **D6_FIXED_ENDPOINT_BRACKET_NO_GO_BEFORE_TRAJECTORY_EXPOSURE**

## Scope

D6 did not reach dynamic hydrological validation.

Its preregistered one-state quasi-steady manifold required the prescribed-head
root search to start from a fixed flux bracket

`[-Ksat,+Ksat]`

and required both bracket endpoints to generate finite, physically admissible
unsaturated profiles.

That condition was tested before any D01-D08 or V01-V04 trajectory evidence was
consumed.

## Immutable preflight

Workflow run **35446115430**, job **105905207753**, executed head
`e979ff99045166b645be72a6ece09afba2066e5d`.

Artifact:

- ID: **10585064118**
- digest:
  `sha256:4177cc02c7cb542f546f3b6969fdc68b743770cf2a45751753d3112677ce6588`.

At the initial B01 equilibrium:

- Se = 0.85;
- h = -29.793709 cm;
- K = 3.923998 cm d-1;
- storage = 58.619184 cm.

The equilibrium control profile at q=K is finite and reproduces the requested
storage to about (10^{-12}) cm integration scale.

The frozen bracket endpoints do not satisfy the preregistered physical-domain
contract:

- q = -Ksat: profile evaluation reaches an invalid conductivity state;
- q = +Ksat: the profile reaches water content outside the open unsaturated
  physical domain.

Therefore the fixed bracket is not a valid bisection bracket under D6's own
rules.

## What this means

D6 is a **root-search-design no-go**.

It is not a hydrological no-go for the quasi-steady manifold hypothesis.

No dynamic forcing sequence was evaluated and no D01-D08 or V01-V04 evidence
was consumed.

This distinction matters because the frozen physical equations themselves were
not contradicted. The failed element is the assumption that two extreme flux
values can serve directly as finite endpoint evaluations.

## Why the bracket is not changed in D6

After the preflight, the invalid endpoints are known.

Narrowing the bracket until it works would therefore be post-result tuning of a
preregistered search rule.

That is prohibited even though the repair is mathematically obvious.

The correct action is to close D6 and preregister a new search construction
before it is evaluated.

## D7 design requirement

A successor may preserve the QS1 physical model, constitutive relations,
steady-profile ODE and fixed RK4 resolution, but it needs a different root
search.

The next search should first identify the physically admissible connected
segment around the known equilibrium solution using a deterministic,
predeclared continuation procedure.

Only finite admissible points may be used for sign-bracketing.

That search procedure must be fixed before any dynamic trajectory evidence is
evaluated.

## Boundary

D6:

- changes no production or Reference source;
- changes no production tolerance;
- consumes no dynamic trajectory evidence;
- establishes no application acceptance;
- establishes no performance claim;
- establishes no production ROM authority.

Production ROM remains unauthorized.
