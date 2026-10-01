# F-MACRO-TRACER01-D2B1 — canonical FMR MB ownership audit

Date: 2026-10-01

Status: QUALIFIED_SOURCE_AUDIT / WALL_EXCHANGE_AVAILABLE / MB_BOTTOM_OWNER_FALSIFIED

Canonical authority:

    integration/f-ci-canonical@ebea588070f7a44dbaea78169f2548c745061c48

## Purpose

Test whether the canonically admitted standard FMR macropore runtime can supply
the missing D2B water-transfer authority without adding new RFM hydrology.

The required D2B outputs are:

    depth-resolved MB -> matrix wall exchange
    vertical MB water transfer
    explicit MB bottom/deep export below the sampled profile

## Positive finding: wall exchange is source-owned

The canonical runtime publishes:

    macropore_runtime_result_t%exchange_rate_domain_cp(:,:)

and:

    macropore_runtime_result_t%exchange_rate_node(:)

The owning rate bundle constructs:

    qexc_to_matrix_rate
      = qout_sat_rate
      + qout_unsat_rate
      - qin_interflow_rate
      - qin_matrix_sat_rate

Thus positive exchange is explicitly macropore -> matrix and negative exchange
is matrix -> macropore.

Unsaturated wall absorption is source-bound through the admitted B1.11
sorptivity/Darcy equations. Saturated exchange is likewise source-bound.

Therefore a conservative tracer observer could, in principle, use accepted
FMR wall-water exchange without inventing a new wall-water law.

## Positive finding: vertical transfer is reconstructed

The canonical runtime also publishes:

    macropore_runtime_result_t%vertical_flux

with per-domain/per-compartment:

    q_bottom
      = q_top
      - q_exchange_to_matrix
      - q_external_outflow
      - dS/dt

and verifies local residuals at <= 1e-12 rate scale.

This is an adequate water-transfer observation contract for conservative
donor-cell tracer movement inside the admitted macropore domain.

## Critical finding: standard FMR has no deep bottom export owner

The candidate macropore storage update is:

    S_new
      = S_old
      + accepted_top
      - internal_exchange_to_matrix
      - rapid_external_outflow

There is no independent lower-boundary macropore export term in the standard
candidate mass balance.

The vertical-flux reconstruction uses the same accepted top input, storage
change, wall exchange and external rapid-drain terms.

Summing the reconstruction over all active compartments therefore yields:

    q_bottom_face
      = accepted_top
      - exchange_to_matrix
      - rapid_external_outflow
      - (S_new-S_old)

and substitution of the candidate storage balance gives identically:

    q_bottom_face = 0

up to numerical roundoff.

This is not an implementation defect. It is the current admitted ownership
boundary.

## Why rapid drainage cannot be reused

A10 explicitly defines rapid drainage as an external drain receipt from the
main macropore domain, with drain topology, drain level and resistance.

It is not the same physical receipt as conservative tracer surviving vertically
below the 1-m Spechtacker sampling profile.

Relabeling rapid drainage as MB bottom breakthrough would violate the admitted
process semantics and would create a false recovery mechanism.

## Consequence for D2B

The earlier blocker can be narrowed:

    MB wall-water exchange owner = AVAILABLE
    MB vertical internal transfer observer = AVAILABLE
    MB bottom/deep export owner = ABSENT

Therefore the canonical FMR standard runtime cannot close the Spechtacker
95-percent recovery forward problem as the MB hydrology owner.

## Falsified route

The following route is explicitly rejected:

    use canonical standard FMR as complete MB tracer hydrology owner
      -> reinterpret its reconstructed lower face or rapid drainage
         as below-profile bromide export

because the lower face is algebraically zero and rapid drainage has different
semantics.

## Decision

    CANONICAL_FMR_WALL_EXCHANGE_FOR_TRACER = SOURCE_COMPATIBLE
    CANONICAL_FMR_VERTICAL_TRANSFER_OBSERVER = SOURCE_COMPATIBLE
    CANONICAL_FMR_STANDARD_MB_BOTTOM_EXPORT = ABSENT
    RAPID_DRAIN_AS_MB_BOTTOM_EXPORT = REJECTED
    FULL_D2B_RECOVERY_USING_STANDARD_FMR = FALSIFIED
    NEW_RFM_PHYSICS = NONE

## Remaining valid resume routes

A full D2B recovery test requires an independently justified MB lower-boundary
owner, for example:

1. a future admitted continuous macropore bottom-outflow process;
2. a source-backed external MB travel/breakthrough model whose parameters are
   fixed independently of the 95-percent recovery datum;
3. direct breakthrough observations sufficient to define and qualify that
   lower-boundary owner.

Until then, Profile-1/Profile-2 depth validation remains qualified at D2A, but
absolute 95-percent recovery remains outside the executable source-bound
contract.
