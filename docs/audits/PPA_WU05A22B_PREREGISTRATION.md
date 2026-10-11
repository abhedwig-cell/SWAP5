# PPA-WU05-A22B preregistration — RFM persistent MB wall/deep fate

Date: 2026-10-01
Status: PREREGISTERED_IMPLEMENTATION_IN_PROGRESS
Baseline: integration/f-ci-canonical@8bfff34e5bf06817f63a571282f70436cd90ede2
Parent blocker: PPA-WU05-A21

## Purpose
Replace the provisional ALT34 MB reservoir release constant with a parameter-free fate owner consistent with the frozen meaning of f_MB: persistent continuous/deep pathway fraction.

## Frozen semantics
A17 MB rate is the activated preferential rate allocated to persistent paths. A19 integrates it exactly once to interval MB input water.

A22B does not introduce an MB residence-time parameter. Vertical delivery along the persistent path is treated as fast on the SWAP model time scale. During passage, wall exchange may transfer water to matrix. Water surviving wall exchange to the structural deep depth Z_IC is published as an RFM deep receipt.

    MB_input = wall_to_matrix + deep_receipt

The deep receipt is NOT silently added to matrix qbot. It is a distinct RFM external/deep-path receipt for later whole-column coupling/accounting.

## Wall exchange
Use the same reduced source-backed law as A22A:

    Philip = chi_wall*(4/ell_ex)*S_wall*Delta sqrt(t)*L_contact
    Darcy  = 8*K*Delta_h/ell_ex^2*Delta t*L_contact
    wall_potential = max(Philip,Darcy)
    wall_to_matrix = min(MB_input,wall_potential)
    deep_receipt = MB_input-wall_to_matrix

L_contact is the caller-owned persistent structural contact length, normally derived from profile geometry such as Z_IC minus entry depth.

No fixed 1 h^-1 MB release constant is used.

## Event history
A22B consumes explicit wall-event age and event sorptivity for the persistent path. It returns candidate wall age/sorptivity only for any persistent-path water retained by a future extended mode. In the leading fast-through route there is no MB reservoir after the interval: all MB input is resolved to wall exchange or deep receipt, so event history resets after the interval.

This is deliberately distinct from A22A endpoint storage, which can persist across intervals.

## Mass ownership

    MB_input_cm - wall_to_matrix_cm - deep_receipt_cm = 0

wall_to_matrix is an internal whole-column transfer.
deep_receipt is an external/deep RFM receipt.
Neither is standard SWAP matrix qbot unless a later coupler explicitly composes that receipt.

## Hard boundaries
No ALT34 1 h^-1 default. No A10 rapid-drain reuse. No residual balancing against tracer recovery. No hidden bottom-q ownership. No standard SWAP macropore state.

## Qualification oracle
MB input 0.5 cm, contact length 80 cm, ell_ex 20 cm, chi=1, S=0.1 cm/sqrt(d), K=0.001 cm/d, Delta h=10 cm, age=0, dt=0.1 d.

Philip dominates and gives a finite wall transfer below input; deep receipt is the exact remainder.

A second case must be wall-capacity limited above input, yielding all MB to matrix and zero deep receipt.

## Exit criteria
QUALIFIED_PRODUCTION_ADMISSION_CANDIDATE_RFM_MB_WALL_DEEP_FATE, explicit falsification, or true blocker.
