# PERF01 refinement discrimination,24 October2026

Neither tighter research budget is selected as an improved candidate. Production
source, defaults and admission remain unchanged. Reference/forcing/endpoint
semantics remain those of PR1424 e3347ac5. Current canonical47a50ea0 contains
separate NUT source changes; these runs are not current-canonical qualification.
The same GNU13.3 compiler version was recovered after workspace maintenance.

| Variant |1x native |4x native |4x max daily runoff difference |
| --- | ---: | ---: | ---: |
| Original endpoint/amount candidate |1.61s|3.40s|0.63574mm |
| Output amount0.0001cm only |1.59s|4.56s|0.63904mm |
| Storage0.0001cm only |4.55s|reject day6|no full-series comparison |

Times are individual observations, not a portable speed claim. Output-only
refinement still removes the0.1175mm runoff event on day199 and preserves the
large opposite-signed day152/153 differences. Its whole-run4x difference remains
-0.73820mm.1x maximum daily difference0.05660mm is also not improved.

Storage-only refinement (output amount returned to0.001cm) completes1x with no
accuracy improvement, but rejects4x day6 after two rain intervals. The retained
policy and ordinary-policy fallback both reject, with zero mass rejections.
This does not identify the precise solver mechanism or prove that all further
refinements fail. It does reject these two specific alternatives as a remedy.

Output-only first2/day146 budget/state/endpoint/restart bytes are exact at O0/O2.
Its1x/4x day240 continuations are byte exact. All completed daily water checks
retain1e-10cm; no threshold, mass gate or history criterion is relaxed. No new
1e-6, RossFast or highest low-air test. Capsule retains failed4x partial outputs
and diagnostics alongside every completed case.

Next: qualify plain-Boesten endpoint event semantics independently; reconcile
current source/owner dependencies before production changes. The original
changed-accuracy candidate remains research only. The strict daily0.01mm FAIL
and positive-chemistry exclusion still apply. Do not claim convergence or general
usability from these trials.
