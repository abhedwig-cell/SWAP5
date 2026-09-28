# F-RETC01 — primary evidence matrix

Authority context: `integration/f-ci-canonical@1759caebb7ca3bd62bbee65d9319f5d71d3e73f5`
Research branch: `research/f-retc01-historical-reconstruction`

## Acquired primary authority

### E2 — official EPA/USDA RETC Version 1.0 report

Reference: M. Th. van Genuchten, F. J. Leij and S. R. Yates (1991), *The RETC Code for Quantifying the Hydraulic Functions of Unsaturated Soils*, EPA/600/2-91/065.

The official USDA-hosted report is a user manual, algorithm description, source-code listing and sample-case record. This moves several reconstruction fields from unknown to source-specified, while exact executable identity still requires source/executable extraction and tests.

| Reconstruction field | Evidence status | Bounded finding |
|---|---|---|
| optimizer family | E2 | nonlinear weighted least squares using Marquardt's maximum-neighborhood method |
| iteration update | E2 | parameter elements updated sequentially; current/previous iteration results compared |
| retention-only objective | E2 | weighted squared residuals in observed versus fitted water content |
| per-observation weights | E2 | user weights represent reliability; unity weights give ordinary least squares under stated assumptions |
| joint retention + K/D objective | E2 | two residual families with per-point weights and two cross-family weighting factors |
| family balancing | E2 | one factor is calculated internally for observation count and numerical scale/units; another user factor controls relative K/D weight |
| K/D transform | E2 | optional logarithmic transformation before fitting |
| fitted/fixed parameters | E2 | coefficient index selects fitted versus fixed |
| model restrictions | E2 | Brooks-Corey limiting restriction and Mualem/Burdine m-n restrictions selectable |
| maximum iterations | E2 | user-controlled MIT; manual suggests e.g. 30 for simultaneous fits |
| stopping criterion | E2 | STOPCR uses relative change in coefficient ratios; exact executable expression remains to extract |
| diagnostics | E2 | correlation matrix, standard errors, T-values and 95% confidence limits |
| source listing | E2 | Appendix A contains program source |
| sample cases | E2 | Appendix B contains example input/control/output |

## Version distinction

The 1991 report identifies RETC Version 1.0. A historical EPA page identifies RETC Version 1.1 with a November 1994 release date. These versions must not be conflated. The first reconstruction target is Version 1.0 because its source and sample cases are bound in the official report. Version 1.1 is a separate compatibility target if its executable/source differs.

## Current implications

1. A generic modern least-squares implementation is insufficient for exact RETC equivalence.
2. Joint theta/K fitting is not simply an unweighted concatenation of residuals.
3. K/D is not universally fitted on its raw scale: RETC explicitly supports log K/D modes.
4. Parameter identifiability was already explicit RETC functionality through correlation and uncertainty diagnostics.
5. Profile-likelihood, bootstrap or Bayesian diagnostics remain modern extensions unless later evidence shows otherwise.

## Still unresolved before executable reconstruction

- exact internally calculated family-balancing formula, to recover from source rather than OCR;
- exact Marquardt implementation and damping update;
- derivative or finite-difference construction;
- exact STOPCR expression and defaults;
- parameter safeguards, transformations and bounds;
- invalid intermediate-state handling;
- source precision/compiler-sensitive behaviour;
- Version 1.0 versus 1.1 differences;
- settings/provenance used for historical Dutch/Staring-series parameter sets.

## Next gate

Extract Appendix A and Appendix B into immutable checksum-pinned evidence. Select one retention-only case and one joint retention/conductivity case from the official examples. No fitter is called RETC-equivalent before source semantics and both example outputs are reproduced.
