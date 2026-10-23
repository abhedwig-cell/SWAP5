# Actual native coupled grid observations

Qualified bounded research, 23 October 2026. Execution baseline93c462522;
reconciled with canonicalf729f0b. This study does not admit native full-year or
active-crop spatial accuracy and does not change production, policy or tolerances.

The actual native120-cm project from the admitted refined-year capsule supplies
all original soil, chemistry, weather and crop files. Only NCOMP subdivision
counts change:41,82 and164cells subdivide the same three sublayers, preserving
soil boundaries and the original small dispersivities0.01/0.02cm, nonlinear
Freundlich exponent0.5, bottom flux and surface/crop/weather forcing. Implicit
upwind, continuous Picard conductivity, historical-zero-solute exfiltration and
temporal tolerance1e-4 remain unchanged. Native initial stock quadrature is
reported rather than normalized away. These are constructed supported inputs
with original1998 weather, not the original full Andelst model.

A fresh checked O2 build compiles194 physical and153 original TTUTIL providers.
Two prefixes are retained, including the unsuccessful cost selection:

| Period | 41cells | 82cells | 164cells |
| --- | --- | --- | --- |
| 8days | complete,61.19s | complete,156.18s | censored at180.10s |
| 2days | complete,19.25s | complete,50.04s | complete,127.18s |

Censoring is not a failed physical gate or a PASS. The incomplete pending files,
return status and raw streams remain in the capsule. The three-grid2day phase
changes only the observation horizon. No64day extension is selected from these
measured costs. Native times are local measurements, not portable speed claims.

Conservative aggregation puts every finer grid back onto the same41base cells.
The profile metric is the sum of absolute differences in dissolved-plus-sorbed
cell stocks, divided by the finer-grid total soil stock. It measures change
between discretizations, not error against a known coupled exact solution.

| Period and grids | Relative soil-stock L1 difference | Maximum common-bin aqueous concentration difference (mg/cm3) |
| --- | --- | --- |
| 8days,41 versus82 | 0.5389% | 0.04763 |
| 2days,41 versus82 | 0.18735% | 0.03817 |
| 2days,82 versus164 | 0.12327% | 0.02563 |

The2day stock difference falls by about34% under the second refinement. This
supports decreasing discretization sensitivity over this short interval; it
neither establishes an asymptotic convergence rate nor bounds full-year error.
The native starting solute stocks are76.52935476,76.47954148 and76.47867658mg/cm2;
the41-to82 initial-stock difference is about0.065%. These initial differences
are part of the mesh experiment, so later profile differences cannot all be
attributed to transport alone. Local concentration differences can be larger
than the global stock metric suggests.

All completed days satisfy independent daily water/solute reconstruction,
gross water and terminal stock reconstruction at the unchanged1e-10 gates.
The largest retained water/solute/gross-water residuals are respectively
2.413e-14cm,9.627e-14mg/cm2 and2.405e-14cm, rounded upwards. Stocks remain
nonnegative. These January prefixes contain zero active crop days and zero
runoff: they do not newly qualify uptake, runoff sensitivity or crop-season
accuracy. Original future crop files remain bound as native inputs.

During the experiment canonical added seasonal-bottom orchestration in four
front-end files. The production SRC tree stayed identical. The study keeps its
actual historical source snapshots rather than silently relabeling82/164runs as
current executions.193verified unchanged physical objects were reused to freshly
compile/link the new current reader/caller. A new41cell2day current execution
matches all state.csv,endpoint.csv and budget.csv bytes exactly. Restart bytes
are not claimed equal across differently source-bound input documents. The
current seasonal source/raw owner and30controls pass. This bridge and the
explicit four-file pre/postimage inventory are sealed separately in the same
capsule; it is not an extra current82/164execution claim.

STATUS.json and OBSERVATIONS.json own scope, measurements and recovery. The
1428-member capsule retains raw source/build/run evidence, inherited authority
references by SHA256 and six discriminating corruption/false-claim controls.
Recheck with verify.py --capsule EVIDENCE.tar.xz.b64 --expected-sha256 followed
by the value from EVIDENCE_INDEX.json; add --self-test for rejection controls.

Native profile accuracy remains open. The earlier constant-water pulse study
already shows that conservative positive upwind can still spread a narrow pulse.
A wider coupled accuracy envelope or a separately qualified less diffusive
policy is needed before claiming whole migration completion.
