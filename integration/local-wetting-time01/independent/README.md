# Independent qualification of the day364 groundwater discrepancy

**Current result: qualified bounded numerical attribution; ready for PR review.**
This closes the unexplained-origin/independence review blocker in PR1701.
The original nominal whole-run comparison remains **FAIL**, unchanged.
There is no universal groundwater-error guarantee, default promotion, blanket
B1 adoption, canonical admission or whole-trajectory equivalence claim.

## Independent method and fixed criteria

The reference is compiled from the immutable original431 provider. Its own
HeadCalc retains the original residual assembly, constitutive calls, Newton
updates, convergence thresholds, iteration limit and rollback. A minimal,
source-hashed effort patch executes two additional original converged Newton
iterations. It imports/links **no SWAP5 HeadCalc, projected residual, strict
water-budget object, kernel or daily host**. The existing1e-10 cm daily balance
acceptance check is applied to its independently calculated legacy BALDEV;
no original input tolerance or scientific threshold is changed.

This is independent of the SWAP5 numerical implementation being checked,
not a different set of physical equations or an external experimental data set.
The shared strict-HeadCalc experiment in `../strict-reference/` is earlier
supporting evidence; it is not the independence basis of this assessment.
`HEAD_CALC_EFFORT.patch` is the complete physical-solver effort difference.
No production source changes were needed in this work unit.

The selected scope is the actual saved362 soil state and days363–365 of the
water/runon/hysteresis variant. The original-readable binary seed, weather,
material, crop and output deck are hash-bound in INPUT.zip. Initial water and
pond stocks reproduce the saved values exactly. The derived original initial
GWL is recomputed about0.00134cm differently; this is recorded, not suppressed.
The original fixed table contains only past irrigation and is explicitly
disabled in the separate restart diagnostic; both actual interval irrigation
histories are zero. These are not labelled byte-identical full cold inputs.
The full literal-input B0 comparisons remain preserved in their own cohorts.

Before execution, source/object hashes and the compiler are validated. No
desired GWL value is supplied to the solver. It first completes its own
calculation/balance check; comparison with SWAP5 occurs only afterwards.

## Distinguishing controls

1. Original-only adaptive refinement at DTMAX4e-4,1e-4,2.5e-5day tests an
   unshared numerical solve with its own step proposals. The GWL changes shrink
   from0.0305494 to0.00198304cm for the portable fixed-seed comparison.
   Observed refinement order is1.973; this empirical observation is not a
   rigorous global error certificate or a newly allowed error tolerance.
2. Actual **accepted** SWAP5 time grids are observed without changing any
   physical receipt in the365-day prefix. Both nominal and refined grids are
   then supplied to the independent original solver. Any inability to solve
   a prescribed step is an error, not a silent retry, truncation or weakened
   acceptance. All read clocks and accepted steps must reproduce the trace
   exactly. Nominal Windows uses449 steps; refined uses120008 over the3days.
3. Common-input Windows/Ubuntu O0/O2 separates code/compiler effects from
   initial-state and grid effects. Ubuntu's actual **own** saved state and
  456-step nominal grid are additionally recovered from its qualified full
   execution, observed exactly and checked independently. The Windows fixture
   is not silently substituted for Ubuntu's own history.

DTMAX is only a ceiling: the additional original Newton iterations also affect
its iteration-based adaptive proposals. Consequently equal DTMAX does not
imply equal time grids. The exact-grid controls distinguish that difference
from a physical-implementation discrepancy.

## Results

| Actual nominal trajectory on day364 | Windows, cm | Ubuntu own trajectory, cm |
| --- | ---: | ---: |
| SWAP5 | −2.666206188564 | −2.770746986438 |
| Independent original on its accepted grid | −2.666210077360 | −2.770750737522 |
| Absolute difference | 0.000003888796 | 0.000003751084 |

On the shared refined grid, the difference is3.5661e-8cm Windows and
3.5654e-8cm Ubuntu. O0/O2 give the same reported GWL in each independent
profile. The portable fixed-seed original-only refinement results agree across
platforms to about1.3e-11cm at the recorded output precision.

All **28 three-day reference models /84 daily records** pass the unchanged
1e-10cm water criterion. BALDEV is zero at the recorded12-decimal precision;
this is not a claim of mathematically exact zero. Maximum model cost is
8.79seconds Windows and5.44seconds Ubuntu, below the predeclared20second cap.
No finer censored stress level is retried and no cost bound is widened.

The original nominal2.678132/2.782673cm comparison is therefore classified,
within this window, as **numerical time-grid and saved-initial-state/history
dependence**, rather than an unexplained2.8cm discrepancy in the migrated
water solve. Independent original equations reproduce both actual nominal
platform trajectories when those inputs are controlled, and separate temporal
refinement changes the result. No groundwater acceptance tolerance was invented
or widened to obtain this disposition.

This does not establish accurate groundwater levels for every run of the
heuristic wetting limiter. It does not turn the failed full nominal comparison
into PASS, certify the whole preceding history, or qualify a universal reference
at all states. The opt-in policy and these limitations remain explicit for
scientific review. The former blocker was absence of independent attribution;
that attribution is now demonstrated. Review readiness is separate from merge
approval, default promotion and whole scientific equivalence.

## Source, platform runs and sealed evidence

Physical snapshot remains c3a0a7e17; production app/src/tools are unchanged in
this work unit. The8 full1096-day Windows/Ubuntu O0/O2 trajectories,64 exact
own day-restart windows and8 nonperturbing heat observations remain valid at
that unchanged dependency surface. They are not repeated for reference tooling.

Independent portable run[44091311535](https://github.com/abhedwig-cell/SWAP5/actions/runs/44091311535)
at8b1a09652 completed SUCCESS, artifact14331578060, SHA256
`d233ff0c7eaed747cc1758dfa2110694fb54aa5b3adf0fb3f91df78813e41235`.
Ubuntu-own run[44093576937](https://github.com/abhedwig-cell/SWAP5/actions/runs/44093576937)
ata6fc4e31d completed SUCCESS, artifact14332712305, SHA256
`ac5f0dac5fc6cc82bec14e19bf077cbc0bcc68875e57bf2248e647ff5f7b4c7a`.

QUALIFICATION.json records the scoped decision and measured values. RAW.zip
contains content-addressed original sources, exact commands, input states,
CSV/accepted-grid/raw logs and reports; RAW.json maps the original paths and
SEAL hashes the exact bytes and upstream artifacts. Compiler products and
executables are omitted; their hashes/commands remain. Earlier unsuccessful
methods and failed B0 comparisons remain in the preceding sealed packages.

`independent_evidence.py --verify` rereads sealed physical outputs, balances,
source/link independence, seed hashes and actual accepted-step logs rather
than trusting only PASS fields. INPUT.zip is a separately hash-bound scientific
fixture. RAW.json is stored without Git newline conversion.

## Reproduction

Unpack INPUT.zip into FIXTURE after checking INPUT.json and use a validated
original provider with gfortran in PATH. Each output directory must be fresh:

```text
python -B tests/local_wetting/independent_reference.py --provider PROVIDER --seed-input FIXTURE/seed --output ADAPTIVE
python -B tests/local_wetting/independent_reference.py --provider PROVIDER --seed-input FIXTURE/seed --output NOMINAL --caps 0.04 --grid FIXTURE/nominal-grid.txt
python -B tests/local_wetting/independent_reference.py --provider PROVIDER --seed-input FIXTURE/seed --output FINE --caps 0.000025 --grid FIXTURE/fine-grid.txt
python -B tests/local_wetting/independent_evidence.py --output integration/local-wetting-time01/independent --verify
```

The own-platform workflow additionally validates the previous physical bundle,
captures its exact prefix and exports its own saved362 state; its commands are
in `.github/workflows/local-wetting-own-grid.yml`. No foreign SWAP5 capsule is
rebound or used as an own-build restart: the legacy input reader is explicitly
given an original-format physical input state.

Coverage is unchanged: two selected full process combinations. Reliability
adds independent balance/solver attribution and actual own-platform grid
controls. Development return is28 short reference runs and three checked prefix
observations; no full1096-day or retired long low-air campaign is repeated.
