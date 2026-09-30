# PPA-WU05-A6 R1b source map — Darcy versus sorptivity competition

Date: 2026-09-30

Status: EXACT_SOURCE_MAP / TYPED_IMPLEMENTATION_IN_PROGRESS

## Exact source

Authority: B1.11 ABSORPTION, SwDarcy > 0, SWABS=1.

## Darcy candidate

Darcy absorption is only evaluated below the top water-storage compartment of the macropore domain.

Macropore head is HMp = max(0, ZWaLevDm-Z).

A positive head difference is allowed only when matrix head is below the entry-head threshold and HMp is positive.

Reciprocal resistance:

RecRes = ShapeFacMp * 8 * PpDmCp * Dz * K / DiPo^2.

Raw Darcy amount:

AbsDarc = RecRes * DelH * dt.

## Sorptivity scaling of Darcy

The Darcy candidate is multiplied by:

SorpFac = SorpFacParl + (1-SorpFacParl) * (1 - ((ThetaS-Theta)/(ThetaS-ThetaR))^SorpAlfa).

## Winner selection

B1.11 does not add sorptivity and Darcy.

If AbsSorp > SorpFac*AbsDarc, sorptivity wins.

Otherwise Darcy wins.

The winning amount is then multiplied by FrReduQ.

When Darcy wins, AbsSorp is set to zero before the event-end flag is evaluated; the sorptivity event is therefore eligible to end.

## Local oracle

For theta=0.16, ThetaS=0.45, ThetaR=0.05, Pp=0.2, Dz=10, DiPo=4, K=0.01, H=-100, Z=-50, ZWaLev=-20, dt=0.1:

- with SorpMax=0.5: sorptivity wins, 0.2557953283 cm versus scaled Darcy 0.0746544943 cm;
- with SorpMax=0.05: Darcy wins, 0.0746544943 cm versus sorptivity 0.0255795328 cm.

## Transactional implication

The rate evaluator returns winner identity and event-end semantics without mutating accepted history.