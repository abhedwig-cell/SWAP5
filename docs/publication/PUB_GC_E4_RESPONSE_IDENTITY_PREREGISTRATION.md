# PUB-GC E4 preregistration — finite-window response identity

## Status

**PREREGISTERED BEFORE E4 EXECUTION**

Date: 2026-09-18.

Canonical baseline:

`integration/f-ci-canonical@86969f502015ae259a536a57cc7125c38a3e42e6`

Publication line: PUB-GC / COUPLE.

E1/E2 established interface and transaction authority. E3 established a valid weak-feedback control regime and localized the current higher-flux/window boundaries to bounded SWAP predictor/corrector execution. E4 now asks what response information the component actually exposes.

No production physics, coupling tolerance, temporal tolerance, retry budget or solver setting is changed by E4.

## Research question

For one immutable accepted SWAP origin and one finite coupling window, what is the relationship among:

```text
u_A      current accepted-trajectory response coefficient
u_FD     centred flux-to-terminal-head finite-difference response
J_S      d(whole-window storage change) / dH
J_R      d(whole-window accepted-sign interface transfer) / dH
```

and over what perturbation range are the head-driven derivatives reproducible?

E4 does not assume in advance that these quantities are equal.

## Response definitions

### Head-driven finite-window response

For fixed accepted state `S_n`, forcing `F_W` and window `W`, define:

```text
V_u(H) = accepted-sign whole-window SWAP-to-groundwater transfer
```

with `V_u` in metres of water depth.

The interface derivative is:

```text
J_R = d V_u / d H
```

with units m/m.

The storage response is:

```text
J_S = d DeltaS / d H
```

where `DeltaS` is converted from the canonical SWAP native column-depth carrier to metres before differentiation.

### Current analytic/trajectory response

The current F-GC44/F-GC30 route exposes:

```text
u_A
```

through the accepted-trajectory predictor response.

E4 treats this as a measured response quantity whose identity must be established, not as an assumed storage coefficient or interface Jacobian.

### Centred flux-driven response

For a prescribed-bottom-flux predictor mapping

```text
q_bot -> H_end
```

define:

```text
u_FD(deltaq) =
    ((q_plus - q_minus) * DeltaT_day)
    /
    (100 * (H_end_plus - H_end_minus))
```

where `q` is in cm/day and `H` in metres. The factor 100 converts the head difference to centimetres, so `u_FD` is dimensionless.

## Baseline states

Five already demonstrated predictor states are used.

| ID | window (day) | q predictor (cm/day) | reason |
| --- | ---: | ---: | --- |
| B1 | 1e-4 | 1e-6 | F-GC44/E1 control |
| B2 | 1e-3 | 1e-6 | longer-window low-flux control |
| B3 | 1e-3 | 1e-4 | 100x flux, E3-D READY and E3-R converged |
| B4 | 1e-2 | 1e-6 | longest-window low-flux control |
| B5 | 1e-2 | 1e-4 | E3-D READY predictor; known corrector-envelope edge |

B5 is intentionally included even though E3-R showed prescribed-head corrector failures for small departures from the predictor reference. A bounded failure is part of the E4 response-domain result.

## E4-A — head-driven response scan

For each baseline, initialize the real SWAP bridge once and retain the same accepted origin.

Reference head:

```text
H0 = predictor reference head
```

### Repeatability

Evaluate the head-driven diagnostic trial at `H0` three times, discarding every candidate.

Record:

- whole-window transfer `V_u`;
- storage start/end/change;
- total inflow/outflow;
- canonical mass residual;
- terminal bottom flux;
- execution status.

The authoritative state tuple must remain unchanged after every trial.

### Symmetric perturbations

Use the fixed geometric sequence:

```text
deltaH_m =
  1e-10
  3e-10
  1e-9
  3e-9
  1e-8
  3e-8
  1e-7
  3e-7
  1e-6
  3e-6
  1e-5
```

For every `deltaH`, evaluate independently from the same accepted origin:

```text
H_minus = H0 - deltaH
H_plus  = H0 + deltaH
```

A centred derivative is available only if **both** trials complete under the unchanged transaction policy.

No one-sided derivative is substituted into the primary identity analysis when one side fails.

### Derived quantities

For every valid centred pair:

```text
J_R(deltaH) =
  (V_u(H_plus) - V_u(H_minus))
  / (2 deltaH)

J_S(deltaH) =
  (DeltaS_m(H_plus) - DeltaS_m(H_minus))
  / (2 deltaH)
```

Also report:

```text
J_R / u_A
J_S / u_A
J_R / J_S
```

when denominators are numerically meaningful.

No sign is normalized after observing the result.

## E4-B — flux-driven response scan

For each baseline q0, use centred predictor perturbations:

```text
deltaq / q0 =
  1e-4
  3e-4
  1e-3
  3e-3
  1e-2
  3e-2
  1e-1
```

Each q-minus and q-plus predictor is executed in an independent process using the same initial physical state and window.

A centred `u_FD` is reported only if both predictors are READY and produce finite `H_end`.

The scan also records the current `u_A` for each perturbed predictor, but the primary comparison uses the unperturbed baseline `u_A`.

## Qualification-only mass observer

The production SWAP participant does not expose its internal trial mass record.

E4 may therefore add a **qualification-only bridge function** that executes the same real FMR prescribed-head trial from a freshly captured checkpoint of the unchanged committed state and reports:

- public-sign `q_swap`;
- whole-window bottom exchange;
- storage start/end/change;
- total inflow/outflow;
- mass residual.

This function must:

1. use the same corrector backend, parameters, forcing materializer, numerical configuration, datum and coupling window as the production F-GC44 participant;
2. discard its candidate before returning;
3. leave committed SWAP revision/time and interface ledger unchanged;
4. reproduce the production-participant `q_swap` at `H0` to representation-scale tolerance.

If parity at `H0` fails, the E4 diagnostic path is invalid and no response result is interpreted.

## Numerical noise and derivative plateau

The three H0 repeats establish the deterministic repeatability floor.

For a derivative sequence to be called a **plateau candidate**:

- at least three consecutive valid centred perturbation levels must exist;
- their absolute derivative values must be above the repeatability/representation floor;
- their relative spread around the median must be <= 1%.

This 1% criterion is a reporting rule, not a physical accuracy claim.

If no such plateau exists, E4 reports that the derivative is not robustly identifiable over the tested perturbation range.

## Identity assessment

E4 does not use a binary equality tolerance to force a label.

For every baseline report the plateau estimates, if available, and relative discrepancies:

```text
E_AFD = |u_A - u_FD| / max(|u_A|, |u_FD|, eps)

E_AS  = |u_A - J_S| / max(|u_A|, |J_S|, eps)

E_AR+ = |u_A - J_R| / max(|u_A|, |J_R|, eps)

E_AR- = |u_A + J_R| / max(|u_A|, |J_R|, eps)
```

Both `E_AR+` and `E_AR-` are retained because the sign relation between the storage-style response and the outward interface-transfer derivative is a scientific result, not a preregistered assumption.

## Failure semantics

Structured head-trial failure is evidence of a bounded local response domain.

It must not be converted to a valid derivative by:

- relaxing retry limits;
- relaxing temporal or mass tolerances;
- reducing solver requirements;
- extrapolating through the failed side.

Similarly, a failed q-plus/q-minus predictor pair means `u_FD` is unavailable at that perturbation scale.

## Primary E4 outputs

For each baseline:

1. `u_A`;
2. `u_FD(deltaq)` sequence and plateau estimate if available;
3. `J_S(deltaH)` sequence and plateau estimate if available;
4. `J_R(deltaH)` sequence and plateau estimate if available;
5. response ratios/discrepancies;
6. largest symmetric valid head perturbation;
7. first failed head-perturbation scale on either side;
8. repeatability floor;
9. mass-closure check for every successful head trial.

## Stop/go interpretation

### If u_A ~= u_FD ~= J_S and not J_R

Interpret the current response primarily as a storage / inverse flux-to-head linearization, close in scientific role to dynamic-storage coupling prior art. ACCELERATE must use a different object if it requires the actual interface derivative.

### If u_A ~= u_FD ~= +/-J_R

The current response behaves as a finite-window interface tangent within the tested local domain.

### If u_A tracks neither J_S nor J_R

The physical/numerical meaning of the current coupling response requires further derivation before it can support an acceleration claim.

### If no stable J_R plateau exists

A single local head-to-exchange tangent is not a robust response descriptor in that regime. This is adverse evidence for a tangent-based ACCELERATE claim and may motivate a richer finite-window response only if coupling value justifies it.

## Relation to later work

E4 establishes **response identity and local validity**.

Only after E4 may E5 fairly compare:

- fixed point;
- Aitken;
- IQN/Anderson cold;
- IQN/Anderson with admissible warm history;
- zero-cost oracle response;
- practical supplied response.

E5 is not started merely because a response quantity exists.
