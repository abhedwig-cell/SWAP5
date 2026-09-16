# F-VQ99 RECONCILE checkpoint — SWAP 4.3.1 ↔ SWAP5 Status-A scientific equivalence

Date: 2026-09-16
Phase: RECONCILE complete; QUALIFY permitted
Workunit: verification/evidence only
Production mutation: forbidden and not performed

## Pinned authorities

### SWAP5

- canonical branch: `integration/f-ci-canonical`
- live Status-A authority at reconcile: `992a5c657bfe10a10100f92e0cb77c4825ae65b6`
- Status-A governance tree: `dec751ba5182fd9ceee86568020090952d118fae`
- scientific production baseline: `50346642bd565f79134ea17d5462e544b354998c`
- scientific production tree: `3b085d7dea3d3f3fce42ad9d8f259a8350205846`

The Status-A authority explicitly pins scientific production to the commit/tree pair above. This campaign compares against that pair, not against later or moving branch state.

### SWAP 4.3.1 B0 immutable audit baseline

- model: SWAP 4.3.1
- supplied distribution `SWAP_4.3.1.zip` SHA-256: `2b48353db6cdf00246a1e5c0dcaafc2c61858729fad18446a1dc66359ec2a360`
- nested source archive `tools/SWAP/source/SWAP.ZIP` SHA-256: `1a2d798994c2990b397f9349317e3a26f40662fbcff55c9ea484dd638af45151`
- expanded 63-member source manifest SHA-256: `d923ac9aa474e9ef78cd8c5c51a9ca6ce6b4fb549a61180461da04ce1af4922f`
- supplied Windows executable SHA-256: `d13f5e0321db1780d211520287dc59db2e7aa763649998a4b29a187195ca89a5`
- supplied Linux executable SHA-256: `e3b45c1fe66a614c1caead4b2fc0684a09165672a32d8d3bf4eac00498767862`

B0 is byte-defined. A text-normalized or reconstructed tree is not silently promoted to B0.

### Corrected legacy oracle B1.10

The current qualified corrected-reference oracle is `B1.10`, reconstructed from B0 plus the ordered admitted patch set:

`SWAP-001, SWAP-005, SWAP-006, SWAP-007, SWAP-008, SWAP-009, SWAP-010, SWAP-013, SWAP-012, SWAP-002`.

B1.10 source identity:

- member count: 63
- source bytes: 1,863,575
- member-manifest SHA-256: `2dfc004f1bae3fc249f384d4f947a07ed4627e83e251ce6557d03092f0b4d1b1`
- deterministic reconstructor: `tools/vq/b1_10_reconstruct.py`

These patches are the complete admitted B0→B1.10 difference set. A B0↔SWAP5 difference may be class III only when the observed divergence is causally tied to one of these admitted corrections or to another explicit SWAP5 admission authority. Patch presence alone is not sufficient.

## Comparison chain

The authoritative interpretation is triangular:

1. `B0 ↔ B1.10` establishes whether a difference is an admitted correction of SWAP 4.3.1 behaviour.
2. `B1.10 ↔ SWAP5 Status-A production baseline` establishes preservation/equivalence against the corrected legacy oracle.
3. `B0 ↔ SWAP5` is reported, but a difference is never called harmless merely because B1.10 differs from B0.

## Explicit exclusions

- dedicated WOFOST 8.1 comparison campaign;
- EB;
- ROSS / RossFast;
- new physics;
- production optimization;
- API or IO redesign;
- tolerance widening after observing results;
- production repair inside this workunit.

Crop-related water-demand interaction is in scope only at the already admitted reference ET/canopy/root-water-demand interfaces. It is not a WOFOST 8.1 potential-production campaign.

## Bounded comparison matrix

| ID | Existing authority / fixture | Scientific purpose | Direct cross-model role |
|---|---|---|---|
| `LONG-HUPSEL-2002-2004` | supplied `1.hupselbrook`, previously verified against exact B0 package in MP-3A | long trajectory; precipitation/input, ET, runoff, drainage/bottom exchange, storage and annual water balance; accumulated drift | required broad end-to-end comparison; existing B0 run evidence is reusable, but Status-A trajectory evidence must be matched before closure |
| `HUPSEL-PROBE-D4` | F-CI07 full B1.10 Hupsel rerun, offset 4 | early trajectory state, pressure head, theta, soil temperature, solute state and accumulators | B1.10 state/replay authority; cross-model only if the same state vector is obtained from Status-A path |
| `HUPSEL-PROBE-D499` | F-CI07 full B1.10 Hupsel rerun, offset 499 | long-enough state probe to expose drift | same qualification rule as D4 |
| `RICHARDS-15` | F-CI21 / F-SI24/F-SI25, 15 nonlinear cases | unsaturated Richards response, dry/wet head regimes, top flux, prescribed bottom head, storage/mass balance, nonlinear trajectory | existing independent B1.10-derived oracle versus SWAP5 production seam; eligible for direct class I/II qualification |
| `ET-GRID-1700` | F-VQ35 independent B1.10 equation oracle | evaporation/transpiration demand partition, cover semantics, units, inactive-crop dependency, boundary cases | existing independent B1.10-derived oracle versus admitted SWAP5 ET process; eligible for class I/II qualification |
| `ET-RUNTIME` | F-VQ36 / F-MR23 reference ET runtime binding | process-to-runtime crop water-demand interaction excluding WOFOST 8.1 production comparison | verifies binding rather than only isolated equations |
| `QBOT-PRESCRIBED` | F-VQ75 / F-MR44R prescribed bottom-flux temporal runtime | bottom-boundary flux application, timing and accepted-state propagation | direct Status-A bottom-boundary qualification; legacy comparability must be proven before assigning I/II |
| `RESTART-SPLIT` | F-MR19 plus later coupled-restart qualification | restart / continuation equivalence and terminal state | compare only semantically equivalent restart points and state; SWAP5-only lifecycle additions are not treated as legacy variables |
| `DRAINAGE` | admitted drainage process/runtime chain plus current-canonical preservation | drainage flux and contribution to balance | compare legacy-equivalent formulas/options only; new coupling composition is not silently mapped to 4.3.1 |
| `SURFACE-WATER` | bare-soil ponding / surface-storage preservation gates | infiltration/ponding, surface storage and runoff | direct legacy comparison only where forcing, top-boundary semantics and sign conventions match |

No synthetic case is invented merely to fill a matrix cell. If an authoritative legacy-comparable fixture cannot be established for one row, that row remains evidence-limited and cannot support a stronger global verdict.

## Comparable variables and normalization rules

Direct physical quantities, when present in both models with the same semantics:

- pressure head `h` by node;
- water content `theta` by node;
- ponding/surface storage;
- groundwater level where the boundary semantics are the same;
- profile storage;
- top flux and bottom flux;
- drainage flux;
- soil evaporation;
- transpiration;
- runoff;
- groundwater exchange only for a legacy-equivalent boundary/coupling mode;
- cumulative precipitation/input, bottom exchange, runoff, evaporation and drainage;
- cumulative and terminal water balance;
- terminal physical state.

Normalization is permitted only for representation, never physics:

- generated timestamps/compiler banners may be removed from text-output identity checks;
- units are converted explicitly and recorded;
- sign conventions are converted explicitly and recorded;
- column/order/layout differences may be normalized by named variable and semantic timestamp;
- missing values remain missing and are never coerced to zero;
- instantaneous and cumulative quantities are never interchanged;
- time coordinates must denote the same physical instant/interval before values are paired.

## Predefined comparison thresholds

Thresholds are frozen before evaluating this campaign. They are inherited from existing immutable qualification gates where possible.

1. Integer/status/event values: exact equality.
2. Expected legacy-preserved textual outputs: exact normalized equality after representation-only normalization above.
3. B1.10 full-state Hupsel-style state comparison, inherited from F-CI07:
   - `h`: max absolute difference `<= 1.0e-10` in model head units;
   - `theta`: max absolute difference `<= 1.0e-12`;
   - soil temperature: max absolute difference `<= 1.0e-10` where compared;
   - cumulative/accounting quantities: max absolute difference `<= 1.0e-12` in their model units.
4. F-CI21 Richards indicator/oracle comparison: `abs(a-b) <= 65536 * epsilon(real64) * max(1, abs(a), abs(b))`, exactly as frozen by that gate.
5. F-SI24 synthetic Richards mass closure: `<= 1.0e-12` in the gate's water-balance units.
6. F-VQ35 ET equation oracle: use the qualification's frozen equation-oracle acceptance, not a new campaign-specific tolerance.

A failed threshold is a failed comparison. No threshold may be widened after observing a result. Coarse printed outputs such as annual `.bal` values are reported at their actual print resolution and cannot establish a stronger hidden-precision claim.

## Classification rule

Every material result is classified exactly as:

- I — IDENTICAL
- II — NUMERICALLY_EQUIVALENT
- III — EXPLAINED_ADMITTED_MODEL_EVOLUTION
- IV — IO_OR_REPRESENTATION_ONLY_DIFFERENCE
- V — UNEXPLAINED_SCIENTIFIC_OR_NUMERICAL_DIFFERENCE

Class III requires exact admission authority. Class IV requires proof that physical state and balance are unchanged. Class V stops closure for the affected case; production remediation is out of scope.

## Adversarial checks

For every executable comparison:

- verify executable/source identity before run;
- isolate run directories and delete/avoid stale outputs;
- record input hashes;
- verify intended input names are actually opened/consumed;
- record units and sign convention per variable;
- fail on NaN/nonfinite values unless explicitly expected;
- preserve missing values;
- align timestamps semantically;
- distinguish cumulative from instantaneous fields;
- for restart, hash/check the restart state and ensure the resumed initial state equals the uninterrupted checkpoint state.

## RECONCILE verdict

`RECONCILE_PASS`

The authority chain and bounded case matrix are coherent. QUALIFY may proceed. The broad end-to-end equivalence verdict remains open until executable evidence is classified.

## Next permitted action

Run/replay immutable direct B1.10→SWAP5 oracles first. Then attempt the broad Hupsel cross-model trajectory only from exact authoritative assets. If the exact B0 package/case or an equivalent Status-A end-to-end trajectory cannot be materialized with provenance, record that as an evidence gap and close with `SWAP431_SWAP5_STATUS_A_EQUIVALENCE_NOT_YET_ESTABLISHED` rather than substituting a reconstructed or non-equivalent case.
