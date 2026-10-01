# PPA-WU05-A26 resume result — backend dispatch precomposition audit

Date: 2026-10-01
Status: BLOCKED_BY_MACRO_TO_MATRIX_HEAD_OWNER
Canonical baseline: integration/f-ci-canonical@f477f3fb7bf272757ac7a764bf9492883a521754

## Progress

A26H is canonically admitted and resolves endpoint/MB wall sorptivity ownership:
- wet endpoint event sorptivity persists;
- dry-to-wet endpoint sorptivity is seeded from accepted mapped-node hydraulics;
- MB K/S are derived trial-locally from the accepted mapped MB node.

The remaining live dispatch was then traced field-by-field through A22A/A22B -> A25 -> A24.

## Blocking field

Both admitted wall-exchange operators require explicit:

    macro_to_matrix_head_difference_cm

A22A preregistration defines the Darcy term as:

    8*K*Delta_h/ell_ex^2*Delta t*dz

and explicitly treats the exchange inputs as caller-owned. Its qualification oracle used Delta h = 50 cm.

A22B likewise consumes explicit Delta h; its oracle used Delta h = 10 cm.

No admitted RFM configuration, physical state, hydraulic binding or runtime owner defines the macropore-side hydraulic head from which Delta h is to be derived.

The accepted matrix pressure head is available, but choosing for example:

    Delta h = max(0,-h_matrix)

would silently assume a macropore water pressure head of zero. That assumption is not present in the admitted repository authority and was not qualified by A22A/B. Endpoint storage depth is also not currently mapped to a macropore pressure head.

Therefore A26 cannot construct the A22A/B Darcy request without inventing a new physical boundary/state rule.

## Classification

This is a true physics ownership blocker, not a compile defect.

A26H remains valid and A25 is not falsified. The missing owner is narrower than the former wall-sorptivity blocker.

## Required resolution

Before live backend dispatch, qualify a source-backed rule for the macropore-side hydraulic head for:
1. terminating endpoint wall exchange;
2. persistent MB wall exchange.

The rule must specify whether the macro head is atmospheric/saturated zero head, storage-dependent, depth-dependent, or otherwise derived. It must not be selected merely to make the runtime gate pass.

After that rule exists, A26 can derive Delta h from the accepted origin, populate A25 requests, bind A24 matrix sources, and proceed to transaction/refinement qualification.

## Decision

```text
A26_BACKEND_DISPATCH = BLOCKED
BLOCKER = MISSING_MACRO_SIDE_HEAD_OWNER_FOR_DARCY_WALL_EXCHANGE
A26H = QUALIFIED_AND_CANONICALLY_ADMITTED
A25 = NOT_FALSIFIED
A20_RUNTIME_GUARD = KEEP
ZERO_HEAD_ASSUMPTION = NOT AUTHORIZED
NEXT = source-backed macro-side head contract, then resume A26
```
