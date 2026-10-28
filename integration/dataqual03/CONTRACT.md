# DATAQUAL03 perched-exchange Jacobian experiment

Baseline4b61966e63bcb20d0688c919687a798147226114; follows DATAQUAL02/issue1458.
RT/HY/MP/VQ. Candidate, no qualification/admission claim yet.

Import only the optional local perched seepage diagonal derivative from PR1457
at51439058, its inner-provider/runtime policy plumbing, and its production leaf
finite-difference controls. Do not import continuous-wall/sorption, positive-film,
headcalc, bordered drainage or141day claims. Flux equations and limiter outputs
stay byte-identical; no tolerance, mass, rollback or restart-schema change.

Numerical flag `--perched-jacobian` is default off and requires experimental mode.
It is independent of the source-surface-demand physical mapping. The derivative
is minus matrix→macro conductance, with the local shared-inflow limiter derivative
when eligible; moving partial-top and overlapping local exchange cases retain
the old derivative. This is the existing diagonal correction/preconditioner,
not a claim to include all off-diagonal couplings.

Invariants3,7,13,20,21,23,26. Optional trailing arguments preserve old callers.
Every new primary run binds policy/executable into its prepared-input identity.
A first diagnostic may consume the retained2.495 file through the existing native
reader with its authentic origin binding and current physical parameter checks:
physical equations/parameters/state schema are unchanged. Such cross-executor
origin-state diagnostics do NOT qualify new restart files, production admission
or same-source history. Any published primary restart proof must be freshly
source-bound to the new executable/policy. Never rewrite CRC or forge bindings.

Select real production derivative finite differences O0/O2; unchanged flux/default
checks; actual2.495 source-window diagnostics; then decide whether benefit warrants
primary short/full/split runs and preservation. Stop expanding a failed numerical
hypothesis; keep negative/censored outcomes and do not promote it. No fresh481,
broad F-CI, highest low-air, RossFast, tolerance relaxation or new source law.
