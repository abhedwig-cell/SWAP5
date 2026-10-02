# C3A boundary repair qualification and application routing

Date: 2026-10-02
Status: REPAIRED_FOCUSED_GATES_PASS / SHARED_APPLICATION_BINDING_AUTHORITY_REQUIRED
Tested production/test postimage: f8b1055111e5c4ebb64014d0432c774383b6f5a8
Canonical read-only reference: 828df126e0c0d70f5cbfae51614bfc3b53e832a4
Compiler: GNU Fortran 13.3.0. All tests executed locally. No Actions requested.

## Reference recovery
Existing canonical B0 distribution identity: 2b48353db6cdf00246a1e5c0dcaafc2c61858729fad18446a1dc66359ec2a360.
tools/vq/b1_11_reconstruct.py completed qualified_reconstruction=true.
Source tree: 63 members / 1886519 bytes.
Manifest: 24ce2768b3804ca1744457e8a7adcf101e37a4c1390049df23179e09816957e2.
Corrected oxygenstress: 8c0c27c780b797c829c207a5e96bcb8951dd5399182c55094ffbb88165711a87.
An alternate stored SWAP.ZIP was not treated as canonical: its archive hash differs.

## Repairs
1. Source-bound GFP<1e-4 shortcut returns RWU=0 and advances C_top=0.
2. Nonnegative hydraulic head forces the same saturated shortcut.
3. Waterfilm is skipped for shortcut nodes, before zero diffusivity can reject MACRO.
4. Immutable crop/soil parameters, runtime shapes and finite values are validated.
5. NaN/Inf may not silently become a successful full-stress sink.
6. Empty-root and zero-root-extraction routes preserve the existing sink after configuration selection.
7. Exact legacy conversions restored: soil temperature C+273, matric potential -100*h.
   C+273.15 and abs(h)*98.0665 were unqualified changes in the assembled candidate.

No accepted oxygen continuation state or second water booking was introduced.
The original negative record remains historical evidence, not erased.

## Executed gates on persisted postimage
- PPA_WU05C3A_ACTIVE_CHAIN=PASS
- PPA_WU05C3A_ADMISSION_BOUNDARIES=PASS (failure count 0, saturated accepted,
  NaN parameters rejected, NaN physics rejected)
- C3A_DYNAMIC_OFF=PASS
- C3A_DYNAMIC_ACTIVE_NONROOTED_SINGLE_SINK=PASS
- C3A_SATURATED_VERTICAL_PROPAGATION=PASS
- C3A_GFP_THRESHOLD_PRESSURE_SHORTCUT=PASS
- C3A_NAN_INF_RUNTIME_REJECTION=PASS
- C3A_NO_STRESS_POLICY_SHAPE_ABA=PASS
- C3A_NO_ROOT_ZERO_DEMAND_FAIL_CLOSED_SELECTION=PASS
- PPA_WU05C3A_DYNAMIC_RUNTIME_BOUNDARIES=PASS
- C3A_EXECUTION_STATIC_OWNERSHIP=PASS
- PPA_WU05C3P_ROOT_OXYGEN_COMPOSITION=PASS
- PPA_WU05C3P_ACTIVATION=PASS
- PPA_WU05C3A_PRODUCTION_PRESERVATION_GATE=PASS
- PPA_WU05C3Q_KERNEL_SMOKE=PASS
- PPA_WU05C3R_MACRO_ZERO_DEPTH_CHECKS=27
- PPA_WU05C3R_MACRO_ZERO_DEPTH=PASS
- PPA_WU05C3R_SCALAR_BRACKET=PASS
- PPA_WU05C3Q_ROOT_COMPOSITION=PASS

All invoked gate scripts exited 0. Persisted content identity was checked for
changed physics, runtime and harness files. Active/runtime gates compile the actual
hydraulic and thermal owner types. Only their unrelated abstract transaction base
is stubbed to avoid the full transaction graph.
Linker emits the pre-existing executable-stack warning from the internal residual callback.

This qualifies the repaired narrow runtime seam, not the full application loop.
C3Q source-input MICRO/MACRO replay evidence is not reinterpreted as assembled
application parity. A full source-bound application replay remains required.

## Concrete shared integration boundary

At the pinned canonical:
- src/crop/mod_crop_root_uptake_input_contract.f90 exposes crop_emerged,
  potential_transpiration, rooted_nodes and cumulative_root_fraction only.
  It does not carry Bartholomeus root length/biomass, specific-root-length-derived
  quantities, senescence or maintenance-respiration inputs.
- src/runtime/mod_fmr_root_uptake_process_binding.f90 calls the existing drought
  uptake process and has no selected Bartholomeus call/input binding.
- src/runtime/mod_fmr_serialized_reference_backend.f90 exposes an already-composed
  root_extraction_sink in fmr_b110_physical_forcing_t. It does not configure an
  oxygen process or provide its current crop inputs through that forcing contract.

Root fractions cannot be silently substituted for absolute root length/biomass.
A copied temperature or static oxygen factor must not substitute for owner-consistent
current views. Calling the new routine only from a test is not production integration.

Required shared decision:
- issue an additive read-only crop oxygen input contract from the actual crop owner;
- define construction-time immutable dataset materialization, including hysteresis key;
- select the application-owned staging point with matching hydraulic and thermal views;
- compose once into the existing backend sink, retaining solver/ledger ownership;
- retain fail-closed groundwater tangent/parallel envelopes.

Owning route is central SWAP5 regie plus production runtime/crop owners, under
docs/development/quality-governance-a-aa.md sections 5-6 and the PROJECT-CONTROL
shared-interface rule. This branch did not silently widen those common contracts.

## Current decision
Focused implementation defects repaired and tested. Canonical admission is held.
The local semantic-expansion stop is the shared crop/runtime input authority above,
not missing source files, a compiler, a runner queue, or a request for a new upload.

PR #962 remains draft. No merge, canonical success, post-merge preservation or final
migration closeout is claimed.
