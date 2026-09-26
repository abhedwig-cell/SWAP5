# F-PE-TEMPORAL07 P2 endpoint-bracket amendment

Date: 2026-09-26

Status: `PREREGISTERED_HARNESS_REPAIR`

## Trigger

The first live one-SWAP/one-MODFLOW-cell P2 run on TEMPORAL07 reached the independent endpoint oracle and failed before endpoint comparison with:

`independent physical endpoint is not bracketed`

The groundwater oracle itself completed and produced a finite, monotone local q(H) relation.

The production coupled path also completed and had already shown, on the immediately preceding P2 run:

- live MODFLOW6 convergence;
- two coupled iterations;
- final production external residual approximately 8.5e-20 m/s;
- corrector relinearization PASS;
- rejected-trial zero authority PASS;
- exactly-once publication PASS;
- MODFLOW -> SWAP -> ledger publication order PASS.

The blocker is therefore the independent root-search interval, not an observed endpoint mismatch.

## Cause

The inherited closeout oracle starts with a fixed half-width:

`2.0e-6 m`

around the reference head.

That width was sufficient for the historical closeout fixture. It is not an admission tolerance and is not part of the canonical physical residual or endpoint-head acceptance gates.

For the dynamic c=0.65 origin, the physical exchange scale is larger than in the historical fixture, so the root need not lie inside that historical fixed search interval.

## Repair

Retain the existing initial half-width:

`2.0e-6 m`

If the physical residual does not change sign, expand the bracket symmetrically by factor 2 until either:

- a sign change is obtained; or
- a frozen maximum half-width of `2.56e-4 m` is reached.

Maximum expansions: 7.

No root is accepted unless the original frozen physical residual gate is met.

## Invariants

This repair does not change:

- c=0.65;
- SWAP response;
- MODFLOW response;
- HCOF/RHS;
- endpoint-head acceptance tolerance;
- flux-residual acceptance tolerance;
- MODFLOW component-balance gates;
- stopping-flow gate;
- mass or transaction semantics;
- publication order.

If no bracket is found by the frozen maximum width, P2 fails.

The expanded bracket is only a numerical search device for the independent oracle. It is not an enlarged physical acceptance envelope.
