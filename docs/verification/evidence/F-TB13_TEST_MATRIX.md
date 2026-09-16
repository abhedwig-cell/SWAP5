# F-TB13 preserved analytical test matrix

| Gate | Cases | Fresh B1.11 result |
| --- | ---: | --- |
| steady-state layered water | 12 | 12/12 PASS |
| documented steady-state metric comparison | 12 | 12/12 PASS |
| Srivastava-Yeh/Gardner homogeneous transient | 12 | 12/12 PASS |
| Srivastava-Yeh coarse-to-fine h-RMSE convergence | 4 times | 4/4 PASS |
| historical framework GNU vs fresh B1.11 preserved outputs | 4 files | byte-identical |

The preserved suite intentionally excludes the historical steady-state-solute release interpretation and incomplete Basha target from the qualified denominator.
