# Stromingen external-source audit

Date checked: 2026-10-16. Previous audit: 2026-09-19.

Purpose: record current public-source authority for factual Dutch instrumentarium claims in the Stromingen overview. This is not scientific publication evidence.

## Source hierarchy for current-status claims

Use, in order:
1. dated NHI/Deltares/WENR release or programme news that explicitly states current status;
2. current official model/tool documentation;
3. event/webinar announcements for terminology and development direction;
4. older evergreen product pages only for stable background concepts.

When two official pages differ because one is older, use the newer dated status source and note the date.

## Verified public claims

### iMOD / MODFLOW 6 / MetaSWAP

Official NHI release news dated 10 June 2026 states that stable releases were delivered at the end of 2025 for iMOD Python for building MODFLOW 6 models and iMOD Coupler for coupling MODFLOW 6 and MetaSWAP. It also states that the focus is shifting toward transition of regional models to new iMOD software and MODFLOW 6.

Preferred source:
https://nhi.nu/nieuwsoverzicht/nieuwe-releases-voor-modelsoftware/

### Ribasim

The same 10 June 2026 NHI release news states that a stable Ribasim release became available at the end of 2025, that it provides a good basis for replacing MOZART, DM and SIMRES, that regional water managers already use Ribasim in combination with MODFLOW 6, and that the national schematization still needs refinement.

Preferred current-status source:
https://nhi.nu/nieuwsoverzicht/nieuwe-releases-voor-modelsoftware/

Background concept source:
https://nhi.nu/modelcode/ribasim/

Important caution:
The earlier audit warned about beta/2025 wording on the model-code page. That wording is no longer present on the page read on 16 October 2026. The dated release news remains the authority for the end-2025 release claim; the model-code page supports the conceptual water-balance, allocation and network description. A release is not evidence of national schematization completeness.

### MultiSWAP terminology

The NHI news overview dated 18 March 2026 explicitly titles webinar #4 'MultiSWAP: opvolger van MetaSWAP' and describes MultiSWAP as the new model bringing SVAT processes together for modern applications.

Preferred terminology source:
https://nhi.nu/nieuwsoverzicht/

### New unsaturated-zone module based on SWAP

NHI news dated 18 June 2025 states that WENR and Deltares are developing a successor for MetaSWAP, that SWAP is the basis, and that the new setup is intended to support a choice between more detailed and faster computational routes for large applications.

Source:
https://nhi.nu/nieuwsoverzicht/nieuwe-module-voor-onverzadigde-zone/

### MetaSWAP transition caution

The June 2025 communication said MetaSWAP would be phased out after 2025, but later NHI communication in September 2025 explicitly stated 'MetaSWAP blijft voorlopig beschikbaar'. In addition, the June 2026 stable iMOD Coupler release still couples MODFLOW 6 and MetaSWAP.

Implication for Stromingen:
Do not write that MetaSWAP has already disappeared or is no longer relevant. Safer wording is that MultiSWAP is publicly positioned as the successor while MetaSWAP remains part of existing/current coupled model practice during the transition.

### MODFLOW role

Current NHI model documentation describes MODFLOW as the model code used to simulate saturated groundwater flow and groundwater heads. Current NHI release communication specifically describes the transition toward MODFLOW 6.

Sources:
https://nhi.nu/modelcode/modflow/
https://nhi.nu/nieuwsoverzicht/nieuwe-releases-voor-modelsoftware/

## Claims that remain project-authority dependent

Public sources do not by themselves establish:
- that SWAP5 is identical to MultiSWAP;
- that SWAP5 is the formally adopted NHI unsaturated-zone production component;
- that a final SWAP5–MODFLOW 6–Ribasim architecture has been selected for national production;
- the current qualification status of specific SWAP5 capabilities;
- the scientific validity of any new solver, coupling, scaling or numerical method.

These must not be inferred from public NHI wording.

## Current repository reconciliation, 16 October 2026

The manuscript status box now cites exact canonical `a86da5b6931b15ef8a5432fd03adc30a72491b65` and its `docs/status-a/POST_STATUS_A_CURRENT_STATE.md`. Frozen Status-A is a separate denominator. Later bounded macro/frost, crop/weather and NUT/SOL admissions must not be described as blanket missing production functionality. Broad historical source envelopes and coupling application scope remain separate.

Public pages reread: both dated NHI news items above, the NHI news overview (dated MultiSWAP entry), Ribasim and iMOD product pages, and the NHV SWAP-50 article page. The NHV page confirms the five listed authors, 2024 anniversary and 2025 publication. Public nomenclature does not establish SWAP5/MultiSWAP identity or formal NHI production adoption.

Internal repository integration remains `PUB_CONTEXT_ONLY`. No external submission, author invitation, new performance result, coupling inference or research-portfolio reassignment is authorized by this reconciliation.

## Submission refresh rule

Repeat this audit immediately before manuscript submission. The Dutch instrumentarium is changing quickly and current-status statements can age within months.
