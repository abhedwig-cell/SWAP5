# ROM-PURPOSE P1 Reference qualification closeout

## Decision

**P1_REFERENCE_NOT_QUALIFIED_STOP_BEFORE_CANDIDATES**

Candidate response authorized: **false**.

R512_T32 and R1024_T32 were executed as complete independent histories. R2048 routes were recovered through exact physical-state checkpoint segments only after checkpoint/restart hydrological identity was qualified. The hosted-runner exit-143 failures are infrastructure failures, not scientific failures.

## Qualified scope

| Purpose | Material | Reference gate | Max transaction mass residual (cm) |
| --- | --- | --- | ---: |
| gw | B01 | PASS | 4.334e-13 |
| gw | B14 | PASS | 3.766e-13 |
| surface | B01 | FAIL | 4.263e-13 |
| surface | B14 | FAIL | 1.421e-13 |

R2048_T32 remains a numerical Reference with preregistered three-level space/time uncertainty. Numerical uncertainty is not an application tolerance.

## Firewall

No S4, G4 or U4 response was generated before this gate. No production solver, physics, RossFast or production coupling code changed. No performance or production-ROM claim follows.

## Next step

Stop before candidate response. Any new Reference design requires new prospective authority.
