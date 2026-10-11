# PUB-GC external reference audit

## Status

**VERIFIED AGAINST PUBLISHER / STANDARD SOURCES — 2026-09-18**

This audit checks the manuscript's working bibliography against current publisher metadata. It is a bibliographic control, not a novelty ranking.

## Verified records and manuscript use

| Reference | Verified metadata | Manuscript role | Audit disposition |
| --- | --- | --- | --- |
| Abbaszadeh et al. 2025 | HESS 29, 5429–5452; DOI 10.5194/hess-29-5429-2025 | recent ParFlow–LIS integrated hydrology precedent | VERIFIED |
| Bailey et al. 2025 | GMD 18, 5681–5697; DOI 10.5194/gmd-18-5681-2025 | recent SWAT+–MODFLOW integration precedent | VERIFIED |
| Buahin & Horsburgh 2018 | EMS 108, 133–153; DOI 10.1016/j.envsoft.2018.07.015 | OpenMI/HydroCouple interoperability precedent | VERIFIED |
| Degroote et al. 2010 | Computers & Structures 88, 446–457; DOI 10.1016/j.compstruc.2009.12.006 | partitioned quasi-Newton prior art | VERIFIED |
| Delaissé et al. 2022 | Computers & Structures 260, 106720; DOI 10.1016/j.compstruc.2021.106720 | supplementary/surrogate response information in quasi-Newton coupling | VERIFIED |
| Hughes et al. 2022 | EMS 148, 105257; DOI 10.1016/j.envsoft.2021.105257 | MODFLOW6 external API/XMI control | VERIFIED; full author list restored |
| FMI 3.0.2 | specification dated 2024-11-27 | generic component/co-simulation state interface | VERIFIED; year pinned to specification release |
| Nachabe 2002 | WRR 38(10), 1193; DOI 10.1029/2001WR001071 | transient shallow-water-table storage response prior art | VERIFIED |
| Rüth et al. 2021 | IJNME 122, 5236–5257; DOI 10.1002/nme.6443 | multirate finite-window / waveform quasi-Newton prior art | VERIFIED |
| Schüller et al. 2025 | GEM 16, article 9; DOI 10.1007/s13137-025-00265-4 | convergence analysis for iteratively coupled surface–subsurface systems | VERIFIED |
| Sicklinger et al. 2014 | IJNME 98, 418–444; DOI 10.1002/nme.4637 | interface-Jacobian co-simulation prior art | VERIFIED; full author list restored |
| Trim et al. 2025 | EMS 194, 106668; DOI 10.1016/j.envsoft.2025.106668 | current hydrologic modularity/interoperability precedent | ADDED_AND_VERIFIED |
| Twarakavi et al. 2008 | Vadose Zone Journal 7, 757–768; DOI 10.2136/vzj2007.0082 | HYDRUS–MODFLOW vadose/groundwater coupling precedent | VERIFIED; volume/pages restored |
| van Walsum & Veldhuizen 2011 | Journal of Hydrology 409, 363–370; DOI 10.1016/j.jhydrol.2011.08.036 | shared-state SIMGRO coupling precedent | VERIFIED |
| Yang et al. 2026 | GMD 19, 1849–1866; DOI 10.5194/gmd-19-1849-2026 | current modular/maintainable ParFlow coupling context | VERIFIED |
| Zeng et al. 2019 | HESS 23, 637–655; DOI 10.5194/hess-23-637-2019 | iterative HYDRUS–MODFLOW feedback precedent | VERIFIED |

## Material literature conclusion

The checked literature reinforces, rather than weakens, the current manuscript boundary:

- bidirectional vadose-zone/groundwater feedback is prior art;
- shared hydrological state/storage response is prior art;
- MODFLOW external programmatic control is prior art;
- solver-autonomous partitioned coupling and rollback/checkpoint concepts are prior art;
- interface Jacobians, quasi-Newton acceleration, waveform/multirate coupling and surrogate response reuse are prior art;
- modular hydrologic model design and interoperability are an active current research direction.

Accordingly, the manuscript must continue to locate its contribution in the **integrated hydrological contract**: typed finite-window exchange semantics, explicit trial/accepted authority, exactly-once mass publication, response-map identity, and evidence-based component-admission boundaries while component solvers retain ownership.

## Bibliographic corrections made

1. Expanded the Hughes et al. author list.
2. Expanded the Sicklinger et al. author list.
3. Added Twarakavi volume and page range and restored Šimůnek spelling.
4. Pinned FMI 3.0.2 to the 2024 specification date.
5. Expanded recent Abbaszadeh and Yang author lists.
6. Added Trim et al. 2025 because it is directly relevant current hydrologic modularity/interoperability prior art.
7. Added explicit in-text use for Delaissé, FMI and Nachabe so the bibliography contains no intentionally uncited background references.

## Submission rule

Re-run this audit against the final target-journal bibliography immediately before submission. New references may be added for journal fit, but no literature addition may be used to convert an already excluded novelty claim back into a manuscript contribution without a separate novelty review.
