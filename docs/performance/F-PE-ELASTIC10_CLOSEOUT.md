# F-PE-ELASTIC10 — BRO BHR-GT mechanical target acquisition closeout

Date: 2026-09-29

Status: QUALIFIED_RESEARCH_CLOSURE

Branch:
`research/f-pe-elastic10-bhrgt-targets`

Purpose:
acquire direct Dutch mechanical evidence that can constrain physical SWAP ELAS
without fitting ELAS to solver performance and without inferring it from MvG
hydraulic parameters.

## Result

F-PE-ELASTIC10 is closed as a mechanical-target acquisition and source-binding
work unit.

The research line has established all of the following:

1. the official BHR-GT public service contract is machine-bound;
2. current public BHR-GT objects contain explicit settlement/compression
   load/unload semantics;
3. source-bound stress-strain series can be parsed without guessed tuple order;
4. unload and reload mechanical branches can be converted to skeleton specific
   storage using the preregistered mechanical relation;
5. a frozen Dutch calibration corpus exists with holdout preservation;
6. source-bound descriptor coverage is characterized before model selection;
7. no solver-performance quantity enters the physical target.

## Evidence chain

### Phase A: service and schema authority

Run:
`36538415609`.

Outcome:
official BHR-GT v2 service and settlement semantics bound.

### Phase B: bounded object pilot

Run:
`36538921262`.

Outcome:
explicit load/unload and rate-controlled stress-strain target path confirmed.

### Phase C: mechanical target extraction

Run:
`36539688169`.

Outcome:
- 8 valid unload branches;
- 8 valid reload branches;
- no sign-inconsistent branches.

Pilot skeleton-specific-storage range:

`3.0082e-7 .. 8.9413e-5 cm^-1`.

### Phase D: frozen calibration corpus

Run:
`36540905498`.

Outcome:
- 692-object search population frozen;
- 36 calibration objects fetched;
- 18 holdout objects frozen and unopened;
- 82 settlement determinations;
- 169 valid mechanical targets;
- 77 unload targets;
- 92 reload targets;
- 35 / 36 calibration objects yield at least one valid target.

Unload skeleton specific storage:
- minimum `4.7061e-7 cm^-1`;
- median `7.1720e-6 cm^-1`;
- maximum `7.3740e-5 cm^-1`.

Reload skeleton specific storage:
- minimum `6.6654e-8 cm^-1`;
- median `2.0067e-5 cm^-1`;
- maximum `1.3639e-3 cm^-1`.

Unload and reload remain separate target families.

### Phase D2: source-bound descriptor audit

Run:
`36543951520`.

Evidence artifact:
`11021327530`.

Outcome:
- frozen Phase-D artifact only;
- zero holdout XML;
- zero holdout fetches;
- target-bound volumetric mass density: 169 / 169 valid targets;
- target-bound water content: 169 / 169;
- target-bound solids density: 75 / 169;
- target-bound dry density: 0 / 169.

The preregistered dry-density and dry-density-plus-solids gates fail.

No categorical descriptor passes its preregistered model-eligibility gate.

## Physical interpretation

The mechanical evidence rejects a universal interpretation of
`ELAS = 1e-6 cm^-1`.

That value remains physically plausible:
it lies inside the observed unload calibration range and near its stiffer lower
tail.

The calibration median is materially larger, and the corpus spans more than two
orders of magnitude when unload and reload behavior are considered.

The evidence also confirms that ELAS cannot safely be treated as a function of
MvG shape alone.

The target depends on mechanical state and test path. Depth, stress range,
determination method and unload/reload identity therefore remain explicit
provenance variables.

## Source-variable conclusion

The directly source-bound variables currently broad enough for later predictor
research are:

- volumetric mass density;
- water content;
- solids density on a substantial subset;
- target depth;
- branch stress change;
- determination method;
- branch identity.

The current corpus does not support a target-bound dry-density shortcut.

Borehole-log descriptors may exist object-wide but require a separately
preregistered depth-linkage rule before they can be attached to settlement
targets.

## What is qualified

Qualified research claim:

`BRO BHR-GT can provide direct, source-bound Dutch mechanical specific-storage
targets suitable for physical ELAS parameter research.`

Qualified bounded data authority:
- exact 36-object calibration set;
- exact 18-object unopened holdout set;
- exact mechanical target extraction semantics;
- exact source-bound descriptor inventory.

## What is not qualified

F-PE-ELASTIC10 does not establish:
- a national Dutch ELAS distribution;
- a BOFEK/Staringreeks mapping;
- a pedotransfer function;
- a default ELAS;
- a stress-independent material constant;
- a parser keyword or production input contract;
- a production activation rule;
- any solver-performance-tuned physical parameter.

## Separation from production

The production chain is already admitted separately:

`elasticity_active + cofgen(24,:)`
-> ELASTIC08 materialization
-> ELASTIC05 constitutive ELAS
-> ELASTIC09 production application bootstrap.

F-PE-ELASTIC10 changes no production code and does not alter that chain.

## Next scientific work

Any predictor/model-selection phase must start with a new preregistration.

It must:
- keep the 18 holdout objects unopened until the model family and scoring rule
  are frozen;
- preserve unload as the primary small-strain/recompression target family;
- treat reload separately unless a mechanical justification is preregistered;
- forbid MvG or solver-performance fitting as target construction;
- freeze any stress normalization or derived variable before seeing holdout
  performance;
- explicitly define how a predictor maps from available field/soil information
  to the per-layer SWAP ELAS parameter.

A natural successor is a separate Phase-E/F-PE-ELASTIC11 predictor
preregistration rather than widening F-PE-ELASTIC10 after closure.

## Closure

F-PE-ELASTIC10 has reached qualified research closure for target acquisition.

There is no remaining target-acquisition blocker.
