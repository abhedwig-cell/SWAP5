# SWAP5-MODFLOW6 fixed-interface drainage ownership contract

Status: **canonical authority for the bounded fixed-interface profile**

This contract applies to the bounded fixed-interface groundwater profile closed by
`F-GC_FIXED_INTERFACE_COUPLING_CONTRACT.json`.

## Current admitted profile

The admitted drainage owner is `NONE`.

Active SWAP drainage response is excluded by the production bootstrap. No MODFLOW
drain package or surface-water route is admitted here as an alternative owner of
the same physical drainage process. The coupling mass ledger is accounting only
and can never own a physical drainage route.

This is deliberately narrower than the research testbank. Analytical drainage
oracles remain regression evidence and do not widen production physics.

## One-route, one-owner rule

Before any physical drainage route is admitted, application topology must assign
that route to exactly one owner:

- `SWAP`;
- `MODFLOW`; or
- `SURFACE_WATER`.

For that same physical route, all other model-side representations must be absent
or explicitly disabled as independent drainage-flux calculations. Mirrored
reporting and an explicitly qualified receiving-budget entry are not independent
calculations. Coupler bookkeeping is not a fourth physical owner.

A route with unresolved ownership fails closed. A topology that represents the
same physical drainage route in more than one owner is invalid, even if the
resulting coupled calculation converges or its total water balance happens to
close.

## Both SWAP and MODFLOW can own drainage

The rule applies per physical path, not to the complete model application.
Distinct paths may be owned by SWAP and MODFLOW in the same application. For
example, a proposed configuration may assign local field drains to SWAP and a
different regional drain network to MODFLOW. These are examples, not declared
owners of an existing application or currently admitted coupled drainage.

Changing model names or route IDs does not make two representations of the same
physical drain independent. Identity must include physical asset/segment,
catchment/support, elevation/resistance law and destination provenance. Spatial
overlap alone does not establish duplication; neither does a different model
grid establish independence. Application authority must justify the mapping.

| Role | Required authority | Accounting consequence |
| --- | --- | --- |
| Flux evaluator | One authoritative drainage law for one physical path | Publishes the accepted signed transfer once |
| Donor budget | Declared physical source/control volume | Books the donor leg once |
| Receiving budget | Declared destination/control volume, if inside the modelled system | Books the opposite receiving leg once |
| Mirror/report | Reference to the same accepted transfer ID | Reports the amount without a second physical leg |
| Coupler/interface ledger | Accepted bookkeeping and provenance | Does not calculate drainage or create storage |

A receiver can be implemented in another model without becoming a second
drainage evaluator. Importing a SWAP-computed drainage amount into a MODFLOW
budget is permitted only when that budget entry has a justified physical role.
A second groundwater sink for water already removed from the same physical
storage is not such a role. An actual return/injection into a distinct receiving
domain is a different leg and needs explicit destination authority. For serial
segments, name the physical segments separately and qualify junction storage
and conservation; do not duplicate a complete path under two model names.

## Proposed per-path declaration and accepted receipt

Before mixed drainage admission, each route needs at least:

- physical path identity plus provenance, source domain and destination;
- authoritative evaluator and parameter/law authority;
- all other relevant model representations, marked disabled or mirror-only;
- explicit units, tile/cell area conversion and signed direction;
- physical storage-role authority for every budget leg;
- one accepted transfer identity, coupling window and committed-origin lineage;
- donor/receiver receipt identities, retry/rollback and restart publication rules.

For a signed accepted amount `D` directed from declared source to destination,
the physical ledger has source leg `-D` and receiving leg `+D`. For an external
destination, `+D` is an external export, not a fabricated receiving reservoir.
Reverse exchange uses the same pinned orientation with negative `D` when the
owning law admits it. Equal-and-opposite legs and mirrors of those legs are not
double counting. Two debits of the same physical amount are.

This is a proposed declaration surface for future admission, not a new typed
production API. The present per-cell `drainage_owner` selector is not enough to
declare an arbitrary set of mixed physical paths. Do not widen or reinterpret
it silently; any route carrier needs a separately reviewed runtime/topology
contract and selective owner/preservation qualification.

## Storage and PB01 boundary

The current fixed-interface contract already admits native MODFLOW STO as
`HEAD_STATE_CAPACITANCE`, not independently additive physical water storage.
Do not invent a physical drainage source by treating a STO budget term as a
second reservoir. Broader independent regional storage requires its own
application-domain authority. Drainage attribution does not resolve that
broader storage question.

PB01 discriminates response orientation. The accepted fixed-interface contract
already maps native inward `q_bot` to outward `q_swap` and uses the physical
corrector tangent. A drainage export is not automatically part of that lower-face
exchange, and cannot be booked as both drainage and `q_swap` without explicit
authority. PB01 does not qualify an active drainage path or its destination.

## Admission evidence for a future route

A future drainage widening requires route identity and destination to be explicit,
plus accepted component budgets showing that the drainage amount appears exactly
once and that the fixed-interface groundwater transfer remains separately
equal-and-opposite. Such a widening is outside the present closeout.

Required future witnesses include mixed SWAP/MODFLOW distinct-path execution,
same-path duplicate rejection even under aliases, both component budgets,
unit/area conversion, active-route response/tangent coverage, rejected-trial
nonpublication, accepted-window exactly-once publication, continuous/restarted
identity and affected owner/F-CI preservation. Actual physical component budgets
must be qualified; an abstract bookkeeping example is not sufficient.

`tests/fgc/test_drainage_route_authority_contract.py` checks only synthetic
declaration/receipt logic and that the existing production NONE gate is still
present. It is not a SWAP/MODFLOW physical execution or production admission test.

### Current-source physical component boundary (2026-10-11)

**Qualified component replay, active coupled drainage admission pending.**
The existing F-GC31 physical fixture has now been replayed against canonical
`989069886d971daed94b1ce7c8176e2d3f73dad1` production dependencies at O0 and O2.
The original fixture, six scientific assertions, finite-difference step and
tolerances are unchanged. Both modes produce byte-identical output: two accepted
substeps, three retries and a maximum head/face finite-difference error of
`2.711697e-5` within the original relative gate. This qualifies the restricted
prescribed-qbot, lagged active-drainage component, including its accepted-step
coverage and absence of extra full nonlinear solves.

The additive negative control uses the actual production head-forcing
materializer and Reference backend. With the same smooth drainage projection
and `bottom_mode=5`, materialization succeeds but backend execution returns
`KERNEL_STATUS_NOT_ADMITTED=101` before any transaction. No candidate becomes
available; pressure, water content, ponding, groundwater-level carrier, lineage,
revision and time remain byte-exact. Materializer acceptance alone therefore
does not establish physical backend or application admission.

This reproduces the bounded E6 profile-intersection failure on current source.
It does not establish that every head/drainage profile is rejected or that
SWAP-owned drainage cannot physically coexist with MODFLOW-owned drainage.
Removing the smooth projection would change the tested physical response and
requires its own explicit qualification; it is not an interchangeable repair.

Before this fixture can support a joint coupling experiment, RT/HY and central
F-GC must establish head-driven drainage authority: phreatic projection distinct
from lower-face head, lagged versus fully implicit response, complete drainage
budget/tangent coverage, and actual physical storage/path mapping. The existing
production NONE guard remains required. Physical distinct-path SWAP/MODFLOW
budgets, accepted-window publication and joint restart remain separate gates.

Exact checkpoint, current compile manifest, full raw logs and source recovery
are recorded in
`integration/f-gc/F-GC_DRAINAGE_PROFILE_BOUNDARY_20261011.json`;
the replay is `tests/fgc/run_fgc31_current_drainage_profile_boundary.sh`.
