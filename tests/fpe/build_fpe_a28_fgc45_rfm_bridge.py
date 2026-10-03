from pathlib import Path
import sys
src=Path("tests/fgc/support/mod_fgc45_real_multiswap_c_bridge.f90").read_text()
mode=sys.argv[2]
src=src.replace("fmr_b110_physical_state_t, fmr_serialized_reference_backend_t, fmr_new_b110_temporal_indicator_committed_state",
"fmr_b110_physical_state_t, fmr_b110_rfm_state_t, fmr_serialized_reference_backend_t, fmr_new_b110_temporal_indicator_committed_state, fmr_new_b110_rfm_committed_state")
src=src.replace("use mod_fmr_serialized_reference_backend, only:", "use mod_fmr_serialized_reference_backend, only:",1)
src=src.replace("use mod_modflow6_swap_predictor_response, only: modflow6_swap_predictor_lineage_t, modflow6_swap_predictor_response_t",
"use mod_modflow6_swap_predictor_response, only: modflow6_swap_predictor_lineage_t, modflow6_swap_predictor_response_t, &\n       compose_modflow6_swap_predictor_response, modflow6_derivative_coverage_t, MODFLOW6_DERIVATIVE_CENTERED_FD")
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
src=src.replace("call predictor_backend(i)%initialize(top(i))\n      call corrector_backend(i)%initialize(top(i))",
"""call predictor_backend(i)%initialize(top(i))
      call corrector_backend(i)%initialize(top(i))
      call configure_tile_rfm(predictor_backend(i),i,ok); if(.not.ok)then;write(*,'(a,i0)')'A28_FGC45_INIT_FAIL=PRED_RFM tile=',i;return;end if
      call configure_tile_rfm(corrector_backend(i),i,ok); if(.not.ok)then;write(*,'(a,i0)')'A28_FGC45_INIT_FAIL=CORR_RFM tile=',i;return;end if""")
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
    allocate(f%rfm_surface); f%rfm_surface%supplied=.true.; f%rfm_surface%event_active=.false.
    f%rfm_surface%precipitation_rate_cm_per_day=0.0_real64; f%rfm_surface%event_active=.false.
    f%rfm_surface%ponding_max_cm=0.1_real64; f%rfm_surface%runoff_resistance_day=0.1_real64
    f%rfm_surface%runoff_exponent=1.0_real64""")
# Insert centered-FD RFM predictor helper.
fd_helper=r"""  subroutine build_tile_predictor_rfm_fd(i,response,status)
    integer,intent(in)::i
    type(modflow6_swap_predictor_response_t),intent(out)::response
    integer,intent(out)::status
    type(kernel_checkpoint_t)::checkpoint
    type(kernel_result_t)::rp,rm
    type(kernel_candidate_state_t)::cp,cm
    type(kernel_diagnostics_t)::dp,dm
    type(fmr_b110_physical_forcing_t)::fp,fm
    type(soil_water_physical_state_t)::sp,sm
    type(soil_water_parameter_set_t)::pp,pm
    type(modflow6_swap_predictor_lineage_t)::lineage
    type(modflow6_derivative_coverage_t)::coverage
    real(real64)::dq,hp,hm,h0,deriv
    logical::ok
    status=1;dq=1.0e-5_real64
    call fmr_capture_checkpoint(committed(i),checkpoint,ok);if(.not.ok)then;write(*,'(a,i0)')'A28_FGC45_FD_FAIL=CHECKPOINT tile=',i;return;end if
    fp=base_forcing(i);fm=base_forcing(i);fp%bottom_flux=PREDICTOR_QBOT+dq;fm%bottom_flux=PREDICTOR_QBOT-dq
    call predictor_backend(i)%run_trial(column(i),template(i),predictor_parameters(i),committed(i),fp,predictor_config,window%t0,window%t1,checkpoint,rp,cp,dp)
    if(.not.rp%completed)then;write(*,'(a,i0,a,i0,4(a,i0))')'A28_FGC45_FD_FAIL=PLUS tile=',i,' status=',rp%status,' attempts=',dp%attempts,' retries=',dp%retries,' solver=',dp%solver_rejections,' temporal=',dp%temporal_rejections;return;end if
    if(.not.cp%ready())then;write(*,'(a,i0)')'A28_FGC45_FD_FAIL=PLUS_CANDIDATE tile=',i;return;end if
    call materialize_solver_view(cp,predictor_parameters(i),sp,pp,ok);if(.not.ok)then;write(*,'(a,i0)')'A28_FGC45_FD_FAIL=PLUS_VIEW tile=',i;return;end if
    write(*,'(a,i0)')'A28_FGC45_FD_PLUS_VIEW_OK tile=',i
    call predictor_backend(i)%discard_trial_candidate(cp,dp)
    write(*,'(a,i0,a,g0)')'A28_FGC45_FD_PLUS_OK tile=',i,' hbot_m=',hp
    call predictor_backend(i)%run_trial(column(i),template(i),predictor_parameters(i),committed(i),fm,predictor_config,window%t0,window%t1,checkpoint,rm,cm,dm)
    if(.not.rm%completed)then;write(*,'(a,i0,a,i0,4(a,i0))')'A28_FGC45_FD_FAIL=MINUS tile=',i,' status=',rm%status,' attempts=',dm%attempts,' retries=',dm%retries,' solver=',dm%solver_rejections,' temporal=',dm%temporal_rejections;return;end if
    if(.not.cm%ready())then;write(*,'(a,i0)')'A28_FGC45_FD_FAIL=MINUS_CANDIDATE tile=',i;return;end if
    call materialize_solver_view(cm,predictor_parameters(i),sm,pm,ok);if(.not.ok)then;write(*,'(a,i0)')'A28_FGC45_FD_FAIL=MINUS_VIEW tile=',i;return;end if
    call predictor_backend(i)%discard_trial_candidate(cm,dm)
    write(*,'(a,i0,a,g0)')'A28_FGC45_FD_MINUS_OK tile=',i,' hbot_m=',hm
    hp=(sp%pressure_head(numnod)+predictor_parameters(i)%z(numnod))*0.01_real64
    hm=(sm%pressure_head(numnod)+predictor_parameters(i)%z(numnod))*0.01_real64
    h0=H0_CM*0.01_real64;deriv=(hp-hm)*100._real64/(2._real64*dq)
    lineage%coupling_id=COUPLING_ID;lineage%swap_lineage_id=COLUMN_ID(i);lineage%swap_origin_revision=0_int64
    lineage%groundwater_service_id=GW_SERVICE_ID;lineage%groundwater_lineage_id=GW_LINEAGE_ID;lineage%groundwater_origin_revision=0_int64
    coverage%lower_face_head_semantics_covered=.true.
    call compose_modflow6_swap_predictor_response(window,lineage,PREDICTOR_QBOT,h0,0.5_real64*(hp+hm),deriv,MODFLOW6_DERIVATIVE_CENTERED_FD,coverage,'centered-fd-rfm-full-trajectory','fgc45-rfm-fd',response,status)
    write(*,'(a,i0,a,i0,a,g0)')'A28_FGC45_FD_COMPOSE tile=',i,' status=',status,' deriv=',deriv
    if(status/=0.or..not.response%valid)write(*,'(a,i0,4(a,g0))')'A28_FGC45_FD_FAIL=COMPOSE status=',status,' hp=',hp,' hm=',hm,' deriv=',deriv,' h0=',h0
  end subroutine build_tile_predictor_rfm_fd

"""
idx_fd=src.index("  subroutine build_tile_predictor(")
src=src[:idx_fd]+fd_helper+src[idx_fd:]
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
# Ensure diagnostics are present even if formatting-specific replacements above missed.
src=src.replace("if(.not.ok)return\n      call predictor_backend(i)%initialize", "if(.not.ok)then;write(*,'(a,i0)')'A28_FGC45_INIT_FAIL=STATE tile=',i;return;end if\n      call predictor_backend(i)%initialize",1)
src=src.replace("if(status/=0)return\n      binding(i)%groundwater_cell_id", "if(status/=0)then;write(*,'(a,i0,a,i0)')'A28_FGC45_INIT_FAIL=PREDICTOR tile=',i,' status=',status;return;end if\n      binding(i)%groundwater_cell_id",1)
src=src.replace("if(status/=MODFLOW6_MULTI_CELL_OK .or. .not.cell%valid)return", "if(status/=MODFLOW6_MULTI_CELL_OK .or. .not.cell%valid)then;write(*,'(a,i0)')'A28_FGC45_INIT_FAIL=CELL status=',status;return;end if",1)
src=src.replace("if(status/=MODFLOW6_LINEAR_BACKEND_OK .or. .not.term%valid)return", "if(status/=MODFLOW6_LINEAR_BACKEND_OK .or. .not.term%valid)then;write(*,'(a,i0)')'A28_FGC45_INIT_FAIL=TERM status=',status;return;end if",1)
src=src.replace("if(status/=GW_SWAP_PARTICIPANT_OK)return\n      call ledger", "if(status/=GW_SWAP_PARTICIPANT_OK)then;write(*,'(a,i0,a,i0)')'A28_FGC45_INIT_FAIL=ORIGIN tile=',i,' status=',status;return;end if\n      call ledger",1)
src=src.replace("if(status/=GW_MASS_LEDGER_OK)return", "if(status/=GW_MASS_LEDGER_OK)then;write(*,'(a,i0,a,i0)')'A28_FGC45_INIT_FAIL=LEDGER tile=',i,' status=',status;return;end if",1)
src=src.replace("if(.not.result%completed)return", "if(.not.result%completed)then;write(*,'(a,i0,a,i0,a,i0,a,i0,a,i0,a,i0)')'A28_FGC45_PRED_FAIL tile=',i,' status=',result%status,' attempts=',diagnostics%attempts,' retries=',diagnostics%retries,' solver=',diagnostics%solver_rejections,' temporal=',diagnostics%temporal_rejections;return;end if",1)
src=src.replace("if(.not.candidate%ready())return", "if(.not.candidate%ready())then;write(*,'(a,i0)')'A28_FGC45_PRED_FAIL=CANDIDATE tile=',i;return;end if",1)
src=src.replace("if(.not.result%accepted_trajectory_direction%available)return", "if(.not.result%accepted_trajectory_direction%available)then;write(*,'(a,i0)')'A28_FGC45_PRED_FAIL=DIRECTION tile=',i;return;end if",1)
Path(sys.argv[1]).write_text(src)



