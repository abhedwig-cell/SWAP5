# F-PE-HYDTABLE01 P1 solver result

Date: 2026-09-27

Status: `P1_PHYSICS_PASS_PERFORMANCE_FAIL`

PR:
`#659 — F-PE-HYDTABLE01: bounded conductivity table research`

Measured head:
`9dfc2791311a395a87527c4860e064a4f258d065`

Workflow:
`36304457244`

## Frozen candidate

The P0-frozen candidate was unchanged:

- N=1024;
- uniform ln(-h) grid;
- piecewise-linear ln(K);
- same-interpolant derivative;
- represented domain -1e6 to -1 cm;
- analytical fallback outside that domain.

The first P1 implementation was found to compute analytical K and then overwrite it with table K. That duplicate work was removed without changing the table, domain, error envelope or fallback semantics. This result is from the corrected implementation.

## Solver matrix

B01, B12, O05 and O14 were each exercised in wet, mid and dry states.

All 12 candidate solves converged.

For every case:

- nonlinear-iteration count matched the analytical Reference arm exactly;
- backtracking count matched exactly;
- no new solve failure occurred.

Maximum observed deviations across the matrix:

- pressure head: 9.989e-5 cm;
- water content: 2.507e-7;
- bottom flux difference: 2.596e-6 in the fixture's native units;
- mass residual magnitude: 1.332e-15.

Thus the frozen table does not create an obvious nonlinear-robustness penalty on this matrix.

## Runtime

Candidate / analytical timing ratios:

- B01 wet 1.0289;
- B01 mid 1.0295;
- B01 dry 1.0441;
- B12 wet 1.0361;
- B12 mid 1.0242;
- B12 dry 1.0293;
- O05 wet 1.0063;
- O05 mid 1.0416;
- O05 dry 1.0281;
- O14 wet 1.0202;
- O14 mid 1.0417;
- O14 dry 1.0345.

Aggregate:

- median runtime ratio: 1.029395;
- speed-positive cases under the preregistered practical threshold: 0/12;
- materially speed-negative cases (>1.02): 11/12.

The frozen conductivity table therefore makes the actual Richards solve about 3% slower on this matrix despite a several-fold faster isolated K microkernel.

## Interpretation

The isolated K and K+dK/dh arithmetic is not the limiting accepted-solve cost in this implementation.

The result rules out the inference that a fast conductivity microkernel automatically yields a faster Richards solve. Provider dispatch, lookup/index arithmetic, the remaining theta/C work and the rest of the solve dominate enough that the K-table saving does not survive end-to-end solver execution.

This is a useful negative result rather than a failed physical candidate.

## Gate decision

The preregistered P1 performance objective fails.

Therefore HYDTABLE01 does not proceed to:

- P2 combined practical stack;
- P3 live SWAP + MODFLOW6 qualification;
- production admission.

The P0 accuracy and holdout evidence are retained as characterization evidence, but no production implementation is authorized.
