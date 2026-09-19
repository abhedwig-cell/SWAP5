# PUB-GC E7 realistic Hupsel result

## Status

**CLOSED — REALISTIC_COMPONENT_DOMAIN_LIMIT**

Date: 2026-09-18.

E7 did not produce a loose-versus-strong Hupsel trajectory. It terminated at the preregistered component-domain gate **before coupled participant state was created**.

That is an allowed E7 result, not a failed attempt to obtain a more interesting coupling response.

## Frozen cases

The two Hupsel dates were selected from standalone dynamics before any coupled output:

| role | date | Phi | daily drainage outflow |
| --- | --- | ---: | ---: |
| median-dynamics control | 2003-06-17 | 0.5067351598 | 0.0225868702 cm |
| high-dynamics day | 2003-05-20 | 0.8831050228 | 0.9069694039 cm |

The dates remain immutable.

The exact whole-Hupsel typed-adapter authority has 32,518 accepted intervals and 16,507 intervals with non-zero drainage. M1-C3 and M1 are closed.

## Production gate reached by E7

The production groundwater application owner is intentionally restricted.

For groundwater coupling, PPA-WU01 requires:

```text
bottom_mode = 5
```

and validates the tile configuration before allocating owner state.

The same production validation rejects a tile when:

```text
drainage_response_active = true
```

or when any other process outside the restricted WU01 groundwater profile is active, including root extraction.

The later PPA-WU03 admission adds a bounded stateless atmospheric/common-forcing layer. It does **not** widen this groundwater-process profile.

Because authentic Hupsel drainage is active on both frozen dates, disabling the drainage process to make a mode-5 participant would change the application physics. The E7 preregistration expressly forbids that.

## Independent precedent

E6 had already exposed the same lower-boundary incompatibility from the opposite direction:

- the admitted active-drainage predictor is valid and mass-complete;
- active drainage uses the admitted smooth prescribed-`q_bot` projection;
- the prescribed-head corrector requires the mode-5 groundwater profile;
- the reference corrector returns `KERNEL_STATUS_NOT_ADMITTED`;
- transaction calls = 0.

E7 now shows that this is not only a synthetic stress-case limitation. It is encountered by a prospectively selected authentic Hupsel application.

## Qualification

Publication qualification:

```text
workflow run: 35375181814
job:          105698080443
conclusion:   success
```

Decisive markers:

```text
PUB_GC_E7_SELECTED_DAYS_FROZEN=PASS
PUB_GC_E7_M1_WHOLE_HUPSEL_AUTHORITY=PASS
PUB_GC_E7_HUPSEL_DRAINAGE_REQUIRED_ON_MEDIAN_DAY=PASS
PUB_GC_E7_HUPSEL_DRAINAGE_REQUIRED_ON_HIGH_DAY=PASS
PUB_GC_E7_PRESCRIBED_HEAD_OWNER_BOTTOM_MODE5=PASS
PUB_GC_E7_ACTIVE_DRAINAGE_PROFILE_FAILS_BEFORE_OWNER_ALLOCATION=PASS
PUB_GC_E7_E6_PRECEDENT_PRETRANSACTION_NOT_ADMITTED=PASS
PUB_GC_E7_NO_WU03_PROFILE_WIDENING=PASS
PUB_GC_E7_OUTCOME=REALISTIC_COMPONENT_DOMAIN_LIMIT
```

## Coupled execution disposition

| item | result |
| --- | --- |
| loose/sequential completed E7 windows | 0 |
| production-strong completed E7 windows | 0 |
| E7 MODFLOW windows executed | 0 |
| production physics changed | no |
| coupling/solver tolerance changed | no |
| selected date replaced | no |
| event window merged or shortened | no |
| groundwater model calibrated | no |

The stop occurs before the requested Hupsel prescribed-head participant can be instantiated. Therefore it is not classified as MODFLOW failure, Richards failure, mass failure or outer-coupling divergence.

## Scientific interpretation

RQ5 is answered in a bounded negative form.

The coupling contract remains **scientifically interpretable** under authentic Hupsel forcing and process composition because it identifies the exact production component boundary rather than silently dropping a process. It is **not yet executable for the full authentic Hupsel profile** as a prescribed-head groundwater participant.

Thus realistic transferability of the current production coupling is limited by component admission before loose-versus-strong convergence can be measured.

This strengthens the paper's distinction among:

1. hydrological interface semantics;
2. component-admission domain;
3. outer-coupling convergence domain;
4. hydrological importance of a converged correction.

## Stop rule after E7

Do not reopen E7 merely to obtain a positive trajectory.

A future production capability that admits active drainage and the required Hupsel process composition under prescribed-head trials would be a new capability. It could motivate a later follow-up experiment, but it must not retroactively replace this preregistered E7 result.


## Current-canonical reconciliation

Current canonical basis for this closeout: `integration/f-ci-canonical@6413adc4d29f5749105b30e45f395331b450d5f3`.

The decisive production boundary is unchanged:

- the groundwater application owner remains a homogeneous `bottom_mode=5` prescribed-head profile;
- `tile_config_valid` still rejects both `root_extraction_active` and `drainage_response_active` before owner-state allocation;
- PPA-WU02 and PPA-LOW02-TIME broaden `bottom_mode=2` prescribed-`q_bot` application semantics only;
- PPA-WU03 supplies bounded stateless common forcing and does not widen mode-5 process ownership;
- PPA-ROOT-HYD01 and PPA-ROOT-HYD02 add restricted prescribed-root temporal/tangent evidence, but explicitly do not admit a root-active live-MODFLOW production application owner;
- PPA-WU04-A admits the bounded SWREDU=1 Black evaporation slice, but does not admit Black evaporation under mode 5 and does not alter the root/drainage guards.
- PPA-WU04-B admits the bounded SWREDU=2 Boesten-Stroosnijder evaporation slice, but likewise rejects mode-5 Boesten composition and leaves the root/drainage guards unchanged.

The current production-bootstrap blob is `356b3825a8ba13af1fed385ab17ffdb330b1058f`. Canonical work after PPA-WU04-B through the inspected head is confined to evidence-only F-ROMV2/TRACE/F-DOC work and ROM tests; the relevant production postimages are unchanged. Therefore the authentic Hupsel root/drainage composition is still outside the admitted prescribed-head participant domain.

E7 remains `REALISTIC_COMPONENT_DOMAIN_LIMIT`. A future process-complete prescribed-head owner would define a new prospective experiment; it does not turn the closed E7 result into unfinished work.
