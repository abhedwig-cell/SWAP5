# PPA-WU05-A15 closeout — canonical bounded unponded RFM surface composition

Date: 2026-10-01

Status: CLOSED_CANONICAL_ADMITTED

Decision:

    CANONICALLY_ADMITTED_BOUNDED_UNPONDED_RFM_SURFACE_COMPOSITION_RECEIPT

## Canonical evidence

- baseline: `d89912713f9182f4a5319a54cb6094930d38e2cd`
- qualified postimage: `1056406db887aab0b3fe13d3a5071da5965275fa`
- qualification run: `36863638042` — SUCCESS
- admission PR: #937
- canonical merge: `875171570df1141bb116dcacfb18d8969211b601`

## Admitted capability

A15 canonically establishes a common surface-composition receipt for the bounded
case where the existing B1.10 surface owner has already classified the interval
as:

    flux-controlled
    unponded
    runoff-free
    carrying surface mass terms.

The owned quantity is:

    effective_supply = net_potential_surface_flux

and not `actual_top_flux`.

The receipt enforces:

    effective_supply = matrix_supply + preferential_supply

within explicit tolerance.

## A14 disposition

The A14 ownership blocker is resolved only for this unponded subset.

Still blocked:

- matrix-only head-controlled preflight;
- positive ponding;
- active runoff;
- attempts to recover a matrix-only ponded case through extra preferential
  capacity.

Those cases remain Reference-owned.

## Post-merge preservation

The exact qualified dependency surface is byte-identical on canonical:

    source 0107156b127d185df2d93d9de0ec18153072a245
    test   8387dcb9b3a6ae17c31e63d9d837d8a21afd526d
    runner 9d119f46d12856072d1c8c24e79427389bb45c0a

The focused qualification is therefore inherited without another CI replay.

## Lifecycle

    implemented -> persisted -> tested -> qualified -> canonically admitted -> closed

## Next safe step

A16 may take the A15 matrix share and construct a fresh matrix dynamic-top
request in which surface evaporation has already been accounted for and is not
double-counted.

A16 must prove that the recomposed matrix case remains flux-controlled,
unponded and runoff-free. If that proof fails, the whole interval returns to
the existing Reference route.

Preferential routing remains a separate later ownership problem.
