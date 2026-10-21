# PERF01: head quantization isolated, local rounding correction not admitted

21 October 2026. Executed source baseline
`fda2a6de35ab60e8c836a6687482efa3774d95dc`. This follows the
[original total-balance diagnosis](SWAP5-PERF01_DRY_DIAGNOSIS.md). Production
providers, tolerances, retry limits, reference policy and capability authorities
remain unchanged. The owner is `integration/diagnostics/PERF01_PRECISION_STATUS.json`.

## What the new execution establishes

Two fresh 178-provider current column builds, GNU 13.3 O0 checked and O2 production,
capture the final failed iterate of the original dry32 case. Each reproduces the
prior native failure's budgets, physical trajectory, external clocks and work
counters exactly. Their captured 32 heads, coefficients and residual terms are
byte-identical. Observing code stores only the final exhausted iterate before
the original reset and dumps it after the application rejects the interval.

The last 32 Newton updates are **all smaller than half a head ULP**. The largest
ratio is 0.4335257967640202. Every binary64 subtraction therefore reproduces the
unchanged stored head. A ULP here is the spacing between adjacent representable
pressure heads, not a water-content rounding bound.

| Reconstruction at the same iterate | Total residual, cm/day |
| --- | ---: |
| Original native HeadCalc | -4.520616382431123e-5 |
| Compensated sum of stored residuals | -4.520616382431121e-5 |
| Exact rational arithmetic on captured binary64 storage/flux primitives | -4.520616382429578e-5 |
| Independent MvG retention difference at 80 and 120 decimal digits, frozen heads | -4.520616382425741e-5 |
| Same independent equations, heads updated by the unrounded captured Newton step | 5.380136412842311e-17 |
| Existing effective total tolerance | 4.160257649522721e-5 |

Thus improved summation alone cannot correct this terminal solve. Nor is a simple
replacement of `theta-theta_previous` a new remedy: the production MvG provider
already uses a stable increment. Independent high-precision retention reproduces
the residual from the rounded heads. Applying the unrounded Newton updates in
high precision removes that residual in the frozen explicit-conductivity system.
The 80/120-digit agreement is numerical evidence, not an interval-arithmetic proof
or a high-precision reference trajectory for the complete model.

## Small executable fixture

`integration/diagnostics/perf01_precision_replay.f90` reconstructs every captured
residual and storage increment **exactly** using the actual production provider.
Its standalone build needs only the soil-water contract, default MvG provider
and driver, three Fortran sources. No full column run or column objects are
needed for this standalone execution once the captured CSV inputs are extracted.
O0/O2 standalone and original-object replays produce identical results.

The fixture examines 60 single-ULP changes, both directions at 30 interior nodes.
Twenty-five satisfy the unchanged compartment, total and head-increment criteria.
The best changes node 31, giving total residual -4.074193717869729e-5 cm/day. Surface
head and prescribed bottom flux stay fixed; internal gradients and storage are
recomputed. This establishes feasibility for that frozen solve. It does not
execute the complete dynamic surface publication, temporal, chemical or restart
acceptance chain and cannot qualify a production solver change.

`replay_perf01_precision.py --standalone` compiles that closure and independently
evaluates the captured equations with exact rational and 80/120-digit Decimal
arithmetic. Specify `--capture`, `--build` (compiler/profile manifest directory),
and a new `--output` directory. `capture_perf01_precision.py` regenerates the full
native capture when given a fresh source-matching column build and original input.

## Full-model counterfactual and limits

Generated-only HeadCalc instrumentation tests one adjacent interior head when
the Newton subtraction stagnates and every compartment already passes while
total balance fails. Candidate selection uses the capacity and grid to predict
the smallest total residual. It then re-evaluates actual constitutive storage,
gradients and the full native residual. Every original convergence, surface,
mass, temporal and transaction acceptance check remains in the executed path.
No iteration or retry tolerance is relaxed. It is an experimental algorithm,
with extra residual evaluations, not merely an observer or a production feature.

Two five-window prefixes finish at 0.078125 day with O0/O2 byte-identical budgets,
states, endpoints, trajectories and restart files, and identical work counters.
The largest water and solute budget residuals are 7.502158616556898e-14 cm and
1.950037002296375e-13 mg/cm2. The application transaction mass tolerance stays
1e-10. There are 34971 rounding attempts: 8749 pass the local compartment/total
tests and 26222 do not. Local pass counts include rejected transaction branches;
they are not counts of committed physical steps.

The prefix uses 202137 HeadCalc calls and 822126 nonlinear iterations, with no mass
rejections. Relative to the original five accepted windows, maximum head,
water-content and concentration differences are 1.4144562396722904e-4 cm,
7.7680762933241e-9 and7.196749418625359e-9 mg/cm3. These are trajectory differences,
not errors against independent truth. Single timings are retained, not used for
a matched-error performance claim. Byte-identical O0/O2 restart files are not a
fresh-process continuation-equivalence qualification for the new algorithm.

The first O2 six-window trial did **not** complete. It received SIGKILL after
115.297749 seconds; no terminal model status or sixth-window clocks were
published. The cause of that particular signal is not established by a before/
after resource measurement. It is retained as censored evidence, never PASS.
No 64-window trial followed it.

Subsequent runs have explicit 512MiB address-space limits. The experimental
five-window prefixes finish within 30 seconds. An experimental fresh-process
restart into window 6, limited to 15 seconds, fails allocation after 6.79 seconds.
Its last sampled accepted cursor is 0.08654370516502695 day, after 3840 accepted
substeps, 11144 solver rejections and 44232 temporal rejections. This is internal
working progress, not an external committed reporting-window clock.

A paired unmodified-numerics control also completes five windows under 512MiB,
then fails allocation in window 6 under the **same** limit. The experimental
allocation failure is in the flux-history payload append; the original control
fails another trace-payload allocation. This identifies a resource boundary in
this test. It does not prove a new memory regression, a leak, or intrinsic
inability to finish with more memory. The arena retains immutable trial payloads
while rollback restores a tail/count view. Any reclamation change must preserve
live sibling/checkpoint views and stale-history rejection; blindly truncating
the arena on rollback is not selected.

## Disposition

Head quantization is now independently reproducible in a small native fixture.
The one-ULP experimental remedy is **not production-qualified**: it has no
completed sixth-window or full-day trajectory, independent global-error proof
or full restart/failure-atomicity qualification. Long infiltrating dry32 remains
excluded. The next scientific work requires bounded history-memory handling and
the full temporal-controller trajectory, in addition to a numerical correction.

Raw native successes, expected original failures, SIGKILL, bounded allocation
failures, commands and compiler/source/object identities are archived together.
`verify_perf01_precision.py --self-test` reconstructs the independent arithmetic,
checks all selected outcomes and rejects evidence corruption or false completion.
Existing current production qualification and documentation gates are preserved.
Invariants 3,5,7,22,23,25,26 are relevant; no shared production interface changes.
No full F-CI, hosted compilation, regional speed claim or RossFast expansion.
