# F-ROM-LARE BC2-C4L closeout

Formal decision: QH_PRESERVING_CUBIC_MIXED.

C4L fixed the lower-boundary slope exactly to the already-supported B7/B9 terminal slope and solved only two curvature coefficients from Wt and Wb. No response fitting, extra state, clipping or direction switch was used.

All numerical hard gates passed. The maximum 64-vs-128 qi difference is about 2.64e-9 cm/d, storage residuals remain below 8e-13 cm, and qH is exactly identical to B9.

The internal flux result is mixed. At 2.5 cm, RISE RMS improves from about 0.361 to 0.343 cm/d and FALL from 0.294 to 0.282. At 5 cm, FALL improves from about 0.492 to 0.439, but RISE worsens from about 0.630 to 0.854 cm/d. HOLD is also damaged: cubic qi becomes about 0.0046 cm/d at 2.5 cm and 0.0169 cm/d at 5 cm while B9 remains near numerical zero.

Therefore the cubic curvature family is not admitted for propagation. The next diagnostic must explain the sign and magnitude of the required interface-slope correction relative to the B9 terminal slope before another closure is proposed.
