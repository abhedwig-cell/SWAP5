# MC-SOL01-SURFACE-AGE02: multi-cycle Reference qualification and dry limit

Status: canonically admitted supplemental evidence through PR1315 at
`916e0725508a4807a65b81174b9e28b603ccb7f7`, over unchanged production
`65db94901eba8222b070920827621fdffddb2180`; admission is recorded separately in
`integration/audits/MC_SOL01_SURFACE_AGE02_STATUS.json`. PR [1315](https://github.com/abhedwig-cell/SWAP5/pull/1315).
Executed postimage: `87da11c38515b1d78d62de8e6608fb42303395a0`.
No production, existing test, workflow, reference or admission guard is changed.
The existing SURFACE-AGE01 scientific qualification and full preservation remain
source-identical. RossFast remains frozen. This does not promote master coverage.

## Executed scope

The reproducible research driver lives under
`integration/audits/surface_age_longrun/driver.f90`; `run.py` and `verify.py` reproduce
and validate the qualification. These are supplemental audit drivers, not a new
production route or changes to existing admission selectors. A four-node, 3 cm
column uses the actual Reference Richards production API, its complete accepted
water-flux trace, native soil age, private joint state owners and atomic snapshot.
It is a controlled numerical/physical composition test, not a calibrated field run.

Two model days contain four half-day cycles. Each cycle has 0.1 day of rain
4 cm/day, irrigation 1 cm/day and runon 2 cm/day, followed by 0.4 day without
incoming surface water. Pond evaporation demand is 0.05 cm/day while wet and
0.2 cm/day while drying. Initial pond is 0.5 cm with mean age 3 days; incoming
irrigation and runon ages are 2 and 7 days. Initial soil mean ages are 2..5 days.
The existing low-conductivity soil, 0.50001 cm runoff threshold and 0.001 day
runoff resistance retain positive pond throughout. Roots, signed drainage and
lower boundary exports remain in the soil budget.

All actual accepted fluxes enter the balance; no prescribed synthetic flux trace
is substituted. Both individual age balances and the cumulative combined balance
are asserted at every window, with infiltration counted once internally. Water
is checked for both pond and whole column. Age tolerances scale with inventory,
roundoff and accumulated windows; water closure remains 1e-10 cm per window.
External full/two-half tolerance remains 1e-6, and the existing explicit retained
accepted-duration proposal is selected. No acceptance criterion is relaxed.

The finest O0/O2 result has these actual two-day water depths:

| Component | cm |
| --- | ---: |
| Rain | 1.600000000000001 |
| Irrigation | 0.400000000000000 |
| Runon | 0.800000000000000 |
| Infiltration to soil | 0.151549214106756 |
| Runoff | 2.406729324121062 |
| Pond evaporation | 0.339999999999950 |

Pond depth ranges from 0.3828714350 to 0.5069121406 cm. The final combined
age amount is 6.7744894005 cm day. Its final balance residual is
3.99e-13 cm day; maximum cumulative residual is 4.31e-13 cm day.
Maximum individual-window water residual is 7.45e-16 cm; the direct accumulated
pond water residual is 1.58e-12 cm. The latter is reported separately rather than
mistakenly presenting the interval maximum as accumulated closure.

## Refinement and continuation

O0 and O2 produce byte-identical full endpoints on each mesh, including water,
soil age, surface age and their clocks/revisions. Twelve fresh OS-process
continuations recover exactly the corresponding uninterrupted endpoint. Finest
checkpoints cover wet conditions (1.55 d), wet-to-drying (1.60 d), drying (1.85 d)
and drying-to-wet (1.50 d). Restart forces are deterministically reconstructed from
the generic event schedule; snapshots retain the physical triplet.

| Outer maximum window (day) | Actual maximum accepted trace step (day) | Final pond amount (cm day) | Final soil amount (cm day) |
| --- | --- | --- | --- |
| 0.0000625 | 0.00003125 | 1.466409806099428 | 5.308136334535199 |
| 0.00003125 | 0.000015625 | 1.466376493813572 | 5.308133980176990 |
| 0.000015625 | 0.0000078125 | 1.466356108868691 | 5.308133291645444 |

Successive pond changes decrease from 3.33123e-5 to 2.03849e-5 cm day;
soil changes decrease from 2.35436e-6 to 6.88532e-7 cm day. The final changes
are about 0.00139% and 0.0000130% of their inventories, below the preregistered
0.1% final-difference ceiling. This is observed stabilization under actual step
refinement, not a known-error bound or proof of formal whole-model order.
The independent first-order stirred-reservoir oracle from SURFACE-AGE01 remains
unchanged. There is no evidence requiring a production midpoint-formula change.

Two earlier refinement selections are retained as failed final criteria. Their
physical, balance, restart and optimization checks passed, but the endpoint
changes were not yet monotonic. The first selection barely refined the actual
adaptive mesh. The second halved the actual maximum but had not reached the
observed stabilizing regime. Small differences alone were not called convergence.

## Scientific limit: evaporation and the meaning of age

The requested convention is that evaporation exports water but no age amount.
For an isolated pond with no incoming or liquid outgoing water, let h be depth,
M the age amount, E constant evaporation and a0 initial mean age. This convention
requires

```text
h(t) = h0 - E t
M(t) = h0 a0 + h0 t - E t²/2
mean age = M(t)/h(t)
```

At complete drying, t=h0/E, the retained moment is
`h0 a0 + h0²/(2E) > 0`. It cannot simultaneously be a finite mean age of zero
water. This is a conflict between the stipulated balance and a regular dry state,
not a roundoff error or a defect fixable by smaller time steps.

The independent production-owner limit test uses h0=0.5 cm, a0=3 days and
E=1 cm/day. At t=0.4999995 d, depth is 5e-7 cm, moment is approximately
1.625 cm day and the computed mean approaches 3.25 million days. The next
complete-drying step rejects and leaves the candidate identical to the original
committed owner. It is explicitly an analytic limit test, not a Richards run.

There is also a semantic distinction before zero depth: for perfectly mixed
physical water whose evaporating molecules have the same mean age as the pond,
evaporation would export `E * mean_age`, giving `mean_age = a0 + t` in this isolated
example. The stipulated no-export convention instead behaves as a nonvolatile
age moment. This derivation does not silently revise the user's convention or
historical model. The present evidence qualifies that existing convention and its
coupling, not a universal interpretation as literal molecular water age during
evaporation. Complete evaporative drying remains **scientifically blocked**.
Deleting the residual, clipping the mean or inventing a dry deposit would change
the scientific contract and is not admitted here.

## Costs, evidence and reproduction

All six final two-day native runs total 55.205 s. The twelve fresh-process
continuations total 24.560 s. Leaf compilation costs 8.594 s and linking 1.296 s;
incumbent replay costs 0.859 s and the isolated dry limits 0.006 s. These sum
measured command walls, not an end-to-end service or portable speed guarantee.
GNU Fortran 13.3.0 uses independent O0/O2 with bounds/runtime checks and floating
point traps. Provider reuse is local to the existing execution: every production,
caller, fixture, oracle and compiler input matches the admitted capsule, every
reused artifact is hashed, and original admitted native endpoints execute again.
Cold reproduction remains available and does not require a persistent cache:

```bash
FC=gfortran python integration/audits/surface_age_longrun/run.py --out /tmp/age02-fresh
python -B integration/audits/surface_age_longrun/verify.py --self-test
```

Two expensive pilots were censored before their first 0.05 day window completed.
The immutable logs/status retain them without a PASS claim. Diagnostic probes
of 0.001 and 0.01 day showed 103 and 952 accepted transactions, costing about
0.082 and 11.448 s. Existing accepted-trace append/checkpoint code repeatedly
copies growing trace prefixes, a concrete candidate cost mechanism. This is not
exclusive profiling or a proof that all runtime is trace copying. Shorter generic
windows bound trace size while retaining every scientific gate. No production
performance patch or tolerance reduction was introduced.

The versioned capsule contains raw final and unsuccessful logs, all endpoints and
snapshots, source identities, generated fixtures, compiler commands, artifact
hashes and forensic diagnostic sources. Eight negative evidence controls reject
corrupt endpoints, missing fresh processes/streams, failed commands, unchecked
compilation, inactive mesh refinement, unfinished results and production drift.
The old admitted source/evidence guard and twelve current HIST negative controls
also pass. Full moving F-CI and new hosted numerical runs are NOT_SELECTED_IMPACT:
no production, existing test selector or scientific admission guard changed.
Previously qualified source and preservation remain exact. Affected invariants
7, 9, 13, 25 and 26 are strengthened by evidence, not changed.
