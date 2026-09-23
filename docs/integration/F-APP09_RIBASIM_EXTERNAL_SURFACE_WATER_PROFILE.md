# F-APP09 Ribasim external surface-water production profile

F-APP09 is the production-facing successor of the closed SW-RIB-SWM01 research line.

It admits no new surface-water store in SWAP. For the declared profile, Ribasim is the sole surface-water storage and level owner. SWAP owns only the signed soil/drainage exchange physics, and the coupling transaction owns feasibility, replay and final commit permission.

The first profile deliberately uses Ribasim-native surface-water geometry. The Q1H epsilon representation remains a separate migration option and is not silently turned into a production tolerance.

The transaction contract follows the already admitted groundwater participant pattern:

```text
accepted SWAP origin
    -> materialize accepted external surface-water heads
    -> SWAP candidate trial
    -> compare requested signed exchange with external realized transfer
       -> mismatch: discard and recompose from the same accepted origin
       -> match: publication preflight
    -> sole kernel commit
```

For this first admission candidate, one coupling window may contain exactly one accepted SWAP substep. Solver retries are allowed, but publishing a whole-window drainage transfer assembled from multiple accepted substeps is held until an explicit cumulative exchange authority exists.

This work unit does not delete the standalone F-CI52 fixed-weir capability. It fails closed if that optional state layout is selected for the same externally owned store.
