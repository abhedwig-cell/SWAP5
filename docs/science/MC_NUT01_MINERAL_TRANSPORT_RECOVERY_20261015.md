# MC-NUT01 mineral transport qualification and recovery

Bounded daily mineral N route over actual Full Richards transport. Canonical
starting point: ee2d84498bec23c55449f5d7fd8ebd9ecb7bfdde. PR #1231 is the
single work-unit PR. PR #1227 is merged; crop continuation through PR #1229 and
matrix transport through PR #1228 are already canonical. This work preserves
those sources and does not reopen their physical contracts.

The private aggregate inventory retains FOM, biomass and humus, derives their N
from immutable fractions, and owns NH4/NO3 mineral masses. NH4 uses linear
sorption, NO3 water storage. The daily carrier consumes every accepted hydraulic
substep, verifies source attribution, contiguity and hard water closure, then
applies the historical analytical daily transport. Root water extraction is
active; root N extraction, organic turnover and reactions are zero in this profile.
A water trial becomes committed only after the N candidate succeeds. The new
public entry point is run_mineral_joint_interval. Existing water and matrix
production providers are unchanged.

Direct executable: python -B tests/nut-mineral/run_mineral.py --direct.
Four real production providers compile separately at O0/O2. The oracle is the
literal unchanged historical Wofost_SoilWaterN/Detcoef2 source, pinned by SHA256,
not a formula copied from the new production code. All five analytical classes,
inventory balance, replay rejection and opaque restart execute.

Targeted physical qualification: python -B tests/nut-mineral/run_mineral.py.
The explicit fixture has four nodes spanning30cm. It executes two complete days,
outflow then inflow, nonzero root water extraction, sorption retardation, exact
legacy daily balance reconstruction, hydraulic rejection, chemical rejection
following successful hydraulic trial, same-day retry, nine malformed carriers,
wrong identities/configuration, opaque continuation, ten corrupted disk cases,
and independent fresh-process continuation. Physical endpoints match byte for
byte across O0/O2 and both restart paths. The qualified composition uses the
Richards temporal-history family. No portable cross-compiler disk ABI is claimed.

The small process closure costs1.1905s compile/.0630s link/.00265s native across
both optimizations. Actual physical composition necessarily imports the real
accepted-state/backend/restart interfaces:235 providers,108.524s compile/.2576s
link/18.5088s native. This large composition closure does not replace the four-
provider local feedback seam. Generated fixtures, exact commands, raw outputs,
failed/censored attempts and recoverable execution Git bundle are versioned in
the physical capsule. Seventeen independent source/evidence negatives pass.

The full local moving gate is selected once because two incumbent admission
eligibility guards changed. It runs with FCI_RESUME_MODE=OFF. Original CO2 owner
verification executes unchanged at the exact ee2d8449 baseline after the complete
additive delta is checked, rather than silently reinterpreting old evidence as
new N qualification. The new route has separate source-bound physical proof.
No long highest-low-air run is selected, and no global GitHub-green claim is made.

Production restrictions: exactly one day, complete modeled column, zero top flux
and ponding, no macropore/SSDI/optional chemical store, no simultaneous external
inflow/outflow. No crop N, amendments, organic reactions, age, aquifer, general
solute or simultaneous matrix-plus-N application is promoted. Capability master
counts and full NUT/SOL dispositions are unchanged. Next dependency-ready work:
source-bound organic turnover and NH4/NO3 reaction ownership, followed by explicit
crop-N supply/demand and a combined chemical commit contract where needed.

Future crop-N integration must preserve the accepted WOFOST81 fixation semantics. Historical B1.11 fixation is not admitted by this bounded mineral route. The disk decoder bounds N revisions to nonnegative values at most100000000; cross-platform/ABI portability and extreme-duration trajectories are outside this qualification.

Terminal full moving result: **PASS**, return0, FCI_RESUME_MODE=OFF, wall 1411.227 seconds, 6228 tracked input hashes unchanged during execution. Actual execution 6a1c3b7f157b8dc6f687c268f52e8991234469d0; source tree f3ebea90ec20ff52e97e42c26d59673519089a28.

The status is the frozen premerge receipt. Read [PR #1231](https://github.com/abhedwig-cell/SWAP5/pull/1231) for its actual merge and canonical source/tree verification. All later closeout changes are additive evidence/recovery documentation and non-executable status metadata. Original scientific inputs and guard-consumed status fields remain exact.
