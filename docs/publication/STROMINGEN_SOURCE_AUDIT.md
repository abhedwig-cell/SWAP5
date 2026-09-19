# Stromingen external-source audit

Date checked: 2026-09-19

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
The Ribasim model-code page still contains older text describing Ribasim and iMOD Coupler as beta releases and further testing during 2025. Do not use that older paragraph for 2026 release status. Use the dated 10 June 2026 release news for current status and the model page only for stable conceptual descriptions such as water balance, allocation and network representation.

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

## Submission refresh rule

Repeat this audit immediately before manuscript submission. The Dutch instrumentarium is changing quickly and current-status statements can age within months.