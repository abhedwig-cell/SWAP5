# PPA-MICRO03 bounded production root sink

Status: bounded local runtime qualification on a stacked MICRO draft branch. Parent
component: PPA-MICRO02 standalone de Willigen evaluator and MICRO01 corrected
matric-flux table. No canonical admission is implied.

The opt-in `micro_de_willigen` physical parameter selects one root sink owner.
The forcing supplies root length density, rooted node count and potential
transpiration. Its ordinary `root_extraction_sink` must be all zero. At each
trial and substep, the serialized Reference backend uses the candidate's
current start pressure and the prepared B1.10 MvG table to evaluate the
MICRO sink. It binds that one nonnegative sink to the existing root provider;
the Richards mass ledger therefore sees the identical vector. Rejected
trials do not publish a new committed state. The evaluator, tables and root
density are worker inputs or scratch, never persistent state or restart data.
The existing Richards temporal-history certificate is required. Its accepted
history is the ordinary backend continuation. The external full/half route
requires bitwise equal states and cannot admit a pressure-dependent root sink.

This slice allows Campbell or threshold de Willigen reduction with normal
uptake (`oxygen_mode=0`, stress factor one), no hydraulic lift and no
relative saturated uptake. The production application rejects post-MICRO
Jarvis/Walsum compensation, Bartholomeus, salinity, root frost, Rutter,
elasticity, direct retention, KSATEXM, snow, frost and temperature effects.
The backend repeats the route guards for callers that bypass the application.
Incompatible or invalid input fails before a sink can reach the solver.

The table adapter samples per node. Exact B1.11 source equivalence is claimed
only for hydraulically homogeneous rooted horizons; arbitrary node hydraulic
heterogeneity and the legacy horizon representative mapping remain separate
work. MICRO stress construction, de Jong van Lier and signed hydraulic lift
remain separate migrations. This opt-in does not change existing root routes.

Qualification requires a compiled production path, a measured accepted
nonzero sink with hard mass balance, rejection without commit, and restart
replay from a captured checkpoint. Source equivalence remains bounded by
MICRO02 oracle evidence, with no new claim for full production trajectory.

The local [O0/O2 evidence](evidence/PPA_MICRO03_LOCAL_RUNTIME_REPLAY.json)
records identical 1.0e-4 cm/d accepted root rates and 1.636603e-16 cm mass
residual. It covers an external double-sink rejection, a failed nonlinear
trial with retry and unchanged committed revision, deterministic replay from
the same checkpoint, and a successful production application commit. The
existing root hydrology runtime source also runs at O0/O2 in that gate. Its
older wrapper pins the exact backend blob and therefore stops on the
intentional backend change before running; its numerical test is compiled
and executed separately without modifying the historical wrapper.

This is local bounded qualification. It does not admit the route into
canonical Status-A or establish a literal full B1.11 trajectory for variable
hydraulics, crop stress, or other MICRO selectors.
