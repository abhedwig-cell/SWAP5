# F-WOF07 leaf reallocation reference reconciliation

## Scope

This workunit resolves what can be source-bound about leaf biomass reallocation without admitting production leaf reallocation.

## Pinned reference evidence

PCSE baseline: `0d51ae84f405fd9b061222f2a0130e5351f460df`.

At this commit:

- `Wofost73` imports `WOFOST_Leaf_Dynamics`;
- `Wofost81` imports `WOFOST_Leaf_Dynamics_N`;
- the N-aware leaf integration removes leaf death first;
- it then ages surviving cohorts;
- if `REALLOC_LV > 0` and `REALLOC_LV < sum(surviving LV)`, every surviving cohort is multiplied by the same factor `(sumLV - REALLOC_LV)/sumLV`;
- only after this proportional reduction is new leaf growth added;
- `SLA` and cohort age are not changed by reallocation itself;
- dead leaf biomass is not increased by reallocation because reallocation is an internal biomass transfer, not senescence.

Historical commit `3648114b11900222adcec8ae8349503f5c346b05` explicitly introduced this proportional cohort operation. Later commits repaired top-level WOFOST73/81 reallocation bookkeeping, but the pinned WOFOST73 route still imports the ordinary leaf class rather than the N-aware class carrying this operation.

## Interior-domain semantics

For surviving living leaf cohorts `L_i` after same-day leaf death and a requested leaf transfer `R` satisfying

`0 <= R < sum(L_i)`, 

the source-bound transformation is:

`f = (sum(L_i) - R) / sum(L_i)`

`L_i,new = f * L_i`

This has desirable properties:

- exact intended living-leaf mass change up to floating-point arithmetic;
- all cohort mass fractions are preserved;
- all cohort ages are preserved;
- all cohort-specific SLA values are preserved;
- pre-growth leaf area scales by the same factor `f`;
- new growth can then be inserted as a new youngest cohort.

This ordering also fits the supplied SWAP 4.3.1 leaf-state structure, where leaf death is applied before surviving cohorts are shifted/aged and new growth is inserted.

## Synthetic oracle

A deterministic 10,000-case random oracle over 1 to 20 positive surviving cohorts and interior transfers gave:

- maximum absolute leaf-mass identity error: `4.547473508864641e-13`;
- maximum absolute leaf-area scaling error: `1.7763568394002505e-15`;
- maximum absolute cohort-factor error: `1.1102230246251565e-16`.

The interior transformation is therefore numerically straightforward and scientifically interpretable.

## Blocking edge semantics

The pinned N-aware PCSE code applies the transformation only when:

`REALLOC_LV < sumLV`

not when equal.

Consequences:

1. If `REALLOC_LV == sumLV`, no cohort reduction occurs even though the top-level reallocation flux can still transfer biomass to storage.
2. If `REALLOC_LV > sumLV`, no cohort reduction occurs either.
3. A reallocation cap fixed at activation can later exceed same-day surviving leaf biomass after senescence or stress-related leaf death.
4. Blindly copying the reference condition can therefore create storage biomass without a matching leaf withdrawal.

Synthetic edge checks illustrate the defect directly:

- survivor mass `123.456`, requested transfer `123.456`: historical leaf removal `0`, unbacked transfer `123.456`;
- survivor mass `100`, requested transfer `110`: historical leaf removal `0`, unbacked transfer `110`.

This is incompatible with SWAP5 invariant 13.

## Required production contract before admission

A production leaf-reallocation route needs an explicit availability-aware contract. At minimum it must define:

- whether the top-level requested transfer is limited by surviving living leaf biomass after same-day death;
- whether the actual applied transfer, rather than the pre-limited request, updates cumulative reallocation bookkeeping;
- how storage inflow and conversion loss are recomputed from the actually applied leaf and stem transfers;
- whether a lack of available leaf mass is a physical limiter or a failed trial;
- exact ordering relative to leaf death, physiological ageing, new leaf growth and N bookkeeping;
- hard dry-matter conservation for equality and excess cases.

Simply changing `<` to `<=` resolves the equality case but not the excess case and is therefore insufficient as a production design.

## Verdict

Interior leaf-cohort transformation semantics are sufficiently resolved for a reference testbank.

Production leaf reallocation is not admitted because the availability/cumulative-flux contract remains unresolved and the pinned WOFOST73 route does not provide a clean active reference implementation.

Status: `BLOCKED_LEAF_REALLOCATION_AVAILABILITY_CONTRACT_REQUIRED`.
