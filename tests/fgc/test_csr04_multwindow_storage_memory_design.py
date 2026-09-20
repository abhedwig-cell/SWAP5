"""CSR-04 Phase-B experiment contract.

This is a repository-owned preregistration/executable design guard.  It does
not fake the coupled experiment: execution remains blocked until the real
FMR bridge exposes a next-window operation that preserves committed SWAP
state while rebuilding the F-GC30/F-GC33 predictor from that state.
"""

SY_SEQUENCE=(0.30,0.05,1e-2,1e-3,1e-4,1e-5)
FORCING_PHASES=("baseline","pulse","pulse","recovery","recovery","recovery")
# Existing bridge forcing lever: equal prescribed top/bottom predictor flux.  The
# pulse is deliberately tiny and diagnostic; no new atmospheric physics is introduced.
QBOT_SEQUENCE_CM_PER_DAY=(1e-6,1e-6,5e-6,5e-6,1e-6,1e-6)
REQUIRED_WINDOW_OBSERVATIONS={
    "accepted_modflow_head_m",
    "swap_lower_face_head_m",
    "accepted_interface_transfer_m",
    "swap_storage_start_native",
    "swap_storage_end_native",
    "swap_storage_change_native",
    "swap_mass_residual_native",
    "modflow_sto_rate_m3_per_day",
    "q_reference",
    "j_swap_dqdh",
    "interface_residual",
}
FORBIDDEN_INFERENCES={
    "near_zero_sto_is_reference_truth",
    "swap_storage_plus_modflow_sto_is_unconditionally_physical_storage",
    "geometric_overlap_alone_proves_double_counting",
}

def test_phase_b_preregistration():
    assert SY_SEQUENCE[-1] < SY_SEQUENCE[-2] < SY_SEQUENCE[-3]
    assert "pulse" in FORCING_PHASES and "recovery" in FORCING_PHASES
    assert len(QBOT_SEQUENCE_CM_PER_DAY)==len(FORCING_PHASES)
    assert max(QBOT_SEQUENCE_CM_PER_DAY)>QBOT_SEQUENCE_CM_PER_DAY[0]
    assert "swap_storage_change_native" in REQUIRED_WINDOW_OBSERVATIONS
    assert "modflow_sto_rate_m3_per_day" in REQUIRED_WINDOW_OBSERVATIONS
    assert "j_swap_dqdh" in REQUIRED_WINDOW_OBSERVATIONS
    assert len(FORBIDDEN_INFERENCES)==3

if __name__=="__main__":
    test_phase_b_preregistration()
    print("CSR04_PHASE_B_EXPERIMENT_CONTRACT=PASS")
    print("CSR04_PHASE_B_REAL_EXECUTION=BLOCKED_NEXT_WINDOW_BRIDGE_REQUIRED")
