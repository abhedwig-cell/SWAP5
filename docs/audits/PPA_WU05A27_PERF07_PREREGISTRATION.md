# PPA-WU05-A27-PERF07 preregistration — state-adaptive sorptivity quadrature

Date: 2026-10-02
Status: PREREGISTERED_APPROXIMATE_RESEARCH

PERF06 falsifies global panel reduction but shows that reduced quadrature is accurate in wetter states.

Freeze the first adaptive candidate before trajectory testing:
- surface pressure head < -300 cm: 64 panels;
- -300 <= h < -100 cm: 32 panels;
- -100 <= h < -30 cm: 16 panels;
- h >= -30 cm: 8 panels.

This policy is deliberately conservative relative to the sampled frontier:
- 32 panels at -300 cm has <=0.812% sampled error;
- 16 panels at -100 cm has <=0.543% sampled error;
- 8 panels at -30 cm has <=0.286% sampled error.

The same rule applies globally to all soils and regimes. No soil-specific or case-specific tuning.

Stage 1 extension:
- sample B01/O05 at h=-500,-400,-350,-300,-250,-200,-150,-100,-75,-50,-30,-20,-10,-3,-1 cm;
- compare adaptive S to 64 panels;
- require max relative S error <=1%.

Stage 2 only if Stage 1 passes:
- representative production-C keys R2/G1/B01, R4/G2/B01, R5/G1/O05, R6/G2/O05;
- compare against qualified PERF02 64-panel route;
- mass residual <=1e-6 cm;
- each case must remain E1;
- final total storage and drainage difference <=0.02 cm;
- max sampled theta difference <=0.01;
- five timing repetitions.

A trajectory candidate is promising only if all four cases pass and median C speed improves in at least three of four cases. This remains research-only approximate mode.
