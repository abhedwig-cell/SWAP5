# RIBASIM-DUMMY-19G: does output frequency change management?

> Status: PREREGISTERED while DUMMY-19E2 is active.

DUMMY-19E exposed an unexpected coupling between two clocks that were assumed
separate:

```text
allocation.dt = management prediction/update horizon
solver.saveat = output frequency
```

Pinned source inspection shows that allocation time stops are initialized on
the `saveat` grid and a fixed allocation step is capped at the next such stop.
The allocator is then rebuilt from the current physical Basin storage.

DUMMY-19G turns that implementation fact into a controlled experiment.

Everything remains fixed except:

```text
saveat = 1 h, 6 h, 12 h, 24 h
```

while:

```text
allocation.dt = 24 h
```

in every case.

The preregistered prediction is monotonic. More frequent save boundaries expose
physically retained water to a new allocation sooner. Thus within the same one
day horizon total physical demand delivery is predicted to rise from about
16.02 m3 at daily saveat to about 29.09 m3 at hourly saveat.

This experiment does not decide whether that behavior is desirable. It
establishes whether output frequency is hydrologically and managerially neutral
in the pinned model. If it is not neutral, any coupled SWAP-Ribasim contract
must make that clock ownership explicit.
