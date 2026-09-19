# PUB-GC E7 current-canonical preservation

## Status

**E7_CURRENT_CANONICAL_PRESERVED**

Reconcile date: 2026-09-19.  
Canonical head inspected: `308a619c91d2cc3dae7f7aa143cfbe97c780c635`.

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
| PPA-LOW02-TIME | canonical admitted / closed | extends only the `bottom_mode=2` prescribed-`q_bot` application with legacy sine/table time law and dry `-2` continuation; explicitly no new groundwater semantics | unchanged |
| PPA-ROOT-HYD01 R1 | qualified restricted production patch | admits temporal-certificate coverage for one bound prescribed root-sink provider in the temporal indicator; does not alter the application bootstrap or admit `root_extraction_active` in mode 5 | unchanged |
| PPA-WU05-C | canonical review authority / closed | oxygen/root ownership review only; zero production source mutation and no production admission | unchanged |

None admits active Hupsel drainage or root extraction under the prescribed-head groundwater owner. In particular, the newer root-temporal certificate is a solver/acceptance-layer capability, not an application-owner admission. The decisive `tile_config_valid` guard remains unchanged.

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


## Refresh after later production work

The preservation check was refreshed after PPA-LOW02-TIME, PPA-ROOT-HYD01 R1 and PPA-WU05-C entered canonical.

Current supporting production blobs:

```text
production bootstrap:
135803e056697a20aa3295721b02c77aba22367a

serialized Reference backend:
80c7ca618ea228e31ac43ae493f16dd6eccc5991

Reference-Richards temporal indicator:
2068215a57edb1d2a59c36d6b32f519ebdc09ebd
```

The backend and temporal-indicator changes broaden lower-boundary time-law execution and prescribed-root temporal certification respectively. Neither changes the mode-5 groundwater application-owner admission rule. The E7 stop therefore remains at application composition, before outer coupling.
