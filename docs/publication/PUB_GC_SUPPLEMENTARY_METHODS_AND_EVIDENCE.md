# PUB-GC supplementary methods and evidence package

## Status

**JOURNAL_NEUTRAL_SUPPLEMENT READY THROUGH CLOSED E7 REALISTIC COMPONENT-DOMAIN RESULT**

Date: 2026-09-18.

This package collects the reproducibility information that is too detailed for the main scientific narrative but must remain auditable. It introduces no new scientific claim.

## S1. Governing evidence sequence

| Block | Scientific purpose | Source head / provenance | Primary workflow evidence | Result state |
| --- | --- | --- | --- | --- |
| E1/E2 | interface identity, conservation, trial/state/mass authority | evidence head `0022e854000afe5a050303d9a0709f72b7dae518` | run `35342313248`; first failed sign-hypothesis run `35342179045` | PASS_RESTRICTED |
| E3 | loose versus iterative coupling and component-envelope characterization | governed consolidated result | main `35343426404`; predictor screen `35343968268`; failure diagnosis `35344946609`; stronger-flux refinement `35344946652` | SUPPORTED_RESTRICTED |
| E4 | finite-window response identity | source `c85b1f1ad2a35ad12d917c54e682e8705c508c7e` | run/job `35349233134 / 105613077818` | SUPPORTED_RESTRICTED |
| E5 | incremental value of supplied response information | source `41e68a89a52f1f0fac00c8cfe920152ffd4e3fda` | run/job `35351467531 / 105620375280`; artifact `10550095859` | SUPPORTED_RESTRICTED_STOP_INDEPENDENT_ACCELERATE |
| E6 active drainage | test stronger response through admitted drainage predictor | source `191f1d8ac0ab0b84eff438023f1d32e00c09b925` | run/job `35360873209 / 105651690323`; artifact `10554144629` | SUPPORTED_NEGATIVE_COMPONENT_ENVELOPE |
| E6 state/flux screen | test stronger response through accepted-state geometry | source `97dba8764ca85c7499cbb2402cf5309447621a66` | run/job `35360999577 / 105651945363`; artifact `10554314676` | PREDICTOR_ONLY_OR_NO_USEFUL_EXPANSION |
| E7 | realistic Hupsel transferability | M1/M1-C3 closed; standalone selection frozen before coupled output | run `35375181814` / job `105698080443` | CLOSED_REALISTIC_COMPONENT_DOMAIN_LIMIT |

## S2. Important execution qualifications

### E1/E2 sign adjudication

The first preregistered sign hypothesis failed. Code-trace adjudication showed two sign transformations between native bottom transfer and public outward-from-SWAP rate. The corrected identity was rerun without changing production coupling code. The failed expectation remains part of the evidence trail.

### E3 component-envelope classification

Cases that fail before a valid SWAP predictor/corrector exists are recorded as component-domain failures. They are not counted as outer-coupling divergence.

### E4 derivative availability

Centred derivatives require valid positive and negative perturbations. A one-sided successful trial is not promoted to `J_R` or `J_S`. B5 therefore reports the head-driven derivative as unavailable, not zero.

### E5 postprocessing failure

The E5 workflow recorded a postprocessing summary-writer error only after all four scientific baseline matrices completed. The governed result retains the complete scientific matrix and artifact digest. The workflow-level postprocessing failure is therefore reported explicitly rather than hidden.

E5 artifact digest:

`sha256:7d19287d89a74848928a566855205ffebd43081ddbb5d19846684f32b265fac4`

### E6 preregistered stop rules

The active-drainage route stops because the prescribed-head reference corrector is not admitted under unchanged production semantics, before any transaction call.

The independent state/flux route stops because no case retains the preregistered symmetric ±1e-4 m corrector neighbourhood required for live E6-B coupling.

No numerical tolerance, retry budget or physical parameter was changed to convert either negative result into a positive case.

## S3. Core machine-readable evidence

| Scientific block | Governing file |
| --- | --- |
| E1/E2 | `PUB_GC_E1_E2_RESULT.json` |
| E3 | `PUB_GC_E3_RESULT.json` plus E3/E3-R detailed result files |
| E4 | `PUB_GC_E4_RESPONSE_IDENTITY_RESULT.json` and `evidence/PUB_GC_E4_DERIVATIVES.csv` |
| E5 | `PUB_GC_E5_INFORMATION_VALUE_RESULT.json` and comparison CSV |
| E6 active drainage | `PUB_GC_E6_ACTIVE_DRAINAGE_RESULT.json` |
| E6 state/flux | `PUB_GC_E6A_STATE_SCREEN_RESULT.json` and summary CSV |
| E7 | `PUB_GC_E7_STANDALONE_SELECTION_RESULT.json` + `PUB_GC_E7_REALISTIC_COMPONENT_DOMAIN_RESULT.json` |

Raw E4 and E6 records are retained under `docs/publication/evidence/` where applicable.

## S4. Figures and tables

Figures F1–F7 are version-controlled SVG assets. F3–F6 are regenerated from governed numerical evidence with:

```text
python docs/publication/figures/generate_pub_gc_numeric_figures.py
```

The figure-to-evidence binding is frozen in:

`docs/publication/figures/PUB_GC_FIGURE_EVIDENCE_MANIFEST.json`

Tables T1–T6 and their evidence notes are frozen in:

`docs/publication/PUB_GC_MANUSCRIPT_TABLES.md`

F7 and T6 are present and encode the zero-window preregistered component-domain outcome explicitly.

## S5. Reproducibility boundaries

The manuscript can reproduce its publication figures/tables from repository evidence without redistributing the historical SWAP 4.3.1 distribution.

The former M1-C3 external-asset prerequisite is now closed in canonical authority:

- M1-C3 whole-Hupsel typed-adapter qualification passed;
- PR #313 admitted criterion 3;
- PR #316 formally closed M1;
- accepted intervals: 32,518;
- exact normalized BAL/BLC identities retained.

The exact externally governed distribution identity remains:

```text
SHA-256:
2b48353db6cdf00246a1e5c0dcaafc2c61858729fad18446a1dc66359ec2a360

size:
8,959,314 bytes
```

For E7, the standalone 2002–2004 Hupsel dynamics were observed with a non-interfering daily trace whose normalized BAL/BLC outputs remained exactly equal to the admitted M1-C3 authority. The selection population, scoring rule and two selected dates were then frozen before any coupled output.

Full-population trace identity:

```text
daily metrics SHA-256:
d532d07a34ad5bdd98730373330bca4b870439eec6783bf9f25b8d58c1906fb3

scored-days SHA-256:
016e6d14a23d5cd5eb0f464167a50f232106cd7cd28c16f11478b04b1d237e6e
```

## S6. E7 closed realistic component-domain evidence

The two frozen Hupsel dates remain:

- 2003-06-17 — median-dynamics control, `Phi=0.5067351598`, daily drainage outflow 0.0225869 cm;
- 2003-05-20 — high-dynamics day, `Phi=0.8831050228`, daily drainage outflow 0.906969 cm.

The current production groundwater owner requires the all-`bottom_mode=5` PPA-WU01 profile and rejects `drainage_response_active` during `tile_config_valid` before owner-state allocation. PPA-WU03 does not widen that process profile.

The publication qualification therefore terminates E7 under its preregistered component-domain stop rule:

```text
workflow run: 35375181814
job:          105698080443
result:       REALISTIC_COMPONENT_DOMAIN_LIMIT
```

No E7 MODFLOW window is executed. Loose and strong completed-window counts are both zero because the required SWAP prescribed-head participant cannot be instantiated while preserving authentic Hupsel drainage.

This is not treated as missing data. It is the E7 result.

No selected date was replaced, no drainage process was disabled, no event interval was merged/shortened, no groundwater parameter was calibrated and no solver/coupling tolerance was changed.

Persistent result files:

- `PUB_GC_E7_REALISTIC_COMPONENT_DOMAIN_RESULT.md`;
- `PUB_GC_E7_REALISTIC_COMPONENT_DOMAIN_RESULT.json`;
- `figures/PUB_GC_F7_REALISTIC_COMPONENT_DOMAIN_LIMIT.svg`.

## S7. Claim and literature controls

Claim wording is controlled by:

`PUB_GC_COUPLE_CLAIM_EVIDENCE_LEDGER.md`

Journal-facing claim audit:

`PUB_GC_MANUSCRIPT_CLAIM_SENTENCE_AUDIT.md`

External prior-art / reference metadata audit:

`PUB_GC_REFERENCE_AUDIT.md`

Current manuscript-readiness boundary:

`PUB_GC_SUBMISSION_READINESS.md`
