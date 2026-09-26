# F-PE-PROFILE05 A2C reproducibility result

Date: 2026-09-26

Status: `REPRODUCIBILITY_FAILED`

## Protocol

Six independent replicas of the existing live SWAP + MODFLOW6 A2C gate were run with:

- unchanged production source;
- `APPROX02_CANDIDATE_TOL=1E-08`;
- the same pinned xmipy/flopy dependencies as the successful APPROX02 production qualification.

The preregistered rule required 6/6 success.

## Result

Replica outcomes:

- replica 1: PASS;
- replica 2: FAIL, `SWAP corrector trial failed: 6`;
- replica 3: PASS;
- replica 4: FAIL, `SWAP corrector trial failed: 6`;
- replica 5: PASS;
- replica 6: PASS.

Therefore:

- success: 4/6;
- candidate-only trial failures: 2/6;
- reproducibility gate: FAIL.

Successful replicas retained exact coupled endpoint identity:

- final MODFLOW head;
- final SWAP groundwater exchange;
- cumulative accepted interface ledger exchange;
- coupled iteration count.

Observed successful coupled-loop speedups were variable, including approximately:

- +2.95%;
- +10.59%;
- -2.95%;
- +11.43%.

These timings are secondary because the robustness gate failed.

## Source reconciliation

There are no `src/**` changes between the successful APPROX02 qualification source head

`5525971b20c07fad87e536aa45fa245eff1c84ff`

and the PROFILE05 source postimage under test.

Therefore the new failures cannot be attributed to intervening production-code changes.

## Interpretation

A2C at `1e-8` is not reproducibly coupled-robust under the existing live FGC44 gate.

The earlier 3/3 success was insufficient to establish a stable production envelope.

The failure mode is discontinuous:

- some nominally identical runs complete with exact endpoint identity;
- others fail at the SWAP corrector trial with participant status 6.

This must be understood before A2C can be treated as part of a combined practical production stack.

## Decision

PROFILE05 must not make an A1+A2C production-stack speedup claim.

For current practical-stack rebaseline purposes:

- A1 remains admissible for measurement;
- A2C is treated as `QUALIFICATION_UNRESOLVED`;
- exact behavior remains authority.

A separate workunit is required to explain the nondeterministic A2C trial-failure boundary.
