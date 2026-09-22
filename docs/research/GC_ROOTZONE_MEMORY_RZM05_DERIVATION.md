# GC-RZM05 management binding derivation

Date: 2026-09-22  
Status: PREREGISTERED DESIGN  
Prerequisite: GC-RZM04 qualified

## Imported qualified semantics

RZM05 imports only the bounded semantics already qualified by the Ribasim dummy
line:

- DUMMY-12: committed physical root-zone storage is the persistent demand
  memory; management shortage is diagnostic.
- DUMMY-14: future demand follows accepted root storage after forcing, not the
  previous shortage.
- DUMMY-15: priority may change delivered irrigation and therefore future root
  state while physical allocation bookkeeping remains explicit.

No production SWAP irrigation algorithm is imported.

## Binding to the analytical SWAP root state

Define a management target `W_target` inside `[0,W_capacity]`. At the start
of a coupling window the irrigation request is frozen from committed storage:

```text
R = max(0, W_target - W_r^committed).
```

Available managed supply `A>=0` gives

```text
U = min(R,A)
shortage = R-U.
```

`U` is an external root-zone input owned exactly once. It is represented as
a rate `U/T` during the declared management interval in this analytical
experiment. Shortage is returned as a diagnostic and is not added to any
physical state.

After the hydraulic/forcing window accepts, next demand is recomputed only
from accepted root storage:

```text
R_next = max(0, W_target - W_r^accepted).
```

The root zone remains hydraulically internal to SWAP. Management may inject
water at the root boundary, but it does not create a direct hydraulic
root-to-MODFLOW coupling.

## Frozen tests

1. Full supply fills the frozen request at the management boundary, with later
   hydraulic redistribution allowed to change accepted W_r.
2. Partial supply records shortage but shortage does not persist as water or
   debt state.
3. Two histories with identical accepted W_r have identical next request even
   when previous shortages differ.
4. Rainfall after a current shortage can erase next demand.
5. Root loss after full current supply can create next demand.
6. Request remains frozen from committed W_r during a window.
7. Managed U enters the root component ledger once and the complete
   SWAP-interface ledger closes.
8. With coupled groundwater, irrigation is external root input while E_c
   remains the only SWAP-MODFLOW transfer.
9. Trial order/retry from one committed state cannot alter request or accepted
   result.

## Gate

Qualification means management semantics can be layered on the dynamic
root-zone dummy without inventing persistent shortage state or bypassing the
fixed hydraulic interface.
