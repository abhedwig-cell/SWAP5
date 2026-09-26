# F-PE-PROFILE06 D3B — groundwater-head bias discovery

Date: 2026-09-26

Status: `PREREGISTERED_OBSERVATION_ONLY`

## Trigger

D3A mapped an O05 wet direct-difficult case into the live mode-5 coupling architecture.

The mapping was robust 6/6, but every corrector remained a two-Newton solve because the symmetric groundwater fixture kept the MODFLOW head close to the predictor origin.

## Question

What is the smallest finite groundwater-head displacement that makes the exact mode-5 corrector materially nonlinear while preserving coupled robustness?

## Fixed SWAP workload

Retain D3A:

- O05 hydraulics;
- initial top-node pressure head: -10 cm;
- coupling window: 1e-3 day;
- top flux: 0 cm/day;
- predictor qbot: 0 cm/day;
- exact/default Richards tolerances;
- max iterations 16;
- unchanged retry and temporal policy.

## Groundwater bias axis

Shift the MODFLOW starting head and both outer CHD heads by a common bias relative to the predictor reference head.

Keep the existing ±0.002 m CHD gradient around that biased level.

Discovery biases:

- -0.020 m;
- -0.010 m;
- -0.005 m;
- -0.002 m;
- 0 m;
- +0.002 m;
- +0.005 m;
- +0.010 m;
- +0.020 m.

These are finite 0–2 cm interface perturbations, not extreme forcing.

## Metrics

For each bias report:

- full coupled completion;
- number of outer iterations;
- maximum and total corrector nonlinear iterations;
- maximum backtracking attempts;
- internal retries;
- final head;
- final SWAP exchange;
- mass/ledger publication success.

## Selection

A bias is eligible when:

- exact coupled run completes;
- no internal retry pathology occurs;
- at least one corrector trial requires >=4 nonlinear iterations.

Select the smallest absolute eligible bias.

If both signs qualify at the same magnitude, prefer the sign with fewer outer iterations and retries; if still tied, retain both for D3C.

No A1 or A2C timing is allowed before this exact-only discovery closes.
