# F-TB13 legacy analytical reference suite

This directory preserves the strongest reusable analytical/reference assets recovered by F-AR01 without promoting the complete historical verification framework as current authority.

The immutable asset archive is `F-TB13_RECOVERED_ANALYTICAL_ASSETS.tar.gz`. It contains:

- the 12-case steady-state layered-water benchmark;
- the documented-metric comparison helper;
- the 12-case homogeneous Srivastava-Yeh/Gardner transient benchmark and independent analytical series solution;
- the common SWAP input template;
- four expected result files from a fresh B1.11 replay.

The source framework archive was `SWAP_4.3.1_verification_framework_extended.zip`, SHA-256 `199f3d1d607255a813bb023c5741de17eacb173c2537a56bfa214ad2827b0fca`.

A fresh replay was performed twice: first with the recovered framework GNU executable and then with a GNU Fortran 14.2.0 build from exact reconstructed corrected reference B1.11. Both runs produced byte-identical preserved result files. See `F-TB13_FRESH_REPLAY_RECEIPT.json`.

This work unit preserves analytical/reference tests and evidence only. It does not claim that the recovered GNU executable is the immutable official B0 executable, does not turn the historical steady-state-solute RMSE table into a hard gate, does not complete Basha (1999), and does not establish SWAP5 production-solver equivalence.
