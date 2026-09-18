# PUB-GC E4 implementation plan — qualification-only response probes

## Purpose

Implement the E4 response-identity preregistration without expanding the production coupling API.

The E4 instrumentation must observe the same real SWAP/FMR execution route used by F-GC44, but all additional derivative and mass diagnostics remain in the qualification bridge under tests/fgc/support.

## Dependency

E4 execution should start only after the current E3 coupling branch is reconciled into canonical, because E4 reuses its configurable window / predictor-flux fixture.

The E4 design itself does not depend on the outcome of E3-R.

## Production-code rule

Do not change:

- groundwater_swap_trial_t;
- the production participant public API;
- SWAP state ownership;
- transaction acceptance;
- F-GC30 response semantics;
- production numerical tolerances.

The current production participant intentionally exposes only the interface quantities needed by coupling. Publication diagnostics are not a reason to enlarge that contract.

## Qualification bridge extension

Extend tests/fgc/support/mod_fgc44_real_swap_c_bridge.f90 with two independent, non-committing probe families.

### Probe P — bottom-flux predictor perturbation

Suggested C ABI:

~~~text
fgc44_e4_predictor_probe_c(
    qbot_cm_per_day,
    completed,
    h_end_m,
    bottom_exchange_cm,
    storage_start,
    storage_end,
    storage_change,
    total_in,
    total_out,
    mass_residual,
    status_code
)
~~~

Implementation:

1. require an initialized E4 baseline and an unchanged committed origin;
2. capture a fresh checkpoint from the same committed state;
3. copy the baseline predictor forcing;
4. vary only bottom_flux;
5. keep top flux and all other forcing equal to the baseline;
6. call the real predictor_backend%run_trial;
7. extract the candidate terminal lower-face hydraulic head through the same materialization path used by F-GC44;
8. return whole-window mass and bottom-exchange diagnostics;
9. discard the candidate;
10. verify committed revision/time remain unchanged.

The probe must not call the configurable initializer with q0 +/- delta_q, because that initializer changes both top and bottom flux.

### Probe H — prescribed-head corrector perturbation

Suggested C ABI:

~~~text
fgc44_e4_head_probe_c(
    head_m,
    completed,
    q_swap_m_per_s,
    bottom_exchange_cm,
    storage_start,
    storage_end,
    storage_change,
    total_in,
    total_out,
    mass_residual,
    status_code
)
~~~

Implementation route:

1. require the same initialized baseline and accepted origin;
2. capture or reuse an immutable checkpoint of the committed state;
3. call materializer%materialize(head_m, datum, forcing, status);
4. run the real corrector_backend%run_trial directly from the accepted checkpoint;
5. require an exact completed window before returning a valid observation;
6. derive q_swap from signed whole-window bottom exchange using the same public conversion as the production participant;
7. expose the complete canonical mass account;
8. discard the candidate;
9. leave committed state and the interface ledger unchanged.

Using a qualification-only direct backend probe is preferred to extending groundwater_swap_trial_t with publication diagnostics.

## Baseline response observation

The initialized baseline must additionally expose:

~~~text
q0
H_start
H_end
u_AT
dh_bot_end_cm_per_qbot_cm_per_day
window duration
~~~

The current E1 diagnostics already expose all except the native accepted-trajectory derivative. Add that derivative only to the qualification getter if needed.

## Repeatability

The Python E4 harness must call:

- the central predictor probe at least three times;
- the central head probe at least three times.

All repetitions start from the same accepted state and are discarded.

Record raw repetitions. Do not average away non-repeatability before reporting it.

## Predictor perturbation runner

For each preregistered baseline:

~~~text
for relative delta_q in preregistered sequence:
    run q0-delta_q predictor probe
    run q0+delta_q predictor probe
    if both complete:
        compute D_Hq
        compute u_FD
    else:
        record centered-pair unavailable
~~~

Use terminal lower-face head in centimetres:

~~~text
D_Hq =
  (H_plus_m - H_minus_m) * 100
  / (2 delta_q_cm_per_day)

u_FD = DeltaT_day / D_Hq
~~~

No unit conversion is hidden in the formula.

## Head perturbation runner

For each delta_H:

~~~text
run H0-delta_H probe
run H0+delta_H probe
~~~

Convert the returned signed bottom amount from centimetres to metres:

~~~text
V_out_m = bottom_outward_exchange_cm * 0.01

J_V =
  (V_plus_m - V_minus_m)
  / (2 delta_H_m)
~~~

For storage:

~~~text
DeltaS_m = storage_change_native * 0.01

J_S =
  (DeltaS_plus_m - DeltaS_minus_m)
  / (2 delta_H_m)
~~~

For the remaining net terms:

~~~text
B_other_m = DeltaS_m + V_out_m

J_B =
  (B_other_plus_m - B_other_minus_m)
  / (2 delta_H_m)
~~~

and verify:

~~~text
J_S - J_B + J_V
~~~

against the derivative noise/error scale.

## Public-rate consistency

For every completed head probe also check:

~~~text
q_swap_m_per_s * DeltaT_s = V_out_m
~~~

to representation/accounting tolerance.

This preserves the E1 sign adjudication in the E4 derivative path.

## Noise classification

For an observable x, define central repeat spread:

~~~text
spread(x) = max(x_repeat) - min(x_repeat)
~~~

For a centered numerator:

~~~text
Delta_x = x_plus - x_minus
~~~

label it noise-limited when |Delta_x| is not resolved above a conservative multiple of the repeat spread and floating-point scale.

The multiplier must be frozen in the executable E4 protocol before the first result is interpreted.

## Plateau selection

Do not choose one perturbation size by agreement with u_AT.

Instead identify contiguous perturbation scales whose derivative estimates are mutually stable relative to:

- repeatability floor;
- floating-point scale;
- neighboring centered estimates.

Persist all estimates and the objective plateau rule.

If no stable contiguous region exists, return NO_DERIVATIVE_PLATEAU.

## Expected output files

~~~text
PUB_GC_E4_RAW.jsonl
PUB_GC_E4_RESPONSE_IDENTITY.json
PUB_GC_E4_RESPONSE_IDENTITY.csv
~~~

The summarized record must never discard the raw plus/minus measurements.

## Qualification controls

Before interpreting E4:

1. default F-GC44 initializer reproduces the current anchor;
2. E1 mass/sign identities remain green;
3. every E4 probe leaves committed SWAP revision/time and ledger unchanged;
4. central repeatability is finite and classified;
5. no probe silently accepts a partial window.

## Implementation order

1. merge/reconcile E3 configurable fixture into canonical;
2. add qualification-only predictor probe;
3. add qualification-only head/mass probe;
4. add Python bindings;
5. add deterministic probe-contract test;
6. add E4 preregistered matrix runner;
7. execute only after the executable noise/plateau rule is frozen;
8. persist result and update manuscript/claim ledger.

## Scientific boundary

The probe implementation is an observation facility, not a new coupling capability.

If E4 shows that the production response coefficient is not the actual corrector response, do not change the production coupling inside the evidence workunit. First record the scientific result and then create a separately governed coupling-method change if warranted.
