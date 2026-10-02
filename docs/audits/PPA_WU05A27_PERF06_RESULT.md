# PPA-WU05-A27-PERF06 result — global sorptivity panel frontier

Date: 2026-10-02
Status: FALSIFIED_NO_GLOBAL_REDUCTION

Run: 37003579753
Artifact: 11224671229
Digest: sha256:ea21da9066875762d2c45573e6d6d66c6b10d4e8a2df70cf58e4df3802b23be8

Relative to 64 panels, maximum sampled sorptivity relative error is:
- 32 panels: 0.8181;
- 16 panels: 0.9672;
- 8 panels: 0.9941.

Therefore none passes the preregistered global 2% gate and none proceeds to PERF06 trajectory qualification.

The computational scaling itself is favorable. At h=-100 cm, 32 panels is about 1.97x faster than 64, 16 about 3.8x and 8 about 7.2x in the isolated integral.

The error is strongly state dependent. Examples:
- B01 at h=-300 cm: 32-panel error 0.812%; at -100 cm 0.126%; at -30 cm 0.019%.
- O05 at h=-300 cm: 32-panel error 0.0092%; at -100 cm 0.0004%.
- Very dry states dominate the failure: at h=-10000 cm the 32-panel error is about 62% for B01 and 82% for O05.

Decision: reject any one global reduced panel count. A state-adaptive panel policy requires a new approximate contract; it may not be retrofitted into PERF06.
