# F-PE-PROFILE05 A2C reproducibility result

Date: 2026-09-26

Status: `MIXED_REPRODUCIBILITY_FAILURE_ATTRIBUTION_PENDING`

## Protocol

Six independent replicas of the inherited live SWAP + MODFLOW6 exact-vs-A2C runner were executed with:

- unchanged production source;
- `APPROX02_CANDIDATE_TOL=1E-08`;
- the same pinned xmipy/flopy dependencies as the successful APPROX02 production qualification.

The run-level outcomes were:

- 4 jobs completed;
- 2 jobs terminated with `SWAP corrector trial failed: 6`.

## Critical attribution limitation

The inherited APPROX02 runner executes the exact arm first and A2C second, but exits on the first Python failure.

Therefore the two failed jobs do **not** by themselves prove that A2C was the failing arm.

The mixed 4/6 result establishes a reproducibility problem in the exact-vs-A2C live coupled comparison, but its ownership is not yet known.

## Successful-job evidence

The four completed jobs showed exact coupled endpoint identity between exact and A2C:

- final MODFLOW head;
- final SWAP groundwater exchange;
- cumulative accepted interface ledger exchange;
- coupled iteration count.

Successful-job timing was variable, including speed-positive and one slightly speed-negative result. Timing is secondary until failure ownership is resolved.

## Source reconciliation

There are no `src/**` changes between the successful APPROX02 qualification source head:

`5525971b20c07fad87e536aa45fa245eff1c84ff`

and the PROFILE05 source postimage under test.

The mixed result therefore cannot be explained by intervening production-source changes.

## Next required evidence

Use the preregistered failure-arm attribution runner:

`tests/fpe/run_fpe_profile05_a2c_failure_attribution.sh`

It executes exact and A2C independently within each replica and reports:

- `EXACT=PASS/FAIL`;
- `A2C=PASS/FAIL`;
- status-6 provenance when present.

Do not classify A2C as qualification-unresolved until this attribution exists.

## Interim decision

PROFILE05 must not make an A1+A2C combined production-stack claim while the coupled reproducibility issue is unresolved.

A1 remains independently qualified.

Exact production behavior remains authority.
