# F-GC-STRIP01 C2-RAIN01 diagnostic result

## Outcome

The repaired one-period/two-step MODFLOW TDIS setup now executes. The exact fresh-process replay is reproducible, but this is a **negative hydrologic result**: the registered dynamic-surface C2a zero-rain window is rejected at the first SWAP corrector. C2b rainfall was not attempted.

All 50 MODFLOW trial heads were −1 m and passed the fixture head-domain guard. The SWAP participant still returned invalid; the context status was 5 and the window was not published. The committed profile state hash remained `8ada1b3d57a832b50d56d33e808c18745b46797250183618a923a142ce9ad7fd`; revisions and interface-ledger counts remained zero. MODFLOW prepared and solved once but did not finalize its solve or time step.

## Isolated direct diagnostics

Per-column direct diagnostic calls were made at −1 m after the rejected window, against the same committed state. All 50 returned call status 0 with raw diagnostic codes `[101,0,0,0,0,1,0,0]` and completed time 0. The meaning of code 101 is not yet mapped, so this evidence does not support labeling these as solver or temporal rejections. These are isolated replays, not counters from the original context call. The state remained unchanged.

The same full sequence reproduced byte-for-byte in two fresh processes (sequence JSON SHA-256 `f1f0a8ccf551d509e65450157b571b2cbc1b11b94b1ef26ad73f47071aa06c9f`).

## Interpretation and next investigation

This B1.11 dynamic-surface variant rejects even in its zero-rain first window, whereas the ordinary C2a matched-head zero-forcing window was accepted. The result is specific to this preregistered variant, which excludes Richards temporal history; it does not establish a general failure of rainfall coupling. C2b was not reached, and no mass balance can be evaluated.

Next inspect the canonical mapping and origin of diagnostic code 101, then compare B1.11 dynamic-surface state/boundary construction against the ordinary C2a path without changing physical forcing or acceptance gates. Keep this variant separate from the ordinary Richards path. Hupsel remains blocked pending an accepted, balanced coupled window.

## Provenance

- Workflow run: [37115035032](https://github.com/abhedwig-cell/SWAP5/actions/runs/37115035032), harness conclusion `success`.
- Research source commit: `d51867150567685e262039cda1242963c62b1221`.
- Canonical source: `e3bfcdca00ba89cfeea529cf9b648dcc803483ab`.
- Artifact digest: `sha256:8f7a23b6f701bb25dea19db70e7272c150cc3b4f2155dc7a160bed56292beaa4`.
- Research/qualification only; no canonical admission.
