# PUB-GC E7 realistic-case selection note

## Status

**CANDIDATE SELECTION — NOT YET PREREGISTERED FOR EXECUTION**

Date: 2026-09-18.

Canonical basis at note creation:

`73bd6571de1c7f17a34417d407b14075d58b8798`

## Purpose

E7 must demonstrate the central coupling contract outside the deliberately controlled F-GC44/E3/E6 qualification fixtures.

The realistic case must not be manufactured to make strong coupling look important. It should originate from an already authoritative SWAP application with independent forcing and process provenance.

## Preferred case: Hupselbrook

Hupselbrook is the preferred PUB-GC E7 demonstrator because the repository already contains unusually strong scientific authority around the case:

- exact SWAP 4.3.1 distribution identity has been recovered and verified;
- the official Hupsel case path and fixture-member hashes are recorded;
- a three-year legacy run has been independently rebuilt;
- normalized BAL/BLC outputs match the qualified historical oracle;
- daily and timestep application traces exist;
- SWETR=0 PMdirect has been rederived and independently qualified;
- Rutter interception / SWCF=2 observations are qualified;
- SWINTER=0 interval identity is qualified over 3505 exact B1.11 records;
- scheduled/fixed irrigation composition is qualified over 110 active intervals;
- output composition bindings have been independently qualified.

This makes Hupsel scientifically preferable to inventing a new "realistic" synthetic forcing series for the paper.

## Why E7 is not yet executable as whole-Hupsel coupling

The historical application workunits explicitly distinguish their process/binding admission from **whole-Hupsel closure**.

The current evidence therefore does not yet justify the statement:

> the complete historical Hupsel application is available as one production SWAP5 participant that can simply replace its lower boundary by the PUB-GC MODFLOW coupling.

Before E7 execution, the following must be demonstrated on current canonical:

1. the selected Hupsel forcing/application route is fully materialized through admitted typed production composition;
2. no hidden legacy monolithic execution path supplies process state that the SWAP5 participant cannot reproduce;
3. the lower coupling plane, head datum and q_bot/q_u accounting are defined for the Hupsel profile;
4. a standalone SWAP5 run over the selected period reproduces the controlling Hupsel reference evidence at the agreed precision;
5. replacing only the lower-boundary representation by the coupling contract leaves atmospheric, crop, irrigation, drainage and other selected process semantics unchanged.

Until those gates pass, Hupsel is an **E7 candidate**, not a completed realistic validation.

## Period selection rule

When the full typed Hupsel participant is available, the publication period should be selected from **standalone SWAP hydrological dynamics**, before MODFLOW coupling results are inspected.

Recommended prospective rule:

1. exclude any documented spin-up interval;
2. partition the authoritative Hupsel trace into fixed-duration candidate windows;
3. characterize each window using standalone quantities only, such as:
   - absolute storage change;
   - cumulative lower-boundary exchange;
   - rainfall/irrigation pulse magnitude;
   - groundwater/pressure-head excursion;
4. select:
   - one median-dynamics control window;
   - one high-dynamics window using a frozen scalar selection metric;
5. only then construct the coupled MODFLOW case.

The selection metric and window duration must be frozen in a separate E7 preregistration before any coupled result is calculated.

This avoids choosing a period because it happens to maximize the loose-versus-strong coupling difference.

## Groundwater model requirements

The E7 groundwater model must be interpretable rather than merely convenient.

At minimum document:

- cell geometry and area represented by the SWAP column;
- storage coefficients and hydraulic properties;
- external/fixed-head boundaries;
- initial groundwater head relative to the SWAP datum;
- mapping of SWAP whole-window exchange to MODFLOW;
- whether the model represents a local conceptual aquifer or is extracted from a larger regional model.

If a simplified local MODFLOW cell/strip is used, the paper must call it a **real-forcing hydrological demonstration**, not a full regional validation.

## Required E7 comparisons

At least:

- loose/sequential exchange;
- strongly converged PUB-GC coupling;
- same accepted initial SWAP and groundwater state;
- same coupling window(s);
- component work and wall-clock time;
- head, storage and exchange differences;
- whole-system mass closure.

The paper should also compare the observed correction against the E3 weak-feedback control and the E6 process-stress case.

## Relation to E6

E6 and E7 have different roles.

```text
E6
    controlled hydrological stress experiment;
    asks whether non-trivial coupling feedback can be produced
    inside an already admitted process state.

E7
    realistic application demonstration;
    asks whether the coupling contract remains usable and
    scientifically interpretable under authentic application forcing.
```

An E6 active-drainage success does not replace E7.

A Hupsel E7 case does not need to maximize coupling strength to be useful.

## Fallback

If whole-Hupsel typed composition cannot be closed without substantial new application-development work, E7 should not silently substitute a synthetic case and call it realistic.

The manuscript may instead:

- retain E6 as the strongest process-level hydrological demonstration;
- explicitly report that a full realistic application remains future work; or
- choose another existing, independently authoritative application only after the same provenance and selection criteria are met.

## Current decision

**Hupselbrook is the preferred E7 case, conditional on whole-application typed-participant closure.**

No E7 coupling execution is authorized by this note.
