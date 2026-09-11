# F-TB02 — Source, Oracle and Disposition Map

| Item | Exact authority | Oracle class | F-TB02 disposition |
|---|---|---|---|
| F-TB01 architecture | `1d039292d5768496c4550a8e1b35a92c6f836504`, tree `217ad406db38b564a8b03e6c34c26b9123b58c6c` | governance architecture | inherited, not requalified |
| Current canonical context | `0aeb0a2ed4096e1f9493d3dabc70962ea5270182`, tree `c77ac75aea522ac20a60da012595af9166efcff6` | none by presence alone | context/source-presence only |
| SWAP-009 historical qualification | `7b5f4650b0c7aa2799a33c49f0d5f36983b2f9f5`, tree `cf12791ea4bcbda3bf6b3238c68ec043ea4885e1` | O1 analytical Kelvin + O6 invariance; parent legacy admission is source-bound | historical qualification only |
| SWAP-009 recorded strict function result | same commit; `reference/swap-4.3.1/patches/SWAP-009/tests/result_gfortran14_2.json` | O1/O6 | replayable evidence record |
| SWAP-011 qualification dossier | same pinned repository commit; `reference/swap-4.3.1/patches/SWAP-011/qualification.md` | O3 independent numerical reference evidence | characterization only; not admitted |
| current FSI24 source surface | current canonical context; `tests/fsi/test_fsi24_gate_c_nonlinear_b110.f90` | O6 owner property surface | characterization until dedicated rebinding |

## Tolerance bindings

`F-TB02-TOL-PDI-KELVIN-RATIO-v1` is not newly tuned. It records the historical SWAP-009 gate threshold exactly:

- class: `SCIENTIFIC_COMPARISON`;
- quantity: old/corrected isolated PDI vapor-conductivity ratio versus independently calculated Kelvin ratio;
- unit: dimensionless;
- comparison: relative error;
- threshold: `1e-9`;
- provenance: pinned SWAP-009 runner and recorded result;
- scope: model 8, `T=20 °C`, `h=-1e5,-1e6,-1e7 cm` in the exact historical candidate gate;
- prohibition: no reuse outside that scope without a new tolerance version and evidence.

Exact-zero non-target deltas use `EXACT_OR_HARD_ONLY`; no numerical tolerance is introduced.

SWAP-011 thresholds are not imported into a new F-TB02 pass/fail policy. The dossier remains characterization evidence because formal patch provenance/admission was incomplete.

## Authority separation

A case path, a stored result, a workflow run and a governance admission are separate authorities. F-TB02 treats the current canonical tree only as source context. Historical evidence is never upgraded by file identity alone; moving-current preservation requires an explicit later requalification workunit.
