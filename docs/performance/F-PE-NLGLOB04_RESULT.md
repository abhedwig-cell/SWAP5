# F-PE-NLGLOB04 result — residual-term cancellation and storage representation floor

Date: 2026-09-29

Status:

`NLGLOB04_STORAGE_REPRESENTATION_FLOOR_SIGNAL`

Canonical base:

`integration/f-ci-canonical@a409df7572018969f0e73a05696c402edd2363c2`

Qualification authority:

- workflow run: `36539684028`;
- job: `109311861278`;
- conclusion: SUCCESS.

## Coverage

PASS.

- audited failing Newton iterations: 768;
- primary poor-model near-floor iterations: 333;
- adequate-model iterations: 433;
- term decomposition coverage: 100%;
- residual reconstruction coverage: 100%;
- finite diagnostics: 100%;
- process failures: 0.

## Local residual summation

No local term-summation signal exists.

- primary records with >=25% change under `math.fsum`: 0%;
- primary records with >=10% change: 0%;
- crossings from naive local residual ratio >1 to compensated <=1: 0%;
- summation-direction route-mode families: 0/6.

Thus neither final-vector summation nor local-term summation explains the floor.

## Storage representation result

The storage representation signal passes all frozen gates.

Primary fraction with:

`r_storage_ulp <= 10`

is:

`1.0`

Adequate-model fraction:

`0.35797`

Median primary:

`r_storage_ulp = 0.47992`

All six route-mode families satisfy the preregistered storage-floor direction:

- FLUX / KLAG: primary 1.0, adequate about 0.339;
- FLUX / TG: primary 1.0, adequate about 0.317;
- HEAD / KLAG: primary 1.0, adequate about 0.355;
- HEAD / TG: primary 1.0, adequate about 0.355;
- RUNOFF / KLAG: primary 1.0, adequate about 0.410;
- RUNOFF / TG: primary 1.0, adequate about 0.355.

Frozen classification:

`NLGLOB04_STORAGE_REPRESENTATION_FLOOR_SIGNAL`.

## Cancellation structure

Median local residual cancellation condition number in the primary subset:

approximately `3.81e11`.

The dominant residual is therefore commonly the small difference of terms many orders of magnitude larger.

However, compensated summation of those already formed terms does not reduce the residual.

The limiting precision is introduced before local summation, consistent with finite representation of constitutive/storage state differences.

## Interpretation

NLGLOB04 directly links the TIMEINT17 endpoint stagnation to the representational scale of the storage increment `theta - thetam1`.

This is consistent with the earlier BALTOL01/BALTOL02 authority:

- the effective balance-rate floor scales with timestep;
- the equivalent integrated-depth floor is approximately fixed;
- theta-state representation is a dominant limiting mechanism.

NLGLOB04 does not discover a new reason to loosen that floor.

Instead, it shows that the current nonlinear convergence contract can continue demanding residual improvement after the dominant residual has reached the already qualified storage-representation limit.

## What this does not authorize

This result does not authorize:

- changing the BALTOL02 coefficient;
- weakening physical interval mass closure;
- accepting every state within 10 storage ULP rates;
- ignoring head or ponding convergence;
- increasing MAXIT or MaxBackTr;
- changing dt or K staging;
- changing dynamic-top physics or route semantics.

## Consequence

A separately preregistered floor-aware convergence-certificate workunit is now justified.

The certificate must use the already qualified BALTOL02 authority and independent physical/state checks.

It must demonstrate that it accepts only numerically exhausted near-floor states that are otherwise physically resolved.

A negative control population must be included to prove that unresolved states are not newly accepted.

## Production boundary

Research diagnostics only.

No production `src/**` change.

No numerical default change.

`LEGACY_NUMERICS` remains production default.
