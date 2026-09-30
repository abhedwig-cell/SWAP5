# F-PE-ELASTIC60 — direct defect-head blind multi-profile holdout result

Date: 2026-09-30

Status: QUALIFIED_BLIND_HOLDOUT_WITH_SATURATED_IMPRACTICALITY

Branch:
`research/f-pe-elastic60-direct-defect-holdout`

Qualified postimage:
`79b81c48127519d561b2b26cea23dba34e795e02`

Canonical baseline:
`integration/f-ci-canonical@785b4a72a0beb0f6c89a82522e2bf489ec45c761`

Workflow run:
`36699563510`

Job:
`109835547228`

Conclusion:
SUCCESS.

## Selection amendment

The first workflow stopped before any numerical holdout case because the
original second-candidate rule was infeasible for horizon-count class 1.

The selection amendment was committed before any ELASTIC60 numerical result.

The amended source-only rule excluded all development profiles first and then
selected the smallest eligible profile from the first four remaining non-empty
horizon-count classes.

## Blind holdout profiles

The frozen algorithm selected:

1. profile `11020`
   - soilunit `Zn10A`;
   - 2 horizons;
   - blocks `[104,204]`.

2. profile `8120`
   - soilunit `EZ50A`;
   - 3 horizons;
   - blocks `[101,101,201]`.

3. profile `4015`
   - soilunit `uHn21`;
   - 4 horizons;
   - blocks `[103,202,202,201]`.

4. profile `3011`
   - soilunit `Y21g`;
   - 5 horizons;
   - blocks `[102,202,202,202,205]`.

None overlaps the ELASTIC55 development profiles or profile 90116260.

## Frozen candidates

Primary:

`D1 = DEFECT_HEAD_INF`

with accept rule:

`D1 <= 0.01 cm`.

Comparator:

`D2 = 2*DEFECT_HEAD_INF`

with accept rule:

`D2 <= 0.01 cm`.

No scaling or refit was allowed.

## Bank

The complete preregistered bank executed:

- 4 profiles;
- 4 initial states;
- 4 forcing perturbations;
- 3 ELAS regimes;
- 9 dt values.

Total:
`1728` requested cases.

O0/O2 semantic identity passed.

Direct defect-head observables remained finite/nonnegative when available.

Zero production `src/**` changes.

## D1 blind result

Across 192 profile/state/forcing/regime controller sequences:

- selected: `54`;
- exhausted: `138`;
- saturated selected: `0`;
- unsaturated selected: `54`;
- paired selected: `48`;
- paired head-limit failures: `0`;
- paired theta-limit failures: `0`.

Worst paired selected values:

- max realized H_INF:
  approximately `2.71e-5 cm`;
- max realized THETA_INF:
  approximately `2.97e-8`.

Both are far inside the inherited physical limits:

- H_INF <= `0.01 cm`;
- THETA_INF <= `1e-5`.

Thus D1 passes the blind safety test on every paired selected observation.

## D2 blind result

Across the same 192 sequences:

- selected: `48`;
- exhausted: `144`;
- saturated selected: `0`;
- unsaturated selected: `48`;
- paired selected: `42`;
- paired head-limit failures: `0`;
- paired theta-limit failures: `0`.

D2 is also blind-safe on every paired selected observation, but is still more
restrictive than D1.

## Per-profile selection

### profile 11020

D1:
- selected 18;
- saturated selected 0;
- paired selected 12.

D2:
- selected 12;
- saturated selected 0;
- paired selected 9.

### profile 8120

D1:
- selected 12;
- saturated selected 0;
- paired selected 12.

D2:
- selected 12;
- saturated selected 0;
- paired selected 9.

### profile 4015

D1:
- selected 12;
- saturated selected 0;
- paired selected 12.

D2:
- selected 12;
- saturated selected 0;
- paired selected 12.

### profile 3011

D1:
- selected 12;
- saturated selected 0;
- paired selected 12.

D2:
- selected 12;
- saturated selected 0;
- paired selected 12.

## Interpretation

ELASTIC59 established that direct defect-head measures are much tighter than
the mass-normalized Binf bound.

ELASTIC60 independently confirms that D1 and D2 remain safe on new source
profiles.

However, direct use of the inherited 0.01-cm physical head limit as the direct
defect threshold remains too conservative for the saturated domain:

`0 / 96` saturated sequences are selected by D1.

Therefore the problem has moved again.

The remaining saturated conservatism is no longer mainly the Binf
minimum-mass-weight conversion. It is now the gap between the defect correction
magnitude and the realized full-versus-two-half endpoint error.

ELASTIC59 development data showed that D1 remained several times larger than
realized H_INF even in the least conservative saturated cases.

## Hypothesis outcome

D1 blind safety:
SUPPORTED.

D2 blind safety:
SUPPORTED.

Direct defect-head metric materially tighter than Binf:
SUPPORTED by parent characterization and blind safety.

Unscaled D1 practical for saturated 0.01-cm control:
FALSIFIED over the blind holdout ladder.

## Decision

Classification:

`QUALIFIED_DIRECT_DEFECT_HEAD_BLIND_SAFE_BUT_SATURATED_IMPRACTICAL`.

No production admission is authorized.

The next bounded workunit may calibrate a multiplicative D1 scaling using only
the ELASTIC59 development bank.

Because ELASTIC60 results are now observed, they must not be used to choose
that scale.

A subsequent test must use a third independent profile set selected after the
D1 scale is frozen.
