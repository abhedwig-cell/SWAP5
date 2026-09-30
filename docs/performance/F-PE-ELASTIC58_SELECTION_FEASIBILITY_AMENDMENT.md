# F-PE-ELASTIC58 — independent-profile selection feasibility amendment

Date: 2026-09-30

Status: SOURCE_FEASIBILITY_AMENDMENT_BEFORE_NUMERICAL_RESULTS

Parent preregistration:
`F-PE-ELASTIC58_PHYSICAL_BUDGET_PREREGISTRATION.md`.

## Trigger

The first ELASTIC58 workflow stopped before compiling or executing any physical
case because the frozen BRO artifact contains no second eligible independent
1-horizon profile after excluding:
- parent profile 90116260;
- ELASTIC55 profiles 11060, 10260, 8016 and 3030.

No numerical ELASTIC58 result existed when this amendment was written.

## Corrected independent-profile selection

Keep all original eligibility, exclusion and diversity-key rules.

Select exactly four independent profiles as follows:

1. enumerate eligible profiles in ascending profile id;
2. retain only the first profile per unique diversity key
   `(soilunit,horizon_count,block tuple)`;
3. group retained profiles by horizon_count;
4. from each non-empty horizon-count class, take its smallest profile id;
5. order these class representatives by horizon_count and select the first four;
6. if fewer than four non-empty horizon-count classes remain, fill remaining
   slots from the globally smallest still-unused eligible diversity-key
   representatives;
7. require four distinct profile ids and at least three distinct horizon_count
   classes, otherwise fail closed.

No physical output, Binf, convergence result or oracle result may participate in
selection.

## Unchanged scope

Unchanged:
- frozen alpha;
- H_budget = 0.01 cm;
- C-SAFE logic;
- states/forcing/regimes/dt ladder;
- 32-substep oracle;
- all physical gates;
- no production source changes.
