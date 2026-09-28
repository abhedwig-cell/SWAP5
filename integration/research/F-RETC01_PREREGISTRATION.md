# F-RETC01 — historical RETC reconstruction preregistration

Status: PREREGISTERED, evidence acquisition pending  
Authority at preregistration: `integration/f-ci-canonical@1759caebb7ca3bd62bbee65d9319f5d71d3e73f5`  
Scope: research/reconstruction only; no production-code change is authorized by this document.

## Research question

Can the RETC behaviour relevant to historical SWAP soil-hydraulic parameter estimation be reconstructed from primary or otherwise traceable evidence closely enough to reproduce known parameter-estimation cases, without importing undocumented assumptions from textbook Mualem–Van Genuchten formulations?

## Motivation

SWAP5 already has qualified executable authority for substantial parts of the soil-hydraulic constitutive route, including exact B1.10 internal `cofgen` aliases and qualified `theta(h)`, `C(h)` and `K(h,theta)` behaviour for bounded model families. What is not yet repository authority is how historical RETC transformed observations, choices, constraints, weights and initial values into fitted parameter sets.

The reconstruction therefore targets the inverse-estimation procedure, not a replacement constitutive model.

## Separation of claims

F-RETC01 has three deliberately separate layers.

1. **Historical reconstruction.** Recover what RETC actually accepted, computed and reported.
2. **Executable reproduction.** Reproduce selected historical cases from pinned inputs and expected outputs.
3. **Modern extensions.** Alternative optimizers, uncertainty/identifiability analysis, physically coherent parameter ensembles and SWAP-solver-aware selection are out of scope until layers 1 and 2 close.

A modern method that produces a plausible or better fit is not evidence of RETC equivalence.

## Evidence hierarchy

Evidence will be classified before implementation:

- E0: exact RETC source code, if legally and technically available;
- E1: official RETC executable plus pinned input/output cases;
- E2: official RETC manual/documentation defining equations, options, transformations, objective functions or constraints;
- E3: peer-reviewed publication by the RETC authors that binds a specific algorithmic detail;
- E4: historical SWAP/Staring-series artefact with traceable RETC provenance;
- E5: secondary description or conventional textbook formulation.

E5 may generate hypotheses but cannot establish historical equivalence.

## Required reconstruction inventory

Before coding a fitter, record evidence for:

- RETC version(s) and provenance;
- supported retention and conductivity model families;
- exact parameterization and parameter transformations;
- relation between `m` and `n`, including fixed versus fitted modes;
- residual and saturated water-content treatment;
- saturated conductivity and pore-connectivity/tortuosity treatment;
- objective function(s);
- residual scale: linear, logarithmic or transformed;
- weighting of retention versus conductivity observations;
- weighting within each observation family;
- handling of zero/invalid conductivity values;
- parameter bounds and fixed parameters;
- initial-value rules;
- optimization algorithm and stopping rules;
- multiple-start or restart behaviour, if any;
- treatment of units and pressure-head sign;
- output precision and reported goodness-of-fit diagnostics.

Unknown fields remain explicitly unknown.

## Falsification criteria

Historical equivalence is rejected or left unresolved if any of the following holds:

- required algorithmic choices cannot be bound above E5;
- two evidence-compatible reconstructions produce materially different fitted parameters and no evidence adjudicates them;
- a pinned RETC case cannot be reproduced within a preregistered numerical tolerance after input/output precision is accounted for;
- agreement requires changing the constitutive equations away from the evidenced RETC model;
- agreement is obtained only by case-specific tuning not documented by evidence.

Negative results are retained.

## First executable gate

No general optimizer is admitted as a RETC reconstruction until at least one case has:

1. immutable input observations;
2. a provenance record for the RETC version;
3. RETC-produced expected parameters/output;
4. explicit model/options;
5. an independently implemented forward constitutive evaluator;
6. a declared comparison tolerance justified from RETC output precision.

A second, structurally different case is required before calling the reconstruction general for that model family.

## Relation to current SWAP5 authority

The reconstruction must not silently equate textbook Mualem–Van Genuchten symbols with every historical SWAP `cofgen` row. Existing repository provenance explicitly distinguishes internal aliases, model-dependent activation and unresolved user-facing parser/unit mappings.

Where a RETC parameter set is mapped into SWAP, that mapping is a separate evidence object and must identify the SWAP hydraulic model family and units.

## Deferred hypotheses

These are useful but are not part of the historical-equivalence gate:

- H-MOD1: modern bounded least-squares can reproduce RETC fits while improving robustness;
- H-ID1: profile likelihood/bootstrap/Bayesian diagnostics expose practically non-identifiable parameter combinations hidden by a single optimum;
- H-ENS1: coherent parameter ensembles are preferable to independent one-at-a-time parameter perturbations for sensitivity analysis;
- H-SOL1: among statistically near-equivalent fits, constitutive shape can materially alter Richards solver effort;
- H-SOL2: a later multi-objective selection can trade negligible fit degradation for improved SWAP numerical robustness.

Testing these hypotheses requires a separate preregistration after historical reconstruction.

## Immediate work order

1. acquire and pin primary RETC evidence;
2. build an evidence matrix without filling gaps by convention;
3. select at least two reproducible historical cases;
4. implement only the forward equations needed by those cases;
5. reconstruct the objective and optimization semantics;
6. run blind reproduction against pinned outputs;
7. classify findings as reproduced, bounded-equivalent, unresolved or falsified;
8. only then design a modern RETC-successor layer.
