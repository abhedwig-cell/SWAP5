# RIBASIM-DUMMY-20C: actual RibaMod runtime clock equivalence

> Status: PREREGISTERED while DUMMY-20B is pending.

This is the first dynamic clock test through the actual pinned iMOD Coupler
`RibaMod` product driver.

The product route uses real kernels but deliberately no active groundwater
exchange packages. MODFLOW therefore supplies only the real product clock.
That isolates the management-clock question from groundwater flux physics.

Two routes use the same Ribasim v2026.1.1 input:

```text
A: actual RibaMod + real MF6, four 6-hour product updates
B: fresh RibasimWrapper, direct update_until at 6/12/18/24 h
```

The routes are compared after every accepted 6-hour boundary in Basin level
and cumulative UserDemand delivery. The root-first scarcity case also checks
that the external recipient remains physically unsupplied during day 1.

A pass means the real RibaMod driver is dynamically transparent with respect
to the bundled v2026.1.1 management clock for this isolated topology.
