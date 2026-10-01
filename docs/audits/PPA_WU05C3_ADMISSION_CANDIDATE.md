# PPA-WU05-C3 production admission candidate

Date: 2026-10-01

Status: `QUALIFIED_ADMISSION_CANDIDATE / CANONICAL_REBASE_REQUIRED`

## Admitted scope proposed

Bartholomeus oxygen stress:
- oxygen mode 2;
- oxygen type 1;
- analytical MvG water-film reference route;
- pure MICRO/MACRO response;
- bounded inner and outer scalar solves;
- ordered vertical `C_top(node+1)=C_macro(node)`;
- immutable-after-construction oxygen precompute with complete construction key;
- oxygen as modifier of the existing root-water-uptake sink.

Explicitly excluded:
- SWSOPHY=1/tabular water-film route;
- WFT300/practical lookup mode;
- changed scientific parameters;
- persistent OxygenState;
- exact legacy iteration-history reproduction.

## Evidence chain

C3Q source-bound physical parity:
- 1000 real grassgrowth evaluations;
- MICRO max abs difference 4.43e-17;
- MACRO max abs difference 5.86e-09 kg/m3;
- respiration factor max abs difference 2.48e-05;
- rwu factor max abs difference 1.22e-05;
- all sampled response differences within legacy outer SOLVE accuracy 1e-4.

Persisted C3Q kernel gate:
- PPA_WU05C3Q_KERNEL_SMOKE=PASS;
- MACRO zero-depth 27 checks PASS;
- scalar bracket PASS;
- root composition PASS.

Persisted C3P composition:
- workflow run 36919068192;
- PPA_WU05C3P_ROOT_OXYGEN_COMPOSITION=PASS.

Production architecture:
- fail-closed activation matrix;
- typed hydraulic/thermal runtime view;
- immutable soil/crop parameter contract;
- reference water-film provider;
- response assembly;
- ordered profile factor provider;
- existing root-sink composition;
- explicit oxygen-off preservation route.

Local gates are persisted as scripts and are intentionally not automatic Actions triggers:
- tests/fmr/run_c3a_bartholomeus_production_gate.sh
- tests/physics/run_bartholomeus_response_assembly.sh
- tests/physics/run_bartholomeus_waterfilm_provider.sh
- tests/physics/run_bartholomeus_active_chain.sh

## Governance finding before merge

The long-lived research branch has accumulated many concurrent repository changes and its PR base is
behind current canonical. It must not be merged wholesale.

Canonical admission therefore requires a fresh admission branch from current
`integration/f-ci-canonical` containing only the C3 oxygen slice plus its tests/evidence.
This is an integration hygiene requirement, not a physics blocker.

## Decision

`READY_FOR_SCOPED_CANONICAL_RECOMPOSITION`
