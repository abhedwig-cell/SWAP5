# PPA-WU05-C3A admission boundary falsification

Date: 2026-10-02 (Europe/Amsterdam)

Status: `PRODUCTION_READINESS_FALSIFIED / NOT_CANONICALLY_ADMITTED`

## Exact execution

Candidate production source: `ffde8d45567f3cf19d741a2e5d5794d03d8d1ced`.
Canonical reconciliation reference: `828df126e0c0d70f5cbfae51614bfc3b53e832a4`.
GNU Fortran 13.3.0, local execution, strict warnings and runtime bounds checks.
Compiler was materialized from Ubuntu packages in a writable temporary prefix.
No GitHub Actions run was requested.

The independent waterfilm function had an invalid PURE declaration with an INTENT(OUT)
status argument. Commit ffde8d4 repairs only that declaration, without changing equations.

Executed positive gates:
- PPA_WU05C3A_ACTIVE_CHAIN=PASS
- C3A_EXECUTION_STATIC_OWNERSHIP=PASS
- PPA_WU05C3P_ROOT_OXYGEN_COMPOSITION=PASS
- PPA_WU05C3P_ACTIVATION=PASS
- PPA_WU05C3A_PRODUCTION_PRESERVATION_GATE=PASS
- PPA_WU05C3Q_KERNEL_SMOKE=PASS
- PPA_WU05C3R_MACRO_ZERO_DEPTH_CHECKS=27
- PPA_WU05C3R_MACRO_ZERO_DEPTH=PASS
- PPA_WU05C3R_SCALAR_BRACKET=PASS
- PPA_WU05C3Q_ROOT_COMPOSITION=PASS

These gates do not establish full application admission.

## Reproducible negative gate

Run:
```bash
bash tests/physics/run_bartholomeus_admission_boundaries.sh
```

It first compiles and executes the existing active chain, then checks required
saturation and invalid-input boundaries using the same production objects.

Observed output:
```text
PPA_WU05C3A_ACTIVE_CHAIN=PASS
FACTORS= 0.0000000000000000E+00 3.3847426250576973E-01
SATURATED_ACCEPTED=F
NAN_PARAMETERS_ACCEPTED=T
NAN_PHYSICS_ACCEPTED=T
NAN_FACTORS= 0.0000000000000000E+00 0.0000000000000000E+00
C3A_ADMISSION_BOUNDARY_FAILURES=3
PPA_WU05C3A_ADMISSION_BOUNDARIES=FAIL
ERROR STOP 20
```

Exit status: 20. IEEE_INVALID_FLAG was also reported.

### Saturated valid-input failure

The two-node fixture uses water content equal to saturated water content (0.45)
and finite negative pressure head (-1 cm). Other parameters are identical to the
passing active fixture. The provider returns ok=false.

Zero gas-filled porosity yields zero soil diffusivity. The ordered response enters
MACRO, which rejects d_soil<=0, instead of providing the required valid saturated/
gas-filled-porosity shortcut. This is a production physical-regime handling failure,
not a missing harness dependency. The probe does not claim a newly qualified
legacy saturated numerical factor.

### Non-finite input silently accepted

Replace root_radius_m with IEEE quiet NaN in the passing fixture.
validate_bartholomeus_parameters returns true, and the complete factor provider
also returns ok=true with factors [0,0].

A non-finite scientific input must fail closed. Producing an apparently valid full
stress result violates that contract and can silently suppress root extraction.
Finite-range comparisons alone do not reject NaN.

## Application admission limitation

At the recorded canonical/head comparison the branch delta consists of additions.
No existing production root-execution caller/configuration was modified.
The new execution routine is an independently callable seam, not evidence that the
actual FMR application selects and calls it. The current active-chain test calls
the factor provider directly. The preservation script checks execution ownership
statically and executes composition/activation tests; it does not execute the full
runtime seam. Its green marker must not be represented as a full application run.

## Decision and bounds

The current production-readiness claim is falsified. PR #962 must remain draft and
unmerged. C3Q source-bound response evidence and C3P composition evidence remain
qualified within their tested dependency envelopes. This finding does not falsify
the Bartholomeus scientific formulation or the bounded-solver replay.

Required recovery:
1. Restore source-bound saturated shortcut and prove its ordered-profile semantics.
2. Validate all non-finite/shape inputs before physical evaluation; test NaN and infinity.
3. Exercise the execution seam dynamically, including OFF, unsupported, no-roots,
   negligible transpiration and non-rooted preservation.
4. Bind actual application selection and owner inputs under the owning runtime contract.
5. Consolidate duplicate research composition modules and reconcile current canonical.
6. Only then requalify admission and post-merge preservation.

No canonical admission or closeout success is claimed.
