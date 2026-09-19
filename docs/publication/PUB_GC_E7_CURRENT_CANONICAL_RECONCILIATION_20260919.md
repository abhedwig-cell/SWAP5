# PUB-GC E7 current-canonical preservation

## Status

**E7_CURRENT_CANONICAL_PRESERVED**

Reconcile date: 2026-09-19.  
Canonical basis inspected: `integration/f-ci-canonical@ab8d52a3b3ab39470a989a46dc19e3bd24a01906`.

E7 was canonically admitted through PR #330 as `REALISTIC_COMPONENT_DOMAIN_LIMIT`. PR #327 is historical/superseded and must not be rebased or merged as a second authority path.

The latest E7-relevant production merge before this reconcile is PPA-WU04-B at `4d40b8d4b6a1df06ff97fab55497542778431290`. The subsequent delta through the inspected live head is confined to evidence-only F-ROMV2/TRACE/F-DOC work and ROM tests. The current bootstrap, serialized backend, runtime core, restart state and restricted surface-evaporation blobs remain exactly the PPA-WU04-B postimages, so that delta has no E7 authority effect.

## Current prescribed-head owner

The production bootstrap still admits homogeneous profiles for:

- `bottom_mode=5`: groundwater / prescribed-head ownership;
- `bottom_mode=7`: standalone free-drainage ownership;
- `bottom_mode=2`: prescribed-`q_bot` ownership.

Before owner-state allocation, `tile_config_valid` still rejects both E7-critical active flags:

- `root_extraction_active`;
- `drainage_response_active`.

Current bootstrap blob:

`356b3825a8ba13af1fed385ab17ffdb330b1058f`

The authentic Hupsel application therefore still cannot be materialized as a process-complete mode-5 production groundwater participant.

## Post-E7 authority reconciliation

| Workunit | Current authority | Effect relevant to E7 |
| --- | --- | --- |
| PPA-WU02 | canonical admitted / closed | adds homogeneous typed `bottom_mode=2` prescribed-`q_bot`; no mode-5 process widening |
| PPA-WU03 | canonical admitted / closed | bounded stateless common forcing; no mode-5 process widening |
| PPA-WU04 | scientific transaction authority frozen | review-only at that stage; no E7 owner widening |
| PPA-WU05 / WU05-A / WU05-C | bounded review/authority work | no process-complete groundwater-owner admission |
| PPA-LOW02-TIME | canonical admitted / closed | extends only mode-2 prescribed-`q_bot` time-law semantics |
| PPA-ROOT-HYD01 | restricted prescribed-root temporal certificate | does not admit `root_extraction_active` in the mode-5 application owner |
| PPA-ROOT-HYD02 | restricted prescribed-root accepted-trajectory tangent coverage | explicitly no live-MODFLOW root-active application admission by this workunit alone |
| PPA-WU04-A | bounded SWREDU=1 Black evaporation production slice | mode-5 Black composition remains unadmitted; root/drainage guards unchanged |
| PPA-WU04-B | bounded SWREDU=2 Boesten-Stroosnijder evaporation production slice | mode-5 Boesten composition remains unadmitted; root/drainage guards unchanged |
| HYDRO-MEMORY ACC02-F1 | live MODFLOW6 single-window prescribed-root research qualification | no production/reference source change; drainage inactive; no mode-5 production-owner widening; Stage 0 not authorized |

PPA-ROOT-HYD01/HYD02 are relevant numerical/accepted-trajectory capabilities, but they do not constitute application-owner composition. PPA-WU04-A/B change bounded evaporation production code, but both remain excluded from mode 5 and leave the E7-critical root/drainage guards intact. HYDRO-MEMORY ACC02-F1 does not alter that conclusion: it is a research qualification of prescribed-root coupling with drainage inactive, not a process-complete application-owner admission.

## E7 provenance repair

The former stale statement `ppa_wu03_found_in_canonical=false` has been retired from current-state provenance. The restored current application-requirements record now states explicitly that:

- PPA-WU02 is canonical and does not widen mode-5 process composition;
- PPA-WU03 is canonical and does not widen mode-5 process composition;
- PPA-ROOT-HYD01/HYD02 do not create a process-complete mode-5 owner;
- PPA-WU04-A does not alter the root/drainage admission boundary.

Historical preregistration and frozen case-selection records remain unchanged.

## Scientific consequence

The current repository preserves the bounded E7 conclusion:

**The prospectively selected authentic Hupsel application reaches the admitted participant/application boundary before outer loose/strong coupling can execute.**

This remains:

- not outer-coupling divergence;
- not MODFLOW6 failure;
- not Richards-solver failure;
- not evidence that strong coupling is unnecessary in realistic Hupsel;
- not regional Hupsel groundwater validation.

The zero E7 coupled-window count is therefore the consequence of the preregistered stop rule, not missing execution.

## Reopen rule

E7 stays closed. A future canonically admitted process-complete prescribed-head owner may justify a new prospective realistic coupling experiment. It must not retroactively replace or reinterpret E7.

## Current supporting blobs

```text
production bootstrap:
356b3825a8ba13af1fed385ab17ffdb330b1058f

serialized Reference backend:
9bd344a83afd5e10b96178933362dbb7eeea4f30

Reference-Richards temporal indicator:
2068215a57edb1d2a59c36d6b32f519ebdc09ebd

PPA-ROOT-HYD02 result:
5ac799921574082731180356a23f7e983585800b

PPA-WU04-A status:
75674d84b5eb4d17ae92d7e25696957630fe7fd0

PPA-WU04-B status:
b212fa4dd2705263c1fdf033dc62d0230210b98a
```
