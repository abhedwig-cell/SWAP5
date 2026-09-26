# F-PE-PROFILE05 fixed-build repeatability result

Date: 2026-09-26

Status: `FAILED_FIXED_BINARY_REPEATABILITY`

## Protocol

One exact binary and one A2C binary were compiled once from the same PROFILE05 production source postimage.

Without rebuilding, each binary was executed in 20 fresh live SWAP + MODFLOW6 Python processes, alternating exact and A2C by cycle.

No production source or numerical settings changed between cycles.

## Result

Exact:

- PASS: 12/20;
- FAIL: 8/20.

A2C:

- PASS: 16/20;
- FAIL: 4/20.

Every observed failed process terminated at the first SWAP corrector trial with participant status:

`6 (TRIAL_FAILED)`.

Failures occurred in both arms.

Examples include:

- A2C failures in cycles 1, 4, 12 and 18;
- exact failures in cycles 5, 6, 10, 11, 14, 17, 18 and 19.

Cycle 18 failed in both exact and A2C.

## Interpretation

This falsifies the hypothesis that the mixed PROFILE05 failures are explained only by independently rebuilt CI jobs.

A single fixed compiled binary is not repeatable across fresh processes.

It also falsifies attribution of the problem specifically to A2C:

- the exact production route failed 8/20;
- A2C failed 4/20;
- both use the same failure class.

The successful exact/A2C attribution set and the earlier successful qualification runs are therefore compatible with a latent runtime-state or undefined-state sensitivity that is sampled differently between processes.

The exact failure fraction observed here must not be interpreted as a production failure probability. This is a small synthetic live-coupling fixture. It is sufficient, however, to show that the fixture/runtime path is nondeterministic and cannot currently serve as timing authority.

## Performance consequence

Coupled-loop timing from this FGC44 live fixture is not admissible as PROFILE05 end-to-end performance evidence until the status-6 nondeterminism is explained.

Local/application-shaped evidence remains usable where those runners are deterministic:

- A2C application sequence remains speed-positive with preserved mass accounting;
- repeated Reference/directional decomposition remains measurable;
- A1 and A2C coupled timing values from successful runs are descriptive only, not admission-quality performance authority.

## Decision

Stop PROFILE05 coupled stack timing.

Do not tune A1 or A2C in response to this result.

The next workunit must isolate the exact-route status-6 nondeterminism before any A1+A2C end-to-end stack claim is made.
