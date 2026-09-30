# PPA-WU05-A6 R1a source map — SWABS=1 sorptivity, SwDarcy=0

Date: 2026-09-30

Status: EXACT_SOURCE_MAP / TYPED_IMPLEMENTATION_IN_PROGRESS

## Exact B1.11 source

Authority: ABSORPTION in exact B1.11 macrorate.f90.

Bounded route:

- SWABS = 1;
- SwDarcy = 0;
- no diffusion route;
- no Darcy/sorptivity competition yet.

## Active vertical range

For each domain:

- bottom node = min(ICpBtDm(id), ICpTpSatZon-1);
- main kinematic domain under swmbf=2 starts at IcTopMp;
- otherwise the domain starts at ICpTpWaSrDm(id);
- compartments inside the perched partly saturated matrix interval are excluded.

## Fresh event

If TimAbsCumDmCp < 1e-8 and the matrix saturation deficit is significant:

- ThtSrpRefDmCp seed = ThetaS;
- SorpDmCp seed = SorpMax * ((ThetaS-Theta)/(ThetaS-ThetaR))^SorpAlfa;
- active sorptivity equals that seed.

## Continuing event

If ThtSrpRefDmCp-Theta > 1e-8:

- active sorptivity = SorpMax * ((ThtSrpRefDmCp-Theta)/(ThetaS-ThetaR))^SorpAlfa.

Otherwise active sorptivity is zero and the event remains eligible to end in MACROSTATE.

## Amount

AbsSorp = SorpAct * PpDmCp * (4*AwlCorFac*Dz/DiPoCp) * (sqrt(Time+dt)-sqrt(Time)).

For swmbf=1 or id>1, the top water-storage compartment is weighted by FrMpWalWet.

The source then caps the amount at:

QSorpMax * dt * Dz, with QSorpMax = 1e3.

Finally FrReduQ scales the potential outflow amount.

## Event-end flag

FlEndSrpEvt defaults true and is set false when the pre-reduction sorptivity amount rate exceeds 1e-7.

## Transactional interpretation

Rate evaluation must not mutate accepted history.

The typed evaluator therefore returns:

- potential sorptivity amount/rate;
- event seed sorptivity;
- event seed reference theta;
- event-end flag.

Candidate history is updated only by the later accepted-state builder.

## Local oracle

Representative results:

- fresh event: 0.2557953283 cm;
- aged event: 0.0564433997 cm;
- nearly saturated matrix: 0;
- extreme sorptivity: capped at 1000 cm for dt=0.1 d and Dz=10 cm.

## Next

Implement the typed distributed evaluator and qualify it before adding Darcy competition.