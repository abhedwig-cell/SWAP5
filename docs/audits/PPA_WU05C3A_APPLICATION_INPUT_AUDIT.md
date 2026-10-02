# C3A actual application input audit

Date: 2026-10-02
Classification: SHARED_INTEGRATION_DECISION_REQUIRED, not physics falsification.
Audited candidate: 5f28db3e5997d30aeb619e6815c447b56c9eceff.
Audited canonical: 828df126e0c0d70f5cbfae51614bfc3b53e832a4.

## Exact source authority

The qualified reconstruction was used, not an alternate uploaded source tree:
oxygenstress SHA-256 8c0c27c780b797c829c207a5e96bcb8951dd5399182c55094ffbb88165711a87;
source manifest 24ce2768b3804ca1744457e8a7adcf101e37a4c1390049df23179e09816957e2.

The previous repair result's shorthand "absolute root length/biomass" is narrowed
by this audit. It does not mean that the oxygen solver needs an independent
root-length state or an additional crop-state owner.

| Candidate input | Corrected B1.11 binding | Role / owner |
| --- | --- | --- |
| w_root(node) | 1 / SRL | kg/m root, crop construction parameter; repeated across rooted nodes |
| w_root_z0(node) | wroot_node_top(node) | kg/m3, crop-derived current profile view |
| soil depth_m(node) | 0.01 * dz(node) | compartment thickness in m, not cumulative depth |
| soil temperature K | tsoil(node) + 273 | current thermal owner; exact legacy conversion |
| matric potential Pa | -100 * h(node) | current hydraulic owner; nonnegative-head shortcut first |
| atmospheric C_top | 672 / (8.314472 * (tav + 273)) | current atmospheric forcing, kg/m3 |
| percent organic matter | 100 * orgmat(layer(node)) | immutable soil construction input |
| percent sand | 100 * psand(layer(node)) * (1-orgmat(layer(node))) | immutable soil construction input |
| waterfilm alpha per Pa | 0.01 * cofgen(4,node) | analytical-MvG construction parameter |

In corrected MOD_cropdevelopment.finalize_wroot_node, nodal root weights are
derived from differences of cumdens_top and WRT, then interpolated using dz and
converted by 1e-4/(1e-2*dz). This exact routine has a surface expression referencing
node 2. A new single-rooted-node implementation must not invent its behavior;
the crop-owner contract and reference fixtures must resolve that boundary.
This is an untested binding boundary, not a newly qualified legacy defect.

The six precomputed arrays in oxygenstress.calc_ini_pars depend on the actual
watcon evaluations at campbell_h100, campbell_h500 and gfp_h100 and on cofgen.
The qualified hydraulic construction, including applicable initial hysteresis,
must materialize them. An arbitrary fit from current theta is not equivalent.

## Canonical producer audit

All 22 Fortran files under src/crop at the pinned canonical were read and checked
for SRL, specific_root_length, wroot_node_top, c_mroot, q10_root, rootradius,
root_radius, specific_resp_humus and q10_microbial. None declares those bindings.
This scoped check is not a claim that every repository file lacks such strings.

mod_wofost_actual_biomass_state exposes actual_root_biomass, but total biomass
alone does not establish wroot_node_top or SRL. mod_wofost_rate_parameters contains
WOFOST RMR/Q10; it does not establish equivalence to Bartholomeus c_mroot/q10_root.
Do not alias these named quantities without dedicated authority and evidence.

mod_crop_root_uptake_input_contract and its runtime adapter carry emergence,
potential transpiration, rooted count and cumulative root fractions only.
mod_fmr_root_uptake_process_binding still evaluates drought-only uptake.
mod_fmr_wofost_physical_trial_binding accepts a separately prepared finite
root_extraction_sink; it does not construct oxygen inputs.

Crucially, the serialized backend already accepts the composed root sink.
Changing its forcing schema or water ledger is NOT intrinsically required.
The gap is the actual upstream crop/configuration/view producer and application
call site, not another solver-side oxygen owner.

## Proposed minimal shared integration contract, not accepted authority

- Workstream: PPA-WU05-C3A plus central runtime/crop integration.
- Exact baseline: canonical and candidate SHAs above.
- Owned surface: existing oxygen parameter/physics/factor/sink-composition modules.
- Read-only authorities: corrected B1.11, qualified C3Q/C3P, hydraulic/thermal
  contracts, existing root sink and transaction/ledger ownership.
- Proposed allowed addition: separate read-only crop oxygen parameter/profile
  provider, configuration selection and one application-level composition caller.
  Do not expand the drought-only crop contract merely to carry optional oxygen.
- Interfaces held fixed: serialized backend forcing and ledger, kernel transactions,
  existing drought evaluator, hydraulic and thermal owner contracts.
- Dependency surface: actual crop profile construction, atmosphere and matching
  committed/candidate hydraulic/thermal staging, immutable analytical-MvG data.
- Required qualification: source-bound assembled replay within SOLVE accuracy 1e-4;
  oxygen OFF exact preservation; unsupported routes fail closed; single/multiple
  rooted nodes; negligible demand; no roots; immutable-data sharing/hysteresis;
  actual application call; one composed root sink; rollback and preservation.
- Cross-workstream consequences: read-only crop publication and application staging
  selection must be agreed before implementation on shared surfaces.
- Canonical admission owner: central SWAP5 regie, as existing registry states.

The integration decision must state the actual producer and staging point.
An additive DTO populated only by a test would not close the gap. The proposal
does not authorize this branch to select a new crop owner or publication policy.
Quality governance sections 5-6 require returning this shared decision to central.

## Executed preservation and status

Executed persisted postimage: 6d3d47e1fe46a5ce0402f76b64289717c068207b.
Connector readback confirmed exact content identity for both commented source
files, this audit and the status checkpoint before the final rerun.

The existing narrow runtime, active-chain, admission-boundary, C3A preservation,
C3P composition/activation and C3Q kernel gates were rerun locally with GNU
Fortran 13.3.0. Their executed markers and exit codes are recorded in the status
checkpoint. No GitHub Actions were requested for this read-only producer audit.

Only explanatory source comments were added. There is no new physics route,
crop state, sink booking or application caller. PR #962 remains draft; canonical
admission and post-merge preservation are not claimed.

The exact GitHub comparison reports 149 commits ahead / 204 behind, 75 added
files and no existing canonical file changed. This independently confirms that
the candidate does not yet modify an existing application caller. It also
requires canonical reconciliation before admission, even after the shared input
decision is resolved. PR #962 was checked open/draft with this tested head.
