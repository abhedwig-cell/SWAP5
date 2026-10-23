# Explicit water-state and flux temporal policy

Proposed production contract, 23 October 2026; baseline `57e1b3f2`.
This succeeds PR1404's generated research without changing its accuracy claim.
The current pressure-head error remains the default. The optional metric changes
temporal accuracy, not the physical equations or hard acceptance gates.

The model owns geometry and the interpretation of trial outcomes. A new default
transaction-model assessment binding receives full and two-half outcomes plus
the attempted duration. Its default delegates the incumbent state comparison.
This preserves source compatibility for existing model extensions. The engine
still owns solver/mass/temporal acceptance and commit/rollback.

The Reference backend's explicit optional policy uses immutable physical `dz`,
never a generated module or application-global geometry. Normalize independently:

- `sum(abs(theta_full-theta_half)*dz)+abs(pond_full-pond_half)` by a depth budget;
- absolute groundwater-head difference by its own head budget;
- full uptake minus both half uptake integrals, divided by attempted duration,
  by an uptake-rate budget;
- full external output minus both half output integrals, divided by duration,
  by an output-rate budget.

The maximum normalized error is mapped to the transaction's existing tolerance
scale; acceptance remains error <= tolerance. No state error is divided by dt.
Budgets must be finite, positive and at most0.001cm or0.001cm/day respectively.
Missing/nonfinite uptake, invalid geometry/state/duration or unsupported routes
reject. Actual `qrot` metadata is exposed additionally only while this option is
enabled. Existing metadata and physical default behavior remain unchanged.

Initial application scope is the PR1404 four-cell30cm native simple-crop/ETref
zero-tracer route, frozen conductivity, prescribed bottom2, no seasonal/detailed
forcing, thermal, implicit pond, Boesten or wider constitutive/root options.
Retained proposals and the existing atomic ordinary-policy day retry remain
available; retry changes proposal retention, not this explicit accuracy policy.
Native input/CLI selection is explicit and default OFF. No restart layout changes.
Different numerical policies may continue physical restart state, but equality is
claimed only for continuations with identical policy/forcing/parameters.

Required qualification: real small O0/O2 estimator/invalid-input contracts;
unchanged transaction/context tests; typed-backend O0/O2 full97day1x/4x base and
active empirical-root stress, repeated O2 native timings, exact day48 restart,
predeclared PR1404 physical criteria and original-forcing water reconstruction;
default bytes and all affected current owner preservation/admission checks.
Individual soil/pond evaporation allocation is reported, not independently bounded.
No new1e-6, RossFast expansion, highest-low-air or unrelated full F-CI is selected.

Affected invariants:2,3,5,7,13,22,23,25,26,29,30. New numerical configuration
is worker/backend configuration, not persistent physical state. A focused PASS
does not admit this option or rebind older owner evidence to changed providers.
