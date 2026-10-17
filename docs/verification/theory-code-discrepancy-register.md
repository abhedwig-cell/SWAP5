# Theory-documentation-code-evidence discrepancy register

## Purpose

This register records material differences or unresolved questions among SWAP theory, formal/user documentation, corrected legacy behaviour, SWAP5 implementation and executable evidence.

A discrepancy is not automatically a code defect. It remains open until evidence supports a bounded classification and resolution.

Governing policy: [Quality governance after Status A](../development/quality-governance-a-aa.md).

## Status vocabulary

Use one of:

- `NOT_ASSESSED`
- `INVESTIGATING`
- `DOCUMENTATION_ERROR`
- `LEGACY_CODE_DEFECT`
- `INTENTIONAL_LEGACY_DIFFERENCE`
- `ACCEPTED_SWAP5_DIFFERENCE`
- `AUTHORITY_BINDING_DEFECT`
- `IMPLEMENTATION_DEFECT`
- `UNRESOLVED_SCIENTIFIC_AUTHORITY`
- `BLOCKED_EXTERNAL_AUTHORITY`
- `RESOLVED`

A causal classification must point to evidence.

## Entry template

```text
ID:
PROCESS / COMPONENT:
THEORY / FORMAL AUTHORITY:
DOCUMENTED BEHAVIOUR:
CORRECTED LEGACY BEHAVIOUR:
CURRENT SWAP5 BEHAVIOUR:
EXECUTABLE EVIDENCE:
AFFECTED SOURCE / INTERFACE:
SCIENTIFIC / NUMERICAL IMPACT:
CLASSIFICATION / STATUS:
CANONICAL AUTHORITY:
CANDIDATE SUCCESSOR:
DECISION:
NEXT ACTION:
```

## Open register

| ID | Process / component | Difference | Status | Authority / next action |
| --- | --- | --- | --- | --- |
| TCD-SWAP5-001 | SWAP5-MODFLOW6 lower coupling authority | Application-level coupled-groundwater authority has historically been bound to a production profile requiring `bottom_mode=5`, while the coupling-semantics audit identifies `SWBOTB=5` as prescribed lower-boundary pressure-head realization rather than the groundwater-storage/application authority itself. | INVESTIGATING | Canonical remains unchanged. PR #486 is the noncanonical repair candidate. Qualify CSR-01/02 and reconcile preservation/publication consequences before any admission. |
| TCD-SOL-FREUNDLICH-INVERSE | Nonlinear phase equilibrium | Historical inverse stopping and near-unity shortcut approximate phase storage at carried cmsy. This does not establish a global historical mass-loss defect. | ACCEPTED_SWAP5_DIFFERENCE; bounded scope admitted | [Bounded nonlinear matrix successor](../science/MC_SOL01_NONLINEAR_MATRIX_CONTRACT.md). PR1230 atd6e21f02 admits the unchanged inverse at explicit SWAP5 precision for0.5..2, refining the provisional defect label. Independent quad/analytic/source witnesses, actual changing-water joint/restart O0/O2, full moving1829.803s and exact mineral1231 coexistence PASS. No new immutable B1 snapshot or whole source-domain closure. |
| TCD-FROST-DIVDRA-03 | Separate infiltration within one compartment | Native DIVDRA overwrites the correctly computed infiltration-bottom thickness before its overlap formula. Original and B17 each fail 728/9216 multilevel cases at O0/O2; an actual single-level case also divides by zero. | LEGACY_CODE_DEFECT | [B20 adjudication](../audits/PPA_WU05B20_MULTILEVEL_REFERENCE_ADJUDICATION.md). Exact isolated reference candidate eliminates native failures and preserves 8293 unaffected controls plus complete 4536 B17 inputs. Independent 80/100-digit geometry qualifies all 9216 cases and resolves the historical 645 double-comparator screens without tolerance change. Canonical reference admission remains separate. |
| TCD-FROST-MULTILEVEL-TRANSFER | Low-air signed multilevel flux transfer | Near-zero surviving signed totals can change net proposal or amplify opposite rates under native B1.11. This is not established as a legacy implementation defect. | OWNER_APPROVED_SWAP5_POLICY_BOUNDED_ADMISSION | Explicit owner acceptance authorizes NET01 absolute-rate transfer. PR #1275 canonically admits the qualified two/three-level production route with source, hard-mass, rollback, restart and isolation evidence. [Current production authority](../audits/FROST_NET01_PRODUCTION_20261017.md). Wider frost envelopes remain separate; immutable B20 experiment and original B1 are unchanged. |
| TCD-FSI35-HEADED-DERIVATIVE | Legacy non-M1 dynamic-top headed replay | Original producer/consumer mismatch reproduced at O0/O2. Later PR #1202 supplies actual trial-start fixed conductivity through the existing non-M1 SWKIMPL=0 Task2 binding; M1 remains unchanged. | RESOLVED | Bounded canonical repair `d8b2640890203c3444f3d65b8918e31b52cdf74f`, `integration/f-ci/F-CI93_STATUS.json#non_m1_fixed_k_repair_20261011`. Current `e35ea0c6` retains all27 exact native compile dependencies and the admitted Task2 blob; qualification archive and all six raw log hashes verified. Original diagnosis `85866972` remains negative historical evidence. Resolution does not admit untested headed configurations or change the original surface fixture. |

## TCD-SWAP5-001 decision boundary

The current discrepancy record does **not** decide that the whole SWAP-MODFLOW6 coupling architecture is defective.

The candidate evidence currently distinguishes:

- MODFLOW6 ownership of groundwater state/storage;
- SWAP ownership of unsaturated-zone/process state;
- interface head/flux continuity as coupling conditions;
- a temporary lower-face pressure head as a possible Reference-backend trial realization;
- application-level coupling authority as distinct from a legacy standalone boundary selector.

Until the candidate is qualified and admitted, current canonical implementation remains the executable authority. Publication claims affected by the interpretation remain subject to their own reconciliation.

## MC-IRR01 source and execution reconciliation (2026-10-11)

- `TCD-IRR-AVAIL-SSDI`, `IMPLEMENTATION_DEFECT`: the former generic availability helper scaled SSDI rate and positive-rate duration. Literal B1.11 TASK4 scales `gird` and positive-rate duration but leaves `qssdi` unchanged. PR #1198 corrects the SSDI route and preserves surface behaviour. Twelve literal extracted-source cases pass at O0/O2. Zero-rate fallback remains unchanged by TASK4. This is a source binding correction, not a new allocation policy.
- `TCD-IRR-SSDI-NODES`, `INVESTIGATING`: scheduled B1.11 writes the full scheduled source to every selected node. PR #1198 implements that exact spatial mapping and sums actual nodal sources for external mass. A three-node process witness passes. This does not establish total-profile depth normalisation or qualify a multi-node physical trajectory.
- `TCD-IRR-FKT-FORCING-HISTORY`, `INVESTIGATING`: a non-cancelling 0.48 cm/day irrigation onset converged Richards mass but exhausted the existing temporal-controller limits. Twelve physical management cases pass only for a 4.8e-8 cm initial impulse with forcing-consistent derivative history. The F-KT owner must qualify the history policy at event onset/end with existing committed history before unrestricted irrigation coverage. No temporal threshold, hydraulic interface or solver was changed.

Exact source hash, runners, tested envelope, rejected envelope and all sixteen capability dispositions are in `integration/audits/MC_IRR01_CLOSURE_PLAN_20261011.json`. Full MC-IRR01 coverage remains open; PR #1195's five bounded admissions are retained.

## EB-I25 accepted outflow fixture (2026-10-11)

`TCD-EBI25-ACCEPTED-OUTFLOW`, `INVESTIGATING`: fresh explicit-worktree runs of `tests/fkt/run_fkt22_eb_i25_preservation_gate.sh` on untouched canonical `3cc40d599970ef3f85f4dc29c4ef0b09874d92b1` and thermal candidate `f177b589516e7c775bf884b6f2e39e154f5e0fba` both exit 1 at O0. Both first pass `EB_I25_TWO_HALF_ACCEPTED_AGGREGATION` and `EB_I25_MISSING_TOP_DONOR_FAIL_CLOSED`, then fail with `external full-half outflow fixture rejected before commit`. O2 is not reached. This is an observed baseline-equivalent failure, not a passing EB qualification or an established cause. Owner: existing F-KT22/EB-I25 accepted energy-ledger admission authority. No production, assertion or tolerance was changed. Paired exact-head log hashes and durable six-log archive are recorded in `integration/audits/MC_HEAT01_STATUS.json`; the issue remains open independently of the four bounded thermal admissions.

## Resolution rule

Closing an entry must preserve:

1. what differed;
2. which authority changed or was reinterpreted;
3. whether production source changed;
4. what qualification established the resolution;
5. which historical claims were superseded;
6. which evidence remains valid.

A discrepancy resolution never bypasses the owning production/science workstream or canonical admission process.

## MC-IRR01 feasible source-onset successor (2026-10-11)

The inherited 3-cm, equal-flux fixture can store only about 0.231265 cm; its failed 1-cm event cannot establish a history or solver defect. Unique negative evidence is retained. A matching 100-cm serialized context has 7.70884 cm free storage. This feasible probe exposes cancellation in `theta_new-theta_old` at short steps: HeadCalc stagnates with zero head correction and a residual above the unchanged acceptance bound. The proposed shared successor uses the existing constitutive storage-increment interface for all explicit providers; no constitutive formula, budget, mass gate, retry or history ownership changes.

`TCD-IRR-STORAGE-CANCELLATION`, `IMPLEMENTATION_DEFECT`, has local O0/O2 evidence: full 1-cm source-onset refinement, twelve real-depth root/depth cases, preserved existing irrigation hashes, BOFEK wet/dynamic-top and F-SI25/39 assertions. Central preservation and admission remain pending. Source-off, realistic sensor/multi-node restart and authoritative crop/root, salt and allocation lifecycle remain open. Exact blobs, logs and bounds: `integration/audits/MC_IRR01_ONSET_DIAGNOSIS_20261011.json`. No fullcap promotion is established by this successor.

Canonical disposition of `TCD-IRR-STORAGE-CANCELLATION`: bounded numerical repair admitted by PR #1200, merge `ea4759a0633011f26e8ee43126db2484c0def8b3`. Exact owner run `38132433330` and all frozen/moving F-CI jobs in `38132433375` pass. Source-off and complete lifecycle remain separate gates.


## PR700 historical Gash source recovery disposition (2026-10-11)

The historical `mod_gash_interception` and its two WU04-D forcing adapters are not unchanged scientific successors of the admitted daily INT12-D implementation. Their saturation selector uses total intercepted input `rpd`; the accepted INT12-D process uses gross rain `grai`, as explicitly preserved in its closeout. The shared historical partition helper uses a `1e-5` threshold while the admitted daily DivIntercep application uses `0.001 cm`. This is an incompatibility of noncanonical recovery candidates, not a newly discovered canonical regression or a verdict that the preserved legacy law is physically preferable.

Actual compiled original source and the current accepted source are compared on640 valid one-day, constant-table inputs:580 share the bounded formula,60 produce the expected rain/irrigation-crossing difference. Six partition edges include two differing-threshold cases. Independent formulas confirm both policies; O0/O2 diagnostic stdout is byte-identical. Existing INT12-D owner/independent/P0/daily gates also pass at O0/O2. Commands, exact identities, raw diagnostic/owner output and scope limits are in `integration/audits/PPA_RECONCILE01_GASH_SOURCE_DISPOSITION_20261011.json`.

Disposition: retain the three original graph files as archived historical evidence; do not replay them unchanged over the admitted daily Gash policy. The adapters are linked by inspected original imports and propagation, not by an invented full-runtime test. Their broader runtime/API, units, low-LAI and detailed-meteorology equivalence remains unclaimed. Other PR700 source decisions stay with their existing owners, and no capability count changes.
