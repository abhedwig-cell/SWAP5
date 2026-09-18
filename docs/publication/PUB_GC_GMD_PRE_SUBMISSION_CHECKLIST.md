# PUB-GC GMD pre-submission checklist

## Status

**PRE-SUBMISSION PACKAGE READY EXCEPT GOVERNANCE / ARCHIVE METADATA**

Policy checked: 2026-09-18 against the current GMD author, manuscript-type, code/data and submission pages.

## Scientific and manuscript state

- manuscript type: **Development and technical paper**;
- E1–E7 scientific core: closed/bounded;
- E7: `CLOSED_REALISTIC_COMPONENT_DOMAIN_LIMIT`;
- no further primary hydrological experiment required for the current claim set;
- journal-facing manuscript contains no claim of realistic Hupsel loose/strong correction or regional validation.

## GMD-required items

| Requirement | Current state | Action |
| --- | --- | --- |
| model name + exact version/unique identifier in title | BLOCKED_A1 | insert governed SWAP5 publication identifier |
| title page with full author names/affiliations/corresponding email | BLOCKED_AUTHOR_METADATA | supply governed author metadata |
| abstract | READY | use manuscript abstract |
| short summary <=500 characters | READY | current candidate = 432 characters |
| Code and data availability section | STRUCTURE_READY | final archive/licence/PID fields blocked by A1–A3 |
| exact code version in persistent public archive | BLOCKED_A3 | archive governed release after A1/A2 |
| software licence stated | BLOCKED_A2 | controlled legal/governance decision |
| preprocessing/run-control/postprocessing material for reported results | READY_AT_REPOSITORY_LEVEL | include in exact archive and cite |
| figure files in accepted final-production format | EXPORT_PLAN_READY | export F1–F7 to numbered PDF files |
| individual figure size <=5 MB | TO_VERIFY_AFTER_EXPORT | validation gate |
| total submitted files excluding supplements <=30 MB | TO_VERIFY_AFTER_EXPORT | validation gate |
| supplement package | READY_THROUGH_E7 | convert journal-neutral supplement to submission artifact |
| funding / competing interests / acknowledgements | BLOCKED_AUTHOR_METADATA | supply statements |
| AI-tool-use disclosure if applicable | BLOCKED_AUTHOR_METADATA | supply final disclosure consistent with journal policy |

## Final figure upload convention

Prepare one flat zip with no subfolders:

```text
f01.pdf
f02.pdf
f03.pdf
f04.pdf
f05.pdf
f06.pdf
f07.pdf
```

The repository SVG files remain the governed source figures. PDF export is a presentation transformation only.

## Claims guard

The final submission must not state or imply:

- successful Hupsel loose/strong coupled windows;
- a realistic E7 coupling correction magnitude;
- regional Hupsel groundwater validation;
- physical validity of heterogeneous N:1 aggregation;
- novelty for generic partitioned coupling, rollback, Aitken/IQN, Jacobians or MODFLOW API control;
- a software licence, version, DOI or redistribution permission that has not been formally governed.

## Submission closure

The package is submission-compliant only when:

1. A1 publication identifier is governed;
2. A2 software licence/redistribution authority is explicit;
3. A3 exact release + publication evidence are persistently archived with a unique identifier;
4. title and Code/data availability text point to the same exact version/archive;
5. author metadata and declarations are complete;
6. final PDFs satisfy GMD file limits.
