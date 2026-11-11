# Original Grassgrowth with four internal heat steps

The explicit numerical policy admitted by PR #1632 previously had short-window
execution evidence. This package supplies its own complete original113-node,
1827-day production O2 trajectory and fresh-process continuations. The scientific
source is canonical `c3c99cb6c70edfd652d904306daa63d03a283939`; this PR changes
verification and evidence, with no changes to src/app/tools/tests/reference.

| Audited production O2 result | Value |
| --- | ---: |
| Completed original days | 1–1827 |
| Accepted water steps | 1,016,128 |
| Maximum daily water residual | 4.52693438e-14 cm |
| Cumulative stock–flux water residual | 1.0658141e-14 cm |
| Maximum uptake attribution residual | 7.00828284e-16 cm |
| Maximum daily conductive residual | 5.57406565e-10 J/cm² |
| Maximum conductive substep residual | 1.24679919e-11 J/cm² |
| Signed cumulative conductive residual | -1.73816683e-08 J/cm² |
| Fresh own process/checkpoint cuts | 4/4 exact |

The [execution selection and release identity](../../integration/f-ci/GRASS_SUBSTEP4_FULL_20261111.json),
[audited receipt](grass-substep4-full-receipt.json) and
[raw archive manifest](grass-substep4-full-manifest.json) bind the actual original
five input files, all203 source/object inputs, utility library, compiler, link
command and executable. All original input hashes agree with the repository
SWAP4.3.1 Grassgrowth project. The profile is `thermal-subcycle4-1e-5C`, selected
by `thermal-control-4`; one-step remains the default. No existing evidence or
historical reference archive is overwritten.

## Acceptance and inherited implementation gates

Every day appears exactly once in each water, crop and conductive ledger.
All values are finite. Water continuity, stock-minus-flux closure and root
uptake attribution retain the existing1e-10cm limits; cumulative water closure
also meets that limit. The existing daily and maximum-substep conductive
audit limits remain1e-8J/cm2. The signed cumulative conductive residual is
reported separately; no new aggregate energy threshold is invented. The
production per-cell/global energy guard and1e-5C external temporal budget
remain unchanged. Soil conduction does not establish complete surface energy.

The own cuts2-to4,187-to190,365-to367 and1792-to1827 use the same immutable
release, original input bytes and captured checkpoint origins. Every suffix
water/crop/conductive row is exact; the full checkpoint bytes at each cut end
are exact. The final continuation also reproduces terminal nodal state and
endpoint bytes. There is no cross-executable or cross-policy rebinding.

PR #1632 owns the actual Windows/Linux O0/O2 body/runtime, opt-in native
restart/refusal, default Grassgrowth/Andelst preservation and focused F-CI
results at this unchanged source/dependency postimage. They are reused within
their exact scopes. This full production trajectory is Windows GNU16.2 O2;
it is not a full O0 or a full Linux execution claim. No duplicate broad F-CI
or retired highest-low-air campaign is selected for evidence-only changes.

## Historical comparison and day188

| Day188 quantity | New four-step route (cm) | Original B0 (cm) |
| --- | ---: | ---: |
| potential_cm | 0.142421159993 | 0.141707391074 |
| uptake_cm | 0.136430741769 | 0.125136344464 |
| drought_cm | 0.000000000000 | 0.000000000000 |
| oxygen_cm | 0.005990418224 | 0.016571046610 |

The largest absolute daily uptake difference is still on day188, +0.011294397305cm. The largest oxygen difference is on day905, -0.010631484128cm. These are differences, not accepted scientific-equivalence results.

The sealed B0 archive and earlier one-step run remain distinct, immutable
reference families. The [existing assessment](GRASSGROWTH_REVIEW.md#day-188-6-july-1980)
finds the main oxygen gap sensitive to the accepted time grid: a diagnostic
30-second B0 cap explains97.86% against the tested water-only SWAP5 route.
That percentage and its onset observations are not reassigned to this new
thermal route. Same-state kernel exchange was about3e-9cm, while the residual
water-only difference to capped B0 remained0.000226656cm and unresolved.
No extra reference calculation or physics change is warranted by this package.
The failed original daily comparison remains visible. Whole-trajectory
scientific equivalence remains open under the existing criteria, as does the
independent Hupsel day584 reference-qualification barrier.

## Cost and reproducibility

The monotonic launcher elapsed time is **2527.475440seconds (42min7.5s)**. The retained Windows process handle records2484.828125CPU seconds (2459.703125user,25.125000kernel). The earlier one-step launcher observation is6036.22878742218seconds derived from file timestamps on a different source/profile. This is not a controlled full-period speedup measurement. Its accepted-step count is1,819,203 versus1,016,128 here. The previously controlled short-window comparison remains scoped to PR #1632. Original B0's earlier8.21875second same-host run uses different numerical controls; comparable full-project runtime remains unachieved.

The recorded estimate was3600seconds, with a7200second hard cap. This one
new-policy full run was selected because four-day proof cannot establish all
seasons, mowing and late states. Each own continuation has a600second cap.
No prior full trajectory was repeated. Build manifests preserve actual reused
object provenance and the fresh link, rather than labeling it a cold compile.

The [raw archive](grass-substep4-full-20261111.tar.xz) contains the release,
original inputs, all actual compiled inputs, compile manifests, captured files,
raw daily ledgers, process results and actual verifier source bytes. First
check the archive SHA256 against its manifest, then extract to a new directory.
The following only reads retained data; it does not launch a model:

```powershell
$proof = "$env:TEMP/grass-substep4-read-only-review"
python -B -m tarfile -e research/hybrid-water01/grass-substep4-full-20261111.tar.xz $proof
python -B research/hybrid-water01/qualify_grass_substep4_full.py --bundle "$proof/bundle" --full "$proof/full" --restarts "$proof/restarts" --spec "$proof/spec.json" --file-index "$proof/FILE_INDEX.json" --output "$proof/rechecked.json"
```

The current verifier records its own actual file hash, which may differ after
checkout newline conversion; numerical results, source/build identities and
output hashes must match the retained receipt. The old sealed B0 archive is
verified separately from its existing manifest. Exact original launch commands
are in each LAUNCH.json; BUILD.json contains the actual link and build recipe.

Functional coverage remains the three separately scoped original applications;
Grassgrowth gains a complete execution and own restarts on this explicit faster
policy. Whole scientific qualification and runtime parity are not promoted.
The next delivery is bounded native cost attribution using a retained short
window, followed only by a justified output-preserving performance change.
No further whole-period timing campaign is selected by this receipt.
