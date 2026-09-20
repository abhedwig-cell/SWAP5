# F-ROM code-frontier reconciliation: FMC and LARE

**Work unit:** F-ROM-CODEMAP-01  
**Canonical base:** `integration/f-ci-canonical@97afc3176395a8548daa686b89ca6fb2f2a4ea09`  
**LARE research head inspected:** `work/f-rom-lare-rs1@353a779543923c58ce4641260b960c0cd977d3d8`  
**Date:** 2026-09-20

## Purpose

This checkpoint separates the two active reduced-model research frontiers before further implementation work.

It does not choose a production ROM, does not merge the LARE research branch, and does not supersede canonical F-ROMV2 D28-D31 authority.

## Reconciliation result

The FMC/SMVE and LARE lines are physically and computationally distinct research families.

### FMC / F-ROMV2

The branch-local implementation has progressed through native rainfall plus groundwater composition, a compiled shared-host cost screen, and a one-day separated surface-front plus groundwater-front preflight.

Representative code identities:

- D24 Reference comparator and native rainfall-groundwater harness: `tests/rom/test_f_romv2_d24_native_rain_gw_comparators.f90`, blob `482965026d7589bfd5b8dedbe8949ebcb78a3030`, execution branch head `0d7abc3acc374dbe6192baaca471f545caa103c3`.
- D25 compiled FMC research kernel: `tests/rom/test_f_romv2_d25_fmc_compiled.f90`, blob `cd1d84f2186080c08ff06ba8c97d4132d05a61d7`, execution branch head `725945db0885094aef461eca2408f09b69fb7a01`.
- D29 one-day hydraulic preflight: `tests/rom/preflight_f_romv2_d29_one_day_hydraulic.py`, blob `68539dab29579190ff05ecc32cc6181f625dd2ee`, execution head `14b95943842b200b8d7d015814168ab6da7da838`.

The D25 research kernel explicitly evolves separate connected-surface and groundwater front arrays, routes surface storage/runoff, enforces water ledgers and requires positive surface-groundwater separation. D29 is the current executable boundary: the separated representation fails closed when those fronts make natural contact.

Canonical D30/D31 authority therefore remains unchanged. No within-step natural contact transition may be invented without an implementation oracle or equally authoritative unique specification. D28 separately blocks native composite-state root withdrawal / ET semantics.

**FMC frontier:** implementation-rich, but externally source-authority blocked for natural surface-groundwater contact and native ET state updates.

### LARE

LARE is not another tuning of the FMC state. It represents water state using layer-integrated storages and reconstructs interlayer hydraulic exchange through a LARE closure.

Representative code identities on the branch-local research line:

- DYN0A Python ODE kernel: `tests/rom/run_lare_dyn0a_ode.py`, blob `1b7c40f31bfe46ac17d5d5b91a1fdedaa55c64a0`.
- C4T compiled LARE kernel: `tests/rom/test_lare_bc2_c4t_lare_compiled.f90`, blob `97d7aca98326f6f1e91a8a1c9af537a5f0056419`.
- C4T compiled FMC control: `tests/rom/test_lare_bc2_c4t_fmc_compiled.f90`, blob `bbdab55b6a3511c5140ec0a077c443ea3fe4ef0a`.

The current LARE branch is deliberately not mergeable as a unit. It diverged from merge base `9bb73821bb78a04c759b763746b50a3f777cd416` and contains a large research history of execution workflows, kernels and evidence. Any canonical preservation must therefore be selective and evidence-only.

## Current LARE terminal evidence

C4R blind validation replicated a dimension-dependent fidelity frontier on the fixed-water-table B01 workload. On the groundwater-output vector, R4 was the minimum LARE dimension crossing both R2 and FMC. When mapped 10-cm profile fidelity against FMC was retained, R12 was required.

C4S then established a full same-partition CoRichards common cohort for R3, R4, R5, R6, R8 and R12 on that same fixed-water-table workload. This matters because the earlier fixed-flux Q1 result, in which reduced CoRichards was not numerically viable, cannot be generalized across boundary conditions.

C4T subsequently closed branch-locally with:

`C4T_LARE_PURPOSE_VALUE_SIGNAL_RESOLVED`

Immutable execution binding recorded by the LARE closeout:

- workflow run `35492342285`;
- execution head `4f938b040d92ee46646e3397278c78a46942944c`;
- artifact `10599940848`;
- artifact digest `sha256:99ebd356c44e965c5e2ab3b2ef2b45dc4d54c0bdfd3fd19bd9f61d384c72a833`;
- raw result SHA-256 `fc83b5229a0b3c0be3fcdfd93a30fe9d564144b32d70f97a4ce8aadc35dac7a6`;
- fidelity SHA-256 `044ce7897ee35f94812d86962c11b6a09da0688bbdd56edbf7b5fba6600c2b45`;
- timing SHA-256 `f525323dad0505bf09fb085e97e50e303314e902525a5e327a9f1295147cf0ff`;
- compiled-equivalence SHA-256 `03c44855fcb3e282695c66f3cc248b2b7041f259d14aa2cdcbd97e8be55605ea`.

On this particular B01 fixed-water-table workload, LARE R3-R8 occupy a resolved shared-host cost-fidelity frontier and are resolved cheaper than fine R16 under the preregistered C4T timing rule. This is a screening/value signal, not application acceptance. In particular, R3 frontier membership does not erase the C4R finding that R4 is the minimum member crossing R2 and FMC on the groundwater fidelity vector. Nondominance and application adequacy are different statements.

C4T also reports that FMC is more expensive than R16 in this C4T compiled workload. That does not supersede F-ROMV2 D25, because D25 and C4T use different workloads and implementation paths. No portable speedup claim follows from either result.

## C4U: the LARE line has reached a different external blocker

The branch-local C4U authority closes the immediate next groundwater application question as:

`GW_APPLICATION_ACCEPTANCE_NOT_ADJUDICABLE_FROM_CURRENT_REPOSITORY_AUTHORITY`

with status:

`BLOCKED_EXTERNAL_PROJECT_ACCURACY_EVIDENCE_REQUIRED`.

This is not a missing-code blocker. The existing coupling-accuracy contract can transport externally governed application accuracy authority, but no real project-specific numerical prediction-error requirement for groundwater head/drawdown and no independently governed temporal allocation are currently qualified.

Therefore C4U explicitly forbids selecting an application acceptance threshold from:

- observed C4R/C4T candidate errors;
- numerical Reference floors;
- solver tolerances;
- synthetic coupling fixtures;
- generic calibration/observation-fit criteria without explicit project prediction-error authority.

The next admissible LARE step is not another closure or timing optimization. It is to obtain an external project accuracy packet and then preregister a downstream-consequence GW-R and/or GW-D validation.

**LARE frontier:** relative state/fidelity/computational-value research is materially further than canonical project-control currently records, but real groundwater application acceptance is externally blocked on project accuracy authority.

## Live-canonical compatibility

The frozen C4T execution source is `e6c28770786a4cc7cb2ab6cf4b8e3f936c44b3f1`.

The terminal LARE reconciliation checked through live canonical `97afc3176395a8548daa686b89ca6fb2f2a4ea09` and records 43 later canonical commits with no `src/**` or `reference/**` changes. The later changes are F-ROMV2 evidence/governance plus project-control changes, so C4T re-execution is not required by source/reference drift.

This compatibility statement does not canonicalize the LARE branch. It only establishes that its frozen C4T scientific execution was not invalidated by intervening canonical source/reference mutation.

## Side-by-side code frontier

| Axis | FMC / F-ROMV2 | LARE |
|---|---|---|
| State representation | moisture bins with explicit surface and groundwater fronts | layer-integrated storage on fixed partitions |
| Main executable research language | Python + compiled Fortran research kernels | Python + compiled Fortran research kernels |
| Surface rainfall/runoff | implemented and qualified in bounded D24 route | not the current C4T workload |
| Groundwater front | explicit FMC groundwater-front dynamics | bottom-boundary exchange through layer closure |
| Natural surface-GW contact | blocked at D30/D31 for missing implementation oracle | not the active LARE state transition |
| Native ET/root uptake | accounting preflight passed, composite-state update blocked at D28 | not application-qualified |
| Long hydraulic horizon | D29 reaches contact after 2.575 h and fails closed before one day | C4T uses a separate fixed-WT 64-step workload |
| Fine Reference comparator | R16 | R16 |
| Coarse Richards comparator | R2 in F-ROMV2 | same-partition CoRichards R3-R12 plus R2 control |
| Relative fidelity status | positive research candidacy on bounded hydraulic cases | blind dimension-dependent frontier replicated |
| Relative computational-value status | D25 positive on its workload | C4T positive for R3-R8 on its workload |
| Application acceptance | not adjudicated | C4U blocked on external project accuracy authority |
| Production status | forbidden | forbidden |

## Consequence for repository routing

The single project-control label `F-ROM / LARE = BLOCKED_EXTERNAL` is directionally correct but too coarse for implementation planning.

It should be interpreted as two independent blockers:

1. **FMC source-semantics blocker:** materialize M2WC70 or equivalent authority for natural contact and native ET composite-state updates.
2. **LARE application-authority blocker:** source real project groundwater prediction-accuracy and temporal-allocation requirements before selecting a purpose-accepted LARE dimension.

Neither blocker authorizes production implementation.

## Decision

`FMC_AND_LARE_CODE_FRONTIERS_RECONCILED_DISTINCT_EXTERNAL_BLOCKERS`

This checkpoint authorizes no new physics and no code import. It establishes the correct next-work routing:

- do not spend further FMC implementation effort by inventing contact/ET semantics;
- do not merge the LARE research branch wholesale;
- preserve C4T/C4U LARE terminal evidence selectively through the normal evidence-admission path;
- obtain external project groundwater accuracy authority before application-level LARE selection;
- keep Reference Richards, RossFast and production coupling unchanged.
