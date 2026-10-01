# SW-RIB-TOP01 — external surface-water inundation top-boundary research

Date: 2026-10-01

Status: PREREGISTERED_RESEARCH

Baseline:
`integration/f-ci-canonical@8bfff34e5bf06817f63a571282f70436cd90ede2`

Parent issue:
#589, reconciled against later F-APP09 / F-CI109 / SW-RIB-ADM01 authority.

## Purpose

Close only the still-unqualified top-surface exchange gap for the
Ribasim-owned surface-water application profile.

Do not reopen the already admitted EXTENDED_SIGNED drainage/infiltration
exchange.

## Existing admitted authority

F-APP09 / F-CI109 / SW-RIB-ADM01 already own:

- typed accepted external Ribasim surface-water head;
- one signed subsurface drainage/infiltration exchange;
- Ribasim ownership of represented surface-water state;
- same-origin recomposition on realized-transfer mismatch;
- exactly-once accepted transfer/commit semantics.

Their explicit exclusions include top-runoff production binding.

## Exact legacy authority already reconstructed

F-PM08D exact-source reconstruction establishes the secondary balance term:

`V_top_surface_exchange = RUNOTS`

with sign:

- positive: soil surface/runoff -> secondary surface water;
- negative: secondary surface water -> soil surface (inundation).

Legacy source authority is `SWAP/boundtop.f90:292-320` together with the
secondary storage balance in `surfacewater.f90`.

This term is distinct from the EXTENDED_SIGNED subsurface drainage exchange.

## Current gap

Current `mod_b110_dynamic_top_boundary_provider` owns atmospheric input,
ponding and runoff against an internal `ponding_max_cm`, but its request has
no external accepted surface-water head and no external inundation regime.

Therefore the coupled application currently has no qualified route by which a
Ribasim level above the field-surface threshold imposes top-surface water on
SWAP.

## Research hypothesis

For the bounded legacy flooding concept, when the accepted external
surface-water level exceeds the applicable field-surface/ponding threshold and
the local ponding level, the top boundary can be represented as an externally
imposed surface head with zero additional field-surface hydraulic resistance.

The resulting signed top-surface transfer is a candidate cross-model transfer,
not an independently committed Ribasim or SWAP storage mutation.

## Ownership

- Ribasim: accepted external surface-water level/storage.
- SWAP dynamic top boundary: constitutive soil/top-surface response to that
  accepted level.
- Coupler: candidate transfer identity, availability/feasibility if required,
  same-origin recomposition and exactly-once accepted booking.
- Existing SWAP ponding state: local field-surface water only; it must not
  become a duplicate of Ribasim storage.

## Frozen sign convention

Define `q_top_to_soil > 0` as water entering the SWAP soil/surface system.

Interface publication to Ribasim uses the opposite signed amount.

Legacy `RUNOTS` therefore corresponds to:

`RUNOTS = - dt * q_top_to_soil`

for inundation, and positive RUNOTS for runoff to surface water.

No sign reinterpretation is permitted after candidate publication.

## Required research cases

1. external level below threshold: existing atmospheric/ponding behavior
   unchanged;
2. external level exactly at threshold: deterministic equality classification;
3. external level above threshold but not above current local ponding:
   no artificial reverse transfer;
4. external level above threshold and above local ponding: external-head
   inundation route;
5. simultaneous rainfall plus inundation;
6. transition from runoff to inundation across otherwise identical origins;
7. rejected coupled trial: no committed ponding/soil/Ribasim mutation;
8. same-origin replay: identical candidate signed transfer;
9. direct interval mass closure with the top-surface transfer booked once;
10. coexistence with admitted subsurface EXTENDED_SIGNED exchange without
    conflating the two transfer identities.

## Equality policy

Equality seams are part of qualification and may not be hidden behind an
arbitrary epsilon. If a numerical tolerance is required for solver switching,
it must be named as numerical policy and tested on both sides of the physical
equality.

## First implementation boundary

The first candidate may extend the dynamic-top request/result with a typed
external-surface-water hydraulic view and a distinct inundation result.

It must not:

- import Ribasim types into the solver;
- add persistent Ribasim-owned storage to SWAP;
- change F-APP09 subsurface exchange semantics;
- add management/allocation policy;
- retire the standalone fixed-weir profile;
- claim full SWAP5 + MODFLOW6 + Ribasim triangle admission.

## Falsification

The proposed direct external-head representation is falsified if exact legacy
source reconstruction shows a non-negligible field-surface resistance or
additional stateful flooding law in the relevant branch, or if a
transactionally clean single signed top transfer cannot reproduce the bounded
legacy mass semantics.

## Next gate

TOP01-A: recover the exact boundtop flooding branch from the frozen SWAP 4.3.1
source authority and derive the branch inequalities and transfer equation at
source level before production implementation.
