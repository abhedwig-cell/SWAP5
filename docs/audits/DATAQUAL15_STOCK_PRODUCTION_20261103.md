# Numerical stock comparison production successor

Status: **Implemented and locally tested; canonical admission pending.**

Base: `7a7f994d8b7fd0327f761a0db791726ab7a98e75`. The only production delta is
`src/process/mod_whole_column_sensible_energy_accounting.f90`, byte-equivalent
after newline normalization to the previously measured isolated candidate.
No public DTO, physical storage law, heat solver, water solver, restart format
or reference source changes.

## Numerical correction and measured boundaries

For nodal computed stocks a(i), b(i), the two representations
`sum(a(i)-b(i))` and `sum(a(i))-sum(b(i))` accumulate rounding on the endpoint
stock scale. Comparing their difference solely against the small net change
rejected632/864 normalized Grassgrowth component evaluations. Both summation
paths have forward-error bounds proportional to the sum of absolute endpoint
stocks. The implemented conservative gamma(4n+4) bound includes the accumulation
of that scale itself. The prior small-change comparison is retained.

This is representation consistency, not permission to lose physical energy.
On432 explicit113-node inputs at reference temperatures0C/5C, checked
Windows16.2 O0/O2 now accept all864 normalized representations per build.
All864 injected1J/m2 representation inconsistencies are rejected. The raw theta
domain rejections and missing-advection rejections remain864 each per build.
The1.45032703J/cm2 variable-water physical discrepancy is unchanged. Full
physical energy remains OPEN. The endpoint law and strict theta domain are
unchanged; roundoff-only normalization remains an explicit diagnostic copy.

The existing EB-I22 owner and independent F-VQ88 drivers pass at O0/O2.
Measurements and sources are sealed in
`integration/dataqual15/STOCK_PROJECTION_PRODUCTION_EVIDENCE_20261102.tar.xz`,
bound by `STOCK_PROJECTION_PRODUCTION_20261102.json`.

## Runtime preservation and outflow test correction

The production procedure is not called by the runtime. EB-I23/I24/I25 import
its unchanged boundary DTO. Their actual current186-provider compile closure
is measured separately at O0/O2, with fresh executions of all three committed
test programs and exact per-test stdout. No runtime or solver procedure is
replaced by a test formula.

The original I25 positive-flux fixture expected hydraulic rejection. Current
canonical water physics accepts it. Replacing only the accounting module by
its exact7a7f994d8 baseline on identical O0 runtime/test objects reproduces the
same original test failure. Direct observations show one committed water
transaction, mass residual-2.220446049250313e-16, a ready partial receipt with
top status5 (`EB_I25_TOP_OUTFLOW_UNQUALIFIED`) and incomplete energy materialization.
Attribution: `STOCK_RUNTIME_OUTFLOW_ATTRIBUTION_20261103.json`.

The revised fixture asserts the existing normative energy contract directly:
accepted outflow water remains mass-closed, publishes exactly once and carries
two accepted half samples; external inflow donor temperature cannot authorize
outflow energy; top advection remains unavailable, the boundary incomplete and
runtime materialization incomplete. The separate rejected-transaction case
still requires rollback and no publication. No numerical tolerance or solver
budget is relaxed. The I25 contract and F-KT22 marker are updated accordingly.
This tests negative energy authority, not qualified outflow enthalpy transport.

The sealed runtime dossier contains original I23/I24 oracles and the reconciled
I25 oracle, not a claim that every historical test byte is unchanged. The
producer's unchanged-oracle label means the committed test sources are compiled
as captured, without generated modifications. The exact test blobs, attribution
and scope above identify the I25 assertion correction explicitly.

## Preservation and admission composition

The native restart admission boundary now allows exactly the known stock-owner
blob in addition to its already admitted I/O delta. Unknown production changes,
dirty/untracked source and altered approved postimages still fail. Ten actual
Git mutation controls pass. The committed preservation projection restores the
old accounting blob as well as the existing I/O predecessors, yielding the exact
original `src/app/reference` trees. Existing scientific verifiers and their
immutable capsules are unchanged. The composed local gate preserves full
Grassgrowth/Hupsel scientific evidence as historical evidence and verifies the
current native I/O and the new stock owner separately.

F-CI70/72/74/79 moving preservation retains its historical guards as fallback.
The new successor branch requires the source-bound current numerical and runtime
dossiers, an exact one-file production delta from7a7f994d8 and unchanged inherited
contract/qualification assets. The original component tests still execute;
known old heat/backend blob pins are not silently reported as current proof.

```bash
python -B tests/dataqual15/qualify_stock_projection_production.py --output ../stock-new
python -B tests/dataqual15/qualify_stock_runtime.py --output ../runtime-new
python -B tests/dataqual15/verify_stock_runtime_production.py
```

Linux CI independently compiles and executes both numerical and runtime
closures. Original contact and isolated-candidate dossiers execute in the exact
committed predecessor view. This unit does not qualify Andelst481days, change
the macropore contact law, supply missing donor-energy receipts, increase the
full scientific denominator or establish a complete physical energy balance.
