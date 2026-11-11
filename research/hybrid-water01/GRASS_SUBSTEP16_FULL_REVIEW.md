# Original Grassgrowth with sixteen internal heat steps

This package qualifies one complete original113-node,1827-day production O2
trajectory using the explicit numerical policy admitted by PR1636. The frozen
scientific source is canonical `7ef987beb098e9e36c4901adfa865d71ebcd8165`.
There are no changes to src/app/tools/tests/reference. The execution selection
was persisted before build/launch; original inputs and release identity were
frozen before the full run. No other full trajectory was started.

| Audited production O2 result | Value |
| --- | ---: |
| Completed original days | 1..1827 |
| Accepted water steps | 636929 |
| Maximum daily water residual | 5.09592368303e-14 cm |
| Cumulative stock-flux water residual | 9.38138455808e-15 cm |
| Maximum uptake attribution residual | 8.30986755102e-16 cm |
| Maximum daily conductive residual | 2.48820697379e-09 J/cm2 |
| Maximum conductive substep residual | 5.04832495252e-11 J/cm2 |
| Signed cumulative conductive residual | -6.59354828694e-07 J/cm2 |
| Fresh own process/checkpoint cuts | 4/4 exact |


The selection and release in `integration/f-ci/GRASS_SUBSTEP16_FULL_20261111.json`,
`grass-substep16-full-receipt.json` and `grass-substep16-full-manifest.json`
bind all original inputs,203 providers/objects, utility archive, compiler,
code-generation flags, actual executable and native commands. Production O2
executable SHA256 is
`c9647b7643f63555ff61404a356f85b551e71852e7debfa0a28e9ba4f69fdb15`.
The profile is `thermal-subcycle16-1e-5C`, selected by `thermal-control-16`;
one-step remains the default and admitted four remains available.

## Unchanged acceptance and exact own continuation

Every day appears exactly once in water, crop and conductive ledgers; every
numeric value is finite. Water continuity, stock-minus-flux closure and uptake
attribution use the existing1e-10cm assertions. Cumulative stock-flux water
closure also meets1e-10cm. The original daily and maximum-substep conductive
limits remain1e-8J/cm2. Signed cumulative conductive residual is reported
separately, without inventing an aggregate acceptance threshold. Original
per-cell/global energy guards and1e-5C temporal tolerance are unchanged.
Conductive bookkeeping is not complete surface energy qualification.

Four fresh own-process windows2-to4,187-to190,365-to367 and1792-to1827 use
captured full-run origins with the exact same immutable release and inputs.
All water/crop/conductive suffix rows and complete final checkpoint bytes must
match; the final cut also matches nodal state and endpoint bytes. No stream is
rebound, no four-step checkpoint is used, and no full historical run is repeated.

PR1636 owns the actual Windows/Linux cold O0/O2, backend lock/reset/rollback,
native refusal/isolation/default-one/four preservation and focused F-CI gates.
Their production/test dependency postimage is unchanged here. This complete
trajectory is Windows GNU16.2 O2; it is not a full O0 or Linux run. Repeating
unrelated or retired broad gates is not selected for this evidence-only package.

## Historical comparison and changed accepted grid

| Day188 quantity | Sixteen-step route (cm) | Original B0 (cm) |
| --- | ---: | ---: |
| potential_cm | 0.142419536509 | 0.141707391074 |
| uptake_cm | 0.136425388891 | 0.125136344464 |
| drought_cm | 0.000000000000 | 0.000000000000 |
| oxygen_cm | 0.005994147618 | 0.016571046610 |

The largest absolute daily differences to B0 are retained in the full receipt.
The daily oxygen difference on day188 remains about0.0105769cm; this criterion
is not passed by a successful functional execution.

The failed literal B0 daily comparison remains visible. The sealed original
reference is verified by its existing manifest, with no new reference run.
Earlier same-soil-state oxygen exchange and30second diagnostic tests keep their
exact original water-only scope; the97.86percent explanation is not assigned to
this new sixteen-step trajectory. Hupsel day584 reference qualification remains
separate and open. No physical or tolerance change is justified by relabeling
a successful functional run as scientific equivalence.

`grass-substep16-full-comparison.json` verifies the previous full-four archive
and original input identities, then records all daily fields for the changed
accepted numerical grid. It is a descriptive comparison, not a new scientific
acceptance criterion. Existing full-one/four/reference evidence is preserved.

## Cost, retention and reproducibility

The monotonic launcher took **1825.680682seconds (30min25.7s)**, compared with
2527.475440seconds for the separately executed full-four route. Accepted water
steps fall from1,016,128 to636,929. These are separate observations, not a
controlled full-period speedup estimate. The process-handle observer failed
after native exit because a PowerShell process property was null; its failure
is retained and total native CPU/separate process wall time is explicitly
UNKNOWN. The valid launcher measurement and model result are unaffected, and
no expensive rerun was made to replace missing timing evidence.

The signed cumulative conductive residual is-6.593548287e-7J/cm2 versus
-1.73816683e-8J/cm2 in the prior four-step trajectory. Both retain the same
daily/substep guards; the larger signed accumulation is disclosed, without
asserting a new cumulative acceptance limit or complete energy qualification.

The initial planning budget was2700seconds with5400second hard cap. No second
full run was launched. Each restart has its own measured command/cap. Native
process-handle CPU/wall observations are retained separately from launcher
monotonic timing. Separate full executions are not controlled alternating
timing; the prior short-window ABBA35.27percent gain remains its bounded claim.
SWAP4.3.1 B0's earlier same-host8.21875seconds uses different numerical controls;
runtime parity remains unachieved.

The raw capsule retains full/restart files, frozen build, original linked inputs
and proof recipes. The independent extraction checks every member, then reruns
the read-only qualifier and compares the complete regenerated receipt bytes.
Reproduction never launches the physical model:

```sh
python research/hybrid-water01/qualify_grass_substep16_full.py \
  --bundle EXTRACTED/bundle --full EXTRACTED/full \
  --restarts EXTRACTED/restarts --spec EXTRACTED/spec.json \
  --file-index EXTRACTED/FILE_INDEX.json --output /tmp/sixteen-reaudit.json
```

Functional coverage: one complete original configuration on the admitted16
option, retaining the existing three-project functional coverage denominator.
Reliability: full daily finite/balance/uptake checks and four own exact process
cuts, with inherited implementation gates explicitly scoped. Development return:
one justified changed-grid full run and bounded continuations, without replaying
unchanged full projects or a broad reference campaign. Whole science, complete
energy and comparable runtime remain separate acceptance steps.

Raw capsule SHA256: `ebd72c84c51e74692f2cdd531c4bf91438a4efe507e4e3ef318b01212969beee`,
6121724bytes,784 retained members. Fresh extraction checks every member and
regenerates the complete receipt byte-exact (SHA256
`bd40fa7880b2c75a2cb4d521905343cde12f93217af461f4a30cbbecf35da523`).
