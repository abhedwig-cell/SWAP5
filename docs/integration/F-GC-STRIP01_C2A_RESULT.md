# F-GC-STRIP01 C2a — head-matched equilibrium control

Status: **accepted as a bounded research control**. This is not coupled-physics qualification and does not establish rainfall behavior.

The first MODFLOW/SWAP coupled window used 50 one-metre cells and SWAP columns over the 2 m C1 soil profile. All MODFLOW heads, the left drain stage, the SWAP phreatic level, and lower-interface total heads were `-1.0 m`. The initial far-column uplift was removed. The fixed top flux was zero; ET, roots, runoff and other forcing were off. The window was 0.001 d.

Run [37112047980](https://github.com/abhedwig-cell/SWAP5/actions/runs/37112047980) built the fixture against exact canonical source `e3bfcdca00ba89cfeea529cf9b648dcc803483ab` and ran two fresh processes. They produced byte-identical result JSON (SHA-256 `f5cb23a5bce0e6f208d4c7f94951aa0a3e673baa97de10a9be83ed5b050514ac`). The persisted artifact is `F-GC-STRIP01-C2A-37112047980` (artifact digest `sha256:c02018360dd6b0c27abc14356e08a11be8eb818922ccf6e2f291692a79a291b4`).

The application service accepted the window in one iteration. All 50 trial and final MODFLOW heads remained exactly `-1.0 m`; every coupling-flux residual was zero. SWAP storage was unchanged at 0.7499125387644275 m³ per column, and the standalone MODFLOW drain budget was zero. The whole-domain window residual was 0 m³ against the preregistered unchanged (10^{-8}) m³ gate. MODFLOW finalized once, then all 50 SWAP revisions and interface-ledger counts advanced once. No canonical source or admission changed.

Persisted machine-readable evidence:
- `integration/f-gc/strip01/results/C2a_result_run37112047980.json`
- `integration/f-gc/strip01/results/C2a_source_git_blobs_run37112047980.json`
- Parent preregistration: `integration/f-gc/strip01/F-GC-STRIP01_C2_PREREGISTRATION.json`
- Reconciliation addendum: `integration/f-gc/strip01/F-GC-STRIP01_C2_PREREGISTRATION_ADDENDUM.json`

This establishes that the head-matched equilibrium control can publish. It does not resolve the C0/C1 forced-window corrector rejection and it does not test B1.11 rainfall. The next registered experiment uses the canonical dynamic surface-boundary path for rainfall and documents its different numerical continuation layout before implementation.
