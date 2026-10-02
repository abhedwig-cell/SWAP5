# TOP03 surface-contact resistance physical review

Date: 2026-10-02
Status: BOUNDED_PHYSICAL_REVIEW__PARAMETERIZATION_NOT_YET_QUALIFIED

## Purpose

The TOP03 contact-resistance probe showed that a finite series resistance between open surface water and the matrix can regularize the previously non-contracting inundation trajectory. This review asks whether that formulation has a defensible physical interpretation and whether the successful numerical resistance values can already be treated as field-scale parameters.

They cannot yet be treated as calibrated production parameters.

## Physical precedent

Hydraulic resistance of a soil surface crust is an established infiltration representation.

The 1991 Soil Technology paper **“A numerical study of infiltration through crusted soils: Flat and other surface configurations”**, DOI `10.1016/0933-3630(91)90036-M`, compares:

1. a crust represented as an instantaneously saturated impedance characterized by hydraulic resistance; and
2. an explicit crust/underlying-soil two-layer system.

Its abstract reports nearly the same infiltration flux for the two representations, with a difference in ponding time because the impedance formulation does not need to fill the crust storage first. This supports a series-resistance boundary as a reduced representation of a thin restrictive surface layer rather than as a numerical conductivity cap.

Touma et al. (2011), **“In situ determination of the soil surface crust hydraulic resistance”**, Journal of Hydrology 403, 253-260, DOI `10.1016/j.jhydrol.2011.04.004`, explicitly estimates surface-crust hydraulic resistance from infiltration measurements and underlying-soil hydraulic properties. The paper notes that resistance-based and explicit-layer approaches are established ways to represent surface sealing/crusting.

Alagna et al. (2013), **“A simple field method to measure the hydrodynamic properties of soil surface crust”**, Journal of Agricultural Engineering 44(s2), reports a measured mean crust hydraulic resistance of approximately 78-81 minutes for one clay-soil case, with crust thickness about 5-7 mm. That corresponds to roughly 0.054-0.056 day.

HYDRUS documentation separately supports the architectural separation used here: surface atmospheric/head switching is system-dependent, and surface ponding may be represented by a surface-reservoir balance. This is consistent with keeping local surface storage distinct from the soil state and from the external surface-water body.

## Comparison with the TOP03 mechanism sweep

The current synthetic TOP03 fixture uses a top-node surface distance of 1 cm.

The resistance sweep tested `R_s = 0, 0.05, 0.10, 0.25, 0.50, 1.00 day`.

The full event-aligned trajectory remains incomplete at all tested `R_s <= 0.25 day`, while both `0.50` and `1.00 day` robustly complete and contract for every tested microrelief amplitude, including the flat `D=0` control.

The lower successful value, `0.50 day`, is about nine times the 78-81 minute resistance reported in the cited Alagna et al. clay-soil example. This comparison is informative but **not** a contradiction or a calibration result: published crust resistance varies strongly with crust type, thickness and conductivity, and the TOP03 fixture is a four-node synthetic column rather than that measured soil.

More importantly, the numerical threshold may be compensating for more than a real crust. Possible contributors include:

- unresolved near-surface layering;
- the coarse first-node geometry;
- areal contact heterogeneity;
- the inherited near-saturation constitutive behavior;
- the distinction between local micro-storage and external surface-water stage.

Therefore the successful resistance must not be interpreted directly as a measured crust parameter.

## Equivalent transition-layer interpretation

The series resistance has the standard layer interpretation

```
R_s = L_s / K_s
```

for an idealized saturated transition layer of thickness `L_s` and conductivity `K_s`.

This gives a concrete route for physical qualification: instead of calibrating a free numerical resistance, compare the reduced resistance boundary against explicit thin-layer columns with independently specified `L_s` and `K_s`.

The reduced law should reproduce the explicit-layer integrated exchange and accepted-state behavior over a declared envelope before production use.

## Decision

The contact-resistance **formulation** is physically defensible.

The contact-resistance **value** required by the present TOP03 synthetic fixture is not yet physically qualified.

Do not productionize `R_s=0.50 day` or any other value from this sweep.

The next useful falsification is an explicit transition-layer equivalence experiment:

1. retain the same deeper soil and lower boundary;
2. add a thin upper layer with specified thickness and hydraulic conductivity;
3. compare its ponded/inundated response against `R_s=L_s/K_s`;
4. test several plausible layer combinations and at least one no-layer control;
5. require mass closure and temporal state/top/bottom refinement agreement.

If the reduced boundary reproduces an explicit-layer reference across that envelope, the resistance parameter gains a physical parameterization path. If not, the current resistance is acting mainly as numerical regularization and must not be admitted as surface physics.
