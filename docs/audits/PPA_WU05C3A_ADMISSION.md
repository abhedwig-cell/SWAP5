# PPA-WU05-C3A production admission

Date: 2026-10-01

Status: `REPAIRED_FOCUSED_GATES_PASS / SHARED_APPLICATION_BINDING_AUTHORITY_REQUIRED`

Current 2026-10-02 repair authority: [C3A repair result](PPA_WU05C3A_REPAIR_RESULT.md).
The two executable defects were repaired; actual application binding and admission remain held.
The preceding falsification below is retained as historical evidence.

The 2026-10-02 executable admission-boundary gate supersedes the readiness decision below.
See [C3A boundary falsification](PPA_WU05C3A_BOUNDARY_FALSIFICATION.md).
C3Q/C3P qualification remains bounded evidence; production saturation/invalid-input handling fails.
The following original candidate description is a historical snapshot, not current admission authority.

## Scope

Production candidate for the Bartholomeus oxygen-stress route:
- legacy selection `SWOXYGEN=2 / SWOXYGENTYPE=1`;
- analytical MvG water-film route only;
- bounded MICRO/MACRO response solution;
- ordered vertical `C_top(node+1)=C_macro(node)`;
- oxygen as modifier of the existing root-water-uptake sink.

Explicitly excluded:
- SWSOPHY=1/tabular water-film compatibility;
- WFT300/practical lookup;
- other historical oxygen modes/types;
- changed Bartholomeus scientific parameters.

## Qualification chain

C3Q physical parity:
- exact corrected B1.11 oxygenstress authority;
- 1000 source-bound grassgrowth evaluations;
- MICRO max abs difference 4.43e-17;
- MACRO max abs difference 5.86e-09 kg/m3;
- respiration-factor max abs difference 2.48e-05;
- RWU-factor max abs difference 1.22e-05;
- all sampled response differences within legacy SOLVE accuracy 1e-4.

C3P ownership/composition:
- persisted composition gate PASS;
- existing drought/root sink evaluated first;
- oxygen only multiplies rooted-node extraction;
- oxygen does not own/book water.

C3A production architecture:
- fail-closed activation matrix;
- typed hydraulic + thermal runtime view;
- immutable parameter contract including hysteresis construction-key constraint;
- reference water-film provider;
- typed response assembly;
- ordered profile factor provider;
- production execution seam;
- oxygen-off direct preservation route;
- unsupported configurations rejected before sink modification.

## State ownership

No accepted-timestep Bartholomeus continuation state is admitted.

Call-local vertical oxygen concentration propagation is scratch only. Legacy solver globals such as
c_macro/c_min_micro are not migrated as physical state.

## Admission decision

The analytical-MvG Bartholomeus implementation is qualified as a production admission candidate.

Canonical merge requires:
1. current-canonical reconciliation of the research branch;
2. one final focused preservation/compile gate on the reconciled candidate;
3. admission merge and closeout persistence.

No further scientific redesign is required for this admission scope.
