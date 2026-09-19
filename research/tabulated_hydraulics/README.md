# Tabulated hydraulics characterization

This directory is an evidence-only research harness. It does not change SWAP5 production physics.

The first check reproduces the near-saturation indexing path in the current public SWAP tabulated-hydraulics implementation at pinned upstream commit `c22bd832ddf3e53e330a552f5e31e74f183362d1`.

The current reader preprocessing sets `ientrytab(lay,1)=0`. For pressure heads in the small negative range where the fast lookup clamps to `k=1`, `EvalTabulatedFunction` assigns `klo=0` and indexes `sptab(...,klo)`, although the third dimension of `sptab` starts at 1.

The workflow compiles with `-fcheck=all` and treats a bounds-check failure as successful defect reproduction. A later qualification step should add constitutive accuracy tests for theta(h), C(h), K(h), and dK/dh after this indexing defect is bounded or repaired.
