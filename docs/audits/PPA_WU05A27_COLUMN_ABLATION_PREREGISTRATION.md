# A27 column reverse-exchange attribution

Status: PREREGISTERED
Canonical baseline: 19f09b818b1bb30c1428919074c00098dbd062bd

Run the production Reference Richards solver on a 100 cm, ten-cell column. MVG parameters derive from the A26 real-Richards fixture; use Ks=1 and 5 cm/day, common remaining retention parameters. No rainfall, explicit zero top flux, fixed bottom head. Wet hydrostatic water table at 20 cm depth; dry control water table at 200 cm depth. Duration one day. Compare reverse exchange off/on. On uses the admitted standard saturated-exchange primitive with frozen accepted matrix heads per interval, a drained receiver at 100 cm depth, 20 cm characteristic diameter, shape factor 0.1 and horizontal conductivity 0.1*Ks. Extracted water is a separately accumulated external preferential receipt, not matrix bottom flux. This is a maintained drained receiver, not a closed finite IC reservoir.

Use dt=0.002,0.001,0.0005 day and output every 0.1 day. Record cumulative reverse exchange, bottom flux, storage, max head departure, per-step solver residual, iterations and backtracks. Hypothesis: wet cases show changing trajectories and distinct preferential receipts; dry controls have zero saturated exchange. Refinement must contract discrepancies in integrated exchange and states before quantitative conclusions.

This is a mechanism-ablation experiment with evolving production Richards states, not the full A/B/C runtime benchmark. Off represents omission of the reverse route, not a complete RFM execution. On is an explicit process split, not the standard coupled corrector. Timing is CPU diagnostics, not speedup evidence. No coefficients may be fitted to agreement. Results cannot qualify RFM equivalence or broad production performance. Production code and shared contracts remain unchanged.
