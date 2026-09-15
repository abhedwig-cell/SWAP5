# SWAP 4.3.1 + WOFOST 8.1 historical reference archive

Status: PROVENANCE_PLACEHOLDER_PENDING_EXACT_DONOR_SOURCE_ARCHIVE

This record pins the historical SWAP 4.3.1 + WOFOST 8.1 donor that was independently qualified against the Allard de Wit / PCSE 6.0.13 WOFOST 8.1 potential-production oracle in F-WOF-PP01.

## Qualified donor identity

- donor artifact: `SWAP_4.3.1_WOFOST81_WORKING_FINAL_13B.zip`
- donor artifact SHA-256: `4e0bf97bca7f3f8716e5bcf46a5dc9bb6b08436304b032d60adc3757491d94dc`
- historical donor source closeout: `839c34a657c2cee202b55d9ee85253d867a3d47a`
- original `wofost.f90` SHA-256: `84f0033b958132c44d650357e254cf97bc48f455ed9971c449e5582ca3258441`
- rebuilt unmodified donor executable SHA-256: `eefde8e7de08a5dea7fa4e2d53117ecb0e9cccf5a15df97eec27736f15f29042`
- qualification adapter executable SHA-256: `0a62652839db367ea7011acc8cfcfdb34458504f502cbbde5c9cf741e332d23b`

## Oracle identity

- oracle artifact: `tests_Wofost81_PP.zip`
- oracle SHA-256: `99a67a0e5f6bd0881b97950a2ff3fe0f387c0a9e0553f2e36197077fbc15d145`
- generator: PCSE 6.0.13
- model: WOFOST 8.1
- crop: Spring Barley 2023
- case count: 10

## Qualification result

The verified donor reproduced all 12 WOFOST-owned production, phenology and crop-N trajectories in all 10 potential-production cases within the unchanged oracle precision. Residual differences were floating-point roundoff only. `RD` and `TRA` were explicitly outside this equivalence surface because SWAP retains ownership of rooting and hydrology for those interfaces.

Authoritative evidence is retained under `tests/fwof/pp01/`, including `F-WOF-PP01_DONOR_QUALIFICATION.md`, `F-WOF-PP01_DONOR_QUALIFICATION.json`, `REFERENCE_MANIFEST.json`, `MAPPING_CONTRACT.md` and `F-WOF-PP01_QUALIFICATION_ADAPTER.patch`.

## Archive gap

The exact donor ZIP/source tree is not currently available through the connected GitHub repository or File Library. Therefore no substitute source tree has been reconstructed or committed. Reconstructing from SWAP5 or from a nearby SWAP 4.3.1 baseline would destroy provenance.

The archive is complete only when the exact byte-identical donor artifact, or an extracted tree verified to hash back to the pinned donor identity, is available and can be placed under durable version control without modification.

## Admission rule

Do not relabel any reconstructed or later SWAP 4.3.1 tree as this qualified donor unless the donor artifact SHA-256 and relevant source hashes match the values above.
