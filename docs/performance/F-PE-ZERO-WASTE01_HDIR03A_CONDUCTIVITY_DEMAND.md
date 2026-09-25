# F-PE-ZERO-WASTE01 HDIR03A — accepted-step base-state conductivity demand

Date: 2026-09-25

Status: `CANDIDATE_PENDING_QUALIFICATION`

Authority parent: `31de53a448cbd048045a95c111682262c4fb9657`.

## Observation

The accepted-step directional service re-evaluates the constitutive provider at the base state before the tangent backsolve. The full tuple API writes water content, conductivity, capacity and the reserved dK/dh output.

On this route only base-state conductivity is consumed from that call. Water-content scratch is overwritten by the analytic directional sibling and capacity/dKdh are not consumed before the backsolve.

## Candidate

Replace the full base-state constitutive value evaluation with the existing demand API using `CONSTITUTIVE_DEMAND_CONDUCTIVITY`.

The B110 demand implementation still computes the theta intermediate required by the conductivity law, but it does not compute or write capacity or dK/dh.

No change is made to:

- tangent RHS semantics;
- analytic dK direction;
- accepted factorization/backsolve;
- outgoing pressure-head or water-content direction;
- top or bottom flux derivative;
- source/sink direction handling;
- number of backsolves, Jacobian builds or nonlinear solves.

## Gates

- FKT22 directional physical/provenance identity;
- HDIR02 active-drainage successor;
- isolated directional paired runtime against the exact authority parent;
- accepted backsolve count unchanged.

Shared-runner timing is local evidence only, not a portable speed claim.
