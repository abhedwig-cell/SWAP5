# F-PE-ELASTIC58B — BALTOL02 refined-oracle recovery result

Date: 2026-09-30

Status: QUALIFIED_NEGATIVE_RESEARCH_RESULT

Branch: `research/f-pe-elastic58b-baltol-oracle-recovery`

Qualified postimage: `367a93c8bf324663646c49cc395759c1b400dded`

Qualification:
- run `36685224982`
- job `109789422667`
- SUCCESS

## Result

The frozen ELASTIC58 candidate was replayed unchanged:

- alpha = `0.17320259355765216`;
- physical head budget = `0.01 cm`;
- profiles 11020, 8120, 4015, 3011;
- C-SAFE logic unchanged;
- hard physical mass gate = `1e-12 cm`.

Only the direct 32-substep Reference oracle used the admitted BALTOL02
short-step balance-rate floor:

`max(1e-12, 2.8e-16 / dt_sub)`.

Controller replay:
- accepted = `97`;
- exhausted = `95`.

Oracle result:
- complete = `0 / 97`;
- incomplete = `97 / 97`.

Observed marker:

`F_PE_ELASTIC58B_ORACLE_RECOVERY=BLOCKED|incomplete=97|accepted=97`.

No production source changed.

## Interpretation

BALTOL02 alone does not recover the refined-oracle coverage blocker identified
by ELASTIC58A.

The 0.01 cm physical head budget is therefore neither falsified nor qualified by
ELASTIC58B. No physical-error maximum can be inferred from this run because no
32-substep oracle completed.

Classification:

`QUALIFIED_BALTOL02_REFINED_ORACLE_RECOVERY_FAILURE`.

The next bounded question is whether another Reference convergence criterion
limits the BALTOL02 oracle, or whether the 32-equal-substep construction is
itself too fine for a valid independent Reference oracle.

No tolerance widening, hard-mass relaxation, budget change or production
admission is authorized.
