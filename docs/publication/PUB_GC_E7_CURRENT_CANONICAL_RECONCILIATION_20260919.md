# PUB-GC E7 current-canonical preservation

## Status

**E7_CURRENT_CANONICAL_PRESERVED**

Reconcile date: 2026-09-19.  
Canonical head inspected: `67dcbd5252ec6aab465329c55e427f535ce47f02`.

E7 was canonically admitted by PR #330 as:

`REALISTIC_COMPONENT_DOMAIN_LIMIT`

and stale pre-E7 readiness labels were subsequently removed by PR #332.

This record checks whether later production-physics/application work changes that scientific disposition.

## Current prescribed-head owner

The current production bootstrap still defines three homogeneous application profiles:

- `bottom_mode=5`: groundwater / prescribed-head owner;
- `bottom_mode=7`: standalone free-drainage owner;
- `bottom_mode=2`: prescribed-`q_bot` owner admitted by PPA-WU02-A.

Before owner-state allocation, `tile_config_valid` still rejects active:

- drainage response;
- root extraction;
- macropore flow;
- snow;
- hysteresis;
- elasticity;
- frost;
- soil-temperature coupling;
- tabulated hydraulics.

The E7-critical guards are therefore unchanged: authentic selected Hupsel drainage/root composition still cannot be instantiated under the production `bottom_mode=5` groundwater owner.

Current bootstrap blob:

`135803e056697a20aa3295721b02c77aba22367a`

## Post-E7 workunit reconciliation

| Workunit | Canonical state | Production effect relevant to E7 | E7 disposition |
| --- | --- | --- | --- |
| PPA-WU02 | canonical admitted / closed | adds homogeneous typed `bottom_mode=2` prescribed-`q_bot` application only | unchanged |
| PPA-WU03 | canonical admitted / closed | bounded stateless common-forcing adapter; does not broaden groundwater process ownership | unchanged |
| PPA-WU04 | scientific transaction authority frozen / closed | review-only; no production source mutation or admission | unchanged |
| PPA-WU05 | dependency-graph authority frozen / closed | review-only; no production source mutation | unchanged |
| PPA-WU05-A | canonically admitted review authority | no production source mutation; production implementation explicitly held | unchanged |
| PPA-LOW02-TIME | canonical admitted / closed | adds the B1.11 SWBOTB=2 time law and dry continuation inside the typed `bottom_mode=2` serialized Reference application; explicitly no new groundwater-coupling semantics | unchanged |
| PPA-WU05-C | canonical review authority / closed | oxygen-stress source/state/owner decomposition only; zero production source mutation and no production admission | unchanged |

None admits active Hupsel drainage or root extraction under the prescribed-head groundwater owner. The current production bootstrap remains byte-identical to the earlier preservation point (`135803e056697a20aa3295721b02c77aba22367a`); the later LOW02-TIME production mutation is confined to `mod_fmr_serialized_reference_backend.f90` and the homogeneous mode-2 application.

## Scientific consequence

The current repository therefore preserves the E7 conclusion:

**the authentic selected Hupsel application reaches the production component/application domain boundary before outer loose/strong coupling can execute.**

This remains:

- not outer-coupling divergence;
- not MODFLOW6 failure;
- not Richards-solver failure;
- not evidence that realistic strong coupling is unnecessary;
- not regional Hupsel groundwater validation.

The zero E7 coupled-window count remains a preregistered stop-rule result rather than missing postprocessing.

## Reopen rule

E7 itself stays closed.

A future canonically admitted capability that genuinely composes the required active Hupsel process set with prescribed-head groundwater ownership may motivate a **new prospectively defined experiment**. It must not retroactively replace the frozen E7 result.
