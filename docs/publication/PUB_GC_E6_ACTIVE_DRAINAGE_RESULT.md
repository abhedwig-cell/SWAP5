# PUB-GC E6 result — active-drainage hydrological stress route

## Status

**SUPPORTED_NEGATIVE_COMPONENT_ENVELOPE**

Date: 2026-09-18.

Primary evidence:

- source head: `191f1d8ac0ab0b84eff438023f1d32e00c09b925`;
- workflow run: `35360873209` — PASS;
- job: `105651690323` — PASS;
- artifact: `10554144629`;
- artifact digest: `sha256:00685e242f3dfc85b819900853f5af5bf814291fead48d1e968d3ca74b2cb768`.

The workflow passed because it correctly applied the preregistered stop rule. It did **not** execute or pass the live MODFLOW coupling matrix.

## Question

E6 asked whether the independently admitted F-GC31 wetter, active-drainage state could supply a materially stronger SWAP–groundwater feedback while preserving the existing production participant and prescribed-head corrector semantics.

The fixture was intentionally taken from F-GC31 rather than tuned for this publication experiment.

## Predictor result

The prescribed-qbot predictor completed successfully and retained the admitted active-drainage tangent coverage.

| quantity | value |
| --- | ---: |
| window | 0.01 day |
| predictor q_bot | 0.002 cm/day |
| H_start | 0.0130021052632 m |
| H_end / reference head | 0.0129328962586 m |
| q_u | -0.00239867448635 cm/day |
| u_A | 5.76044242657e-4 |
| storage change | -3.97524111917e-6 native depth |
| mass residual | 1.73628201660e-16 |
| mass complete | true |

Thus the active-drainage predictor itself is not the blocker.

## Reference prescribed-head corrector

Before opening the live-MODFLOW E6 matrix, the preregistration required the production SWAP participant to reproduce a valid same-origin corrector at the predictor reference head.

That probe returned:

```text
participant status = 6   GW_SWAP_PARTICIPANT_TRIAL_FAILED
kernel status      = 101 KERNEL_STATUS_NOT_ADMITTED
transaction calls  = 0
accepted substeps  = 0
attempts           = 0
solver rejections  = 0
temporal rejections= 0
mass rejections    = 0
```

The authoritative revision, time and interface ledger remained unchanged.

This localizes the failure before nonlinear trial execution. It is not a Richards convergence failure and it is not a mass, temporal, MODFLOW or outer-coupling failure.

## Why the profile is not admitted

The current production contracts deliberately separate two boundary profiles.

For the production prescribed-head coupling route, `fmr_groundwater_profile_admitted` admits:

```text
bottom_mode == 5
```

The independently admitted F-GC31 smooth active-drainage projection is narrower. When:

```text
drainage_qbot_smooth_freatic_projection == true
```

the serialized Reference backend admits that profile only when:

```text
bottom_mode == 2
```

with active drainage and the remaining F-GC31 restrictions.

Consequently, setting the corrector to prescribed-head mode while retaining the F-GC31 smooth qbot drainage projection is intentionally outside the admitted production envelope.

This matches the F-CI98/F-GC31 authority: the admitted result is a **restricted prescribed-qbot active-drainage tangent**, not a fully implicit candidate-head drainage response.

## E6 adjudication

The preregistered stop condition is met.

The live specific-yield matrix was therefore not executed. Running MODFLOW after the participant had already failed its reference corrector would have mixed a component-domain failure with a coupling experiment and could not support a hydrological feedback claim.

The result is scientifically useful but negative:

1. the wetter active-drainage predictor produces a valid and mass-complete finite-window response;
2. that response does not imply that the same process configuration is admitted for the production head-driven corrector;
3. therefore F-GC31 cannot be used unchanged as the desired non-trivial E6 live-coupling case;
4. expanding the production drainage/head semantics solely to obtain such a case would violate the publication experiment scope.

E6 continues through the separately preregistered accepted-state/flux screen. That route changes the accepted hydrological state while staying inside an already admitted prescribed-head process profile.

## Claim boundary

This result does **not** show that active drainage cannot be coupled to MODFLOW6 in principle.

It shows only that the presently admitted F-GC31 smooth active-drainage tangent and the presently admitted production prescribed-head SWAP corrector are different capability envelopes. Their intersection does not contain this E6 fixture under unchanged production semantics.
