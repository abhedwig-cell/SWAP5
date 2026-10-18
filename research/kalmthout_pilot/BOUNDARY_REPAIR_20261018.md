# Kalmthout boundary repair work unit

Baseline state-export branch f0897758959833f68d092a29e11420a498652c07.
Canonical observed 9bfb06b672260e2462d78f37daefca98da594735.
Reference branch f6322f73260519ca72b2c9d559590295d5eacc68.
Pilot branch dbdba6c24807f65052a441335c43fe1c92738f7f.

Export run 39133863123 completed success. Artifact 12139382295,
SHA256 0af51e5c8ab5de31ec6f9d96043e0480ef6c0c20953870be2b531720f967477a.
Local validators PASS: 4 nodes, 3655 backtrack decisions, 131 true/3524 false,
747 head/2908 flux. These are not committed-step counts.

Concrete geometry defect: pilot imported test stub MOD_grid. dz=[.5,.5,1,1]
cm, z=[-.25,-.75,-1.5,-2.5] cm, but all node_distance=1 cm.
This is an inconsistent 3 cm column, not an established Kalmthout profile.
Exact physical geometric matching to SWAP4 cannot silently preserve both z and
node_distance. Original geometry retained for failure diagnosis; explicit corrected
geometry will be separately labelled. Export lacks exact accepted time and Rutter
carrier, so existing validator PASS alone is insufficient for exact restart.

Affected invariants: 3,7,8,13,23,25. No acceptance tolerance changes authorized.
Next local build uses existing bootstrap production closure (about 200 providers),
retained in isolated O0/O2 directories. Selected full historical run required to
test wet/dry transitions missed by 48h smoke; expected 60-600 s, cost UNKNOWN.
No new CI requested. Current status: diagnosis verified, correction not yet tested,
no qualification/admission.

## Completed local candidate, next selected repeat

Original 3cm fixture: full 24120h plus byte-identical deterministic repeat PASS.
Original 1700h O0/O2 identity PASS; explicit product FD both regimes max scaled
error 2.1063514091465956e-8; FD on/off CSV identity PASS. Bootstrap owner native
driver O0/O2 PASS, including rejected Rutter forcing leaves accepted state unchanged.

34-node consistent 200cm profile: historical K plateau fails May16 09UTC with
720 temporal rejections and no mass rejection. Isolated restart reproduced.
Continuous-K candidate full 24120h PASS. Max hourly ledger residual
5.0337772145e-14 cm; cumulative ledger/storage closure -7.105427357601002e-14 cm.
Initial storage 69.18231266253387 cm, final soil+pond 71.88682354807725 cm.
A full deterministic repeat on identical executable/forcing is now selected:
expected 300s, needed to establish candidate full-period reproducibility;
prior full candidate PASS cannot establish repeat identity by itself.
Candidate K curve and bootstrap owner O0/O2 PASS. No hydraulic-owner or canonical
admission inferred. No hard mass, temporal or head tolerance was relaxed.
