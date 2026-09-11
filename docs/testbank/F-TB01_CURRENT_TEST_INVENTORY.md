# F-TB01 — Current Test and Qualification Inventory

## Frozen inventory authority

This inventory is bound to `integration/f-ci-canonical@3c5f5bd3686e1632058b906be21abd73883e30ef` with tree `6baaf40271497db831698c5a01de355b5d296dbe`. It is an architectural inventory of the current test/evidence surfaces, not a claim that every historical workunit is current-canonical scientific evidence.

## Current test surfaces

| Surface | Tree authority | Primary role |
|---|---|---|
| `tests/fci` | `bdc1b0758b669392672eb29153efc6afc4d727e3` | canonical admission, frozen-authority replay, governance gates |
| `tests/fmq` | `8a62331af7657bf1f96fc27d48c974f5f2f7f74e` | MultiSWAP qualification |
| `tests/fmr` | `3a7edef9db6305cc6a1442b0edc0a55a6e64a262` | MultiSWAP/runtime owner tests |
| `tests/fpm` | `1a7d649b4848d4169f679c697756b48b0c2e576c` | process/materialization owner tests |
| `tests/fsi` | `0c1e67daed82dbfc5eb2921e520ce12205b99646` | solver/interface and constitutive tests |
| `tests/fvq` | `ad4a80c45b58e511e301b17f23cce8f67ee131fb` | independent scientific/numerical qualification |
| `tests/fwof` | `eee663db2d82f009e27be0588dd4f8b0a9fd8616` | WOFOST/crop workunit tests |
| `tests/runtime` | `a86194db0610f4dadcbb90c0d73e8187847cec16` | runtime contract tests |

Top-level `tests/test_mp_*` assets also provide macropore baseline/CPU characterization. These are not automatically release-quality performance oracles.

## Current canonical preservation authorities

`.github/workflows/fci-canonical.yml` separates frozen historical/source authorities from the moving-current preservation job. The broad canonical matrix includes authorities for F-CI19, F-CI24, F-CI27, F-CI28 restart, F-CI29 ptra ownership, F-CI30 restricted parallel V1, F-CI31 reference ET/root uptake, F-CI34 root attribution, F-CI36 active DIVDRA runtime, F-CI37 parallel root uptake, F-CI39 surface-evaporation capacity and F-CI40 effective-forcing source authority, plus historical F-CI03 through F-CI18 and `current-restricted-canonical-preservation`.

F-CI41 has a dedicated canonical-admission workflow and is admitted on the frozen inventory authority above. F-TB01 records that authority but does not reinterpret prior F-VQ or F-CI evidence.

## Existing coverage to register, not rewrite

Representative reusable assets include:

- B1.10 constitutive-provider checks under `tests/fsi`;
- restart/cold-vs-split-run authority through F-CI28;
- serialized and restricted-parallel MultiSWAP replay through F-CI30/F-CI37;
- active DIVDRA runtime replay through F-CI36;
- root attribution/root-uptake preservation through F-CI34/F-CI37;
- surface-evaporation hydraulic capacity through F-CI39;
- explicit effective-forcing execution through F-CI40;
- restricted surface-evaporation runtime through F-CI41;
- broad moving-current preservation in `.github/workflows/fci-canonical.yml`;
- reference qualification in `.github/workflows/vq-reference.yml`.

## Explicit gaps

F-TB01 does not claim that the repository already contains a complete release testbank. Still-open incremental tracks include a source-locked SWAP 4.3.1 scientific comparison corpus with legacy-defect classifications, analytical/manufactured/property expansion, complete restart coverage for optional state, 100k+ MultiSWAP scaling and difficult-column bounded-cost qualification, application-class SWAP-MODFLOW coupling, reduced/coarse/alternative-solver qualification, cross-platform performance gates and a historical-defect regression catalog.

## Evidence boundary

Directory presence does not imply qualification. Evidence is source-bound to an exact source authority, frozen matrix, oracle/tolerance binding and execution record. Historical qualification remains historical; moving-current preservation requires explicit rebinding.