# GC-RZM06A sequential antecedent infrastructure qualification

Date: 2026-09-22  
Status: QUALIFIED RESEARCH INFRASTRUCTURE, SCIENTIFIC RESPONSE NOT YET INSPECTED  
Production authority: unchanged

## Scope

This work unit adds a research-only sequential interval driver around the existing F-GC44 B110 serialized-reference carrier. It does not change production SWAP physics, production groundwater coupling, or canonical production APIs.

Each research interval starts from the current committed origin, derives t0 from committed time, sets t1=t0+duration, copies the existing physical forcing, replaces only top_flux, and materializes the lower boundary from the existing fixed-interface H_c route. The serialized-reference backend performs the trial. A candidate is committed only after whole-window provenance and mass gates pass. Read-only and failed trials are discarded.

Research state preparation deliberately does not publish the groundwater interface mass ledger. The committed Richards state can therefore advance during antecedent construction while the production ledger count remains zero. This is diagnostic preparation, not an admitted production coupling transaction.

## Forcing sign and unit caution

The real serialized-reference mass accounting books negative top_flux as external input to the SWAP profile and positive top_flux as external output. For RZM06A the labels WET and DRY therefore mean negative and positive top forcing respectively.

Historical field names retain cm/day and _CM suffixes. The fixture geometry used by the profile observables is metre-scale. RZM06A therefore freezes and reports exact native carrier values and does not silently relabel all forcing and storage quantities into one reconciled unit system.

## Characterization

The first non-zero grid at ±1e-1 and ±1e-2 was rejected for all tested durations, while zero forcing was accepted. That failure is retained as evidence in workflow 35724013765, job 106733222845. No H1-H4 probe response had been inspected.

The characterization was then extended downward around the existing carrier forcing scale without changing solver tolerances or retry budgets. Workflow 35724287627, job 106734116515 passed. At duration 0.01 d both signs are individually admissible at ±1e-4, ±1e-5 and ±1e-6 in the historical forcing field units.

Sequential admissibility was then characterized response-blind. The ±1e-4, 0.01 d pair was not admissible in both orders: WET→DRY completed, while DRY→WET failed in the second interval. The next prospectively ordered pair, ±1e-5 at 0.01 d, completed in both orders. Workflow 35724746750, job 106735623011 passed at head 35e050f5bfaa11b226ac4c810dc98f67cd06943d.

The frozen antecedent candidate for scientific preregistration is therefore:

- fixed H_c = -0.7149999706136307 m;
- antecedent interval duration = 0.01 d;
- WET top forcing = -1e-5 in the carrier forcing field;
- DRY top forcing = +1e-5 in the carrier forcing field;
- trajectories WET→DRY and DRY→WET;
- equal integrated top forcing by construction;
- exact deterministic replay from fresh initialization.

The WET→DRY endpoint has profile water 1.0430631336699183, root-zone water 0.1037734552350075 and distribution moment -1.5024450029396634. The DRY→WET endpoint has profile water 1.043063184727175, root-zone water 0.10377348348932945 and distribution moment -1.5024449323768638. The profile-water difference is about 5.11e-8 in the native geometry-based storage observable, while the distribution-moment difference is about 7.06e-8.

The two endpoints are therefore observably different and suitable as an H1 antecedent pair. They do not satisfy the frozen H2 distribution criterion |ΔM1| >= 1e-4, so they are not an H2 match.

## Transactional qualification

The infrastructure evidence demonstrates that an accepted committed interval increments revision and committed time once, diagnostics are read-only, accepted-but-discarded trials leave committed state unchanged, invalid trials leave committed state unchanged, and deterministic fresh-process replay is exact for the qualified cases. Top forcing is independent of the materialized bottom/interface head. Accepted cases retain the existing mass gate; observed accepted residuals are zero or near machine precision.

## Authority boundary

This qualification establishes only research/diagnostic infrastructure and admissible antecedent preparation. No H1-H4 probe response was used to select the forcing pair. No production-facing tangent, affine coefficient, physical-state sufficiency claim, coupling admission, or sign correction follows from this work unit.
