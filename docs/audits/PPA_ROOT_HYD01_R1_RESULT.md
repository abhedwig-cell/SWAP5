# PPA-ROOT-HYD01 R1 result

**Decision:** `QUALIFIED_RESTRICTED_PRESCRIBED_ROOT_SINK_TEMPORAL_CERTIFICATE`

The root-specific temporal-certificate coverage gap identified by D2 is closed for one deliberately narrow provider class.

## Admitted envelope

The Reference-Richards temporal indicator may now proceed when the associated root-sink provider is the concrete `b110_root_sink_provider_t` and its prescribed vector:

- has the same number of nodes as the Richards state;
- remains bound;
- contains only finite values.

Any other root-sink provider remains fail-closed through `root-sink-policy-deferred`.

This does not admit dynamically state-dependent plant-stress logic into the temporal indicator. It admits the already existing prescribed root-sink carrier used by the frozen HYDRO-MEMORY coupling-window design.

## Why the extension is semantically bounded

The production patch changes only `src/solver/mod_reference_richards_temporal_indicator.f90`.

It does not change HeadCalc, the Richards equations, the defect operator, indicator normalization, transaction core, solver tolerances or the root-sink provider itself.

The relevant prescribed root-sink provider returns the bound forcing vector unchanged and does not derive a new sink from pressure head or water content during indicator evaluation. HeadCalc inserts that vector additively into the Richards residual. D1 had already shown the prescribed ROOT and equivalent GENERIC sink routes to have identical solver/transaction rejection patterns across five preregistered durations.

## Qualification evidence

Final workflow: **35429605183**, head `b7803c1cf0818677651a0eecaed4bd84ffb3059a`.

The frozen D2 fixture was rerun after the patch. ROOT and GENERIC both produced:

- temporal route `reference-richards-raw-bound`;
- available model certificate;
- normalized indicator (8.5206497718684332\times10^4) under the diagnostic (10^{-5}\) cm budget;
- equal `head_inf_bound` and normalized indicator within the preregistered 64-epsilon scaled criterion;
- zero additional nonlinear solves and one additional tridiagonal solve.

The dedicated marker `PPA_ROOT_HYD01_R1_ROOT_GENERIC_TEMPORAL_EQUIVALENCE=PASS` is present.

A dependency-closed preservation build independently reran the existing direct owner tests:

- F-SI38 prescribed-qbot temporal certificate: PASS;
- F-SI25 reference indicator production seam: PASS;
- F-SI25 cost contract: zero extra nonlinear solves, one extra tridiagonal solve;
- O0/O2 output identity: PASS.

## Remaining boundary

This result closes **root-sink temporal coverage**, not HYDRO-MEMORY temporal accuracy policy.

The (10^{-5}\) cm budget used in D2/R1 was a diagnostic probe inherited from another qualification context. The resulting normalized indicator of about (8.52\times10^4) is direct evidence that this number must not be silently promoted to a HYDRO-MEMORY default.

The next workunit must bind a research/application accuracy requirement to the existing coupling accuracy contract. Until that is justified and preregistered, HYDRO-MEMORY Stage 0 remains unauthorized.
