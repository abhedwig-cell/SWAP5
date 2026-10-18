# MC-SOL01: SWAP5 Reference surface-water chemistry decision (2026-10-18)

Status: **approved scientific model direction; implementation admission remains evidence-gated**.

## Decision

The owner explicitly selected the **new SWAP5 formulation** as normative for Reference-only MC-SOL01 positive runon and runoff. This is an intentional physical model extension, **not** a claim of exact SWAP4.3.1 equivalence for runoff chemistry.

The existing historical B1.11 infiltration concentration expression remains the required zero-runoff regression. For positive runoff, mix the available persistent pond mass and externally loaded rain, irrigation, and supported explicit-concentration runon in the accepted pond water. Compute the shared concentration using end pond depth plus the integrated infiltrating water and accepted runoff depth, and export runoff solute separately at that concentration. Pond evaporation removes water, not solute. The sole committed pond mass owner remains the matrix solute companion. Reject chemically unsupported water sources instead of silently treating them as clean.

For a substep with signed upward-positive qtop, dt in days, runoff depth in cm and concentrations in mg/cm3:

- available mass = committed pond mass + dry deposition + rain mass + irrigation mass + explicit runon mass;
- when infiltration qtop < -1e-6 cm/day, cpond = available / (pond_end - qtop*dt + runoff_depth);
- soil transfer = -qtop*dt*cpond for the currently supported zero macropore fraction;
- runoff export = runoff_depth*cpond;
- retained pond mass = available - soil transfer - runoff export;
- when infiltration does not pass the historical cutoff, soil transfer is zero, and positive runoff uses cpond = available/(pond_end+runoff_depth).

Every accepted substep must pass separate water and solute mass balance checks. Hydraulic and chemical candidate commits remain atomic; rejected attempts and timestep retry cannot publish chemical or water state. Native V2 restart must reproduce full positive-gross continuation in a separate process.

## Scope and qualification boundary

Reference is authoritative for this functionality. RossFast remains frozen optional and UNSUPPORTED_OPTIONAL for the new gross-source/pond-solute contract; protect its previous admitted functionality without inventing a new RossFast qualification.

Source audit: archived SWAP4.3.1 solute.f90 (SHA256 2fc8592001cdcd2de95a252d8b9099416c94e4d2654c335908858a735f80e7a2), lines 345-355, lacks this positive runoff export law. The difference is explicitly accepted as a SWAP5 science decision.

Qualification evidence already executed on prior source head: Actions 39109105991, SUCCESS, O0/O2 Reference production, gross positive runoff/runon physical joint, mass closure, rejection, native V2 independent-process continuation and preservation; see PR #1303. This evidence covers its actual postimage and is not automatically a qualification of this decision-only commit.

**Admission remains conditional** on source-impact reconciliation, applicable mandatory preservation controls and repository owner admission/rules. Do not promote mastercoverage or merge merely because this decision exists. Aquifer remains excluded.

## Integration finding, 2026-10-18: frozen shared contract

The clean canonical PR #1304 passed its own actual O0/O2 Reference qualification (Actions 39110944590) but the RossFast owner preservation deliberately failed in Actions 39110944702: `src/solver/mod_soil_water_solver_contract.f90` has a new shared result/diagnostic layout. The immutable FROSS22 qualified preservation runner explicitly pins the canonical solver contract to the previously admitted source blob (plus named, admitted successors); its moving-canonical mode does not authorize the PR itself to mutate the contract. The optional/frozen RossFast policy is **not** permission to bypass this test.

This is a structural source-ownership conflict, not a positive-runoff solute mass-balance failure. A safe admission must either (A) preserve the original shared solver-contract blob exactly and move final-converged gross-source publication to a new private Reference-owned diagnostic interface (with transactional provenance, complete module compilation, native restart and relevant prior-owner preservation), or (B) independently qualify an explicit shared-contract successor including existing RossFast preservation and its owner admission, before amending the exact-source authority. Merely editing the expected SHA, excluding the contract file from a test, or turning off the preservation workflow is forbidden.

F-ROSS12's separate compile error `mod_drainage_dramet3_response.mod` indicates an incomplete legacy compilation closure. It does not demonstrate a numerical RossFast regression, nor can it be called PASS. Fix that closure only when justified by the admitted RossFast preservation owner.

Current PR #1304 remains deliberately draft until the structural contract problem is resolved with owner-backed proof. This documented diagnosis changes no physical source and never constitutes acceptance.


## Canonical admission closeout, 2026-10-18 (supersedes the earlier draft/blocker status above)

The Reference-only positive-runon/runoff formulation was **canonically admitted** through [PR #1304](https://github.com/abhedwig-cell/SWAP5/pull/1304), merge `ce0291246e9bb732388214098a7a9fe0f44f4a5e`, qualified candidate head `0cc3fe1ff61bb9fc9d082c8958b80d050d1d8cfc`. Earlier sections retain the historical investigation and must not be read as the current PR state.

The original shared-interface conflict was resolved by placing the converged surface result and exact gross forcing source provenance in the Reference-owned workspace. Both shared postimages remained exact against their canonical counterparts: `mod_soil_water_solver_contract.f90` blob `7b16c3fcf58179f1491104a1dce3279010b4178a`; `mod_b110_dynamic_top_boundary_solver_adapter.f90` blob `abe2d699017300e890eeb69a56448bb071660d2d`. RossFast implementation is unmodified and remains optional/frozen on its previous domain. Three missing DRAMET3 compile dependencies were repaired in preserved test source lists; existing full first-parent preservation retains immutable qualification checks.

Actual **final-head** hosted gates all SUCCESS: F-CI96 preservation run `39115709736`; existing F-ROSS12 production wiring run `39115709442`; PUB-P1E02 Reference production / O0,O2 positive gross chemistry, balance, rejection, rollback, continuation run `39115709818`. Earlier failing gates and recovery runs remain historical evidence, not separate successes.

After merge, the GitHub canonical head was verified exactly equal to `ce0291246e9bb732388214098a7a9fe0f44f4a5e` and the MC-NUT01 Soil-N postimage blob `771f01ec201b5807a9e3cb0f36db9a747be95186` was preserved. No distinct numerical postmerge rerun was observed or claimed.

The admission is **bounded to this Reference-only surface-solute formulation**. It does not admit unsupported RossFast routes, aquifer, blanket historic/default activation or remaining MC-SOL01 capabilities, nor does it by itself change mastercoverage dispositions.
