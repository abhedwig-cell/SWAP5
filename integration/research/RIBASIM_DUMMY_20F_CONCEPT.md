# RIBASIM-DUMMY-20F: physical groundwater memory admitted at the next allocation boundary

> Status: PREREGISTERED while DUMMY-20E2 is active.

DUMMY-20E2 asks whether groundwater water that arrives *after* the t=0
management decision changes physical state without retroactively changing that
decision.

DUMMY-20F extends the same product case through a second day.

The intended semantic sequence is:

```text
t = 0
  allocation sees 32 m3/day source
  -> root 32, external 0

6-24 h
  8 m3/day groundwater transfer enters physically
  -> stored/realized in Basin
  -> no management reallocation

t = 24 h
  next fixed allocation.dt boundary
  -> current accepted Basin storage is visible
  -> active 8 m3/day groundwater forcing is visible
  -> new allocation admits the accumulated physical memory
  -> root 40, external 20

24-48 h
  physical realization follows the new full allocation
```

The frozen day-2 endpoint reference is:

```text
time   GW cumulative   root cumulative   external cumulative   Basin level
30 h      8 m3          21.041991 m3        2.508705 m3       1.00002444930449
36 h     10 m3          26.061255 m3        5.018337 m3       1.00002692040883
42 h     12 m3          31.082371 m3        7.528895 m3       1.00002938873474
48 h     14 m3          36.105337 m3       10.040378 m3       1.00003185428537
```

The conceptual point is the time direction of authority:

```text
physical transfer during allocation window
  -> accepted physical memory
  -> next allocation decision
```

not:

```text
physical transfer
  -> retroactive rewrite of the already accepted allocation.
```
