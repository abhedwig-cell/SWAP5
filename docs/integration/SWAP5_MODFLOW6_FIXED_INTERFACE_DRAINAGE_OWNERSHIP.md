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

### Proposed head-driven drainage contract for owner review

**Proposed, not production admission.** Central F-GC separates three response
profiles. A reported groundwater-level carrier and a physical phreatic state
are not interchangeable, even if a trial closes its numerical water balance.

| Profile | Drainage input during a trial | Response authority |
| --- | --- | --- |
| Current F-GC31 qbot | Smooth pressure-state projection, lagged per accepted substep | Admitted restricted qbot tangent; unchanged |
| Held-GWL head discriminator | Explicit reported GWL held throughout the window | Separate research component profile; no claim of evolving phreatic feedback |
| Proposed lagged head drainage | Smooth projection from each substep's physical origin, with head-driven accepted trajectory | Requires RT/HY response qualification and separate F-GC application admission |

The explicitly different held-GWL discriminator now passes six actual Reference
trials at O0/O2 with exact stdout identity on baseline `767503df`. Reported GWL
carriers are `-0.3` and `-1.5 cm`; head perturbations are `-1e-5`, zero and
`+1e-5 m` around the existing predictor reference. The original pressure state
is retained while these carriers are deliberately varied independently. They
are research selectors, not an actual field water-table assignment.

Over `0.01 day`, drainage is respectively `6e-5` and `3e-5 cm` in all three
head trials. The separate bottom exchange responds to head, with centered
native-rate slopes `-5.726905493164124` and `-5.725488201324679 cm/day per m`.
Both the reported complete budget and independent `deltaS + D + bottom_out`
close in all six cases, with maximum absolute residual `6.776263578034403e-21 cm`.
The trials retain the origin's pressure/water/GWL, revision and time. Existing
qbot and smooth-head negative controls also pass. These are finite-difference
response diagnostics; an analytic head/drainage tangent was not requested.

The result demonstrates actual head-driven component drainage with a held
carrier, while explicitly showing its missing head-to-drainage feedback.
Complete evidence and the proposed owner handoff are in
`integration/f-gc/F-GC_FIXED_GWL_HEAD_PROFILE_20261011.json`.

The proposed extension retains the existing drainage laws and bottom-compartment
distribution. It does not introduce fully implicit drainage inside the Newton
residual. Its explicit configuration must distinguish a held carrier from a
projected physical state; disabling the existing qbot projection flag cannot
silently select the proposed response. A component contract does not widen the
production application NONE gate.

#### Physical and directional meaning

For accepted substep `n`, let `x_n(H)` be the physical origin of that substep
within the candidate trajectory. The first origin is the same immutable
committed state for every outer corrector. Later origins are accepted states
inside that trial. The proposed lagged response is:

```text
g_n(H) = P(x_n(H))
D_l,n(H) = L_l(g_n(H), c_l,n) * dt_n
D_l,window(H) = sum over accepted n of D_l,n(H)
```

`P` is an explicitly qualified phreatic projection. `L_l` is the existing
authoritative law for physical drainage path `l`, with externally held controls
`c_l,n`. `H` is the prescribed lower-face head in the accepted datum. It is not
assigned to `g_n` by identity. The solver uses the lagged drainage contribution
unchanged within each substep's Newton solve. On a retry, rejected state,
projection and drainage amount have no authority.

For a fixed qualified sequence of substep durations and smooth branches, the
required drainage direction is the accepted trajectory chain:

```text
dD_l,window/dH = sum over accepted n of
    dt_n * (dL_l/dg_n) * (dP/dx_n) * (dx_n/dH)
```

The first origin has zero direction with respect to the newly varied head;
later accepted substep origins may have nonzero direction. Direct head-dependent
controls or changing substep durations require separately declared derivative
terms and qualification. This contract does not silently ignore them. Finite
differences qualify the analytic direction only when the accepted duration
sequence and physical branch remain the same. Counts alone do not establish
that condition. Kinks, saturated branches, below-profile sentinels and missing
source/sink coverage remain fail-closed rather than becoming fabricated zero
derivatives.

The head-control coordinate already exists in
`mod_soil_water_accepted_step_direction_contract`; the proposed extension must
bind the complete drainage direction to that coordinate. Existing qbot-specific
projection/binding code is source authority for its admitted envelope, not
automatic authority to remove its bottom-mode guards. Runtime finite differences
must not become the production response path.

#### Storage, route receipts and implementation boundary

SWAP retains its physical column storage and its drainage donor leg. A separate
MODFLOW-owned route requires independently justified physical groundwater
storage and path identity. The existing HEAD_STATE_CAPACITANCE proxy cannot be
relabelled as that donor merely because a DRN package can be configured. Distinct
path declarations still require physical provenance; aliases of the same path
must be rejected before accepted publication.

The lower-face transfer and each drainage path retain separate signed amounts
and receipts. Each component budget must contain its own actual physical legs;
no diagnostic aggregate is an additional transfer. Receipt publication follows
committed-origin provenance and the existing all-preflights-before-publication
transaction. New route-specific schema/state is a reviewed RT/F-KT change, not
a reinterpretation of the existing per-cell selector.

The source surfaces for a selective RT/HY candidate are the smooth projection,
drainage directional binding, serialized Reference backend and accepted-step
directional service. Shared owners must review configuration, control-coordinate
binding, accepted-step coverage and exported route amounts before implementation.
Existing qbot guards, drainage laws, lower-face signs, mass acceptance, retry
policy, crop/root/frost/irrigation owners and production NONE profile are held
fixed until their specifically declared qualification/admission gates pass.

The concrete owner gate requires O0/O2 physical trajectories and complete
budgets, same-origin head perturbations with complete analytic drainage/bottom
directions, smooth and excluded-branch witnesses, unchanged qbot/held-profile
controls, rejected-trial nonpublication and affected RT/HY/F-KT preservation.
Actual mixed-path SWAP/MODFLOW execution, unit/area conversion, exactly-once
receipts and joint continuous/restarted identity remain mandatory before
production application admission. This proposal supplies the reviewable contract;
it does not claim those gates have run.
