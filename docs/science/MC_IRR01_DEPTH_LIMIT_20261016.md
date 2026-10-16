# Irrigation minimum and maximum depth

Workstream MC-IRR01, existing capability `SW431-IRR-LIMIT`.
Baseline `c9231e1b`. The existing `integration/audits/MC_IRR01_STATUS.json`
field `limit_completion_20261016` fixes all closure conditions and records exact
execution, qualification and admission state. A test or draft does not itself
establish canonical admission.

## Source and ownership

Authenticated B1.11 `SWAP/irrigation.f90` applies DCSLIM after DCS1 field-capacity
refill, daily rain subtraction and adjustment, or DCS2 interpolation. It applies
`max(depth, minimum)` then `min(depth, maximum)`, before salt excess, rates and
external availability. Minimum is 0..100 mm; maximum is minimum..1e7 mm. The
existing typed configuration converts these to centimetres. The modifier owns
no independent time, crop, root, water, salt or persistence state.

The source permits zero DCS2 FID. A positive minimum must raise that zero gift.
A zero maximum produces no water. The previous positive-only DCS2 policy and
sensor pre-limit rejection prevented these valid paths. The existing policy,
sensor process and management event normalization now retain valid zero gifts.
A zero final gift creates no active event or water; the accepted application
still consumes the existing daily opportunity once. Positive-domain arithmetic,
negative/nonfinite rejection, solver and mass thresholds stay fixed.

## Full rule closure and independent capabilities

The existing rule is the postselection minimum/maximum modifier. Earlier master
annotations referred to missing rooted DCS1, broader selectors and native
continuation. PR1254 supplies accepted material/current-root DCS1 and selectors
2/3/4; PR1262 supplies real weekly progression; PR1267 supplies joint native
continuation for all admitted managed profiles. This work tests the modifier
through selectors2/3/4/6/7/8, both depth criteria, source parameter edges and
zero-gift paths. Generic file parsing and independently unadmitted crop, salt,
hydraulic or selector profiles do not acquire admission from this rule. Their
remaining capability rows stay open. This is the same independent modifier
boundary used for full external availability admission.

## Qualification

The small real policy and sensor production drivers execute the authenticated
literal clamp against934 cases per O0/O2, including adjacent floating-point
values, inactive/lower/interior/upper/equal/zero bounds, legal parameter endpoints,
zero pre-limit depth and malformed caps. The original failed source preflight is
retained, as is the earlier test-fixture compile failure.

Actual authenticated weather, current crop/root/material state, Richards and
accepted water balance are tested with lower, upper, equal, inactive, zero-input
and zero-maximum profiles. Existing one/three-node sensors preserve separate
surface rain/ET and SSDI accounting. Continuous, opaque and fresh-process native
prefix/tail executions compare complete endpoints exactly, including current and
lagged crop feedback, accepted day selection, rejected trials, retry and replay.
The existing native codec and tag are reused. Original AVAIL and TCS6 endpoints
are compared against their immutable capsules. All production providers are
compiled fresh O0/O2 in this restored workspace; no vanished compiled artifact or
old physical PASS substitutes for a fresh application run.

Exact counts, raw evidence, admission negatives, owner entrypoints and final
master/canonical disposition are recorded only after terminal checks finish.
No broad F-CI, RossFast, highest low-air or GitHub Actions is selected.

## Joined qualification result

The fresh canonical-native-drainage composition passes 160 application/continuation
executions and 560 decoder rejection controls across O0/O2, with 296 real
production providers compiled per optimization. All retained 934 literal source
vectors per optimization have exact unchanged input hashes. Complete accepted
endpoints agree across continuous, opaque, fresh-process and O0/O2 execution;
original AVAIL/TCS6 endpoint bytes remain exact. The original DISLAYER and DRAMET3
admission controls were executed at their immutable canonical authorities.
Canonical admission and the one-row master promotion remain governed by the
existing completion record, rather than by this scientific summary.
