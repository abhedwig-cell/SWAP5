# A27 physical exchange and history mechanism contract

Date: 2026-10-02. Status: PREREGISTERED_RESEARCH_ONLY.
Baseline A27: afc7d219f5aa2ee74ba51c411e40c1d8921d04aa.
Canonical: c240a3c1c880663d86e1a702ff283a866ca809ee.
New canonical delta contains only LOW03/LOWGWL research/control material; no A27 dependency or production source changes. AGENTS and Status-A authorities remain identical to the preceding reconciliation.

## Source discrimination

Read the original hash-controlled B1.11 macrorate.f90 ABSORPTION and macropore.f90 MACROSTATE, and the migrated standard sorptivity rate/history and saturated exchange modules. Local originals match SHA256 537a84861fb256be67298064177b3e578305c1d036fe7376471d5bd3f7d4dcc7 and f44049c551b5206ada58f1bb150bc250c5502171e49568a7ad8f01eed7bf106f. Repository authority: integration/audits/PPA_WU05A_MACROPORE_AUTHORITY_CONTRACT.json. Do not revive its historical source-availability blocker.

Live theory authority: https://swap.wur.nl/manual/06_macropore_flow.html (accessed2026-10-02), sections6.3.2/6.3.3, equations6.42-6.53. Equation6.45 supplies theta-minus-theoretical-theta moisture correction;6.46 is an alternative diffusion closure, not a wall-profile PDE. Signed saturated Darcy is separate. The manual identifies Philip1957, Greco/Hendriks/Hamminga1997 and Gerke/vanGenuchten1993/1996. Citation metadata alone is not full original-paper verification; log inaccessible originals explicitly.

## Three prospective probes

1. External wetting with maintained contact: compile actual standard rate/history modules and measure active sorptivity at fixed age/reference while theta changes. Preserve the seed. Compare independent equation6.45 algebra with actual output. A separate horizontal constant-D diffusion slab receives an explicitly accounted moisture pulse; compare retained-profile response against a frozen-seed/age-only diagnostic. The slab is not a nonlinear Richards/field reference.
2. Contact interruption: compile actual standard history reset and reseeding. Independently solve a constant-D horizontal slab with theta=theta_s at the wet wall and no-flow at the polygon centre. During dry contact switch wall to no-flow, keeping matrix water; no evaporation or dry reset is imposed. Wet duration0.2day, gaps0.001/0.01/0.1/0.5day, renewed contact0.00025/0.001/0.01day. Compare original-profile rewet uptake with homogenized same-mean profile and scalar age-reset uptake. This tests exact reset only under explicit no-loss interruption, not every drying environment or approximate field closure.
3. Pressure reversal: actual saturated Darcy primitive must give both signs. Independent two-storage exchange: q=g(h_mp-h_mt), C_mt=0.5,C_mp=0.05 cm/cm, g=8*K/L^2, L=10cm,K=0.025/1/5cm/day, unit-thickness wall. Initially h_mt=2,h_mp=4cm. At t=0.5day add4cm to matrix head as an owned external pulse. Simulate to1day at dt0.5/0.25/0.125/0.0625day. Compare accepted-origin explicit, backward-coupled, explicit subcycling (g*(1/C_mt+1/C_mp)*subdt<=0.1), one-sided and exact exponential flow. Report ledger, equilibrium overshoot, sign reversal and all head/exchange differences. No universal iterative/monolithic requirement follows from this linear diagnostic.

## Reference and gates

Slab: length10cm,D=10cm2/day,theta_i=0.20,theta_s=0.45. Cell-centred conservative diffusion with exact-in-time discrete spectral propagation at128/256/512 cells. Check continuous finite-slab eigenseries uptake for constant wetting at0.05/0.2/1day. Finest spatial error and successive-mesh rewet uptake error <=0.0001cm; dry no-flow mass change <=1e-10cm. Retain every error/negative finding. External wetting pulse at0.2day changes each cell by0.25*(theta_s-theta); record actual mass. Frozen scalar uses initial semi-infinite seed S0=2*(theta_s-theta_i)*sqrt(D/pi), not SWAP calibration.

Fortran source checks: actual outputs versus independent algebra within1e-12cm, O0/O2 equality, immutable accepted history, replay, reset/reseed. Persist raw output, exact code SHA, hashes, compiler/package versions and scripts. The500-case cohort screens remain unchanged.

No production source, top receipt, MB fate, A26H contract, ABI, restart state or numerical defaults may change. New operators live under research/rfm/a27. This block chooses a physical/state research route; it cannot admit or establish full A/B/C equivalence/performance. Central regie owns admission.
