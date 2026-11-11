# Actual original thermal carrier inventory

Baseline: canonical a0c07487c944ff7da2a7e3b502aa725f687e480a, PR1643.
Owner: original-block application heat bridge; read-only observation only.

Question: can actual accepted original water paths and their donor temperatures
form the existing conservative-heat request without inventing thermal inputs?
Acceptance evidence is same-step original q/theta/temperature/root/drain/macro/drip
data, independently reconstructed nodal water closure, accepted-day chronology,
source/build/checkpoint binding and unchanged complete physical/native endpoints.
Unknown external temperatures and gas carriers remain unavailable. Actual local
soil endpoints are reported, not asserted to be exact integrated advective heat.

The original `fluxes.f90` recurrence fixes signs and units: q is upward-positive;
root extraction and lateral drainage are outward-positive; macro/drip are inward.
qimmob enters the original theta increment without multiplying by dt. For macro
mode the original matrix area fraction weights dz and water-content increments.
Drain inflow/outflow are exported separately before summing levels; simultaneous
opposing levels must not disappear in a net sum. Macro exchange is explicitly a
net path, not resolved macropore-domain thermal inventory. It cannot qualify
macropore energy. Gas displacement cannot be reconstructed uniquely from theta.

Implementation is opt-in `--carrier-inventory` in the existing bounded original
heat qualifier. It inserts only marked read-only blocks, stripped text must equal
the entire original source after the already declared line-ending normalization.
The default observer profile, original physics, public host, state/restart schema,
input files, shared production modules and tolerances are unchanged.
New generated source and executable identities distinguish the observation profile.

`thermal_carriers.read_accepted_carriers` omits unaccepted days, checks actual
faces/nodal recurrence and complete chronological support, and retains missing
active donor paths. Every nonzero amount matters, without a donor-availability
cutoff. Full energy remains false even if all observed liquid paths are outward:
gas, unobserved reservoirs and the advective integration policy remain separate.
The existing1e-10cm water and1e-8day clock budgets are retained.

Selected smallest generic proof: original Hupsel4-to6 gift, Grass2-to4 and
Andelst2-to4, each existing O0/O2 kernel/storage owner with original temperatureO2.
Only original temperature and the four small existing observation/accounting
objects relink against immutable PR1641 objects/input/checkpoints. No full project
or reference execution. Native cohort cap240s; compiler/link cap45s each.
Windows first; Ubuntu same sources and original objects if the local proof passes.
No physics repair is selected: absent actual donor measurements would be a
reproducible data/formulation boundary, not a migration implementation error.
