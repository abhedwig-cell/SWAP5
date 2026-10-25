# Native numeric heat with the existing crop project

HIST-INTEGRATION01, baseline `3ebf19fad6027e174341302d64c22585d47b91bc`.
Explicit `--native-heat --native-hydraulics` connects original SWHEA1/SWCALT2
texture/initial temperature to the existing numeric heat provider. Original
daily weather supplies air temperature `(TMIN+TMAX)/2` on the exact native
calendar. Original TTUTIL decimal conversion is retained; an independent Python
weather oracle allows four floating-point ulps, without changing physical budgets.

The real project route retains three simple crop periods, trial-beginning Feddes
stress at each accepted water substep, original detailed rain and ordinary soil/
pond evaporation. The existing endpoint thermal/solute operator split consumes
actual staged heat. Freundlich0.5/2 and source temperature-dependent decay are
qualified over481 days at checked O0/O2, with separate-process day365 restart.
The twelve-node soil is constructed. This is not the full original Andelst grid
or macropore/Boesten/drainage/heat lifecycle and does not establish that cross-product.

The only shared runtime change replaces the blanket thermal/substep-root
exclusion by a numeric-heat, accepted-water-trace, external-chemistry,
frozen-conductivity gate. Frost, snow, Rutter, macro, Picard and oxygen/compensation
exclusions remain. Exact source projection binds every other runtime byte.
No physical equation, kernel state, persistence format or numerical tolerance
changes. The compiled runtime module interface remains byte exact; unchanged
provider objects are reused only with verified source/compiler/flags/module
identities and a fresh runtime object/link.

Each heat step still enforces the existing1e-9 J/cm2 energy closure criterion.
The project budget exposes `observed_heat_residual_j_cm2`, the maximum absolute
residual from the last accepted heat step exposed per rain segment. It is not a
whole-day energy sum or a record of every accepted heat step. Water/solute gates
remain1e-10, and accepted root potential/extraction/reductions reconcile within
the existing1e-12 criterion. Detailed-rain days stage both owners and publish
only when every segment succeeds; rejected-state diagnostics use the existing
thermal restart owner, so rejection cannot publish a partial final generation.

```bash
FC=gfortran python tools/solute/build_project.py --optimization O2 --output /tmp/swap5-project-heat
python tools/solute/run_project.py project.swp --bundle /tmp/swap5-project-heat --output /tmp/swap5-project-heat-result --native-hydraulics --native-heat --temporal-tolerance .01 --solute-transport implicit_upwind --surface-exfiltration historical_zero
```

Preservation is fresh where the shared caller changed: project BBC481 and its
day365 restart, original KSATEXM input/column cases, hydrostatic/heat cases and
incumbent exact outputs at O0/O2. The combined capsule namespaces inherited
column/project parents and replaces their current executed raw proof; all prior
scientific assertions remain. Failed initial thermal/substep-root trials and the
initial overly strict weather-oracle attempt remain evidence, without PASS credit.
Unchanged broad FCI, highest low-air and RossFast are not selected.
