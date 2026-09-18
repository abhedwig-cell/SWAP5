# PUB-GC E7 standalone Hupsel selection result

## Status

**STANDALONE_SELECTION_FROZEN — READY_FOR_COUPLED_EXECUTION**

Date: 2026-09-18.

No E7 coupled output had been calculated or inspected when this selection was made.

## Prerequisite closure

The former M1-C3 blocker is closed.

- M1-C3 whole-Hupsel typed-adapter qualification: **PASS**.
- Canonical admission: PR #313.
- M1 formal closeout: PR #316.
- M1 verdict: `M1_CLOSED_CURRENT_CANONICAL`.
- Whole-Hupsel accepted intervals: **32,518** with no accepted-interval fallback.
- Exact distribution SHA-256: `2b48353db6cdf00246a1e5c0dcaafc2c61858729fad18446a1dc66359ec2a360`.
- Exact nested source SHA-256: `1a2d798994c2990b397f9349317e3a26f40662fbcff55c9ea484dd638af45151`.

The exact historical distribution was also recovered from the existing ChatGPT Library without a new user upload.

## Standalone selection gate

The official three-year Hupsel application was rebuilt with GNU Fortran 14.2.0 using the already-qualified standalone source-preprocessing route. The optional CSV writer was disabled only on a disposable case copy (`SWCSV=0`).

The instrumented daily trace is accepted only because the scientific outputs remained exactly identical to the admitted whole-Hupsel authority after removal of the nondeterministic generation timestamp:

```text
result.bal normalized SHA-256
a9cc9b18a404726dfbce22d8372df279b9d3bdf1bc76c8c38f33c8080430d0e7

result.blc normalized SHA-256
1bd2631d91cb21e72a5949f54524d0cb55ed0bb059a88fc4a4def8507693b77c
```

The daily trace contains 1,096 complete civil days from 2002-01-01 through 2004-12-31. No independent Hupsel spin-up rule is documented in the controlling authority; therefore no day was removed under a newly invented rule.

## Frozen metric

For every eligible day:

```text
I = precipitation + irrigation
E = actual root uptake + soil evaporation + pond evaporation + interception evaporation
D = drainage outflow magnitude
S = |storage_end - storage_start|

Phi = 0.25 * (R_I + R_E + R_D + R_S)
```

Each `R` is the empirical percentile using the mean zero-based rank divided by `N-1`; ties receive the mean rank.

Population median `Phi = 0.5067922374429223`.

## Frozen selected days

### Median-dynamics control — 2003-06-17

| quantity | value |
| --- | ---: |
| input | 0.2000000000 cm |
| actual ET | 0.1791724035 cm |
| drainage outflow | 0.0225868702 cm |
| storage start | 74.7612527638 cm |
| storage end | 74.7594934962 cm |
| absolute storage change | 0.0017592676 cm |
| R_input | 0.7374429224 |
| R_ET | 0.6831050228 |
| R_drainage | 0.6018264840 |
| R_storage | 0.0045662100 |
| **Phi** | **0.5067351598** |

### High-dynamics day — 2003-05-20

| quantity | value |
| --- | ---: |
| input | 2.2300000000 cm |
| actual ET | 0.1146891077 cm |
| drainage outflow | 0.9069694039 cm |
| storage start | 77.6141771197 cm |
| storage end | 78.8225184772 cm |
| absolute storage change | 1.2083413575 cm |
| R_input | 0.9917808219 |
| R_ET | 0.5762557078 |
| R_drainage | 0.9954337900 |
| R_storage | 0.9689497717 |
| **Phi** | **0.8831050228** |

The dates are now immutable for E7. They may not be replaced because a coupled result is weak, negative, inconvenient or fails.

## Frozen groundwater model

No independently authoritative Hupsel MODFLOW/aquifer geometry and parameter set was present in canonical before the first E7 coupled run. The preregistered fallback therefore applies.

E7 reuses the already qualified F-GC44 conceptual MODFLOW6 fixture:

- one layer, one row, three columns;
- `delr = delc = 1 m`;
- model top `0 m`, bottom `-2 m`;
- central cell coupled to SWAP;
- outer cells constant head at `H_ref ± 0.002 m`;
- `K = 1 m d^-1`;
- `ss = 0.02 m^-1`;
- `sy = 0.15`;
- convertible cell (`icelltype=1`);
- initial head `H_ref`;
- MODFLOW6 Newton formulation and existing qualified IMS tolerances unchanged.

The official Hupsel profile is exactly 200 cm deep, so the lower coupling plane is `z_bottom=-2.00 m` relative to the soil surface datum. No groundwater parameter is calibrated against E7 output.

Accordingly E7 is a **real-forcing hydrological demonstration**, not a regional Hupsel groundwater validation.

## Evidence identity

```text
daily metrics SHA-256:
d532d07a34ad5bdd98730373330bca4b870439eec6783bf9f25b8d58c1906fb3

all scored days SHA-256:
016e6d14a23d5cd5eb0f464167a50f232106cd7cd28c16f11478b04b1d237e6e

selection JSON source SHA-256:
96c3ec2dca3f73116fc62ce8313eb0a4b2ec21947f29e273e58208e037a9fc2b
```

## Next permitted action

Run only the already-preregistered E7 comparison on these two frozen dates:

1. event-aligned Hupsel windows;
2. loose/sequential coupling;
3. production strong coupling from identical accepted origins;
4. unchanged component and coupling tolerances;
5. persist continuous head, exchange, storage, work, mass and failure-domain results.

No post-hoc date replacement, groundwater calibration, window merging or numerical-policy relaxation is permitted.
