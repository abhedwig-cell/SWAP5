from pathlib import Path
import sys
src=Path("tests/fgc/support/mod_fgc45_real_multiswap_c_bridge.f90").read_text()
mode=sys.argv[2]
src=src.replace("fmr_b110_physical_state_t, fmr_serialized_reference_backend_t, fmr_new_b110_temporal_indicator_committed_state",
"fmr_b110_physical_state_t, fmr_b110_rfm_state_t, fmr_serialized_reference_backend_t, fmr_new_b110_temporal_indicator_committed_state, fmr_new_b110_rfm_committed_state")
src=src.replace("use mod_fmr_serialized_reference_backend, only:", "use mod_fmr_serialized_reference_backend, only:",1)
# Additional RFM imports are inserted before implicit none.
needle="  implicit none\n"
imports="""  use mod_rfm_physical_state, only: rfm_physical_state_t
  use mod_rfm_runtime_configuration, only: rfm_runtime_configuration_t, RFM_SORPTIVITY_POLICY_A28_V1
"""
src=src.replace(needle,imports+needle,1)
# Template continuation: RFM uses optional RFM state and no temporal-history carrier.
src=src.replace("FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY",
"FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY, FMR_NUMERICAL_CONTINUATION_NONE, FMR_OPTIONAL_STATE_LAYOUT_RFM",1)
src=src.replace("t%state_layout_id=560030_int64; t%solver_interface_id=560040_int64; t%optional_state_layout_id=0_int64\n    t%numerical_continuation_layout_id=FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY",
"""t%state_layout_id=560030_int64; t%solver_interface_id=560040_int64; t%optional_state_layout_id=FMR_OPTIONAL_STATE_LAYOUT_RFM
    t%numerical_continuation_layout_id=FMR_NUMERICAL_CONTINUATION_NONE""")
# Configure both backends after initialize.
src=src.replace("call predictor_backend(i)%initialize(top(i))\n       call corrector_backend(i)%initialize(top(i))",
"""call predictor_backend(i)%initialize(top(i))
       call corrector_backend(i)%initialize(top(i))
       call configure_tile_rfm(predictor_backend(i),i,ok); if(.not.ok)return
       call configure_tile_rfm(corrector_backend(i),i,ok); if(.not.ok)return""")
# Replace committed-state constructor body call.
old="""    call fmr_new_b110_temporal_indicator_committed_state(state,lineage_id,physical,0.0_real64,ok, &
         accepted_predecessor_right_derivative)"""
new="""    block
      type(rfm_physical_state_t)::rfm_state
      call rfm_state%initialize(1,ok); if(.not.ok)return
      call fmr_new_b110_rfm_committed_state(state,lineage_id,physical,rfm_state,0.0_real64,ok)
    end block"""
src=src.replace(old,new)
# Active RFM surface forcing.
src=src.replace("f%top_flux=q; f%top_head=H0_CM; f%bottom_flux=q; f%bottom_head=H0_CM",
"""f%top_flux=0.0_real64; f%top_head=H0_CM; f%bottom_flux=q; f%bottom_head=H0_CM
    allocate(f%rfm_surface); f%rfm_surface%supplied=.true.; f%rfm_surface%event_active=.true.
    f%rfm_surface%precipitation_rate_cm_per_day=0.5_real64
    f%rfm_surface%ponding_max_cm=0.1_real64; f%rfm_surface%runoff_resistance_day=0.1_real64
    f%rfm_surface%runoff_exponent=1.0_real64""")
# Insert config helper.
idx=src.index("  subroutine initialize_parameters")
helper=f"""  subroutine configure_tile_rfm(backend,i,ok)
    type(fmr_serialized_reference_backend_t),intent(inout)::backend
    integer,intent(in)::i
    logical,intent(out)::ok
    type(rfm_runtime_configuration_t)::c
    real(real64)::area,deep,depth
    area=merge(0.05_real64,0.10_real64,i==1)
    deep=merge(0.25_real64,0.65_real64,i==1)
    depth=merge(60._real64,40._real64,i==1)
    c%enabled=.true.;c%sigma_b=.65_real64;c%f_mb=deep;c%connectivity_p=1._real64
    c%z_ah_cm=20._real64;c%z_ic_cm=depth;c%chi_wall=1._real64;c%exchange_length_cm=20._real64
    c%mb_contact_length_cm=80._real64;c%sorptivity_panels=64
    {"c%sorptivity_policy=RFM_SORPTIVITY_POLICY_A28_V1" if mode=="a28" else ""}
    c%mb_wall_node_index=numnod;c%endpoint_depth_cm=[depth];c%endpoint_contact_thickness_cm=[20._real64]
    c%endpoint_area_fraction=[area*(1._real64-deep)];c%endpoint_node_index=[nint(depth/10._real64)]
    call backend%configure_rfm_runtime(c,ok)
  end subroutine configure_tile_rfm

"""
src=src[:idx]+helper+src[idx:]
Path(sys.argv[1]).write_text(src)
