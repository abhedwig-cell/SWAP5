# F-PE-ELASTIC13 — physical parameter-policy result

Date: 2026-09-29

Status: STATIC_MINERAL_ELAS_POLICY_QUALIFIED_FOR_PRODUCTION_SHAPING

Branch:
`research/f-pe-elastic13-parameter-policy`

Preregistration:
`F-PE-ELASTIC13_PARAMETER_POLICY_PREREGISTRATION.md`

Workflow run:
`36552871305`

Job:
`109354995463`

Evidence artifact:
`11024733433`

Conclusion:
PASS.

## Source population

Frozen BRO/BOFEK layer population:
- 368 profiles;
- 1568 layers/horizons.

Regime split under the preregistered source rules:

- MINERAL: 1356 layers;
- ORGANIC_RICH_NONPEAT: 8 layers;
- PEAT: 204 layers;
- UNKNOWN: 0 layers.

Explicit peat types observed:

- bosveen: 11;
- veenmosveen: 11;
- verslagen: 17;
- verweerdKleirijk: 40;
- verweerdMineraalarm: 16;
- verweerdZandrijk: 19;
- zeggeveen: 90.

No missing-regime blocker remains.

## Mineral static prior at h=-100 cm

For 1356 MINERAL layers:

- profiles represented: 357;
- dry bulk density range: `0.261 .. 1.68 g/cm3`;
- median dry bulk density: `1.454 g/cm3`;
- organic matter range: `0.2 .. 15.0%`;
- median organic matter: `1.5%`.

Transferred ELAS/Ss at the frozen reference head `h=-100 cm`:

- minimum: `1.7599e-6 cm^-1`;
- p10: `2.2677e-6 cm^-1`;
- median: `2.8388e-6 cm^-1`;
- p90: `4.1648e-6 cm^-1`;
- maximum: `2.5275e-5 cm^-1`.

Predictor-domain status:
- IN_DOMAIN: `99.8525%`;
- EDGE: `0.1475%`;
- EXTRAPOLATION: `0%`.

Relative to the descriptive `1e-6 cm^-1` band:
- below 0.5e-6: 0%;
- 0.5e-6 .. 2e-6: `0.1475%`;
- above 2e-6: `99.8525%`.

## Reference-state robustness

Sensitivity state:
`h=-200 cm`.

For identical MINERAL layers:

`R = Ss(-200) / Ss(-100)`

has:
- minimum: `1.0220`;
- p10: `1.0377`;
- median: `1.0752`;
- p90: `1.1469`;
- maximum: `1.1477`.

Frozen gates:

1. at least 95% with `0.8 <= R <= 1.25`:
   observed `100%` — PASS;
2. all with `0.67 <= R <= 1.5`:
   observed `100%` — PASS;
3. zero EXTRAPOLATION at -100 and -200:
   observed zero at both states — PASS.

Therefore the static -100 cm convention is locally robust within the declared
field-capacity sensitivity test.

The median state-convention effect is about `+7.5%`, materially smaller than
the independently observed predictor uncertainty.

## Uncertainty policy

Frozen multiplicative uncertainty factor from the independent ELASTIC11 holdout:

`F = 2.123968031921196`.

For every automatically generated mineral prior, the operational evidence
record is:

- `ELAS_prior`;
- `ELAS_lower = ELAS_prior / F`;
- `ELAS_upper = ELAS_prior * F`;
- `reference_head_cm = -100`;
- source profile/layer identity;
- predictor-domain class;
- regime = MINERAL.

Across MINERAL layers at -100 cm:
- lowest lower-envelope value:
  `8.286e-7 cm^-1`;
- highest upper-envelope value:
  `5.368e-5 cm^-1`.

This band is not a confidence interval.

## Organic-rich non-peat

8 layers are classified ORGANIC_RICH_NONPEAT.

At -100 cm:
- median ELAS: `7.94e-6 cm^-1`;
- minimum: `7.72e-6 cm^-1`;
- maximum: `2.39e-5 cm^-1`;
- IN_DOMAIN: 75%;
- EDGE: 25%;
- EXTRAPOLATION: 0%.

The -200/-100 ratio is tightly bounded around `1.063`.

Despite favorable domain behavior, the preregistered policy remains:

`RESEARCH_ONLY_NOT_AUTO_ASSIGNED`.

No post-hoc widening is allowed.

## Peat

204 layers are explicitly classified PEAT across 108 profiles.

At -100 cm:
- dry bulk density range: `0.167 .. 0.788 g/cm3`;
- median dry bulk density: `0.265 g/cm3`;
- organic matter range: `15 .. 95%`;
- median organic matter: `65%`;
- median ELAS: `1.885e-5 cm^-1`;
- p10: `9.557e-6 cm^-1`;
- p90: `2.399e-5 cm^-1`;
- minimum: `6.233e-6 cm^-1`;
- maximum: `3.293e-5 cm^-1`.

Predictor-domain status:
- IN_DOMAIN: `88.24%`;
- EDGE: `11.76%`;
- EXTRAPOLATION: 0%.

The -200/-100 median ratio is `1.0769`.

The predictor therefore behaves numerically inside its bounded descriptor
domain, but that does not qualify a scalar static peat constitutive model.

Per preregistration:

`PEAT = RESEARCH_ONLY_NOT_AUTO_ASSIGNED`.

## Policy decision

Qualified policy:

### MINERAL

`AUTO_STATIC_PRIOR_AT_H_MINUS100`

with:
- exact frozen M1 transfer;
- factor-2.123968 uncertainty envelope;
- provenance and domain metadata;
- no solver-performance tuning.

### ORGANIC_RICH_NONPEAT

`RESEARCH_ONLY_NOT_AUTO_ASSIGNED`.

### PEAT

`RESEARCH_ONLY_NOT_AUTO_ASSIGNED`.

### UNKNOWN

`NO_AUTO_ASSIGNMENT`.

## Main scientific conclusion

For mineral BOFEK layers, uncertainty in the independently validated mechanical
predictor is much larger than the local uncertainty caused by choosing
-100 versus -200 cm as the field-moist reference convention.

That makes a static `h_ref=-100 cm` mineral prior scientifically defensible
as an operational first-order parameterization.

This result does not justify applying the same scalar-linear policy to peat.

## Classification

`STATIC_MINERAL_ELAS_POLICY_QUALIFIED_FOR_PRODUCTION_SHAPING`.
