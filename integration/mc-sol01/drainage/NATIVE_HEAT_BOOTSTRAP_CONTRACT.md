# Native numeric soil-temperature bootstrap

Owner HIST-INTEGRATION01. Baseline de6299171e3b13d8f444993e9bf8893ad15fec72.
Use original SWHEA1/SWCALT2 thermal inputs through original TTUTIL before any
committed owner exists. No new heat equation, time policy or restart schema.

Map physical soil-layer PSAND/PSILT/PCLAY/ORGMAT and OSAT onto the exact water
owner grid (ISUBLAY/ISOILLAY/NCOMP/HSUBLAY). Reuse the source temperature.f90
initialization (organic/mineral mass to volume fractions), then initialize the
existing restricted numeric heat provider. No renormalization. Initialize every
node from original absolute-depth TSOILTB through original RDADORTB and AFGEN_2.
SWINCO1/2, top air temperature1 and bottom zero-heat-flux1 are selected initially.
Analytic heat, external boundary tables and loose historic restart are rejected.

The file column gains explicit default-false swp_heat_bootstrap. It requires
SWP-backed water and dynamic_temperature and forbids a second temperature
profile. Its actual heat parameters/state/boundaries come from the new reader;
air_temperature_c supplies explicit per-window air forcing for this mode;
simultaneous prescribed surface temperatures are rejected.
The existing SWP chemistry import still enforces its original process envelope.
All SWP bytes remain in the existing atomic input/restart identity. Incumbent
files and ordinary explicitly supplied heat retain their current behavior.

An importer-only test may read the unmodified original Andelst heat section,
including a source project with other active processes. That is component input
qualification, never whole-project execution or permission to ignore those
processes. Full native Andelst still requires macro/drainage/heat/crop composition.

Preserve invariants7/13: invalid input must reject before owner construction;
water/solute/energy gates, whole-generation rollback and exact restart remain.
Qualify literal original source initialization and TTUTIL/interpolation, original
Andelst component mapping, invalid domains, real current coupled file execution,
exact separate-process restart and unchanged incumbent application artifacts.
Checked O0/O2; rebuild changed provider/transitive consumers. Expected<300s per
selected group; unrelated highest low-air, RossFast and broad FCI not selected.

The original Andelst component has112 nodes and SWINCO2. Its thermal profile
can be imported without changing the source project. The existing file water
bootstrap remains SWINCO1 only; no full original hydraulic initialization is
claimed by these component tests. Original rounded texture sums (including1.001)
are preserved; individual source ranges and existing typed parameter validity
apply, without an invented exact-unity constraint.

The checked example is the exact executed two-layer coupled input, with heat
texture rows from the original source. It is a constructed short physical
composition, distinct from the112-node original Andelst input-only proof.

```bash
FC=gfortran python tools/solute/build_column.py --optimization O2 --output /tmp/swap5-native-heat
python tools/solute/run_column.py --exe /tmp/swap5-native-heat/swap5_solute_column --input examples/solute_column/native_heat.nml --swp examples/solute_column/layered_heat.swp --output /tmp/swap5-native-heat-output
```

All pre-existing heat procedure bodies and type declarations remain byte exact
after removing the additive texture initializer/export. The new initializer is
not reached by existing heat/NUT/macro callers. Preserve those original scoped
proofs through this exact code projection and the current original-main file
comparisons; do not describe them as fresh full NUT/macro/FCI runs.
