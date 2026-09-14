# EB-R05 status — current-canonical transient Richards response

Status: **PASS**

## Scope

EB-R05 closes the hydraulic gap left deliberately open by EB-R04. EB-R04 demonstrated a balanced current-canonical B1.10 case with zero storage change. EB-R05 requires a real transient Richards trajectory with nonzero storage response while retaining strict mass closure, same-input replay identity, and O0/O2 determinism.

The case is a bounded slice derived from the independently qualified F-VQ28 held-out temporal-profile surface. Historical evidence is used as an experimental oracle only; the current Richards binding and current HeadCalc source are compiled and executed directly.

## Provenance

- Canonical empirical-baseline start: `d44b2eb48e7187f8ddc622a5f2329d7a24c24aa0`
- Tested empirical-baseline head: `45722c0857374834f37a9b337c8447f2721893cc`
- Green cumulative workflow run: `34876163938`
- Historical oracle ref: `origin/qualification/f-vq28-richards-temporal-numeric-profile`
- Historical oracle fixture: `tests/fvq/test_fvq28_heldout_temporal_profile.f90`
- Historical fixture blob: `82e75725e8d8c159b20260cd6d68d25ee4a98823`
- FSI18 test-only reference-TRIDAG ref: `origin/work/f-si18-reference-convergence-cliff`
- FSI18 generator blob: `bf25c4c7fefaa59811255b0bc25c041522ab008e`
- Current Richards binding: `src/adapter/mod_reference_richards_legacy_binding.f90`
- Current Richards binding blob: `03a64b6d09fd804242bcf76f7cb5277f59a6230a`
- Current HeadCalc: `src/legacy/b1_10_port/headcalc.f90`
- Current HeadCalc blob: `3ff8d5cfd6963dfb7dafb33ec454fbc0df938a55`

The FSI18 reference TRIDAG is a test-only control replacing the zero-correction test stub with the SWAP 4.3.1 Thomas-operation-order implementation. It is not a production modification.

## Experimental case

- initial uniform pressure head: `-110 cm`
- prescribed bottom-head jump: `+0.05 cm`
- total trajectory duration: `0.25`
- accepted fixed subdivision count: `4`
- no drainage, subsurface sink, or root sink
- explicit top flux based on initial conductivity
- hard per-step and full-trajectory mass gate: `1e-12`
- the same complete trajectory is executed twice from identical initial conditions

## Current-canonical observation

The O0 and O2 outputs are byte-identical.

```text
case_id,nsteps,total_dt,h0,hbot,storage_start,storage_end,storage_change,total_in,total_out,residual,max_step_mass,max_solver_res,max_niter,max_nback,max_abs_head_change,endpoint_fingerprint
fvq28_h0_m110_jump_p0p05,4, 2.50000000000000000E-001,-1.10000000000000000E+002,-1.09950000000000003E+002, 9.48217300712458799E-001, 9.48324585635068718E-001, 1.07284922609918176E-004, 1.79322125191154792E-002, 1.78249275965055611E-002, 0.00000000000000000E+000, 0.00000000000000000E+000, 4.71844785465691530E-016,3,3, 4.91743338982786327E-002,7997553891619626476
```

Observation SHA-256:

`2f09a2bafb46fa0dfc4875c3f508d19e963f0f7786d3be257c45512bbfb702d1`

Observed properties:

- storage changes from `9.48217300712458799E-001` to `9.48324585635068718E-001`;
- nonzero storage response is `1.07284922609918176E-004`;
- total inflow is `1.79322125191154792E-002`;
- total outflow is `1.78249275965055611E-002`;
- the full trajectory residual is exactly `0` in the emitted observation;
- maximum reconstructed accepted-step mass residual is exactly `0`;
- maximum solver-reported unrounded mass residual is `4.71844785465691530E-016`;
- maximum nonlinear iterations are `3` and maximum backtracking attempts are `3`;
- maximum absolute pressure-head response is `4.91743338982786327E-002 cm`;
- the second identical trajectory reproduces the endpoint fingerprint and full ledger exactly;
- endpoint fingerprint is `7997553891619626476`.

The gate emitted:

- `EB_R05_TRANSIENT_STORAGE_RESPONSE_NONZERO=PASS`
- `EB_R05_TRAJECTORY_MASS_CLOSURE=PASS`
- `EB_R05_SAME_INPUT_REPLAY_IDENTITY=PASS`
- `EB_R05_O0_O2_OBSERVATION_IDENTITY=PASS`
- `EB_R05_CURRENT_CANONICAL_TRANSIENT_RICHARDS_OBSERVATION PASS`

R01 through R05 all passed in workflow run `34876163938`.

## Failed-run classification during harness construction

Three red runs preceded the green evidence. None reached a contradictory model result.

1. Run `34875731250` stopped during compilation because the current Richards binding now imports `mod_reference_richards_temporal_indicator`, which was absent from the historical F-VQ28-style compile list. The current dependency was added; the fixture and expectations were unchanged.
2. Run `34875872855` stopped during compilation because the current temporal-indicator module imports `mod_fixed_flux_top_boundary_provider`. That direct current dependency was added; again no physical fixture, assertion, tolerance, or expected result changed.
3. Run `34876065800` reached and passed the transient scientific assertions, then failed only while formatting the observation row because the format descriptor reserved nine consecutive real fields where seven were supplied. The only correction was output-format arity `9(...)` to `7(...)`.

## Claim boundary

EB-R05 establishes one bounded current-canonical transient Richards response with nonzero storage change, strict mass closure, deterministic same-input replay, and O0/O2 byte identity. It does not by itself establish temporal convergence order, a global timestep error bound, all bottom-boundary modes, root uptake, snow, drainage, or MultiSWAP process interaction.

The next empirical layer should therefore test a process interaction rather than another isolated hydraulic trajectory. A natural next target is reference ET/root uptake coupled into the current physical runtime, because EB-R01/R02 characterize ET demand and EB-R04/R05 characterize the hydraulic substrate separately.