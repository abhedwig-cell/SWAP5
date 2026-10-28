# DATAQUAL04: identify the actual stall and count failed work

Baseline872cf5aacdd87981206c9c1b6d05318d26fad3e1. RT/HY/MP/VQ, issue1458.
Bounded experimental instrumentation and iteration-budget execution; no numerical
convergence repair, production promotion or historical closure is claimed.

The prior day2.748 value is the last committed source window, not the internal
failure location. Authentic archived replay reaches internal time
2.8486751098551224 and then rolls the entire source window back to2.748. At tiny
successful steps the full/half error falls to2.84e-14cm, groundwater is about
-43.05983cm, pond is zero and macro topology is identical. The failure is not a
persistent full/half temporal error or a surface-film/GWL jump at that point.

New opt-in rejected-trial observations show the inner Richards solve exhausting
its nonlinear iteration budget. Directed64/128/256 probes reject at the same
internal time with exact rollback. Increasing the budget costs more work and
provides no progress. Do not increase these budgets further or loosen temporal,
mass or head tolerances. The next hypothesis must address the existing Richards/
macropore residual and Jacobian; the precise missing derivative/contact mechanism
has not yet been established. Do not import PR1457's different wall law or its
long-run evidence as proof for this route.

The experiment exposed a concrete accounting defect: failed macropore inner
solves returned before their solver diagnostics were copied into trial_outcome_t.
Accepted work was counted; failed matrix Newton work was omitted. The corrected
branch copies the same existing counters before returning. It does not change
retry/acceptance, physics or committed state. Raw rejected records independently
supply the omitted nonlinear iteration and HeadCalc counts. Uncomputed failure
balance fields contain huge() sentinels; these are UNKNOWN, not measured balances.

`--solver-max-iterations` / JSON `solver_max_iterations` exposes the existing
iteration work budget with default64, range1..256. Nondefault values require
experimental mode in both native and Python routes and are bound into prepared
input and restart identity. Production/comparison retain64. This is a research
control, not a performance recommendation. Native mode/range/CRC/binding controls
reject without publishing physical output.

Current O0/O2 short and two-day batches verify valid target completion, unchanged
production streams, exact optimization endpoint/payload and full/split restarts.
The same-origin late-state probes are explicitly diagnostic handoffs, not new
source-bound restart qualification. Every raw result, failed/censored attempt and
build identity is retained. The initial short-batch launch permission failure is
retained as harness failure, not evidence of missing SWAP physics.

`STATUS.json`, `RESULT.json`, `summary.csv` and the owning
`integration/audits/verify_dataqual04_current.py` bind the exact measured scope.
Scientific integration is pending the separate exact-merge admission receipt.

## Reproduction and selected costs

Use the ordinary native-water builder and GNU13.3 checked O0/O2. Cold builds were
required because workspace maintenance removed earlier objects; compiler packages
were restored locally without system installation. Record cold compilation,
transitive rebuild, native execution and validation costs separately. The changed
backend rebuild reuses177 of194 physical providers and compiles17 consumers.
No fresh481, low-air, RossFast or full numerical F-CI campaign is selected.

Run the ordinary JSON batchdriver with `short-batch.json` and `two-day.json` in
this directory. `replay_origin.py` consumes the verified DATAQUAL03 capsule,
uses its authentic original binding without retagging, and records executable
identity and numerical work budget. Set `--diagnostic` for the existing
SWAP5_DIAG_MACRO_TEMPORAL observation stream. `check_controls.py` runs six direct
native negative probes. Capsule extraction must verify SHA256 and its member
manifest. Use empty input-only directories for replay.

## Priorities

1. Capture a focused residual/Jacobian counterexample at internal2.848675, distinguishing candidate macro exchange, saturation/contact and linearization; retain strict acceptance and rollback.
2. Implement and finite-difference qualify a generic repair only after that counterexample identifies the missing mechanism.
3. Use corrected failed-work totals to rank short pairwise hydraulic/forcing batches before extending model duration.
4. Compare completed flux/GWL periods with4.3.1; keep production admission separate.

## Recorded final result

Twenty current batch executions:12 physically valid target completions and8 intended
range/mode rejections. Six additional direct native controls pass. Executions are
not20 independent historical configurations. Additional origin-state diagnostics
and retained development/harness attempts are not counted as primary successes.

| Work budget | Old reported Newton iterations | Corrected iterations | Previously omitted | Corrected HeadCalc calls |
| --- | ---: | ---: | ---: | ---: |
|64, O0 and O2|25,846|29,878|4,032|2,523|
|128, O2|25,846|33,910|8,064|2,523|
|256, O2|25,846|41,974|16,128|2,523|

All three budgets have63 recorded rejected inner solves and the identical final
internal time2.8486751098551224. Their physical progress streams and complete
rollback bytes are identical to the authentic predecessor. Failed source-window
internal accepted substeps are not committed progress. Same-machine observed O2
elapsed25.73/35.81/58.72s and O0 default44.73s are retained, without portable speed
claims. The corrected default also counts88,805 backtracking attempts, formerly
39,041; failed line-search work was particularly underreported.

Current full/split two-day budget128 restart files are exact on each optimization;
O0/O2 state, temperature and physical restart payload are exact. Production2day
state/temperature/budget/progress/cost/diagnostics and physical restart payload
remain predecessor-exact. This bounded result qualifies instrumentation and the
explicit work-budget route, not a new historical simulation period.
