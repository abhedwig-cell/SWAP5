# MC-IRR01 SALTEXCESS completion and issue1271 experiment

PR [1274](https://github.com/abhedwig-cell/SWAP5/pull/1274), authority [issue1271](https://github.com/abhedwig-cell/SWAP5/issues/1271). Baseline `0747fd7c8a5e754d73fa5d981e8f5437ee4c12f3`. This completes the final existing irrigation row only after exact-postimage canonical/master admission. Earlier PR1272 admitted four full rows and PR1273 three; their immutable evidence and all fifteen existing irrigation rows are retained. PR1268 is closed and merged at `121ed3503638c2d3168fa30e40f6af24156348a7`.

## Implementation and scientific contract

Use the existing matrix salt mass owner, accepted theta/dz and read-only CML adapter. The actual managed bottom7 weather/crop application now derives CML from its current committed physical state, forwards it through the existing root allocation request, and applies source SALTEXCESS after DCSLIM and before rate/availability. Historical strict `>` equality behavior and additive floating-point operation order are preserved. Active events retain their selected rate/end without concentration reselection. Solute-disabled behavior is unchanged.

The existing S5WI0001 codec conditionally stores the existing matrix masses and salt source identity, and binds numerical salt policy, TSCF and boundary carrier configuration. It restores through the existing physical constructor. Finite values are checked before any ordered untrusted-mass comparison. No new state owner, calendar, restart format tag, generic test framework or governance register was introduced. Same-platform codec limitations remain inherited. Alternate hydraulic models, dispersion, macropores, root salinity stress and reactive chemistry retain their own admission conditions.

## Qualification

A: 360 authenticated original TASK3 source comparisons plus six invalid inputs per O0/O2, calling the real production modifier with exact bit comparisons. The historical source comes from the existing authenticated B1.11 archive, irrigation SHA256 `65830c1e030be8030995547729d9298e6352778f132e5195af2962baa38a3bf1`. Test threshold0/100, below/equal/above, percentage0/25/50/75/100, depth0.4/1.2/39.9cm, option-off and solute-off; invalid controls preserve input depth.

B: 90 actual production trajectory programs using authentic daily weather, evolving accepted roots and material moisture, root TCS3/DCS1 and sensor TCS8/DCS2, DAYFIX, historical activation and availability/SSDI. Actual accepted water mass stays under the inherited hard1e-12cm gate. Existing conservative salt transport and its separate mass ledger remain unchanged; salt mass is in all new state/retry/endpoint comparisons. Continuous/opaque/fresh native endpoints and both optimization outputs are exact. Three water-only representative endpoint profiles remain byte-identical to the existing qualified sensor capsule.248 native negatives include CRC-correct negative/NaN/Inf masses, wrong salt provenance and mismatched policy/boundary/threshold/TSCF configuration, without partial publication.

The additional smallest existing application failure probe runs four times, O0/O2 x continuous/opaque restart. A real internally accepted physical prefix is discarded when the requested interval cannot complete: exact water+salt state, DAYFIX, allocation and event stay unchanged. Smaller accepted retries equal a clean origin; a failed tail retains the previously accepted prefix. The final review selected this probe because allocation preflight rejection alone cannot establish physical rollback. Its separate 297-provider build is measured workflow overhead; the original live Session could have shared its providers had the probe been included initially. No counterfactual time saving is claimed.

C: source/evidence/postimage admission, fail-closed controls and four existing owner/reference entrypoints. The archive includes raw outputs, compiler commands, generated drivers, exact source projections, current15-row incumbent proof and failed attempts. No full moving F-CI, RossFast, highest low-air or hosted Actions run is selected. See the existing recovery record for terminal admission results.

## Measured costs

| Category | Actual measurement |
| --- | --- |
| Initial reconciliation/source analysis | UNKNOWN; no complete category timer |
| Active implementation | UNKNOWN; do not infer from elapsed wall time |
| Selected science controllers, summed wall seconds | 778.295284; overlapping controllers are not added to claim elapsed engineering time |
| Main application controller | 555.978714s |
| Selected compiler / linker invocations | 1252 / 14 |
| Selected native linked programs / invocations | 14 / 344 |
| All recorded attempts, compiler / linker / native | 2508 / 20 / 382 |
| All recorded command wall seconds, summed | 991.275460; includes failures, excludes unknown controller/coordination time |
| Phase elapsed through science sealing | 1479.304086s; includes implementation, qualification, waits and repository operations |
| Admission, evidence and canonical coordination | Terminal controller measured separately in recovery; complete active category time UNKNOWN |

The complete measured phase wall timer is an elapsed observation, not active development time. A comparable total historical development/coordination denominator is unavailable. All failed and superseded runs remain counted. Counts distinguish linked native programs, trajectory invocations, decoder invocations and Python admission programs; parameter vectors are not counted as separate programs.

Inherited:15 full-row incumbent authority, 30 owner-successor flags, original35 root-batch and32 sensor-batch admission controls, unchanged solver/transport/root/calendar science. New coupling, actual salt rollback, modified operation order, native configuration and mass payload are freshly qualified. Qualification inheritance is justified by exact source/body projections and explicit changed-path tests, never by an unrelated green run.

## Defects and critical experiment evaluation

1. Small source test found the pre-existing algebraic rewrite rounding defect. For1.2cm/75percent the literal additive result is `0x1.0ccccccccccccp+1`; factor multiplication produces `0x1.0cccccccccccdp+1`. Corrected source order; no tolerance relaxation.
2. Actual rooted weather rate oracle caught dropped `solute_enabled`/CML fields in the root allocation bridge. Forwarded the already authoritative request fields.
3. CRC-correct NaN native input caught a real SIGFPE in the inherited compound ready predicate. Codec now rejects nonfinite mass before calling it and checks configured salt source identity.
4. Test development failures: ambiguous source extraction selected the input-reading block; undeclared fixture loop variable; unrelated salt-free demo reached a salt-specific endpoint assertion. All raw failed attempts remain in the capsule. Bound the existing complete rooted test at its existing main boundary, without deleting its scientific assertions.
5. Final qualification review found the existing actual incomplete-prefix rollback helper had not been selected by the annual/single profiles. Added its focused salt execution rather than assuming preflight rejection was sufficient. Its extra fresh build exposes a limitation in our test selection/reuse workflow, not a new physical dependency.

Observed previous small-row selected science: TCS6 493.791081s, AVAIL578.324688s, mean536.057885s/row. Four-row PR1272 selected science132.516449s/row, three-row PR1273 207.887715s/row. These are different actual scientific workloads, not a controlled artificial benchmark. SALTEXCESS adds a chemically coupled final row and the above failures/review repair; its actual measured costs are given without hiding them.

The experiment now has two multi-row full closures, with lower selected successful qualification per row. The full requested qualification-plus-coordination speed criterion remains **INCONCLUSIVE**, because complete comparable historical implementation/coordination timers are UNKNOWN. Reliability is supported by the source, actual accepted physical, failure, restart and preservation gates, not by elapsed time. The evidence supports grouping ready shared-owner options; it also shows costly provider recompilation after fixture failures and late test selection. No second irrigation architecture is needed. Extending the existing live shared-build test selection early is the relevant workflow improvement; no synthetic savings estimate is provided.

## Exact admission and coverage

Science execution `d3af41ac10d75091d2649f92c8b0c2c2f84898a7`, source tree `f4aec497a245287d4a2bbeff340e0396d8c86cde`. Exact canonical merge, full qualified-tree identity, master receipt/counts, remaining blockers and completion elapsed timer are appended to `salt_completion_1271_20261017` in the existing `MC_IRR01_STATUS.json`. Promote exactly SW431-IRR-SALTEXCESS after all gates; preserve the other242 master capability records. Expected after unchanged parallel state:113 ADMITTED,91 ACTIVE_MIGRATION,3 QUALIFICATION_ONLY,94 unresolved of243; MC-IRR01 16/16. These expected counts become an admitted claim only with the terminal receipt. Global SWAP migration coverage remains incomplete.
