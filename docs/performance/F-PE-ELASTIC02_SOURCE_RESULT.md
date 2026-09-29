# F-PE-ELASTIC02 official Staringreeks 2018 source record

Date: 2026-09-29

Status: SOURCE_ACQUIRED_AND_VALIDATED

Workflow: `36519109887`
Job: `109247879178`

Official source URL:
`https://nhi.nu/documents/224/staringreeks_1.0.0.zip`

Official zip:
- SHA-256: `9d06dff19392111dad110802058e3894c30355f553842ce32d89eed005071cd5`
- bytes: `784565`

Selected archive member:
`staringreeks/Data/staringreeks_2018.csv`

Original member:
- SHA-256: `ed2e47bcacdbb6e5fe18eb4f712c3ead996f26f97d647fa550dafd8683d64494`
- bytes: `2922`
- header: `year,unit,name,wcr,wcs,alpha,npar,lambda,ksfit`
- data rows: 36
- exact material set: B01..B18 and O01..O18

The repository CSV mirror is a newline-normalized text mirror reconstructed from the validated CI evidence. The original-member SHA above remains the byte-level external source authority.

The first acquisition attempt selected `staringreeks_1987.csv` because the source package contains several historical 36-row series. That result was rejected before any full-population numerical experiment. The corrected acquisition requires the exact basename `staringreeks_2018.csv` and year 2018.
