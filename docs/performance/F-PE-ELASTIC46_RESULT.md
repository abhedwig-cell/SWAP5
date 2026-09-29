# F-PE-ELASTIC46 — production-shaped ELAS numerical/performance characterization result

Date: 2026-09-29

Status: QUALIFIED_RESEARCH_RESULT

Branch:
`research/f-pe-elastic46-production-effect`

Qualified postimage:
`5ab151ad662c8e8a2f21cdcbeab79d388da97547`

Baseline:
`integration/f-ci-canonical@b4578b6dc7258a14474fd829f22353c8ef87ce0a`

Workflow run:
`36615676116`

Job:
`109567924243`

Conclusion:
SUCCESS.

## Scope

ELASTIC46 characterizes, without changing production source, the numerical and
runtime response of the production Reference/default-MvG route under three ELAS
parameter regimes:

- `OFF`: default-off ELAS;
- `FIXED_1E6`: uniform `Ss = 1e-6 cm^-1`;
- `GENERATED`: admitted BOFEK/BRO generated prior.

The frozen real-source profile is:
- `normalsoilprofile_id = 90116260`;
- EPSG:28992 x = `179362.75550490862 m`;
- EPSG:28992 y = `418659.84937244334 m`.

The generated node-local prior spans:
- minimum: `2.2503648121711709e-6 cm^-1`;
- representative middle-node value: `2.6290427195971140e-6 cm^-1`;
- maximum: `2.9981689952213786e-6 cm^-1`.

Therefore the generated profile is materially larger than the illustrative
uniform `1e-6` case and the two must not be treated as interchangeable.

## Qualification repairs before the final result

Earlier attempts exposed qualification-fixture issues rather than ELAS semantic
failures:

1. the initial fixture used an outdated MultiSWAP result/API shape;
2. a generated Fortran continuation was malformed;
3. non-completed frozen-bank cases were initially treated as test failures even
   though preregistration required them to be retained as observations;
4. the first runtime-shaped fixture paired real variable BRO geometry with a
   uniform HeadCalc `MOD_grid` stub, causing pre-solver transaction failure;
5. timing originally used a perturbation case that did not complete;
6. checksum diagnostics for non-committed cases were not initialized
   deterministically.

The final postimage uses the exact 16-node variable experiment grid in the
HeadCalc stub, times a completed equilibrium case, and reports checksums only
for committed postimages.

No physical constant, ELAS formula, solver tolerance, timestep policy, or
regime-specific perturbation was changed during these repairs.

## Frozen bank result

The bank contains:
- 4 initial pressure-head states: `-75, +0.1, +2, +10 cm`;
- 3 flux perturbations per state: `0, +0.05, -0.05`;
- 3 ELAS regimes.

Total:
- 36 case/regime combinations;
- 12 completed and committed;
- 24 non-completed transaction results.

All 12 equilibrium cases (`delta = 0`) completed in all three regimes with:
- one accepted substep;
- one solver iteration;
- three nonlinear iterations;
- zero retries;
- three backtracking attempts;
- three Jacobian builds;
- three linear solves;
- three HeadCalc calls;
- complete mass ledger;
- zero reported mass residual.

The 24 perturbed cases all reached the solver and all remained non-committed.
They are therefore useful numerical-work observations, not preflight failures.

## H1 — unsaturated negative control

At `h0 = -75 cm`, all three ELAS regimes are exactly identical for both
perturbation signs.

For `delta = +0.05`:
- nonlinear iterations: `91 / 91 / 91`;
- retries: `0 / 0 / 0`;
- backtracking: `93 / 93 / 93`;
- HeadCalc calls: `27 / 27 / 27`;

for `OFF / FIXED_1E6 / GENERATED`.

For `delta = -0.05`:
- nonlinear iterations: `99 / 99 / 99`;
- retries: `1 / 1 / 1`;
- backtracking: `127 / 127 / 127`;
- HeadCalc calls: `26 / 26 / 26`.

This supports the preregistered negative-control expectation: while all heads
remain in the unsaturated constitutive regime, activating ELAS does not alter
the observed numerical path.

The equilibrium postimage is also identical across all three regimes:
- pressure-head checksum: `-1200`;
- water-content checksum: `5.534585013`.

## Saturated equilibrium physics

For `h >= 0`, equilibrium pressure-head checksums remain identical while
water-content checksums differ exactly in the physically expected direction
because elastic storage adds saturated storage.

At `h0 = 0.1 cm`:
- OFF: `6.768000000`;
- FIXED_1E6: `6.768001600`;
- GENERATED: `6.768004131`.

At `h0 = 2 cm`:
- OFF: `6.768000000`;
- FIXED_1E6: `6.768032000`;
- GENERATED: `6.768082622`.

At `h0 = 10 cm`:
- OFF: `6.768000000`;
- FIXED_1E6: `6.768160000`;
- GENERATED: `6.768413112`.

These differences are physical consequences of the admitted ELAS term and are
not approximation error.

## Saturated negative perturbation

For `delta = -0.05`, ELAS consistently reduces numerical work relative to OFF
in all three saturated starting states.

### h0 = 0.1 cm

OFF:
- nonlinear `144`;
- retries `9`;
- backtracking `846`.

FIXED_1E6:
- nonlinear `108`;
- retries `4`;
- backtracking `108`.

GENERATED:
- nonlinear `135`;
- retries `5`;
- backtracking `135`.

### h0 = 2 cm

OFF:
- nonlinear `144`;
- retries `9`;
- backtracking `846`.

FIXED_1E6:
- nonlinear `75`;
- retries `1`;
- backtracking `75`.

GENERATED:
- nonlinear `84`;
- retries `1`;
- backtracking `84`.

### h0 = 10 cm

OFF:
- nonlinear `144`;
- retries `9`;
- backtracking `846`.

FIXED_1E6:
- nonlinear `72`;
- retries `1`;
- backtracking `72`.

GENERATED:
- nonlinear `69`;
- retries `0`;
- backtracking `69`.

At `h0 = 10 cm`, GENERATED therefore uses about 52% fewer nonlinear
iterations and about 92% fewer backtracking attempts than OFF, while eliminating
the observed internal retries in this failed interval attempt.

This is a strong numerical interaction signal. It is not yet evidence that the
full interval will converge under a production timestep controller, because none
of the perturbed cases committed under this deliberately fixed frozen interval.

## Saturated positive perturbation

For `delta = +0.05`, the response is not monotonic across the saturated states.

At `h0 = 0.1 cm`:
- OFF: nonlinear/retries/backtracking = `193 / 6 / 409`;
- FIXED_1E6: `186 / 6 / 481`;
- GENERATED: `175 / 7 / 477`.

At `h0 = 2 cm`:
- OFF: `170 / 8 / 455`;
- FIXED_1E6: `178 / 9 / 430`;
- GENERATED: `187 / 9 / 409`.

At `h0 = 10 cm`:
- OFF: `207 / 6 / 608`;
- FIXED_1E6: `125 / 4 / 326`;
- GENERATED: `106 / 3 / 206`.

Thus ELAS can strongly reduce numerical work at the more strongly saturated
state, but near saturation it can trade fewer nonlinear iterations against more
backtracking/retries, and at `h0 = 2 cm` it increases nonlinear iteration
count while reducing backtracking.

There is no defensible single statement that ELAS universally improves or
worsens convergence.

## FIXED_1E6 versus GENERATED

FIXED_1E6 is not a neutral proxy for GENERATED.

Examples:
- at `h0=0.1, delta=-0.05`, FIXED uses `108` nonlinear iterations versus
  `135` for GENERATED;
- at `h0=2, delta=-0.05`, FIXED uses `75` versus GENERATED `84`;
- at `h0=10, delta=-0.05`, GENERATED is slightly lower, `69` versus `72`,
  and uses zero retries versus one;
- at `h0=10, delta=+0.05`, GENERATED uses `106` nonlinear iterations versus
  `125` for FIXED.

This confirms H4: the magnitude and profile structure of Ss participate in the
numerical response.

## Timing observation

Timing used the same completed `h0=2 cm, delta=0` equilibrium interval for all
regimes, with five replicas and 1000 calls per replica after warmup.

O2 median:
- OFF: `9413.756 ns/interval`;
- FIXED_1E6: `9559.666 ns/interval`;
- GENERATED: `9565.353 ns/interval`.

Ratios:
- FIXED_1E6 / OFF: `1.01550`;
- GENERATED / OFF: `1.01610`;
- GENERATED / FIXED_1E6: `1.00059`.

Within this CI observation, active ELAS adds about 1.5–1.6% per-interval cost
for this trivial equilibrium solve, while GENERATED and FIXED_1E6 have
effectively the same direct execution cost.

This is not a portable benchmark claim. In nontrivial cases the solver-work
changes above are much larger than this small constitutive overhead and can
therefore dominate total runtime.

## Gates

- A1 admitted generated-parameter preparation with finite positive Ss: PASS;
- A2 all 36 frozen bank combinations executed or retained as explicit
  non-completed results: PASS;
- A3 all committed cases satisfy the hard mass gate: PASS;
- A4 unsaturated control shows identical regime behavior: PASS;
- A5 numerical-work counters recorded for every bank case: PASS;
- A6 five repeated timing replicas per regime with identical case/call count:
  PASS;
- A7 O0/O2 non-timing classification, counters and committed checksums:
  PASS;
- A8 zero `src/**` production change: PASS.

## Interpretation

H1 is supported.

H2 is confirmed: saturated storage postimages differ physically while
pressure-head equilibrium remains the same in the equilibrium controls.

H3 is not supported as a broad statement that GENERATED reduces numerical work
across the complete saturated bank. The effect is strongly state- and
forcing-direction-dependent. However, the repeated and sometimes large
interaction is sufficiently clear to justify a dedicated threshold/timestep
study.

H4 is supported.

The most important finding is therefore not a universal speedup. It is that
physically parameterized elastic storage materially changes nonlinear work near
and above saturation, and that this interaction becomes large enough that ELAS
and timestep/globalization policy should be studied jointly.

## Decision

Classification:
`QUALIFIED_PRODUCTION_SHAPED_RESEARCH_RESULT`.

No production admission or default change follows from ELASTIC46.

The smallest justified next workunit is an ELAS × timestep/solver interaction
study around the perturbation/convergence threshold, using the same three
regimes and the same frozen profile. That study should determine whether the
large reductions in retries/backtracking translate into fewer accepted
substeps and lower end-to-end runtime when the interval controller is allowed
to adapt, rather than holding the difficult interval fixed.
