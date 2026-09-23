# TAB-HYD application-gate reconciliation — 2026-09-23

Status: **BOUNDED EVIDENCE AUDIT COMPLETE / F APPLICATION GATE NOT QUALIFIED BY THIS AUDIT**

This is a research-side source/evidence reconciliation. It does not reopen K0 representation research, change production ownership, execute a new hydrological simulation, or grant production admission.

## 1. Observed authority

- Research source/results head before this audit: `9aa560a7b8631d14149ffd5a6aab77a1787547b9` on `research/tabulated-hydraulics-characterization`.
- Canonical head observed in the live reconciliation: `bcef9debe56d14ce9b7d75ddbfe5c60c1323d8a5` on `integration/f-ci-canonical`.
- Production head observed and rechecked: `52a455d45fabc6499ad54b89b7e930b02b66ff51` on `work/f-tab02-generated-k0-provider`.
- The production status record still binds its qualification authority to `a2d99ddd149ffaa422d9c422f96bd66e92c8555d`. Observing a later canonical head does not transplant production qualification to that head or authorize a merge.

Production source and production qualification records were read-only in this audit. All repository changes from this audit stay under `research/tabulated_hydraulics/`.

## 2. Dynamic research evidence verified against executed logs

Record: `TYPED_REFERENCE_RICHARDS_DYNAMIC_RESULT.md`.

Controlling workflow: run `35900988596`, benchmark job `107316858888`, successful. The executed job checked out research source `635da89c961c0463260582e09345308e08ac7e34` and canonical `bcef9debe56d14ce9b7d75ddbfe5c60c1323d8a5`.

The research-only typed raw-head400 provider was compared with the analytical provider in a four-node, 16-step non-equilibrium Reference-Richards fixture. Eight balanced repeated trajectory rounds were reported.

| Material | Analytical median (s) | Table median (s) | Runtime reduction | Maximum head difference (cm) | Nonlinear iterations, analytical/table |
| --- | ---: | ---: | ---: | ---: | ---: |
| B4 | 0.032332 | 0.022236 | 31.23% | 7.010808e-6 | 77 / 77 |
| B9 | 0.0273185 | 0.018727 | 31.45% | 9.460980e-7 | 62 / 62 |
| B12 | 0.0251465 | 0.017567 | 30.14% | 4.724836e-6 | 55 / 55 |
| O13 | 0.023787 | 0.016626 | 30.10% | 1.161015e-6 | 51 / 51 |

The linear-solve counts also match route by route. The worst reported water-content difference is approximately `3.81e-9`; native and integrated mass-residual differences are at most `1.7763568394002505e-15` and `2.220446049250313e-16` respectively.

Interpretation: the observed speed reduction does not require fewer total nonlinear iterations or linear solves. Equal counts alone do not prove identical internal numerical paths; the trajectories are demonstrably close, not bitwise identical.

**The provider in this research job is not the separately implemented F-TAB02 production provider. These percentages must not be relabelled as full-application or production speedup.** Production performance remains controlled by its own qualification records. For example, the two E qualification executions `35824004715` and `35824244178` report serialized-runtime reductions of approximately 4.72–9.18% across their bounded profiles, not whole-Hupsel runtimes.

## 3. Production gate status: green preservation is not F

At production head `52a455d45fabc6499ad54b89b7e930b02b66ff51`, `integration/f-tab/F-TAB02_STATUS.json` records:

- A, B, C, D, E and G: PASS;
- F0 provider selection/lifetime: PASS, controlling run `35884404981`;
- F exact whole-Hupsel: `READY_TO_EXECUTE`, not PASS.

The jobs inspected in production run `35901906716` are `slice-a`, `slice-b`, `slice-c`, `slice-d`, `slice-e` and `slice-g`; all completed successfully. The exact workflow `.github/workflows/f-tab02-generated-k0-provider.yml` defines those jobs, but does not define a whole-Hupsel F job. F0 has its own earlier controlling qualification.

The successful source-snapshot run `35902072731` packages source and records. It is not an application execution either.

Therefore neither this green preservation run nor the successful source-snapshot run demonstrates whole-Hupsel generated-provider equivalence. This observation does not claim that no application runner can exist elsewhere; it identifies exactly what these inspected workflows establish.

## 4. New source-snapshot integrity finding

Downloaded artifact:

- run: `35902072731`;
- artifact ID: `10768899841`;
- name: `f-tab02-f-source-snapshot`;
- archive size: `599504 bytes`;
- archive SHA-256: `14ec4a441e21c9c1cafa950f8509e8c7a5cc4f618f16430ce12158a6f48ef7ca`.

The downloaded archive digest matches GitHub's artifact digest. Its `PRODUCTION_HEAD.txt` names `52a455d45fabc6499ad54b89b7e930b02b66ff51`.

Local verification of the original extracted artifact established:

- 265 manifest entries, without duplicate paths;
- manifest paths cover all extracted files;
- all **264 non-manifest payload files match their recorded SHA-256**;
- the only mismatching entry is `SHA256SUMS.txt` itself;
- recorded self digest: `d3e8725ec6d84208888b3ca9d888b245d315ae7356bd26721c5144a1eb07cb6b`;
- actual completed-manifest digest: `a3b9414be06dbae022b2be226d09f2c7871c0937affc109439f6b0c6f2b6f50e`.

Source inspection of `.github/workflows/f-tab02-f-source-snapshot.yml` confirms the cause: the output manifest is placed inside the directory passed to `find`, without excluding itself. Its entry therefore describes bytes read while that manifest is being produced, not the final manifest.

Classification: **packaging/checksum metadata defect, not generated-constitutive scientific failure**. Matching the supplied payload manifest establishes archive/manifest consistency; it does not independently establish the exact SWAP 4.3.1 external-asset authority required by F1.

A packaging-only correction was executed on a separate local copy:

```bash
set -euo pipefail
find ftab02-f-source -type f \
  ! -path 'ftab02-f-source/SHA256SUMS.txt' -print0 \
  | LC_ALL=C sort -z \
  | xargs -0 sha256sum > ftab02-f-source/SHA256SUMS.txt
sha256sum --check ftab02-f-source/SHA256SUMS.txt
```

Result: exit code 0, **264/264 checks pass**, and every non-manifest payload file remains byte-identical to the original extracted archive. The original archive was retained unchanged. This correction was **not** applied to the production repository; its owner can apply the same exclusion without changing physical or numerical code.

## 5. Historical M1 runners are evidence, not drop-in candidate gates

The source snapshot includes the original M1 qualification/closeout scripts. Static inspection found:

- `tests-m1/run_m1_c3_final_owner_qualification.sh` binds the original narrowly constrained production-file delta and historical compile roster;
- `tests-m1/run_m1_final_closeout.sh` checks pinned historical blobs and the persisted original M1 qualification record.

Those guards serve their historical work unit. Running an unchanged historical closeout check, or merely reading its old PASS record, cannot qualify the newly selected generated-provider route. The F candidate needs candidate-specific build assembly and fresh execution while preserving the preregistered scientific acceptance criteria. This is not permission to weaken those criteria or alter the historical records.

## 6. Exact remaining application contract — unchanged

Controlling production preregistration: `integration/f-tab/F-TAB02_F_PREREGISTRATION.json`.

The next production-owned execution must retain all F1–F7 conditions, including:

1. Verify exact external archive, input and B1.11 source-manifest authority before executing. The required `SWAP_4.3.1.zip` SHA-256 is `2b48353db6cdf00246a1e5c0dcaafc2c61858729fad18446a1dc66359ec2a360`, size `8959314 bytes`.
2. Execute analytical-default and explicit generated-opt-in variants of the same exact M1-C3/Hupsel application route and input bytes, without an unreported compatibility fallback.
3. Establish normal completion, `32518` accepted physical intervals and route census `3505 / 14062 / 14951`; report retries separately.
4. Preserve accepted-state ownership and mass-balance acceptance without tolerance, retry or timestep changes.
5. Compare `result.bal` and `result.blc`, normalizing only the nondeterministic `Generated at:` line. Any remaining mismatch is an explicit blocker under the current preregistration, not an invitation to silently broaden normalization.
6. Preserve analytical default, explicit standalone opt-in and the bounded F-SI39/Hupsel KSATEXM scope. No generic tables, generic KSATEXM, worker/MultiSWAP activation or K1 widening.

No full-application runtime reduction has been established by this audit. Any eventual application timing claim must identify the actual production candidate and workload; the research microbenchmark percentage is not a substitute.

## 7. Disposition

**K0 REPRESENTATION RESEARCH REMAINS CLOSED.**

This bounded audit found no demonstrated new scientific discrepancy attributable to generated constitutive interpolation. It did find and locally characterize a packaging defect and clarify the remaining application evidence boundary. Neither finding justifies a new interpolation or tolerance-tuning experiment.

Production closure remains owned by F-TAB02. A concrete generated-constitutive discrepancy from the exact F application comparison is the condition for returning scientific diagnosis to this research line. No production code, default, qualification status or admission state is changed here.
