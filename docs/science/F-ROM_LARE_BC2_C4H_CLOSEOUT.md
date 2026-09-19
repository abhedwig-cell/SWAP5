# F-ROM-LARE BC2-C4H closeout

C4H factorised the already-authorized B9 TERMINAL_SIDE_LINEAR q_i error. It did not change the closure, add state or propagate a corrected model.

Formal decision: TERMINAL_QI_GRADIENT_RECONSTRUCTION_TARGET_SUPPORTED.

Reference q_i is the conservative B8 split moving-control-volume flux. The predicted q_i is exactly the B9 TERMINAL_SIDE_LINEAR trapezoidal endpoint closure. For each interval, the product q=K g was split symmetrically into a conductivity contribution E_K and an effective-gradient contribution E_G. The factorisation closes to at most 1.17e-15 cm/d.

All four monotone cases classify GRADIENT_COMPONENT_DOMINANT. At 2.5 cm WT_RISE, RMS(E_G) is about 0.3614 cm/d versus 0.00525 cm/d for RMS(E_K); |E_G| exceeds |E_K| on about 99.6% of intervals. At 5 cm WT_RISE the corresponding values are about 0.6356 and 0.01635 cm/d, with gradient dominance on every interval. The FALL cases show the same dominance.

The result is not a claim that conductivity is exact. It is a target-selection result: within the current B9 closure, remaining q_i error is not primarily explained by the interface-K reconstruction. A K-focused correction would therefore address the smaller component.

The next research step may preregister a physically derived pressure-head/gradient reconstruction that uses only the already existing Wb, Wt and H state, remains mass consistent and preserves hydrostatic equilibrium. C4H does not authorize an empirical gradient correction, an extra state variable, free propagation, groundwater feedback, application acceptance, speed claims or production ROM.
