# F-PE-TIMEINT17A2 result — route-margin same-route bank

Date: 2026-09-29

Status:

`BLOCKED_TIMEINT17A2_ROUTE_MARGIN_INSUFFICIENT`

Canonical base incorporated before result write:

`integration/f-ci-canonical@e47f337c506551f865aee31288215a7fb91b4214`

Qualification authority:

- workflow run: `36529606269`;
- job: `109280088218`;
- conclusion: SUCCESS.

## Frozen bank result

TIMEINT17A2 replaced the original fixed rain fixtures with formula-derived route-margin fixtures:

- FLUX rain = 0.25 times accepted-origin infiltration capacity;
- HEAD starts at P=0.5 Pmax with Pdot(0)=0;
- RUNOFF starts at P=2 Pmax with Pdot(0)=0;
- horizon = 0.001 d;
- four-level dt ladder from 0.00025 to 0.00003125 d.

The temporal mechanism, physical ledger and all scientific gates remained unchanged.

Final automated classification:

`BLOCKED_TIMEINT17A2_ROUTE_MARGIN_INSUFFICIENT`

Observed:

- eligible complete four-level ladders: 0/12;
- represented materials under the bank gate: 0;
- represented route families under the bank gate: 0;
- order metrics therefore unresolved;
- physical ledger diagnostics on executed segments: PASS;
- cumulative ledger diagnostics on executed segments: PASS;
- theta/head roundtrip diagnostics: PASS;
- endpoint native balance diagnostics: PASS;
- surface-rate collocation diagnostics: PASS.

No second-order same-route qualification can be claimed.

## Important attribution limitation

The current shared TIMEINT17A harness still maps several different terminal mechanisms onto the same externally visible pair:

- `ELIGIBLE=0`;
- `TRANSITION_STEP=n`.

Inspection of the frozen A2 outputs shows many runs that terminate on the first requested interval with:

- unchanged accepted physical state;
- zero physical ledger;
- nonlinear iteration count reaching the configured solve envelope;
- substantial backtracking.

Those observations are consistent with endpoint-solve failure before an accepted route transition can be established.

Other runs execute one or more physical TG intervals before exclusion and may represent true route changes.

Therefore TIMEINT17A2 proves that the route-margin bank still does not produce the required smooth ladders, but it does **not** prove that every exclusion is a physical route event.

Do not label the A2 result as a dynamic-top event failure or as a TG temporal-order failure.

## Stop-rule consequence

The preregistered A2 stop rule forbids a third manually redesigned same-route bank.

Accordingly:

- do not tune rain factors;
- do not shorten the horizon again;
- do not change initial ponding margins;
- do not alter MAXIT or balance tolerances;
- do not select only successful material/route pairs after seeing results.

The smooth-bank qualification path is closed as a bank-design route.

## Parent-gate consequence

The parent TIMEINT17 preregistration says P1 known-time event qualification executes only after positive same-route P0 qualification.

That condition has not been met.

Therefore TIMEINT17 must **not** advance directly to P1/P2 qualification.

A separate attribution work unit is required to answer the unresolved question:

is the dominant blocker a genuine dynamic-top route event, or failure of the endpoint solver composition before route semantics can even be assessed?

That attribution may use the already frozen A/A2 fixtures, but may not claim event qualification.

## Next work unit

Open:

`F-PE-TIMEINT17B — dynamic-top endpoint failure versus route-event attribution`

TIMEINT17B must:

1. distinguish endpoint solve failure from route mismatch explicitly;
2. retain the TIMEINT16C/TIMEINT17 temporal mechanism and tolerances unchanged;
3. record all route states surrounding a trial;
4. compare TG predicted-K endpoint behavior with identical-route KLAG where diagnostic value exists;
5. determine whether event semantics are scientifically reachable without first repairing endpoint robustness.

No event localization or admission gate belongs to TIMEINT17B.

## Production boundary

No production `src/**` change.

No mass-gate change.

No tolerance change.

No adaptive timestep work.

No event localization.

`LEGACY_NUMERICS` remains production default.
