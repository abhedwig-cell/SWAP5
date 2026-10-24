# Native FCT refinement observations and four-day continuation

The unchanged PR1419 research caller completes18 cases/30 native processes at
checked GNU13.3 O0/O2. Six four-day nonlinear active-crop cases (Freundlich0.5,
1,2 and TSCF1) reproduce full restart.bin, endpoint.csv, state.csv and continued
budget rows exactly after independent process restart at day2. Numerical O0/O2
profiles agree exactly. Maximum independent water residual is1.996e-14cm and
chemical residual5.797e-13mg/cm2. Surface storage empties; real root uptake and
positive drainage continue. This extends constructed duration from0.4 to4days.

For the0.4day linear-sorption active-crop trajectory, nested meshes subdivide
every original cell while keeping120cm depth, soil interfaces and rooting depth.
Per-cell drainage scales inversely with subdivision, preserving total extraction.
Fine profiles are aggregated to the original41 finite-volume bins without point
interpolation or mass renormalization. Both optimizations execute every mesh and
tolerance case, in addition to a separately retained41cell pilot.

| Conservative L1 profile difference | 41 versus82 | 82 versus164 |
| --- | ---: | ---: |
| Water,cm | 0.00726910 | 0.00391471 |
| Dissolved chemical,mg/cm2 | 0.0377882 | 0.00518143 |
| Sorbed chemical,mg/cm2 | 0.0263290 | 0.00170952 |
| Total chemical,mg/cm2 | 0.0640973 | 0.00688788 |

Initial chemical stocks are70.9630321,70.9048595,70.9048629mg/cm2 respectively.
The coarse/fine initial stock difference0.0581726mg/cm2 accounts for much of the
first profile discrepancy. Original concentration-table sampling is retained;
these data cannot isolate transport truncation error or establish an accuracy
order. The initial water stocks including0.1cm pond are30.9619820,30.9621246,
30.9621602cm. No initial condition is normalized to hide grid dependence.

At41cells the0.001/0.0005/0.00025 hydraulic temporal tolerances give successive
total-chemical L1 differences7.06269e-5 and5.33372e-5mg/cm2; water differences
8.82829e-5 and6.66709e-5cm. Both decrease, but three tolerances do not establish
asymptotic order or a general temporal error bound. No1e-6 experiment is used.

All201 physical/application providers compile freshly at each optimization;
all153 immutable original reader providers also compile freshly because prior
local builds were unavailable. Checked build times total28.749s O0/81.635s O2;
native process times52.598s O0/27.087s O2, including pilots and restarts. These
are execution costs, not portable performance comparisons. Every generated
Fortran source matches the admitted PR1419 source postimage byte for byte.

The capsule retains raw inputs, output files, native binary restart states,
process return codes/timings/streams, generated sources, original reader sources,
compiler commands/streams, scientific input snapshots and raw build commit.
Eight controls reject missing restart/profile/source/owner evidence, changed
drain scaling, layer interfaces, a numeric sorbed-mass perturbation, and loss of
the analytical empty-pool limit. PR1419's original eight controls and the current
composed owner's13 controls pass; its316 predecessor controls remain frozen
evidence, not316 freshly executed controls.

No production/default/source-dispatch change or master capability promotion.
These are constructed constant-forcing experiments with authentic original SWP
water/chemistry bootstrap. Historical weather, seasonal/annual FCT, general
nonlinear native accuracy, upward top chemical return, heat/age/macropores and
full MC-SOL01 remain open. The next discriminating accuracy experiment should
explicitly qualify consistent conservative initial data across nested meshes;
the next historical trial must first address the unsupported upward top flux.
Actual canonical admission is recorded separately after merge verification.

Reproduce with the unchanged fct_native_domain/build_native.py, then this unit's
run.py (--phase pilot/refinement/duration), seal.py and verify.py. The archived
evidence verifier does not require the compiler or executable to be installed.
