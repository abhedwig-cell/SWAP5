# PPA-MICRO05 literal MvG and runtime horizon map

Status: local O0/O2 qualified, proposed stacked draft, canonical admission
pending. Parent: MICRO04 first-node table adapter and MICRO03 bounded trial
root sink.

The source oracle compiles the complete unmodified B1.11
`MOD_MvG_functions.f90` and the exact `RWU_micro.f90` nonlinear code. The
latter receives only the already disclosed MICRO01 dry table repair and test
visibility. Two MvG horizons have distinct first-node coefficients; other
nodes deliberately differ within their horizon. The exact source
`nod1lay/layer` lookup and typed first-node map must return the same M/K for
the sampled dry, intermediate and wet heads. The B1.11 `ksatfit(lay)` wet
extension is set from the representative node's saturated coefficient and
compared explicitly. Normal de Willigen sinks must match per node within
2e-5 cm/d with all source convergence checks true for equal and varying
pressure heads, with uptake in both horizons. O0/O2 results must be identical.

The production parameter owner may carry a validated optional
`micro_horizon_first_node(:)` map. Without the map, the MICRO03 homogeneous
rooted hydraulic guard remains. With it, immutable tables are sampled from
the declared first node and the existing one-sink trial, mass, rejection and
restart semantics apply. The map is parameter data, never persistent state.
An application trial with two hydraulically distinct horizons commits with
hard mass accounting; direct checkpoint replay preserves sink, mass and time
exactly, and a noncontiguous first-node declaration is rejected. The
MICRO03 one-sink and rejection tests and ROOT-HYD01 numerical preservation
are rerun under both compiler optimization modes.

The source comparison covers standard MvG model 1 with no hydraulic power
tail, KSATEXM, hysteresis, tabulated hydraulics, elasticity or signed lift.
Those routes remain excluded from production. Literal source comparison and
local production qualification do not imply canonical Status-A admission.

Evidence: `docs/audits/evidence/PPA_MICRO05_LITERAL_MVG_LOCAL.json` and
`docs/audits/evidence/PPA_MICRO05_HETEROGENEOUS_RUNTIME_LOCAL.json`.
