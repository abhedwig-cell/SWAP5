# F-PE-APPROX03 T2A result — 2x temporal budget candidate

Date: 2026-09-26

Status: `REJECTED_REFERENCE_ENVELOPE_ROBUSTNESS`

Candidate:

- model temporal-indicator budget `1e-5 -> 2e-5 cm`;
- all local Richards convergence settings unchanged;
- A2C OFF.

## Initial evidence

On the first three production-consistent mode-5 frontier cases, 2x was strongly speed-positive:

- runtime gain approximately 19% to 31%;
- accepted substeps and nonlinear work materially reduced;
- relative pressure-head and water-content deviations remained very small;
- storage-change deviation remained below about 0.7%;
- terminal bottom-flux deviation remained below about 2.2%;
- no retries;
- mass residual remained at roundoff scale.

This justified broader qualification but not production admission.

## Reference-envelope discovery

The first broad matrix specification used a forcing fraction of `5e-4` and a `0.01 day` interval.

The exact/reference B01-wet-plus arm did not commit.

A shorter `0.001 day` interval still failed in the exact/reference arm, so candidate qualification was stopped and a reference-only workload discovery was performed.

For B01 wet, the first stable multi-substep reference workload found was:

- forcing fraction: `5e-5` of local conductivity;
- interval: `1e-4 day`;
- accepted substeps: 3;
- retries: 0;
- complete mass accounting.

A second stable reference point at the same forcing fraction and `2e-4 day` used 4 accepted substeps.

The `5e-5`, `1e-4 day` point was selected before inspecting candidate behavior.

## Candidate robustness result

On that controlling reference-stable workload:

- the exact/reference arm committed and was mass-complete;
- the 2x T2A arm did not commit.

This is a candidate-only robustness failure.

Under the preregistered advancement rule, a candidate-only failure is sufficient to reject T2A. No broader error statistics can override failure to produce an accepted transaction on a workload where the exact reference succeeds.

## Decision

T2A at 2x is rejected.

The earlier speed/error frontier remains valid evidence that temporal-budget relaxation can save substantial work. It does not establish 2x as a globally robust practical setting.

The next experiment, if continued, must move back toward the exact budget and be preregistered independently. It must begin on the controlling B01-wet workload before any new broad matrix is attempted.
