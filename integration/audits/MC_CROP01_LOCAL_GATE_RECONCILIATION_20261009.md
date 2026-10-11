# MC-CROP01 consolidated local gate

Baseline canonical: `5df74f95a8443cc62152f9df4c317957579af087`.
Branch science postimage: `28e8a565b45b9e5627c4ed67f17bfa2b7bc35525`.

Reconstructed exact Git blobs locally and executed three independent test programs with `gfortran -std=f2008 -fcheck=all -ffpe-trap=invalid,zero,overflow -Werror`, separately at `-O0` and `-O2`. All six executions PASS, and output comparisons agree. The 4,464-case source-derived oracle passes. Additional tests reject NaN/Infinity at each input argument, verify basal/effective temperature and 0.1 adjustment branch boundaries, and exercise five consecutive germination days.

Verified Git blobs: candidate `13e83db9e7dad60a62c11134f8951d65a23c7dc6`; basic test `06575e9f105db9abfc278a324251847865e0bc48`; source oracle `56b0ef69355f4a885d06ec7dfb45e180729171a5`; boundary test `b2e4fd531586748c8d144607e15d03d3d62266ea`.

STATE: implemented YES; persisted YES; locally tested YES; integrated qualified NO; canonically admitted NO. No production crop event and no accepted weather provenance are claimed. No GitHub Actions run dispatched. The historic normal `MOD_meteo:Meteo(2)` writer and trusted current weather producer remain unresolved. Preserve candidate-only boundary until an authenticated day-start record and preceding F-KT committed-state contract are established.
