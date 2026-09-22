# RIBASIM-DUMMY-20D: real product clock ownership matrix

> Status: PREREGISTERED while DUMMY-20C is active.

DUMMY-20C first asks whether the actual RibaMod product route is dynamically
transparent relative to direct Ribasim v2026.1.1 for one frozen clock setup.

DUMMY-20D then asks which clock actually owns UserDemand allocation cadence in
that product release.

MODFLOW and RibaMod always step every 6 hours. Four real product cases vary
only `allocation.dt` and `solver.saveat`:

```text
case      allocation.dt   saveat   product step
A24_S24   24 h            24 h     6 h
A24_S1    24 h             1 h     6 h
A6_S24     6 h            24 h     6 h
A6_S1      6 h             1 h     6 h
```

The source contract qualified in DUMMY-20B predicts two equivalence classes:

```text
A24_S24 == A24_S1
A6_S24  == A6_S1
A24     != A6
```

The physical references are independent continuous references for the same
scarce root-first UserDemand model. A pass would dynamically establish that
`allocation.dt`, not `saveat`, owns fixed management cadence in the exact
Ribasim release bundled by the pinned RibaMod product.
