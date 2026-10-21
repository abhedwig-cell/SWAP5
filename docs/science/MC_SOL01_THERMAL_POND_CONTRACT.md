# MC-SOL01 dynamic thermal pond and file application

Proposed successor, baseline fda2a6de35ab60e8c836a6687482efa3774d95dc.
This implements the requested composition of the existing numeric heat and
nonlinear soil Freundlich 0.5..2 routes with the accepted persistent dissolved
pond. It reuses production water, heat, surface mixing, transport and decay.
There is no sorbed pond pool and no new process equation.

Within each explicit reporting/coupling interval the detached Reference
water/heat endpoint supplies a node temperature vector to all that interval's
accepted chemical water receipts. This is the already admitted endpoint split,
not historical substep-temperature identity. Coupling interval refinement is
required; a long run alone does not establish seasonal accuracy. Original
chemical configuration remains immutable. Original external water/heat and
chemical owners publish together only after whole water/solute balance and
endpoint alignment pass. Heat-off retains the historical zero decay factor.

A separate S5PT0001 same-platform POSIX generation carries the physical
water/heat state, chemical configuration, dissolved/sorbed inventories and pond
mass. It uses the existing CRC, staged file, fsync, rename and directory fsync
publication pattern. All identities and owner matching precede either assignment.
This route uses no numerical history, matching the existing evolving pond
forcing contract. S5MT0001 and incumbent joint codecs remain unchanged.

The opt-in file application gains explicit nonlinear/decay/thermal inputs;
legacy inputs retain disabled heat, linear sorption and zero decay. Numeric heat
uses explicit surface temperatures and a zero bottom heat flux; no pond heat
capacity or heat exchange law is invented. Surface temperature is a prescribed
soil heat boundary. Seasonal meteorological derivation remains outside scope.

Affected invariants: 2, 3, 7, 9, 13, 21, 23, 25, 27, 29. No solver, tolerance,
retry or physical acceptance change. Select focused O0/O2 actual production
composition, independent literal/quad oracle, gross sources/losses, heat-off,
chemical/hydraulic rollback and retry, refinement, native restart and semantic
CRC negatives; fresh original file-application preservation. Estimated compile
180 seconds and native assessment under 180 seconds initially. Reuse only exact
same-session provider artifacts; physics-only timing UNKNOWN. Full moving F-CI
NOT_SELECTED_IMPACT pending evidence; highest low-air NOT_SELECTED_POLICY.
RossFast frozen, aquifer excluded. Full historical .swp/default, snow/exfiltration,
analytic heat and age/N companions require separate authority.

## Executed local qualification

GNU Fortran 13.3, checked O0/O2: 279 providers and the direct production driver
pass all six soil exponents 0.5, 0.8, 1, 1.0005, 1.5, 2. The accepted nonuniform
heat profile drives the independent literal source-order surface/transport/decay
oracle and existing real128 Freundlich inverse. Eight coupling meshes, 2..256
intervals over 0.002 day, have strictly decreasing inventory and decay differences.
The last relative decay differences are 0.000508, 0.000441, 0.000408, 0.000408,
0.000357 and 0.000341 respectively, below the unchanged 0.001 gate. Water and
solute gates remain 1e-10 cm and 1e-11 mg/cm2. Fresh-process complete-generation
restart is exact on every mesh. Chemical overdraw rejects staged heat/water/pond;
a smaller retry succeeds. Invalid water, nonfinite clocks, exponent limits,
analytic heat and heat-off controls retain the original assertions.

Another 96 valid-CRC semantic generation rejections and 24 actual SIGKILL
before/after rename observations pass, with exact complete-generation recovery.
The first driver build omitted a numerical-config import; it is retained. An
initial high-conductivity pond fixture rejected hydraulically; the established
low-conductivity evolving pond fixture is used instead. A 1e7 overdraw parameter
was outside the incumbent pond's 1e6 domain and could never reach chemistry;
the corrected 1e6 fixture proves actual overdraw rejection and smaller retry.
No acceptance tolerance, retry budget or process equation is relaxed.

The current file application builds from 187 providers. All 86 original input,
grid, balance and restart observations pass; 160 original application budget,
endpoint, state and restart artifacts remain byte-exact against the admitted
predecessor. New thermal files include temperature.csv in the generation hash
inventory. Both optimizations execute 30-day and 365-day prescribed sinusoidal
soil-boundary runs for exponents 0.5, 1 and 2, at 1, 2 and 4 windows/day, with
positive rain/runon, runoff and nonexporting pond evaporation. Independent fresh
restart at half of each finest-grid run reproduces every physical/chemical byte.
Maximum annual per-window residuals are 5.83e-16 cm and 1.90e-13 mg/cm2.

Monthly successive inventory differences decrease. Annual whole-inventory
successive differences are about 0.46..0.90e-6 mg/cm2 and are not strictly
monotone; endpoint heat changes by about 0.0172 C between half-day and quarter-day
sampling. These are measured grid spreads, not proof of asymptotic order or a
complete seasonal/historical accuracy domain. The synthetic four-node 3-cm
prescribed-boundary case is not a meteorological/regional validation. The
original long dry-infiltration solver failure remains excluded and unchanged.

The source-bound capsule and the existing status record retain all commands,
raw source oracles, native logs, inventories, CRC mutations, failed observations
and compile/link/native costs. Direct driver O0 was resumed from exact successful
same-session providers after its import repair; O2 is a fresh build. Every
scientific executable executes independently. Direct physical compile/link/native
costs in the successful report are 132.49/0.40/2.22 s, excluding the separately
retained first O0 provider build. Annual application controller/native wall time
is 38.59 s for 30 processes. Physics-only time remains UNKNOWN.
