# Andelst accepted main-domain exchange components

Source and state follow [the day-453 native replay](ANDELST_DRY_WINDOW_REPLAY.md).
The four-day dry window is March 30 through April 2, 1999.

B0 read-only instrumentation in MacroIntegral emitted the four
domain-1 terms and the two saturated per-node vectors for 12,423
accepted steps. The 93 published daily rows matched the B0 control.
V9 read-only instrumentation recorded the corresponding limited
raw-rate components at successful inner-runtime return. Each of
4,010 accepted driver observations matched a unique component value
by duration, start/end domain stock, rapid outflow and signed net
matrix exchange. Their component sum closed against the accepted
net to below 1e-14 cm per substep. Daily budgets, diagnostics,
progress, cost, endpoint state, temperature and restart were
byte-identical to the uninstrumented Linux V9 replay.

| Main-domain exchange, mm per column area | B0 | V9 |
|---|---:|---:|
| Saturated matrix to macro | 0.08749777 | 11.83209777 |
| Perched interflow to macro | 0.00005504 | 0 |
| Macro to saturated matrix | 0.24816760 | 5.82467379 |
| Macro to unsaturated matrix | 0.00030753 | 0.00103674 |
| Net matrix to macro | -0.16092232 | 6.00638723 |

| Node-centre band below surface, cm | B0 saturated net to macro, mm | V9 saturated net to macro, mm |
|---|---:|---:|
| 200 and deeper | 0.025680 | 8.918188 |
| 120 to 200 | 0.055314 | 2.890956 |
| 90 to 120 | -0.005624 | -1.252987 |
| 70 to 90 | -0.236040 | -4.548733 |
| Shallower than 70 | 0 | 0 |

Nodes 90, 91 and 92 (207.5, 212.5 and 217.5 cm) account for 7.6535 mm
net saturated inflow to the V9 domain and 0.0200 mm in B0. The deep
inflow is partially offset by return to the shallower saturated
matrix. Interflow and unsaturated absorption contribute negligibly
to the between-model discrepancy in this window.

Use these deep donor cells for the next direct comparison of matrix
and macro head, Darcy conductance, unlimited saturated rate and
accepted rate. The present experiment locates the discrepancy in
the accepted transport. It does not distinguish the local head
gradient, conductance and the allocation/limiter as causes.
