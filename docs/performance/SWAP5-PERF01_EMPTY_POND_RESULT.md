# PERF01 explicit implicit pond evaporation

## Scope and authority

The [production contract](SWAP5-PERF01_EMPTY_POND_PRODUCTION_CONTRACT.md),
`integration/diagnostics/PERF01_SCOPED_ROUNDING_STATUS.json` and
`integration/diagnostics/verify_perf01_empty_pond.py` own this bounded proposal.
Qualification and canonical admission are separate fields in that status record.
The source baseline is `eaa04cf7b00ff5d676eb533d160109c533a92c8a`.

The file application exposes `implicit_pond_evaporation`, default false. The
example `examples/solute_column/dry32_implicit_pond.nml` selects it explicitly.
The qualified surface profile uses the arithmetic face conductivity mean,
fixed explicit top conductivity, zero bare-soil evaporation demand, no macropore
donor or area partition, and pressure head below the top-node distance. The
enabled provider rejects other conductivity means and unsupported couplings.
The application also rejects dynamic heat, enabled accepted-step proposal and
nonlinear Freundlich chemistry, including chemistry imported from original SWP.
Water and chemical policy bits must agree before a joint trial starts.

No committed-state or restart format changes. Callers must supply the same
physical policy on continuation. HeadCalc, transaction algorithms, tolerances,
mass criteria and retry limits are unchanged. This changes an explicitly selected
physical surface closure; it does not establish a matched-physics speedup.

## Mechanism and evidence

The original dry32 case exhausts the sixth reporting window after five committed
windows. A generated one-ULP correction still times out after 90 seconds, with
45312 internal accepted substeps. Sixty-four actual rejected full/half comparisons
contain 2048 nodal records. Switching pond evaporation using previous pond depth
introduces a full/half source difference of half the prescribed demand.

The selected closure solves the endpoint empty-pond constraint. With gross supply
I, initial pond P, duration dt and zero-head infiltration capacity Qc, pond
evaporation is bounded by `E = min(Epot, max(0, I + P/dt - Qc))`. A partially
satisfied demand leaves an empty pond and infiltration Qc. At full demand the
existing positive-pond/runoff solution applies. Independent scalar water-balance,
bound, continuity and frozen-head full/half observations cover 45 cases per build
profile and compare the real enabled provider to the frozen experiment.

A second actual rejection exposed cancellation in empty-pool mixing: an available
mass of 2.1175823681357508e-22 mg/cm2 produced its negative as residual. The explicit
option selects the analytical empty-pool limit: all available mass infiltrates
when the pond, runoff and macro area are zero. It changes no concentration and
performs no mass clipping. Three-provider O0/O2 tests preserve the absent/false
negative counterexample and verify enabled exact limits and other branch results.

The generated coupled case completes all 64 windows through day 1 with unchanged
HeadCalc. Checked O0 and production O2 six-window physical files and deterministic
work agree exactly. Uninterrupted execution and fresh-process continuation after
window 6 agree in final state, endpoint and restart bytes and in all reporting
and deterministic work rows. Maximum water and solute residuals are respectively
9.54e-14 cm and 2.70e-13 mg/cm2. The uninterrupted measured run takes 94.39 seconds
and 144584 KiB peak RSS. Failed and censored observations remain in the evidence.

An independent Python/SciPy continuous finite-volume water model imports no
Fortran providers. Tightening its BDF tolerances verifies reference spread below
1e-4 cm head and 1e-8 water fraction/pond. The first insufficiently converged
reference pair remains recorded as failed. Native temporal tolerance 1e-6 gives
maximum head/water-fraction errors 0.0116653 cm / 1.78576e-6. At 1e-7 these fall to
0.00361188 cm / 5.63545e-7, with smaller cumulative evaporation and runoff errors.
That explicitly selected refinement takes 358.53 seconds and 453360 KiB within
its 360-second/512-MiB limits. There is no independent chemical-trajectory truth
claim, and a local temporal tolerance is not a global-error bound.

## Production preservation and limits

Fresh real production builds execute the original 86 application assertions,
172 original SWP observations and 18 annual thermal/application cases. Their
default physical artifacts match the immutable predecessor exactly. Enabled
production six-window O0/O2 and full-day O2 artifacts match the qualified generated
candidate. Unsupported temperature, proposal, nonlinear and imported nonlinear
inputs reject before budget creation; mismatched or missing water policy rejects with zero water
work and no reporting row.

An exact statement-level projection removes only the named default-false
extensions and recovers all nine incumbent production/application files byte
for byte. The incumbent owner receives three additive entry hooks; its entire
assertion body is retained. Its frozen baseline qualification is replayed in an
isolated worktree. NUT process providers and owning records are unchanged; NUT
preservation combines that frozen qualification, the explicit default-path
projection and fresh current default/thermal composition. This is not a new
native full NUT qualification. Full moving F-CI and retired highest-low-air stress
are not selected solely for optional interface extensions. No full migration,
master-row promotion, broad conductivity-mean or combined heat/nonlinear/proposal
admission follows.
