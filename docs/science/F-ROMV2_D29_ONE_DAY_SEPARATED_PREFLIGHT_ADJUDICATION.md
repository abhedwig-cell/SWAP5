# F-ROMV2 D29 one-day separated-branch adjudication

**Workstream:** F-ROM  
**Work unit:** F-ROMV2-D29  
**Decision:** **D29_FMC_ONE_DAY_SEPARATED_PREFLIGHT_NO_GO**

## Question

D29 asks a deliberately narrow long-window question after D20 and D24/D25:

> Can the already qualified **separated** FMC connected-surface plus fixed-water-table
> groundwater-front branch remain physically valid for one day, without adding ET,
> ponding/runoff, dry-bin activation, slugs or contact/merge physics?

D29 changes only the duration relative to D20.

It keeps:

- B01;
- 200 moisture bins;
- the 10 s process/observation step;
- G25 groundwater lambda 0.25;
- the exact D17/D20 initial composite state;
- the same four infiltration factors, 0.1, 0.25, 0.5 and 0.75 Ksat;
- the same four forcing-order patterns;
- the same D13-D17 finite-volume equations and hard water-ledger rules.

There is no ET or root-water uptake. D29 does not bypass the D28 external
native-ET authority blocker.

## Staged design

The first stage is FMC-only.

No new R16 or R2 trajectory may be generated unless all four 24-hour FMC
histories complete while remaining strictly inside the already qualified
separated branch.

The frozen preflight requires:

- 8640 ten-second steps per history;
- finite physical front states;
- sufficient prescribed supply;
- complete absorption by already connected surface fronts;
- no ponding/runoff;
- no dry-bin activation;
- no falling slug;
- no surface-groundwater contact or merge;
- step/global water ledgers within 1e-12 cm.

This staging prevents a long Reference run from being generated after the
candidate has already left its authorized state envelope.

## Immutable execution

Workflow run **35491949341**, job **106028294032**, executed head

`14b95943842b200b8d7d015814168ab6da7da838`.

Artifact:

- ID: **10599780693**
- digest:
  `sha256:c98d86772ab8b96ad955987b124fdd9fef2509e1ee2dc25caee491bf4c059607`
- preflight result SHA-256:
  `38d5352549f0a569c3e9203a70e8da7921bd8ce823f81260d22a6609db765c16`
- preflight stdout SHA-256:
  `440461682cbef4b313401ceab78231afa6c2e0ef181e397a6404efd7063df9f6`.

The workflow completed successfully because a scientific no-go is a valid
terminal result.

## Result

All four forcing-order histories reach the same excluded physical branch at the
same time:

| history | contact step | elapsed time | contact bin | gap |
|---|---:|---:|---:|---:|
| P_UP_24H | 927 | 2.575 h | 101 | -0.009183 cm |
| P_DOWN_24H | 927 | 2.575 h | 101 | -0.009183 cm |
| P_ALT_A_24H | 927 | 2.575 h | 101 | -0.009183 cm |
| P_ALT_B_24H | 927 | 2.575 h | 101 | -0.009183 cm |

The instantaneous forcing factor at that step differs between histories, but the
contact time, bin and overlap are identical.

That makes the result stronger than a single forcing-order accident.

The D20 separated state representation reaches a common physical domain boundary
after roughly 2.6 hours.

## Why Stage 2 is not executed

The preregistered D29 state space explicitly excludes contact/merge.

D19 contains separately qualified contact/merge evidence, but activating D19
inside D29 after observing the preflight would change the model state-transition
architecture after exposure.

Therefore:

- D29 is not repaired;
- no R16/R2 D29 trajectory is generated;
- the 24-hour relative-to-R2 frontier is not evaluated;
- the existing D20 one-hour result is not extrapolated beyond its evidence.

The reported `equal_cumulative_top_input = false` is not a hydrological
inequality result. It occurs because none of the four histories completed the
24-hour window, so the four-complete-history equality check was not reached.

## Scientific meaning

D29 is **not** a general FMC no-go.

It establishes a domain boundary for one specific already-qualified
representation:

> continuous surface-connected fronts and groundwater-connected fronts cannot be
> treated as permanently separated over the frozen long-window forcing.

For a longer hydraulic calculation, the physical model must transition through
a contact/merge state.

This is exactly the kind of regime transition that a reduced model must expose,
not hide behind a global error metric or numerical fallback.

## Relationship to prior positive evidence

D29 does not reclassify:

- D20 one-hour hydraulic persistence;
- D24 native rainfall plus fixed-water-table candidacy;
- D25 compiled shared-host cost advantage;
- D13/D16/D17/D19 bounded branch evidence.

Those results remain valid within their admitted domains.

D28 also remains unchanged: native root-active FMC trajectories and seasonal ET
are still blocked on external implementation authority.

## Next work

The next scientifically valid long-window work unit is **not** “D29 with merge
turned on.”

It must be a new proposition that first reconciles D19:

1. exact contact detection;
2. finite-volume mass transfer at merge;
3. post-merge groundwater-front state;
4. continued surface forcing after merge;
5. any later detachment or other state transition that may occur.

Only if that combined continuation is already fully specified by existing
authority should a new contact-capable long-window FMC preflight be
preregistered.

If the post-contact continuation is under-specified, that is the next authority
blocker.

No application acceptance or formal performance claim follows from D29.

Production ROM remains unauthorized.
