# Legacy SWAP lower-boundary semantics reconciliation for groundwater coupling

Date: 2026-09-20

Canonical preimage: `integration/f-ci-canonical@919bbf76370c2136932daa04ad88135e7d1615a8`.

## Purpose

This note prevents three different concepts from being collapsed into one another:

1. a standalone legacy SWAP lower-boundary option;
2. a hydraulic state used temporarily inside a coupled numerical solve;
3. the application-level authority of an external groundwater model.

The controlling legacy source evidence is the frozen SWAP4.3.1 B1.11 source inventory already recorded by PPA-WU02, checked against the public SWAP 4.3.030 manual. The public manual is used because the present audit is specifically testing whether later SWAP5 coupling documentation inherited a wrong interpretation.

External references checked on 2026-09-20:

- SWAP manual, Soil water flow:
  https://www.swap.alterra.nl/manual/02_soil_water_flow.html
- SWAP manual, Surface runoff, interflow and drainage:
  https://www.swap.alterra.nl/manual/04_surface_runoff_interflow_and_drainage.html
- 2024 technical SWAP-MODFLOW presentation:
  https://www.stowa.nl/sites/default/files/2024-01/3.%20Ab%20Veldhuizen.pdf

## 1. Correct SWBOTB classification

The source-bound PPA-WU02 classification and the public manual agree on the relevant options.

| SWBOTB | Legacy meaning | Relevant semantic point |
| --- | --- | --- |
| 1 | prescribed groundwater level | groundwater level is the application boundary state |
| 2 | prescribed bottom flux `qbot` | flux-controlled lower boundary |
| 3 | Cauchy/deep-aquifer relation | head/flux relation to regional groundwater |
| 4 | bottom flux as function of groundwater level | lower-boundary/drainage composite semantics |
| 5 | prescribed pressure head at the lower boundary/bottom compartment | lower-face Dirichlet pressure head |
| 6 | zero bottom flux | no-flow lower boundary |
| 7 | free drainage | unit-gradient/free-drainage lower boundary |

A previous version of the coupling-semantics audit incorrectly labelled SWBOTB=6 as prescribed groundwater level. That statement is superseded by this note.

## 2. SWBOTB=5 is not prescribed groundwater level

SWBOTB=5 prescribes `hbot`, the pressure head at the lower boundary.

For a lower-boundary elevation `z_bottom`, the corresponding hydraulic head is

`H_bottom = z_bottom + psi_bottom`

after unit conversion.

This is exactly why the existing SWAP5 datum conversion from public hydraulic head to mode-5 pressure head is useful as a numerical adapter.

It does not turn mode 5 into a prescribed-groundwater-level application. The manual separately identifies SWBOTB=1 for that purpose.

The manual notes that a user may approximate a desired groundwater level by prescribing pressure heads at the bottom that are in hydrostatic equilibrium. That is an application construction, not semantic identity between modes 1 and 5.

## 3. The lower face is not the diagnostic phreatic surface

The SWAP lower boundary is a fixed spatial face. The diagnostic groundwater level is the location inside the soil profile where pressure head is zero.

These may coincide only in a special configuration. In general they are distinct quantities.

The 2024 SWAP-MODFLOW design makes this distinction explicit: the groundwater level diagnosed by SWAP need not be exactly equal to the MODFLOW head because resistance inside the phreatic layer can create a head difference.

Therefore:

- `H_MODFLOW` must not be relabelled as the SWAP diagnostic groundwater level;
- imposing `H_MODFLOW` at the SWAP lower face is a numerical/coupling boundary operation;
- a coupled application is not thereby a standalone prescribed-groundwater-level SWAP application.

## 4. Drainage is not prohibited by SWBOTB=5

The public SWAP manual states that lateral drainage can additionally occur with lower-boundary options 1, 2, 3, 5 and 6.

Therefore the current production rejection of

`bottom_mode=5 + drainage_response_active`

is not a legacy physical restriction of SWBOTB=5.

It is an SWAP5 production/admission restriction introduced by the present FMR participant/bootstrap composition.

This changes the interpretation of PUB-GC E6/E7: their stop is evidence about the current component envelope, not evidence that prescribed lower-face head and drainage are physically incompatible in SWAP.

## 5. Drainage ownership is nevertheless not automatic

The fact that SWBOTB=5 permits drainage does not prove that every standalone drainage configuration can be copied unchanged into a SWAP-MODFLOW application.

The public SWAP drainage chapter explicitly notes that coupling to regional groundwater can require alternative drainage formulations.

The 2024 SWAP-MODFLOW concept also treats the MODFLOW-to-SWAP predictor flux as the net result of regional groundwater flow and local drainage.

Consequently a corrected coupling contract must declare the owner of each physical drainage path. It must prohibit representing the same discharge both as a SWAP drainage sink and as a MODFLOW/surface-water sink.

## 6. Historical two-way coupling semantics

The 2024 design authority is materially different from “MODFLOW head continuously drives SWBOTB=5”.

Its two-way sequence is:

1. predictor: determine a SWAP bottom flux from the previous regional groundwater balance and current forcing;
2. run SWAP with the flux-controlled lower boundary;
3. derive an exchange/recharge quantity `q_u` and response/storage coefficient `u`;
4. solve MODFLOW with that response;
5. after groundwater convergence, impose the MODFLOW head at the SWAP bottom;
6. rerun/finalize SWAP and determine the lower-boundary flux for the next predictor.

The SWAP5 F-GC30/F-GC33 chain is recognizably derived from this formulation.

Mode 5 can therefore be a valid implementation route for step 5 without being the scientific identity of the coupled application.

## 7. Correct authority statement

For coupled operation, the scientifically relevant statement is:

> A MODFLOW groundwater iterate may be translated through an explicit datum/transfer contract into a temporary SWAP lower-face hydraulic condition for a corrector/finalization trial.

The following stronger statement is not supported:

> The SWAP-MODFLOW application is a SWBOTB=5 groundwater application.

## 8. Consequence for repair

The repair should introduce a coupled-groundwater application authority that is independent of the legacy SWBOTB selector.

The existing mode-5 materializer may remain behind that authority if it is qualified as one internal realization of the corrector/finalization boundary.

No new legacy SWBOTB value is required merely to make this semantic distinction.
