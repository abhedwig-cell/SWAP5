# F-TB01 — Execution Profiles

Profiles select cost/frequency; they do not redefine physics, oracle truth or hard conservation.

## FAST

Purpose: rapid source-mutation/PR feedback in seconds to minutes. Select small, high-value deterministic cases across primitives, invariants, transaction semantics and representative physics. FAST may omit expensive cases but may not weaken checks for cases it does run.

## CANONICAL

Purpose: moving-current preservation and broad regression for canonical admission. It exercises the registered preservation matrix for admitted capabilities and validates source/evidence/governance bindings. Historical-only evidence is not silently reclassified as current preservation.

## RELEASE

Purpose: full mandatory release-candidate qualification. It includes the compact TB-L12 release matrix plus all cases marked `RELEASE_MANDATORY` for the release scope. Reports exact source SHA/tree, compiler/platform and actual executed counts.

## DEEP

Purpose: long-horizon/high-cost qualification and research. Includes large parameter matrices, refinement studies, 100k+ MultiSWAP scale where infrastructure permits, alternative-solver comparison, difficult-column tail analysis, adversarial/property search and performance characterization.

Nightly/weekly schedules may later select DEEP subsets; schedule names are not scientific maturity levels.

## Profile invariants

- hard water-mass requirements are identical across profiles for the same case;
- a profile never changes physical options to make a test cheaper without thereby selecting a different case/version;
- reference/balanced/throughput are numerical policies, not physical configurations;
- skipped unsupported scope is reported as such and not counted PASS;
- required unavailable diagnostics/certificates fail closed;
- a timeout is a distinct result, not silently converted into PASS or scientific FAIL.

## Performance protocol

Performance cases record:

- warm-up policy;
- repeat count;
- median and selected percentiles rather than a single lucky run;
- hardware/OS/compiler/build flags;
- OpenMP/worker configuration;
- noise/isolation class;
- peak memory and, where meaningful, bytes/logical-column;
- timeout/bounded-cost policy;
- accepted steps, nonlinear iterations, solves, factorisations/backsolves, retries/fallbacks, constitutive evaluations and allocations when available.

Correctness is evaluated separately. Faster execution with altered physics, nondeterministic scientific output outside policy, failed transaction semantics or failed mass conservation is not a performance success.

## Difficult-column bank

At minimum the catalog roadmap reserves explicit profiles for heavy clay/B12, coarse sand/O5, O13, near-saturation and dry↔wet transitions. These cases characterize tail latency, retries/fallback selection, bounded-cost behaviour and deviation from Full Richards reference without allowing a few pathological columns to hide batch-scale costs.