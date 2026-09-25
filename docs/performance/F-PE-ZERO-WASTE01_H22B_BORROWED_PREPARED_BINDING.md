# F-PE-ZERO-WASTE01 H22B — borrowed immutable prepared-hydraulics binding

Date: 2026-09-25

Status: `CANDIDATE_PENDING_QUALIFICATION`

## Prerequisite

H22B builds only on the qualified H22A immutable-owner contract.

At the authority head before this candidate:

- H21 parameter configuration reuse passed;
- H22A trusted parameter identity passed;
- H22A groundwater paired diagnosis passed;
- production bootstrap passed;
- paired runtime, poisoned workspace and compute-core gates passed.

## Observation

H22A removes the full raw/prepared compatibility scan for an explicitly trusted immutable parameter owner, but the backend still copies the complete prepared 42 x N MvG representation into backend-owned storage on every trial.

Shared-runner measurements showed prepared-copy cost increasing with node count, for example roughly:

- N=60: 0.9 microseconds/call;
- N=200: 3.0 microseconds/call;
- N=1000: 15 microseconds/call.

Exact timings are not portable claims. The repeated O(N) copy is the structural evidence.

## H22B contract

Generic callers retain backend-owned hydraulic storage and exact H22A/H21 refresh semantics.

For an explicitly trusted immutable owner only:

1. `run_trial` temporarily retains a pointer to the trusted typed parameter object;
2. `configure_parameters` may select the already prepared `prepared_default_mvg` object as the active read-only hydraulic source;
3. backend-owned hydraulic storage remains separate and is never reused as a borrowed pointer;
4. the constitutive provider binds to the active hydraulic source only during the kernel trial;
5. immediately after the kernel trial returns, the provider pointer, active hydraulic pointer and trusted parameter pointer are all cleared;
6. no borrowed pointer survives `run_trial`;
7. untrusted/reference-floor routes keep owned-copy or fresh-preprocess semantics unchanged.

No geometry borrowing is included in H22B.

## Failure and invalidation

Trusted borrowing is admitted only when:

- the H22A immutable-owner trust flag is explicitly supplied;
- the prepared representation is structurally compatible;
- node count and prepared shape agree;
- KSATEXM extension identity agrees.

Otherwise the backend falls back to the generic owned path.

## Qualification

Required evidence:

- existing H22A trusted/untrusted physical identity remains PASS;
- existing untrusted stale-cache fallback remains PASS;
- one backend executes trusted A -> trusted B -> trusted A with different prepared parameter sets;
- the two A trajectories are bit-identical in physical state and mass;
- solve counts remain identical;
- PPA-WU01 production owner gate PASS;
- FGC49D production context PASS;
- poison/capture/PROFILE01 and paired runtime remain authoritative;
- no physics, tolerance, transaction, accepted-state or provider formula change.

## Boundary

This candidate is P0 zero-waste only under the existing immutable-owner authority. It does not authorize borrowed parameter lifetime for generic callers.
