# Bounded weather retry after exhausted line search

Status: proposed production implementation,22 October2026.
Baseline: canonical17a6c17a478238e5fafc469aa275313bcdf2e184.
Research authority: PR1376 and `PERF01_NEWTON_WORK_20261022_EVIDENCE`.

Add an explicit default-false numerical option `abort_failed_line_search` to
the typed Reference request, exposed as `weather_line_search_retry` in the
existing weather column parameters. This selects cheaper failure handling,
never weaker convergence, temporal accuracy, mass or acceptance criteria.

The service admits activation only for the already researched dynamic-top,
continuous default-MvG, arithmetic face mean1, free-bottom7, prescribed source/
root route. Exclude sensitivity, macropores, matrix-area scaling, alternative
constitutive providers, extended retention/conductivity and implicit pond
evaporation. Unselected or unsupported requests retain their original route.
Do not expand RossFast or physical surface behavior. Warm start remains OFF;
if explicitly combined, sanitize the retry flag for both warm and cold phases.

Only after every existing backtracking candidate fails to reduce the squared
residual, with compartment maximum residual still at/above its existing gate,
may the current Newton phase end early. The existing original-entry corner
restart remains available once, with its complete state reconstruction and
unchanged per-phase limits. Otherwise report the ordinary failed solver result
and let the transaction owner retry from committed state at a smaller step.
No failed candidate, surface receipt or numerical cache becomes physical state.
No new restart payload or persistent policy history is introduced.

Invariants affected: explicit numerical/physical separation, worker scratch,
immutable accepted origin, rejection/rollback, conservation and restart.
Allowed interfaces: the two default-false numerical/column fields and their
existing runtime propagation; private bounded eligibility and failed-phase
execution. Fixed: hydraulic/surface laws, time policy, all acceptance gates,
committed/restart schemas, original default/source assertions.

Required selection: new direct real-solver OFF/ON/failure/unsupported-route
controls, original corner/retry/derivative/warm-fallback assertions O0/O2,
full97-day1x/4x OFF/ON at1e-3cm, wet-day35 reconstruction and complete rollback.
Build the affected current weather/column/NUT closure because the numerical
type layout changes. Execute affected existing SOL/ETref/crop/root/NUT output
owners and keep the complete original source assertions behind exact additive
registration. Expected local build/native admission cost900seconds; start with
the small direct closure before selecting the shared builds. No new1e-6,
highest low-air, full moving F-CI or RossFast expansion solely for imports.
Record actual dependencies, cost and inherited original FSI35 native identity;
its numerical type/provider changes require fresh selected native execution.

The completed generated research establishes a bounded candidate, not a
universal convergence or speed guarantee. Activation and canonical admission
require the current source/native evidence for the actual implementation.
