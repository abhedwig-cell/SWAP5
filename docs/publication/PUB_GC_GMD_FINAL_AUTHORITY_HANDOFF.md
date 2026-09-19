# PUB-GC GMD final authority handoff

## Status

**TECHNICAL CANDIDATE FROZEN — R1/L1 INPUT ONLY**

The publication candidate is no longer a moving branch target.

Scientific/source authority:

```text
commit 781c829943c9e5880e5ab83281112e66f439ecf2
tree   9ca065553765e38eec4d4ceb611ec80d866dbae3
src    573df94cbb1c3f1cb38498e0003f11b8f7e3bcf1
ref    684f1e2889b6992e5aedc88f52bb45f4558bb3e4
```

The complete RB1-to-candidate source/reference delta and inherited qualification are already governed.

## Authority input

The only release-governance file that needs controlled values is:

`release/pub-gc-gmd/PUB_GC_GMD_FINAL_AUTHORITY_INPUT.json`

### R1

Provide:

- final publication release identifier;
- authority name/role;
- governing record;
- effective date.

The identifier must name this exact candidate or explicitly require creation of a different candidate. It may not reuse or move `SWAP5-RB1-v1`.

### L1

Provide:

- exact software licence expression/wording for the SWAP5 publication archive;
- exact redistribution statement;
- confirmation whether public archive redistribution is authorized;
- authority name/role;
- governing record;
- effective date;
- authorized reviewer-access wording for the separately governed SWAP 4.3.1 reference asset.

Official upstream evidence already establishes SWAP 4 GNU GPL version 2 provenance. It does not substitute for this SWAP5 release decision.

## Automated gate

`release/pub-gc-gmd/validate_final_authority_input.py`

The gate has two valid states.

### AWAITING_R1_L1_AUTHORITY

All decision fields remain null and the validator confirms that the record fails closed.

### AUTHORIZED_FOR_PUBLIC_ARCHIVE

R1/L1 and external-reference access wording must be explicit. Public archive redistribution must be authorized. A3 must still be empty because a DOI/PID may only be recorded after the external archive actually exists.

## Mechanical sequence after authorization

1. Set the authority record to `AUTHORIZED_FOR_PUBLIC_ARCHIVE` with R1/L1 values.
2. Pass the final-authority gate.
3. Create the immutable named successor release bound to the frozen candidate.
4. Deposit that exact release and publication package in the approved persistent archive.
5. Obtain the real DOI/PID.
6. Populate A3 with the archive identity.
7. Bind the version/DOI/licence into the GMD title, Code and data availability, cover letter and reproducibility manifest.
8. Regenerate F1–F7 PDFs once from the immutable release and perform the final visual/upload check.
9. Run the final GMD submission gate.

No new hydrological experiment is part of this sequence.
