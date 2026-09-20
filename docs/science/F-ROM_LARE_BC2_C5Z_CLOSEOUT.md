# F-ROM-LARE BC2-C5Z closeout

C5Z qualified the C5Y all-layer moment-enriched cubic-theta reconstruction without hydrological response. The test was deliberately mathematical: fixed synthetic B14 storage/moment states, five frozen solver starts, hydraulic continuity, exact state recovery and theta admissibility.

The algebraic solve itself is well behaved on the preregistered domain. All 168 cases converge from all five starts, all 168 collapse to the same numerical branch, hydraulic continuity passes throughout, and storage plus centered first-moment recovery is exact to the declared gates.

The route nevertheless fails its physical admissibility gate. Only 154 of 168 cases remain inside the frozen constitutive effective-saturation domain [0.02, 0.995]. Fourteen cases exceed the upper bound. The failures occur in both D8_B2P5 and D12_B2P5 and in both prescribed-head directions, so the result is not a single-partition or single-direction artifact.

This distinction matters. C5Z is not a solver-convergence failure and not a multibranch result despite the broad preregistered status label. It is a profile-admissibility failure of the specific cubic-theta reconstruction.

No post-result repair is permitted. The moment range is not narrowed, the constitutive domain is not relaxed, polynomial order is not changed, and starts or tolerances are not retuned. The all-layer C5Y cubic-theta moment route therefore stops before any free-running moment-ROM or localization experiment.

The first water-content moment itself remains a physically interpretable state with an exact projected conservation balance. What fails is the chosen algebraic reconstruction from that state to a hydraulic profile.

For the original representation question, C5R remains the decisive placement-versus-propagation discriminator. Bottom-focused placement improves response strongly, but once D8 and D12 share the same 2.5-cm lower-boundary support, four additional states above that support do not change the groundwater response. The remaining high-resolution discrepancy is therefore no longer explained by insufficient bottom-adjacent placement or simple missing vertical breadth under CURRENT_LAYER_FACE.

There is still no qualified replacement closure. DSE2P, storage-only P0 SCAFP and the C5Z moment-enriched cubic-theta route each fail prospectively before free-running adoption. Selecting another propagation or state family is now a genuine scientific choice and is not made from exposed response error.

Application acceptance remains unresolved under C4U. No performance, speed or production-ROM claim is authorized.
