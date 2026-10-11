# PUB-GC E3-R result — admitted stronger-flux coupling refinement

## Status

**24-CASE REFINEMENT COMPLETED — STRONGER FLUX STILL WEAK IN HEAD RESPONSE; LONG-WINDOW CORRECTOR ENVELOPE REACHED**

Date: 2026-09-18.

Source branch:

`work/pub-gc-e3-coupling-window-feedback-characterization`

Qualified source head:

`775554022f565e722dbc40dc6e01ecda6c3777b2`

Workflow:

`PUB-GC E3R stronger feedback refinement` run `35344946652` — **PASS**.

Evidence artifact:

`pub-gc-e3r-evidence`, artifact `10546947701`, digest
`sha256:a602d93ce2acceb70e412e8691c78845bc6e333ad2fa71cacc4c31759dda02e7`.

Preregistration:

`PUB_GC_E3R_STRONGER_FEEDBACK_PREREGISTRATION.md`

## Purpose

E3-R removes the original background lateral head gradient and uses only predictor fluxes already demonstrated valid by E3-D.

For each window:

```text
1e-4 day: q = 1e-6 and 3e-5 cm/day
1e-3 day: q = 1e-6 and 1e-4 cm/day
1e-2 day: q = 1e-6 and 1e-4 cm/day
```

with:

```text
K = 0.01, 0.1, 1, 10 m/day.
```

Both fixed-head end cells are set to the predictor reference head, removing the +/-0.002 m background gradient from the original E3 fixture.

## Outcome

Status counts:

| status | count |
| --- | ---: |
| CONVERGED | 20 |
| SWAP_LOOSE_TRIAL_FAILED | 3 |
| SWAP_ITERATIVE_TRIAL_FAILED | 1 |

All cases at:

- `1e-4 day`, both fluxes;
- `1e-3 day`, both fluxes;
- `1e-2 day, q=1e-6 cm/day`;

completed the full loose-versus-iterative comparison.

All four `1e-2 day, q=1e-4 cm/day` cases reached the SWAP prescribed-head corrector envelope before a complete comparison could be obtained.

## Stronger admitted flux at 1e-3 day

The clearest stronger-flux result is:

```text
DeltaT = 1e-3 day
q      = 1e-4 cm/day
```

which is 100 times the original F-GC44 predictor flux.

All four conductivity cases converged.

| K (m/day) | loose relative mismatch | loose residual (m/s) | loose-to-iterative head correction (m) | q_SWAP correction (m/s) | outer iterations |
| ---: | ---: | ---: | ---: | ---: | ---: |
| 0.01 | 0.297930 | -3.72364e-12 | -1.81773e-9 | 6.06372e-15 | 5 |
| 0.1  | 0.297932 | -3.72366e-12 | -1.83115e-9 | 6.10844e-15 | 3 |
| 1.0  | 0.297950 | -3.72394e-12 | -1.79198e-9 | 5.97778e-15 | 4 |
| 10.0 | 0.298113 | -3.72635e-12 | -1.60068e-9 | 5.33961e-15 | 3 |

The largest iterative correction in the entire E3-R matrix is:

```text
|DeltaH iterative - loose| =
1.8311455685e-9 m
```

at `DeltaT=1e-3 day, q=1e-4 cm/day, K=0.1 m/day`.

The corresponding maximum interface-rate correction is:

```text
6.1084368016e-15 m/s.
```

The largest absolute groundwater-head displacement from the predictor reference is:

```text
4.6633172879e-9 m.
```

Thus a 100-fold increase in valid predictor flux increases the measurable coupling correction, but the groundwater-head response in this one-square-metre fixture remains on the nanometre scale.

## Short-window stronger flux

For `DeltaT=1e-4 day, q=3e-5 cm/day`, all four conductivity cases converge in two outer iterations.

The loose-to-iterative head correction is only approximately:

```text
4.1e-12 m
```

with interface-rate corrections of order `1.6e-17 m/s`.

This remains an extremely weak physical feedback regime.

## Long-window boundary

For:

```text
DeltaT = 1e-2 day
q      = 1e-4 cm/day
```

none of the four conductivity cases completes the full refinement.

At `K=0.01, 0.1,` and `10 m/day`, the first diagnostic loose prescribed-head SWAP corrector already fails.

The proposed loose heads differ from the predictor reference by only approximately:

```text
K=0.01 : -2.30e-8 m
K=0.1  : -2.27e-8 m
K=10   : -9.03e-9 m
```

At `K=1 m/day`, the loose corrector succeeds, leaving a loose interface residual of approximately:

```text
-8.59e-12 m/s
```

but the iterative solve reaches a SWAP corrector failure at outer iteration 4. The failing candidate head is only about:

```text
-5.67e-8 m
```

from the predictor reference.

The limiting factor in this case is therefore not an inability of the outer coupling algorithm to reduce a valid residual. The real SWAP prescribed-head corrector itself no longer supplies a valid candidate for the required head perturbation.

## Low-flux control in the zero-gradient fixture

The low-flux controls remain weakly coupled.

The maximum loose relative flux mismatch in E3-R is approximately:

```text
0.497
```

at `DeltaT=1e-2 day, q=1e-6 cm/day, K=0.01 m/day`.

All low-flux E3-R cases converge in two or three outer iterations and produce sub-nanometre to few-nanometre head displacements.

Removing the background CHD gradient also removes the misleading large-K trend seen in the original E3 fixture. Conductivity still affects the coupled response, but the variation is modest compared with the effects of window length and predictor/corrector admissibility.

## Scientific interpretation

E3-R strengthens rather than overturns the E3 null result.

Within the currently demonstrated real-SWAP component envelope:

1. strong iteration reliably restores strict interface consistency when valid SWAP correctors remain available;
2. increasing predictor flux by 30–100 times increases the absolute residual and coupling correction;
3. the resulting groundwater-head correction remains extremely small in this fixture;
4. before a materially large head-feedback regime is reached, the long-window prescribed-head SWAP corrector can become unavailable.

This means the paper now has a well-supported **weak-feedback control regime**, but still does not have a valid strong-feedback positive case.

That absence is scientifically informative. It prevents an exaggerated claim that iterative coupling is always hydrologically important and directs the next experiment toward a different admitted hydrological state/groundwater geometry rather than toward looser tolerances.

## Consequence for RQ3

RQ3 can now be answered partially:

> Iterative coupling is required to enforce the strict finite-window interface equation in the tested cases, but the hydrological state correction is negligible within the currently admitted near-equilibrium fixture. Attempts to increase coupling impact through longer windows and larger predictor flux encounter the SWAP component/corrector envelope before they produce a materially large groundwater-head response.

A stronger hydrological coupling case remains required before generalizing the practical importance of strong iteration.

## Decision

**E3-R complete — SUPPORTED_RESTRICTED.**

Next steps:

1. preserve the E3 weak-feedback result as a negative control;
2. do not expand the flux/window envelope by relaxing transaction criteria;
3. select a different admitted hydrological state or groundwater response geometry for a non-trivial feedback case;
4. proceed to E4 response interpretation on regimes that are demonstrably valid.
