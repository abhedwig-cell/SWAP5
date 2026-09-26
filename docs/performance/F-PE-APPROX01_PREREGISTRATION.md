# F-PE-APPROX01 — practical / approximate MultiSWAP performance phase

Date: 2026-09-26

Status: `PREREGISTERED_NOT_STARTED`

Predecessor:
`F-PE-DIR01 — production bottom-head directional tangent exact-cost reduction`

## Purpose

Open the practical performance phase only after the exact-P0/P1 path has been rebaselined and the remaining exact headroom has become comparatively invasive or small.

The target application is large-N SWAP5-MODFLOW6 operation where wall-clock performance matters more than strict reproduction of the fully exact Reference trajectory.

## Governing principle

Approximation is allowed only when it is explicit, bounded and qualified.

The goal is not to make the model numerically loose. The goal is to identify which controlled concessions produce large runtime gains while preserving the physical meaning required by the coupled application.

## Initial research question

Which approximation levers provide the largest end-to-end MultiSWAP speedup for the smallest and best-understood deviation from the exact canonical Reference path?

Candidate levers may include, but are not assumed to be beneficial in advance:

- reduced nonlinear convergence effort;
- less frequent or selectively computed response tangents;
- approximate directional response;
- timestep / substep simplification;
- bounded constitutive approximation beyond the exact F-AHL50 envelope;
- cheaper coupling-response update policies;
- reuse or lagging of selected coupling information.

No candidate is production-admitted merely because it is faster.

## Qualification dimensions

Every candidate must be measured against the exact canonical production stack for:

- end-to-end runtime;
- water balance;
- pressure head / groundwater response;
- bottom flux and cumulative exchange;
- relevant root-zone state;
- coupled MODFLOW response;
- numerical stability and failure rate;
- bias over repeated timesteps, not only one-step error.

## Error envelopes

The workunit must define explicit practical envelopes before admission.

These may differ by output and application purpose. Small deviations can be acceptable, but large, accumulating or unexplained errors are not.

Mass balance must remain independently monitored even when small state/flux deviations are accepted.

## Measurement authority

Primary authority is production-shaped end-to-end MultiSWAP timing.

Microbenchmarks may explain mechanisms but may not be added together to claim total application speedup.

Candidates must be compared on the same postimage and with replicated timing where runner noise is material.

## First phase

Begin with observation and controlled experiments only.

Do not enable approximate behavior by default.

The first decision should be which single approximation lever has the best measured speedup/error tradeoff. Only that lever should advance to a production-shaped opt-in candidate.

## Default behavior

Exact canonical behavior remains the default.

Any admitted approximate mode must be:
- explicit;
- opt-in;
- documented;
- bounded by a qualified envelope;
- distinguishable in diagnostics / provenance.

## Strategic closure condition

APPROX01 closes when at least one of the following is established:

1. a practical opt-in mode provides a materially larger end-to-end speedup at acceptable bounded error; or
2. tested approximations fail to deliver enough benefit to justify the numerical concession.

The workunit must report the measured speedup/error frontier, not only a chosen implementation.
