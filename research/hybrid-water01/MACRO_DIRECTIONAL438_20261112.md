# Fixed original438 state: preserve the original local derivative

Baseline: canonical `173a3e8e1c231108ddd048c593170f9096e5bf4a`, after PR1655.
This block resolves decision-changing hypotheses after the two rejected PR1656
repairs. It changes no production source, physical formula, numerical tolerance,
default, native format or public project profile. Scientific pressure qualification
remains failed; these observations are not a new reference.

## Decisions supported by the actual controls

The final accepted original438 step has a cached maximum residual5.80e-12 and a
fresh original coupled maximum4.319762946. All independent identical-state
evaluations reproduce the entire fresh vector exactly, including the previous
PR1655 observation. The input is the actual complete live Fortran process state,
not a reconstruction from daily averages or from a different model profile.

Eight pressure directions are tested at nodes1/40/56/60/80/81/90/112. Central
differences use absolute perturbations1e-4cm and5e-5cm. Only the indicated trial
pressure, its original watcon theta and pressure gradients are changed; original
SWKIMPL0 conductivities/root terms retain their actual fixed-step meaning.
Every evaluation begins in a separate fork of the identical live context.

For all eight directions, both scales show **exactly zero response outside the
tridiagonal band**. No dense/global Jacobian solver is justified by this selected
hypothesis at this state. This is not a claim about all112 columns, other steps
or the different regimes where PR1656 reached its short caps.

An additional child evaluates the same pressure twice sequentially, crosses
node81 from positive to negative pressure, then restores the exact original
pressure/theta and reevaluates. Sequential residual vectors are exact. The
saturation-crossing round trip also returns the exact residual, recorded wet-wall
fractions, unsaturated macro stores and event flags. Determinism alone would not
prove this; the separate history control actually tests it. It qualifies only
the selected live context, not general numerical rejected-timestep rollback.

Finally the rate-only and rate/Jacobian original tasks return exactly the same
macro exchange vector at this context. The cached/fresh residual change is
accounted for by that exchange change:

```text
maximum |(F_fresh-F_cached) + (Q_macro_fresh-Q_macro_cached)| = 8.881784197001252e-16
maximum |F_fresh-F_cached| = 4.319762946264462
maximum |Q_macro_fresh-Q_macro_cached| = 4.319762946264463
```

Thus the observed accepted residual discrepancy is attributable to the frozen
macro exchange at this step, to rounding precision. This does not quantify how
much of the whole79.511cm groundwater deviation it causes.

| Node | Numerical macro diagonal, fine scale | Original analytic macro diagonal | Absolute difference |
| --- | --- | --- | --- |
|1|0|0|0|
|40|0|0|0|
|56|-2.074577074731e-5|-2.074577246407e-5|1.717e-12|
|60|-0.0155630419852|-0.0155630457151|3.730e-9|
|80|0|0|0|
|81|-0.0503211818437|-0.0503211818472|3.497e-12|
|90|-0.0358012854473|-0.0358012854442|3.100e-12|
|112|0|0|0|

Both perturbation scales and their differences are retained in the machine
result. These are measured derivative differences, not relaxed physical acceptance
tolerances. The selected original analytic derivatives are supported by the
numerical columns; replacing them or the whole solver is not selected.

## Actual execution, unchanged parent and cost

The exact original native432, build and input binding are reused from PR1654.
The original control from PR1655 is reused by immutable raw artifact digest.
No unchanged control is rerun. Three progressively completed observer profiles
execute only433to438; each adds a new independent decision-changing control.

| Actual Actions run | Exact observer source | Model/controller seconds | Added control |
| --- | --- | --- | --- |
|43174240491|70d4d2d0f4e5f148a719d1563bcc80336d0ea682|4.975798|Identical clones and8 directions/two scales|
|43175012277|d9afaa58cddcaa4d8ec7447fcbffe73b87b021bb|4.795550|Sequential and saturation round trip|
|43175514599|6b4a58b0e131a7fe6f8a3e9d45a4ce3b7c9cfc2e|5.815600|Exchange attribution and original analytic derivative|

All three PASS. Total actual observed model/controller wall15.586947479seconds;
20-second cap per route and3-second child alarm. This is not isolated solver CPU
or a runtime-parity benchmark. No full481 or changed-solver time march is run.

All six physical day records and both complete raw native endpoint438 files
are byte/exact-value equal to the retained original control. Earlier directional
and history samples exactly repeat in later profiles. Only children perturb the
operator; no mutation can return to the parent. No checkpoint is rebound or
published as a source-bound package from the research observer. Original and
instrumented executable/source identities remain distinct.

## Immutable evidence and zero-model reproduction

Three raw artifacts are preserved in the repository, including their actual
executables/generated owners, compiler/link commands, original native input,
complete endpoints, daily records and actual derivative/history/exchange samples:

- macro-directional438-first-evidence.zip, artifact13922769904,2424165bytes,
  SHA256 `bfa1f1267e04b0179f2016e0816178c478bbdd6cdb21cda4809cc67a934eec58`.
- macro-directional438-history-evidence.zip, artifact13923861677,2454916bytes,
  SHA256 `ac8e9e51c17629a7c056961c701f0adddabcc72dada0800b82f8113ad82ce7f9`.
- macro-directional438-evidence.zip, artifact13924063164,2511947bytes,
  SHA256 `ec1ce470c8e09e1c893ca1f43f9eeccba064efe9a74bb6e173c76621139ca268`.

Source-bound metadata for the last artifact is in
MACRO_DIRECTIONAL438_ARTIFACT_20261112.json; the owner records all three exact
sources, runs, costs and selections. They do not depend on hosted retention.

Actual model command at each frozen executed source:

```sh
python3 -B research/hybrid-water01/probe_macro_directional438.py --provider "$RUNNER_TEMP/provider" --proof "$RUNNER_TEMP/proof" --output "$RUNNER_TEMP/directional438"
```

The executed workflow preserves exact frozen-provider extraction/compiler checks
and hashes; actual BUILD_LOG.json records all compile/link commands. From the
repository root, reproduce the independent assessment without a model:

```sh
python -B research/hybrid-water01/audit_macro_directional438.py --output AUDIT.json
```

Compare parsed AUDIT.json with MACRO_DIRECTIONAL438_RESULT_20261112.json.
The auditor verifies raw digests, original source/build/native provenance,
every parent physical record, complete raw endpoint, exact repeated samples,
actual one-node inputs, both derivative scales and original exchange attribution.
The current workflow input hybrid_macro_directional438 with macro_expected_sha=HEAD
selects only this preserved-data assessment. Actual model commands stay frozen
at their respective executed source revisions.

## Follow-through decision

No third speculative solver repair follows the two rejected variants. The
selected original438 derivative/history hypotheses do not justify one. Keep the
original equations/derivatives, failed pressure comparison and distinct full
application evidence visible. Whole functional coverage remains three projects;
scientific equivalence, complete energy and runtime parity remain separate.

The next independent functional acceptance point is **actual numerical rejected-
timestep rollback**, using the known original day15 retry window. Check physical
macro state against its pretrial origin, separately from intended retry controls.
External daily discard and exact own14to16 do not already prove that contract.
Modify code only if that controlled comparison demonstrates a violation; retain
the original mass guard and bounded execution. This avoids another unsupported
solver campaign while addressing an explicit architectural requirement.
