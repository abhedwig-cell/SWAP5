# PPA-WU05-A27-ABC01-TR01 result — post-DEP03 first-dry sanity check

Date: 2026-10-02  
Status: COMPLETED_NEGATIVE_CAUSAL_TEST; SUPERSEDED_BY_QUALIFIED_ABC01

Run: `36993999823` — SUCCESS  
Postimage: `d8c2b96daed5f4732d7b65354b5e1e588c7267f7`  
Artifact: `11220838222`  
Artifact digest: `sha256:27b76cb10fe26f07a21c4fbc5c57edf4f90c6da635c9aaca70ab7ec40a8f1635`

TR01 was preregistered while interpreting the pre-DEP03 ABC01 failures as a possible first-dry endpoint-release instability.

On the current post-DEP03 route, the exact B01/G1/R2 accepted state after four wet production-C intervals contains zero terminating-endpoint storage. The reconstructed first dry interval therefore has zero endpoint release and zero RFM matrix-source rate.

The actual production-C dry interval completes successfully:
- canonical status 0;
- completed = true;
- one transaction attempt;
- zero retries;
- zero solver, temporal and mass rejections.

Direct Reference solves from the same matrix state with zero RFM source converge at every preregistered dt from 0.01 to 0.000625 day.

Therefore the old first-dry endpoint-source causal hypothesis is rejected for the current route. Source inspection and repository history identify the earlier failure correctly as DEP03: zero surface supply was incorrectly converted to REFERENCE_REQUIRED before the dry candidate could be built.

TR01 authorizes no additional physical repair and is closed. The qualified ABC01 result at run 36991992438 supersedes the earlier pre-DEP03 stability interpretation.
