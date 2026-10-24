# Bounded original BBC and macropore Cauchy composition

Successor to PR1425 on canonical9be9a09b. Existing owners: MIGMAC10,
Reference Richards, matrix/macropore continuation, Rutter and Boesten.
Invariants3,7,13,21,23,25 are preserved. No public type, signature, codec,
constitutive equation, flux sign, process equation or default is changed.

The low-level frozen-conductivity Reference solver admits implicit Cauchy3
with its real residual-synchronous macropore provider. Matrix-area-weighted
storage and conductivity retain the original HeadCalc equations. Fifty-four
independent cases per optimization cover matrix fractions .55/.75/.95,
positive/negative aquifer gradients, extra signed flux, half-cell resistance
and the zero-external-resistance limit. Tests compute Robin flux, individual
matrix cell balances, separate matrix/macropore stock balances and gross water
balance from provider inputs and candidate stocks, without calling the production
bottom evaluator or reading the solver residual/Kmean as an oracle.

The FMR application extension is bounded to the existing combined
Rutter/Boesten/macropore layout with implicit Cauchy3. Its unchanged physical
full/half temporal metric applies to that newly admitted domain. Static,
unchanged and shrinking states pass original rejected-trial, replay and FMR
restart assertions. Heat, snow, response drainage, explicit Cauchy and Picard
macropore combinations remain excluded. New coupled roots, native full Andelst,
general scalar or geometric accuracy and full SOL/NUT are not claimed.

Current O0/O2 BBC481 prepared-input runs and independent day365 continuation
must reproduce the admitted physical budget/state/endpoint/restart bytes exactly.
The first O0 model execution completed; its publisher failed on missing build
metadata. Its exact physical outputs were verified before restoring publication.
The failed publisher command is retained; native timing for it remains UNKNOWN.
O0/O2 separate restart executions and O2 publication complete normally.

Original canonical source/raw assertions and25 controls execute on the exact
predecessor. Those NUT/FCT executions remain dated; they are not rebranded as
fresh. Current macro lifecycle/scalar proof is inherited only with exact source,
driver, forcing, generated-source, compiler/flags and artifact identities from
the retained12-run capsule. Current independent Robin and BBC481 proof is fresh.
Full moving F-CI, highest low-air, new1e-6, RossFast and unchanged nutrient-process
rebuilds are NOT_SELECTED_IMPACT/POLICY, never reported PASS. Original FSI35,
current source/raw corruption checks, docs and exact merge admission remain gates.
