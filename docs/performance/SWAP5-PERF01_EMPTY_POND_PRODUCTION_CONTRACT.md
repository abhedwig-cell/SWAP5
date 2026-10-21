# PERF01 opt-in implicit pond evaporation

Production proposal on canonical `eaa04cf7b00ff5d676eb533d160109c533a92c8a`.
The earlier generated experiments use source baseline
`d7b891759a8c378ba0367e1a1a112c684712199f`; concurrent NUT humus-clock changes
intersect none of their executed column inputs. See the scoped rounding contract
for exact original failures, scalar proofs, complete coupled day, independent
continuous water reference and decreasing error at tighter temporal tolerance.

## Physical option and interfaces

Add `implicit_pond_evaporation`, default false, to the file column namelist and
the transient FMR pond-input forcing. Propagate it through the dynamic-top adapter
to a default-false field in the top-boundary request. Add the adapter argument at
the end, optional, so existing source calls retain their meaning. New behavior
requires zero bare-soil demand, fixed explicit top conductivity with the tested
arithmetic face mean, no macropore
donor/partition and positive zero-head infiltration capacity. Unsupported enabled
requests fail closed. Zero pond demand retains the old hydraulic equations.

The enabled physical closure solves the empty-pond evaporation constraint from
the earlier independent scalar and continuous-reference contracts. It does not
change HeadCalc, nonlinear iterations, temporal/mass criteria or retry limits.
The existing previous-pond classification remains the default physical route.
The file application excludes unqualified combinations with dynamic temperature,
enabled accepted-step proposal and nonlinear Freundlich exponent.

Add the same default-false policy bit to `pond_step_t`, a transient forcing
receipt. The joint pond adapter rejects inconsistent water/chemical policy bits.
Append optional `exact_empty_pond_limit` arguments to the pond-mixing process and
reactive-substep entry point. Only enabled pond callers pass true. The exact
analytical zero-pond/no-runoff/no-macro mass limit remains gated by this option;
all existing absent/false calls execute the original floating-point expression.
The persistent pond and matrix-solute owners remain the sole physical owners.

These are source-interface extensions requiring a fresh dependent build. No
committed-state field or physical restart format changes. As with the existing
surface forcing, callers supply the same physical policy on continuation; no
claim covers switching policies across a restart. No hidden global mode or
numerical continuation state is introduced. Relevant invariants are
3,5,7,13,22,23,24,25,26.

## Selected qualification and cost

Before enabling production admission, persist implementation and tests, then:

1. Fresh small real-provider O0/O2 tests: enabled option equals the qualified
   generated surface/mixing algorithms; disabled/absent paths preserve original
   results; source discontinuity/negative-mass counterexamples remain visible
   in the legacy route; unsupported enabled requests reject.
2. Fresh current production O2 and checked O0 column closures (roughly60/30s).
   Execute original86 input/grid/budget/restart assertions and original SWP reader
   assertions, retaining all raw evidence. Verify default physical artifacts
   against the exact admitted predecessor; no old expected values are rewritten.
3. Current enabled six-window O0/O2 files/work and a complete O2 day must match
   the qualified generated candidate exactly. The generated full-day restart,
   independent reference and tighter-run proof remain separately identified;
   source equivalence alone is not a new native production PASS. Expected native
   costs about30s for checked prefixes and100s for the full day, with explicit
   limits and512MiB on the scientific case.
4. Reconcile the exact current owning authorities with an additive source-bound
   successor. Frozen predecessor qualification stays unchanged. Assess affected
   default/thermal/NUT callers using actual guarded-path impact and fresh local
   composition evidence; do not relabel unchanged-file hashes as current proof.
   Full F-CI and highest-low-air are not selected solely for optional arguments.

This is bounded opt-in physical capability, not a global default change,
matched-physics speedup, regional performance claim or master-row promotion.
