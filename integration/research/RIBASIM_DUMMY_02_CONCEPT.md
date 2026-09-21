# RIBASIM-DUMMY-02 controlled three-way conflict triangle

## Question

Can SWAP irrigation demand, Ribasim surface-water allocation and MODFLOW
groundwater exchange be separated cleanly enough that a same-window water
conflict can be diagnosed without hiding it inside one model?

This work unit uses deliberately minimal participants:

- dummy SWAP publishes one irrigation request from committed state;
- dummy MODFLOW publishes a forecast and an actual Basin exchange;
- dummy Ribasim owns Basin storage, allocation and realized UserDemand;
- one research coupler prepares and explicitly commits the resulting window.

No production physics is represented by the dummy participants.

## Coupling window

The window is ordered as follows:

1. snapshot committed SWAP, Ribasim and MODFLOW revisions;
2. read SWAP irrigation request from committed state;
3. obtain MODFLOW forecast Basin drainage/infiltration;
4. calculate Ribasim allocation;
5. obtain MODFLOW actual Basin drainage/infiltration;
6. calculate Ribasim physical realization and realized UserDemand;
7. expose a coupled candidate without mutating any participant;
8. preflight all three revisions;
9. commit the accepted window.

The same-window SWAP request is frozen. A tentative shortage therefore cannot
silently change the demand that created the allocation problem. Any later
feedback from shortage to the next SWAP request must be a separate committed
between-window rule.

## Conflict classes

### C0: no conflict

Forecast and actual exchange agree and enough Basin water remains. Allocation
and realized delivery are equal.

### C1: allocation shortage

The forecast already shows that there is insufficient allocatable water:

```text
request > forecast allocatable storage
```

The shortage exists before the physical realization.

### C2: realization shortage

The allocation is feasible under the forecast, but actual hydrology is less
favorable. The canonical case is:

```text
SWAP request                         50 m3
forecast MODFLOW infiltration         0 m3
Ribasim allocation                   50 m3
actual MODFLOW infiltration          60 m3
Basin water left after hydrology     40 m3
realized irrigation                  40 m3
realization shortage                 10 m3
```

The physical exchange is retained and management delivery is curtailed.

### C3: physically infeasible exchange set

If actual mandatory infiltration exceeds all physically available Basin water,
the candidate cannot satisfy non-negative storage. Preparation fails closed.
The harness does not reinterpret this as permission to clip MODFLOW exchange.

That case is qualitatively different from a management shortage. It requires a
coupling-level physical re-evaluation, such as changed heads/fluxes or a
smaller coupling window.

## Transaction semantics

Preparation is observational with respect to committed participant state.
A candidate carries all three source revisions. Commit first checks all three
revisions. If any participant advanced independently, the candidate is stale
and no coupled mutation starts.

The harness is an in-memory research transaction. It does not claim distributed
atomicity or reproduce the production MODFLOW finalize/SWAP publication
durability contract.

## Why this matters for the next experiment

The triangle now separates three questions that would otherwise be conflated:

1. Was the management allocation already short under the forecast?
2. Did the hydrological realization create an additional shortage?
3. Was the realized physical exchange itself impossible for the available
   surface-water state?

The next useful extension is temporal: run several coupling windows and let a
committed shortage affect only the *next* SWAP demand/state. That permits us to
study conflict propagation and timestep dependence without same-window
circularity.
