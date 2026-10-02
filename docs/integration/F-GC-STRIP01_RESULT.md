# F-GC-STRIP01 standalone qualification and coupled advice

Status: **A/B locally qualified; C/D/E pending shared domain contract**.
Research only. No canonical admission. No production source changes.

## What actually ran

MODFLOW6 6.8.0, verified official Linux archive SHA256
33edf988b672a9f282d6773304c079d0f180541f6fe0c6555265d9c71841256e;
FloPy 3.9.5. All calculations were local; no GitHub Actions were dispatched.
The independent oracle and frozen A/B gates were persisted at
3128c08a2c6348015b4b1a4657f55da94a95db0c before native execution.

Geometry: 50 m half-spacing, 1 m transverse width, 50 cells (100 in refinement),
one convertible layer, base -10 m, top 0 m, first-cell DRN at -5 m,
no-flow elsewhere. Finite drain conductance 100 m2/d. Steady recharge 1 mm/d,
total 0.05 m3/d. Selected K=0.5 m/d. The drain represents a cell-centred sink,
not an ideal Dirichlet condition at x=0.

| K (m/d) | Ideal edge-drain rise (m) | 50-cell oracle rise (m) | 100-cell oracle rise (m) |
| ---: | ---: | ---: | ---: |
| 0.10 | 2.071068 | 2.035979 | 2.053722 |
| 0.25 | 0.916080 | 0.899576 | 0.908045 |
| 0.50 | 0.477226 | 0.468546 | 0.473116 |
| 1.00 | 0.244044 | 0.239752 | 0.242137 |
| 2.00 | 0.123475 | 0.121523 | 0.122743 |

Native maximum head difference against the discrete oracle across ten
K/mesh configurations: 1.0497999803e-8 m (limit 0.005 m).
Maximum recharge/drain residual: 6.8209327075e-14 m3/d (limit 1e-8).
Spatial heads increase toward the no-flow symmetry side. Mesh refinement
approaches the ideal edge-drain relation; the finite cell-centre geometry
difference is reported rather than removed by adjusting an acceptance limit.

At K=0.5, native 50-cell midpoint head is -4.5314535521 m, a 0.468546448 m
rise above drain stage. DRN conductance 10/100/1000 m2/d gives first-cell
head excess 0.005/0.0005/0.00005 m, respectively. Native midpoint heads are
-4.527338399/-4.531453552/-4.531865034 m. The selected drain resistance is
small compared with the resolved mound, without assuming an infinite drain.

## Drain-down

From uniform head -3 m, Sy=0.2, Ss=0, with zero recharge and ET, 480 accepted
MODFLOW timesteps of 0.25 d cover 120 d. Total storage decreases monotonically
from 70 to 53.0676644924 m3 per metre strip width. Cumulative drain discharge
is 16.9323355075 m3. The maximum cumulative storage/drain residual is
4.5332626541e-12 m3 (limit 1e-6). The final state is not asserted equilibrated.
Right/base no-flow follows the absence of external packages on those faces.
This is groundwater-only physical storage, not coupled storage authority.

## Negative evidence and repair

The first NEWTON/default averaging run failed the head/oracle gate at K=0.1:
0.00848973793 m versus 0.005 m. Its water budget passed. AMT-HMK with NEWTON
did not resolve the discrepancy. Removing NEWTON and retaining explicit
arithmetic thickness averaging did resolve it, without changing any tolerance.
Both failed input/output sets remain in the evidence archive. This diagnoses
a discrete-oracle/configuration mismatch, not a SWAP or coupling failure.
See F-GC-STRIP01_DISCRETIZATION_REPAIR.md for the complete chronology.

## Reproduce and inspect

Scripts: tests/fgc/strip01/oracle.py, run_standalone.py, conductance.py,
analyze.py. The native archive contains full inputs, listings, execution logs,
binary heads/budgets, unrounded JSON, figures and manifest. Archive:
integration/f-gc/strip01/evidence/native_AB_20261002.tar.gz;
SHA256 fbcec01311aa832a3bd6d23a489b55d0959fa36895fc428174d4db24ad23eff5.
Extract at repository root. Successful native outputs are in
integration/f-gc/strip01/native_picard_amt_hmk, and the two negatives are
native and native_amt_hmk. Conductance evidence is in conductance.

```bash
tar -xzf integration/f-gc/strip01/evidence/native_AB_20261002.tar.gz
python tests/fgc/strip01/run_standalone.py --mf6 /path/to/mf6 --output /tmp/strip01-replay
python tests/fgc/strip01/conductance.py --mf6 /path/to/mf6 --output /tmp/strip01-conductance
python tests/fgc/strip01/analyze.py --results /tmp/strip01-replay
```

## Actual remaining boundary

A/B remain locally qualified. Isolated real SWAP/MODFLOW short-window research
now ran, including exact replay, commit identity and combined mass balance.
Longer windows failed. Full phase C, far-cell-to-drain transfer, Hupsel and
coupled restart are **not qualified**. See [component results](F-GC-STRIP01_COMPONENT_RESULT.md)
and [disjoint research contract](F-GC-STRIP01_RESEARCH_DOMAIN.md). The earlier
prerequisite's blanket stop on research was too broad; changing shared
production ownership still requires a separate governance decision.
No publication claim or whole-unit closeout follows from these results.
