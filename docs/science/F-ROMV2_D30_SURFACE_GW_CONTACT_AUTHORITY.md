# F-ROMV2 D30 — natural surface/groundwater contact authority

**Decision:** `NATURAL_SURFACE_GW_CONTACT_EVENT_UPDATE_UNDERSPECIFIED_WITHOUT_IMPLEMENTATION_ORACLE`

## Why D30 exists

D29 did not fail because FMC lost mass conservation or because its one-hour
hydraulic fidelity suddenly deteriorated.

Instead, all four frozen long-window histories reached the same physical
transition at 2.575 hours: a surface-connected infiltration front met its
same-bin groundwater front.

That transition was deliberately outside the D29 separated state envelope.

The next question is therefore an authority question before it is a numerical
or hydrological comparison:

> Is the natural, within-step transition from an active surface infiltration
> front plus groundwater front into the FMC surface-to-groundwater connected
> state specified tightly enough to implement without invention?

## What the primary paper does specify

Ogden et al. (2015), doi:10.1002/2015WR017126, defines four water-state classes
in the finite-water-content domain:

1. infiltration fronts connected to the land surface;
2. falling slugs;
3. groundwater-connected capillary fronts;
4. gray bins connected simultaneously to the land surface and groundwater.

The paper also defines the right-most gray bin as (	heta_i). Surface water
first satisfies the demand associated with those groundwater-connected bins
before the remaining water advances infiltration fronts.

Thus the physical **post-contact state class** is clear.

The same paper also gives an explicit rule for a different contact event:
falling slugs that meet groundwater fronts are merged into those groundwater
fronts, increasing groundwater-front height by the slug length.

## What D19 actually qualified

D19 starts from a deliberately constructed exact-contact state.

Its contact object is a **falling slug**, not a surface-connected infiltration
front.

At (t=0):

- each 5 cm falling slug touches a same-bin groundwater front exactly;
- the slug representation is removed;
- the groundwater front is raised by 5 cm;
- finite-volume storage is unchanged.

After that transition, D19 applies **zero top flux** for 64 steps and evaluates
groundwater-front relaxation.

D19 therefore gives strong authority for:

- exact-contact falling-slug merge;
- finite-volume state identity at that merge;
- post-merge groundwater-front dynamics.

It does not exercise continued surface infiltration during the contact event.

## What D29 requires

D29 is structurally different.

At step 927:

- a surface-connected infiltration front is still being supplied from above;
- the same-bin groundwater front is also active;
- the frozen 10 s forward step produces an overlap of about 0.00918 cm in bin
  101;
- the contact occurs **inside** the process interval, not exactly at its start.

A faithful continuation therefore needs more than the statement that gray bins
exist.

It must determine, at minimum:

1. how the contact time inside the 10 s step is located;
2. how both fronts are brought to exact contact without creating or deleting
   water;
3. when the bin becomes part of the gray, surface-to-groundwater connected
   state;
4. how the right-most gray index (	heta_i) is updated;
5. how surface-water demand and infiltration-front advance are recomputed for
   the unused fraction of the step;
6. how groundwater advance and capillary relaxation are ordered relative to
   that conversion;
7. how multiple same-step contacts are ordered if more than one bin crosses.

The primary paper identifies the ingredients and intended continuous behavior,
but its prose does not uniquely specify this event algorithm.

## Why D19 is not silently reused

The natural temptation would be to clamp the D29 overlap to zero, declare the
newly touching bin gray, increment (	heta_i), and continue.

That may be a reasonable algorithm.

It is not yet an **authoritative reproduction** of the published FMC method.

Likewise, splitting the 10 s step at an analytically or numerically estimated
contact time would introduce a new event-localization rule that has not been
qualified in the current repository.

D30 therefore refuses to convert physical plausibility into implementation
authority.

## Preferred implementation oracle

The same University of Wyoming M2WC70 archive identified in D28 contains the
authors' C implementation associated with Ogden et al. (2015).

Its role for D30 is narrower than its ET role:

- inspect how the authors detect an infiltration-front/groundwater contact;
- inspect the exact state conversion to the gray connected domain;
- inspect within-step ordering and any remainder-of-step processing;
- write a clean-room state-transition specification.

External source code is not to be copied into SWAP5.

D28 already established that the archive is identified but is not currently
materializable through the available execution routes.

## Scientific boundary

D30 therefore closes as an **external implementation-authority blocker**.

It does not reclassify:

- D19 exact falling-slug merge;
- D20 one-hour persistence;
- D24 rainfall + groundwater candidacy;
- D25 compiled shared-host cost screening;
- D29's 2.575 h separated-branch domain boundary.

It also does not reopen D29 Stage 2.

A later contact-capable long-window experiment requires a new preregistration
after the natural event update has been reconciled clean-room from M2WC70 or an
equally authoritative source.

Native ET remains separately blocked by D28, and formal portable performance
remains blocked by MP-8 infrastructure.

No application acceptance follows.

Production ROM remains unauthorized.
