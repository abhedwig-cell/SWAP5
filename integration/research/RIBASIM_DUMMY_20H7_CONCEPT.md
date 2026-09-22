# RIBASIM-DUMMY-20H7

## Question

Does the actual pinned RibaMod product carry the DUMMY-20H day-1 accepted Basin
state into the next fixed allocation boundary in the same way as the qualified
DUMMY-20H6 exact-release LP oracle?

This work unit closes a specific authority gap. DUMMY-20H6 starts directly from
the accepted t=24 state. H7 must obtain that state by actual coupled physical
realization first, then cross the t=24 allocation boundary in the same run.

## Frozen causal chain

```text
day-1 active River physical realization
  -> accepted t=24 Basin state
  -> next MF6 River solve from accepted stage
  -> current infiltration forcing
  -> Ribasim fixed-grid t=24 allocation solve
  -> recorded t=24 UserDemand allocation
  -> post-boundary physical realization
```

The test distinguishes accepted physical memory from current forecast forcing.
It does not assume they are one water quantity or one clock event.

## Falsification value

A t=24 result of 32/0 would show that the accepted-state memory admitted by the
standalone H6 oracle is not actually reached by the product runtime. A result
near 31.99033/0 would show that the actual product exposes current River forcing
without the H6 free-alpha attenuation. Either outcome would invalidate the
intended end-to-end bridge and must be persisted rather than retuned.

## Boundary

This remains research evidence for one pinned product topology. It is not a
production coupling prescription and does not establish general Ribasim network
allocation semantics.
