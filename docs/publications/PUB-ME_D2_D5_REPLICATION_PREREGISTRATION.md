# PUB-ME D2/D5 physical-regime replication preregistration

Status: **PREREGISTERED_BEFORE_REPLICATION_EXECUTION**

Publication owner: `PUB-ME`

Doctoral mapping: `RQ1 / PRESERVE`

Freeze date: 2026-09-18

## 1. Purpose

The initial prospective D1-D6 study exceeded the preregistered minimum mechanism-level positive-family threshold, but the design also requires replication in materially different Reference regimes where the same defect operator is physically meaningful.

This file freezes the first required replication pair **before any D2R1 or D5R1 execution**.

No first-pass D1-D6 classification may be changed by these replications.

## 2. Authorities

D1-D6 design authority:

- preregistration head: `b2ebe5825b3c54d9d4eaefe44c33f4c859fa20aa`
- design blob: `61f7133f19cc900971aa454b7bdb16a254468eda`

Cross-defect adjudication:

- `docs/publications/PUB-ME_D1_D6_CROSS_DEFECT_ADJUDICATION.md`

Reference-domain prior authority used for regime selection:

- FSI38 prescribed-qbot matrix already includes `q = -1e-6, -1e-10, 0, +1e-10, +1e-6 cm/day` at `dt = 0.01` and `0.0001 day`.
- P2E08 prospectively retained the complete six-material × three-Se × three-forcing Reference physical domain and selected one common complete-domain temporal scale:
  - coarse = `0.0064 day`;
  - two half steps = `0.0032 + 0.0032 day`;
  - all 54 physical cases valid at that level.

The P2E08 result is used only to guarantee a complete Reference execution domain. Its measured coarse/refined disagreement magnitudes are **not** used to select D5R1.

## 3. Replication selection rule

The replication regimes are selected for **physical/forcing contrast from the original defect fixtures**, not for expected effect size.

After this freeze:

- no alternate regime may replace a blocked or null replication because it gives a more favorable PUB-ME result;
- no threshold or fault operator may be tuned from the replication outcome;
- a blocked fixture remains publication evidence.

---

# D2R1 — reverse-throughflow accounting replication

## 4. Original D2 fixture

Primary D2 used:

- hydrostatic Reference start anchored at `h=-75 cm`;
- prescribed `qtop=qbot=+1e-6 cm/day`;
- rejected trial candidate duration `0.01 day`;
- accepted re-execution candidate duration `0.0001 day`;
- temporal head budget `1e-6 cm`;
- qualification-only accepted side-ledger double-accounting operator.

Primary classification:

`D2 = EARLIER_DETECTION`.

## 5. Frozen D2R1 regime

D2R1 changes **only the throughflow direction**:

- `qtop=qbot=-1e-6 cm/day`;
- same hydrostatic initial Reference state;
- same material/constitutive configuration;
- same grid;
- same long duration `0.01 day`;
- same short duration `0.0001 day`;
- same model-certificate budget `1e-6 cm`;
- same hard mass gate;
- same D2 side-ledger fault operator;
- same B1 and B2 oracle definitions.

Rationale:

FSI38 contained this negative-flow endpoint in its historical preregistered/qualified matrix before PUB-ME D2 existed. The choice therefore does not arise from D2R1 results.

This is a **forcing-direction replication**, not a claim of independent soil/material replication.

## 6. D2R1 pre-execution gate

Before the D2 mutant is evaluated, the frozen clean physical fixture must satisfy:

1. both long and short Reference solves are route-valid;
2. the long `0.01 d` model certificate is above the frozen `1e-6 cm` budget;
3. the short `0.0001 d` certificate is below the same budget;
4. the long trial leaves the accepted origin unchanged;
5. the short re-execution from that origin is accepted;
6. accepted mass accounting is complete and within the existing hard gate.

If any condition fails:

`D2R1 = BLOCKED_REVERSE_THROUGHFLOW_REJECT_ACCEPT_FIXTURE`

and no replacement q/state/material may be chosen inside D2R1.

## 7. D2R1 hypothesis and interpretation

If the fixture is valid, replay exactly the D2 operator:

- qualification-only side ledger records the rejected prescribed throughflow;
- valid short re-execution later records the accepted transfer.

Freeze the same classes:

- `NO_INCREMENTAL_VALUE`
- `EARLIER_DETECTION`
- `UNIQUE_DETECTION`
- `INCONCLUSIVE`

A successful replication of the first-pass class requires:

- accepted endpoint/canonical accepted transaction remain clean as defined by D2;
- B2 detects the rejected contribution at retry entry;
- B1 detects only at its preregistered downstream accepted-ledger comparison;
- matched clean control has no false positive.

No claim of hydrologic-regime generality follows from D2 + D2R1 alone.

---

# D5R1 — wet fine-textured / drying workspace-authority replication

## 8. Original D5 fixture

Primary D5 used:

- material B01;
- 16 × 10 cm cells;
- initial pressure head `-101 cm`;
- one full Reference solve over `0.0016 day`;
- clean/mutant retry over `0.0008 day`;
- prescribed top flux `+0.01 K0`;
- prescribed bottom flux `-0.004 K0`;
- no root/drainage/irrigation/macropore terms;
- real Reference Newton workspace source `full_workspace%richards%old_head`.

Primary classification:

`D5 = EARLIER_DETECTION`.

## 9. Frozen D5R1 regime

Select the deterministic contrast corner of the pre-existing P2E08 physical domain:

- material: **O18**;
- effective saturation: **Se = 0.98**;
- forcing: **DRYING**;
- grid: 16 homogeneous cells × 10 cm;
- initial state: material-specific uniform Se converted with the admitted Mualem-van Genuchten relation;
- coarse/full Reference duration: **0.0064 day**;
- refined/retry duration: **0.0032 day**;
- DRYING top flux: **-0.005 × initial K0**;
- DRYING bottom flux: **-0.019 × initial K0**;
- no distributed sources/sinks;
- same existing Reference convergence/tolerance contract.

Selection rule:

- O18 is the last preregistered material axis member and is deliberately distinct from B01;
- Se=0.98 is the wet-end preregistered state level;
- DRYING is selected as the contrasting forcing direction;
- the P2E08 common temporal level is selected because it was prospectively proven valid for **all 54** physical cases.

The selection does **not** use the observed P2E08 `U_h`, `U_theta` or storage magnitudes.

## 10. D5R1 pre-execution gate

Before the D5 authority mutant is evaluated, establish from the real Reference solve that:

1. coarse and required retry/refined solves converge under the frozen Reference contract;
2. the full trial produces the selected real workspace field `richards%old_head`;
3. that workspace field is finite;
4. it is not bit-identical to authoritative physical pressure head;
5. constitutively reconstructed theta is finite and inside the declared physical domain.

If the workspace is not informative:

`D5R1 = BLOCKED_WORKSPACE_NOT_INFORMATIVE_IN_FROZEN_CONTRAST_REGIME`

No other material/Se/forcing case may replace O18/0.98/DRYING inside D5R1.

## 11. D5R1 mutant and comparator

If the pre-execution gate passes:

- clean retry starts from the untouched authoritative physical state;
- mutant retry promotes the real full-trial `old_head` workspace into physical pressure head;
- theta is recomputed with the unchanged admitted constitutive provider;
- all forcing, parameters, equations and retry duration are identical.

B2 oracle:

- compare proposed retry origin with authoritative accepted physical state **before retry execution**.

B1 comparator:

- strong scientific endpoint/storage comparison **after retry execution**, plus existing convergence/mass/invariant checks.

Freeze the same interpretation classes as primary D5.

A null result or B1-equally-early result is retained and may weaken the cross-defect generalization.

---

# 12. Cross-replication decision rule

The first-pass PUB-ME result remains `PROVISIONAL_GO`.

After D2R1 and D5R1:

### Replication-supported

At least one of D2R1/D5R1 reproduces the first-pass incremental transition-authority value and neither shows a matched-control false positive, while the other is either supportive or transparently blocked for a preregistered physical reason.

### Replication-limited

Both replications are blocked, or only one narrow regime remains executable.

### Replication-undermined

A valid matched replication shows that B2 provides no incremental boundary/timing value under the frozen comparator, especially if that contradicts the mechanism assumed to generalize from the first-pass fixture.

Do not pool the four runs into a statistical detection rate.

# 13. Hard exclusions

This workunit does not authorize:

- changing production or Reference physics;
- modifying D1-D6 first-pass result records;
- searching additional regimes after a blocked result;
- retuning temporal budgets or Reference tolerances;
- redefining B1 after seeing the result;
- claiming rollback/commit/transition authority as novel mechanisms;
- elevating RQ1b selective requalification before replication freeze and final novelty adjudication.

# 14. Next permitted action

1. implement D2R1 clean pre-execution gate first;
2. persist its clean-fixture outcome before running the D2 fault operator;
3. execute D2R1 only if the frozen fixture gate passes;
4. independently implement the D5R1 pre-execution gate;
5. persist its workspace-informativeness outcome before the D5 fault operator;
6. then execute D5R1 if admitted;
7. perform final PUB-ME novelty/go-no-go adjudication before starting publication-primary RQ1b.
