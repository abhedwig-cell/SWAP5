program test_pub_gc_macro_window_response
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite, ieee_value, ieee_quiet_nan
  use MOD_grid, only: numnod, z, dz, disnod
  use MOD_swap_base, only: swmacro
  use MOD_snow, only: legacy_melt => melt
  use MOD_drain, only: legacy_qdra => qdra
  use MOD_irrigation, only: legacy_qssdi => qssdi
  use variables, only: legacy_qrot => qrot, legacy_swbotb => swbotb, legacy_hbot => hbot, legacy_qbot => qbot
  use mod_transaction_reference, only: transaction_state_t, TX_TEMPORAL_MODEL_CERTIFICATE
  use mod_canonical_contracts, only: canonical_numerical_config_t
  use mod_kernel_transactions, only: kernel_committed_state_t, kernel_checkpoint_t, kernel_result_t, &
       kernel_candidate_state_t, kernel_diagnostics_t, kernel_executor_t
  use mod_fmr_checkpoint_orchestrator, only: fmr_capture_checkpoint, fmr_discard_candidate
  use mod_fmr_accepted_commit_receipt, only: fmr_accepted_commit_receipt_t, fmr_commit_candidate_with_receipt, &
       FMR_COMMIT_RECEIPT_OK
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, FMR_BACKEND_SERIALIZED_REFERENCE, &
       FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_state_t, fmr_b110_temporal_indicator_state_t, &
       fmr_b110_physical_parameters_t, fmr_b110_physical_forcing_t, fmr_serialized_reference_backend_t, &
       fmr_new_b110_temporal_indicator_committed_state
  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_pub_gc_macro_window_response, only: pub_gc_macro_window_response_t, pub_gc_run_macro_window_response, &
       PUB_GC_MACRO_OK, PUB_GC_MACRO_INVALID
  implicit none

  real(real64), parameter :: initial_time_day = 4200.125_real64
  real(real64), parameter :: initial_head_cm = -80.0_real64
  real(real64), parameter :: hard_mass_gate = 1.0e-10_real64
  real(real64), parameter :: qualification_head_budget = 100.0_real64
  integer(int64), parameter :: origin_lineage = 910001_int64

  type(fmr_logical_column_t) :: column
  type(fmr_template_t) :: template
  type(fmr_b110_physical_parameters_t) :: parameters
  type(fmr_b110_physical_state_t) :: initial_state
  type(fmr_b110_physical_forcing_t) :: base_forcing
  type(fmr_serialized_reference_backend_t) :: backend
  type(fixed_flux_top_boundary_provider_t), target :: top_provider
  type(canonical_numerical_config_t) :: config
  type(kernel_committed_state_t) :: origin
  real(real64) :: predecessor(numnod), conductivity_reference
  logical :: ok

  call configure_column(column, template)
  call configure_transaction(config)
  call configure_case(parameters, initial_state, base_forcing, initial_head_cm, 0.005_real64, conductivity_reference)
  call backend%initialize(top_provider)
  predecessor = 0.0_real64
  call fmr_new_b110_temporal_indicator_committed_state(origin, origin_lineage, initial_state, initial_time_day, ok, predecessor)
  call require(ok .and. origin%ready(), 'initial temporal committed state')

  call test_q0_one_step()
  call test_q1_sequential_equivalence()
  call test_q2_aggregate_terminal_selectivity()
  call test_q3_same_origin_aba()
  call test_q5_seeded_temporal_history()
  call test_q8_temporal_coordinate()
  call test_failure_controls()

  write(*,'(a)') 'PUB_GC_MACRO_QUAL_Q0=PASS'
  write(*,'(a)') 'PUB_GC_MACRO_QUAL_Q1=PASS'
  write(*,'(a)') 'PUB_GC_MACRO_QUAL_Q2=PASS'
  write(*,'(a)') 'PUB_GC_MACRO_QUAL_Q3=PASS'
  write(*,'(a)') 'PUB_GC_MACRO_QUAL_Q5=PASS'
  write(*,'(a)') 'PUB_GC_MACRO_QUAL_Q8=PASS'
  write(*,'(a)') 'PUB_GC_MACRO_QUAL_FAILURE_CONTROLS=PASS'
  write(*,'(a)') 'PUB_GC_MACRO_PRIMARY_H2_H3_ELIGIBLE=false'
  write(*,'(a)') 'PUB_GC_MACRO_QUALIFICATION=PASS'

contains

  subroutine test_q0_one_step()
    type(pub_gc_macro_window_response_t) :: macro
    type(fmr_b110_physical_forcing_t), allocatable :: forcings(:)
    type(kernel_result_t) :: direct_result
    class(transaction_state_t), allocatable :: direct_endpoint
    integer :: status
    real(real64) :: dt(1)

    dt = [0.01_real64]
    call build_forcings([-1.0_real64], conductivity_reference, forcings)
    call pub_gc_run_macro_window_response(column, template, parameters, backend, config, origin, forcings, dt, &
         initial_time_day, initial_time_day+0.01_real64, -80.0_real64, 920001_int64, macro, status)
    call require(status == PUB_GC_MACRO_OK .and. macro%completed, 'Q0 macro complete')

    call direct_trial_snapshot(origin, forcings(1), initial_time_day, initial_time_day+0.01_real64, &
         -80.0_real64, direct_result, direct_endpoint)
    call require(same_bits(macro%q_whole_cm,direct_result%bottom_outward_exchange_native), 'Q0 whole Q direct identity')
    call require(same_bits(macro%q_terminal_cm_per_day,direct_result%terminal_bottom_outward_flux_native), &
         'Q0 terminal direct identity')
    call require(same_bits(macro%q_whole_cm,macro%q_terminal_rectangle_cm), 'Q0 one-step whole terminal identity')
    call require(states_same(macro%endpoint_state,direct_endpoint), 'Q0 endpoint direct identity')
    call require(macro%disposable_final_revision == 1_int64, 'Q0 disposable revision')
    write(*,'(a,es26.17e3)') 'PUB_GC_MACRO_Q0_Q_WHOLE_CM=',macro%q_whole_cm
  end subroutine test_q0_one_step

  subroutine test_q1_sequential_equivalence()
    type(pub_gc_macro_window_response_t) :: macro
    type(fmr_b110_physical_forcing_t), allocatable :: forcings(:)
    class(transaction_state_t), allocatable :: sequential_endpoint
    real(real64) :: dt(4), seq_q(4), seq_terminal(4)
    integer :: status

    dt = [0.005_real64,0.005_real64,0.005_real64,0.005_real64]
    call build_forcings([-1.0_real64,-1.0_real64,-1.0_real64,-1.0_real64], conductivity_reference, forcings)
    call pub_gc_run_macro_window_response(column, template, parameters, backend, config, origin, forcings, dt, &
         initial_time_day, initial_time_day+0.02_real64, -80.0_real64, 920101_int64, macro, status)
    call require(status == PUB_GC_MACRO_OK .and. macro%completed, 'Q1 macro complete')

    call independent_sequential_response(origin, forcings, dt, initial_time_day, -80.0_real64, 920102_int64, &
         seq_q, seq_terminal, sequential_endpoint)
    call require(real_arrays_same(macro%q_contribution_cm,seq_q), 'Q1 contribution sequence identity')
    call require(real_arrays_same(macro%terminal_flux_cm_per_day,seq_terminal), 'Q1 terminal sequence identity')
    call require(same_bits(macro%q_whole_cm,sum(seq_q)), 'Q1 whole sum identity')
    call require(states_same(macro%endpoint_state,sequential_endpoint), 'Q1 endpoint sequential identity')
    call require(macro%disposable_final_revision == 4_int64, 'Q1 disposable revision')
    write(*,'(a,es26.17e3)') 'PUB_GC_MACRO_Q1_Q_WHOLE_CM=',macro%q_whole_cm
  end subroutine test_q1_sequential_equivalence

  subroutine test_q2_aggregate_terminal_selectivity()
    type(pub_gc_macro_window_response_t) :: macro
    type(fmr_b110_physical_forcing_t), allocatable :: forcings(:)
    real(real64) :: dt(4), explicit_sum
    integer :: status

    dt = [0.005_real64,0.005_real64,0.005_real64,0.005_real64]
    call build_forcings([-5.0_real64,-1.0_real64,-1.0_real64,-1.0_real64], conductivity_reference, forcings)
    call pub_gc_run_macro_window_response(column, template, parameters, backend, config, origin, forcings, dt, &
         initial_time_day, initial_time_day+0.02_real64, -80.0_real64, 920201_int64, macro, status)
    call require(status == PUB_GC_MACRO_OK .and. macro%completed, 'Q2 macro complete')
    explicit_sum = sum(macro%q_contribution_cm)
    call require(same_bits(macro%q_whole_cm,explicit_sum), 'Q2 whole explicit sum')
    call require(same_bits(macro%q_terminal_cm_per_day,macro%terminal_flux_cm_per_day(4)), 'Q2 final terminal identity')
    call require(same_bits(macro%q_terminal_rectangle_cm, &
         macro%q_terminal_cm_per_day*macro%macro_duration_day), 'Q2 terminal rectangle identity')
    call require(abs(macro%whole_minus_terminal_cm) > 1.0e-12_real64, 'Q2 frozen discrimination floor')
    call require(all(ieee_is_finite(macro%q_contribution_cm)), 'Q2 finite contributions')
    write(*,'(a,4(es26.17e3,1x))') 'PUB_GC_MACRO_Q2_CONTRIBUTIONS_CM=',macro%q_contribution_cm
    write(*,'(a,es26.17e3)') 'PUB_GC_MACRO_Q2_Q_WHOLE_CM=',macro%q_whole_cm
    write(*,'(a,es26.17e3)') 'PUB_GC_MACRO_Q2_Q_TERMINAL_CM=',macro%q_terminal_rectangle_cm
    write(*,'(a,es26.17e3)') 'PUB_GC_MACRO_Q2_WHOLE_MINUS_TERMINAL_CM=',macro%whole_minus_terminal_cm
  end subroutine test_q2_aggregate_terminal_selectivity

  subroutine test_q3_same_origin_aba()
    type(pub_gc_macro_window_response_t) :: a1, b, a2
    type(fmr_b110_physical_forcing_t), allocatable :: forcings(:)
    class(transaction_state_t), allocatable :: before_state, after_state
    real(real64) :: dt(4), time_before, time_after
    integer(int64) :: revision_before
    integer :: status
    logical :: available

    dt = [0.005_real64,0.005_real64,0.005_real64,0.005_real64]
    call build_forcings([-1.0_real64,-1.0_real64,-1.0_real64,-1.0_real64], conductivity_reference, forcings)
    call origin%snapshot(before_state, available)
    call require(available,'Q3 origin snapshot before')
    revision_before = origin%current_revision()
    call origin%current_time(time_before,available)
    call require(available,'Q3 origin time before')

    call pub_gc_run_macro_window_response(column, template, parameters, backend, config, origin, forcings, dt, &
         initial_time_day, initial_time_day+0.02_real64, -80.0_real64, 920301_int64, a1, status)
    call require(status == PUB_GC_MACRO_OK,'Q3 A1')
    call pub_gc_run_macro_window_response(column, template, parameters, backend, config, origin, forcings, dt, &
         initial_time_day, initial_time_day+0.02_real64, -95.0_real64, 920302_int64, b, status)
    call require(status == PUB_GC_MACRO_OK,'Q3 B')
    call pub_gc_run_macro_window_response(column, template, parameters, backend, config, origin, forcings, dt, &
         initial_time_day, initial_time_day+0.02_real64, -80.0_real64, 920303_int64, a2, status)
    call require(status == PUB_GC_MACRO_OK,'Q3 A2')

    call require(same_bits(a1%q_whole_cm,a2%q_whole_cm), 'Q3 A Q repeatability')
    call require(real_arrays_same(a1%q_contribution_cm,a2%q_contribution_cm), 'Q3 A sequence repeatability')
    call require(states_same(a1%endpoint_state,a2%endpoint_state), 'Q3 A endpoint repeatability')
    call require(.not. same_bits(a1%q_whole_cm,b%q_whole_cm), 'Q3 B distinguishable')

    call origin%snapshot(after_state,available)
    call require(available,'Q3 origin snapshot after')
    call origin%current_time(time_after,available)
    call require(available,'Q3 origin time after')
    call require(origin%current_revision()==revision_before,'Q3 origin revision unchanged')
    call require(same_bits(time_before,time_after),'Q3 origin time unchanged')
    call require(states_same(before_state,after_state),'Q3 origin state unchanged')
  end subroutine test_q3_same_origin_aba

  subroutine test_q5_seeded_temporal_history()
    type(kernel_committed_state_t) :: seeded_origin
    type(pub_gc_macro_window_response_t) :: macro
    type(fmr_b110_physical_forcing_t), allocatable :: seed_forcing(:), macro_forcing(:)
    type(kernel_result_t) :: direct_result
    class(transaction_state_t), allocatable :: direct_endpoint, seeded_snapshot
    real(real64) :: dt(2)
    real(real64), allocatable :: derivative(:)
    logical :: available
    integer :: status

    call clone_origin(origin, 930001_int64, seeded_origin)
    call build_forcings([-2.0_real64], conductivity_reference, seed_forcing)
    call commit_one(seeded_origin, seed_forcing(1), initial_time_day, initial_time_day+0.005_real64, -82.5_real64)

    call seeded_origin%snapshot(seeded_snapshot,available)
    call require(available,'Q5 seeded snapshot')
    select type (s => seeded_snapshot)
    type is (fmr_b110_temporal_indicator_state_t)
      call s%temporal_history_snapshot(derivative,available)
      call require(available .and. size(derivative)==numnod,'Q5 temporal history available')
      call require(any(abs(derivative)>0.0_real64),'Q5 temporal history nontrivial')
    class default
      call require(.false.,'Q5 temporal indicator dynamic type')
    end select

    dt=[0.005_real64,0.005_real64]
    call build_forcings([-1.0_real64,-1.0_real64], conductivity_reference, macro_forcing)
    call pub_gc_run_macro_window_response(column, template, parameters, backend, config, seeded_origin, macro_forcing, dt, &
         initial_time_day+0.005_real64, initial_time_day+0.015_real64, -80.0_real64, 930101_int64, macro, status)
    call require(status==PUB_GC_MACRO_OK .and. macro%completed,'Q5 macro complete')

    call direct_trial_snapshot(seeded_origin, macro_forcing(1), initial_time_day+0.005_real64, &
         initial_time_day+0.010_real64, -80.0_real64, direct_result, direct_endpoint)
    call require(same_bits(macro%q_contribution_cm(1),direct_result%bottom_outward_exchange_native), &
         'Q5 first native Q same-origin identity')
    write(*,'(a,es26.17e3)') 'PUB_GC_MACRO_Q5_FIRST_Q_CM=',macro%q_contribution_cm(1)
  end subroutine test_q5_seeded_temporal_history

  subroutine test_q8_temporal_coordinate()
    type(pub_gc_macro_window_response_t) :: q8a, q8b, q8c
    type(fmr_b110_physical_forcing_t), allocatable :: forcings16(:), forcings32(:)
    type(kernel_committed_state_t) :: shifted_origin
    real(real64) :: dt16(16), dt32(32), factors16(16), factors32(32)
    real(real64) :: shifted_time, shifted_predecessor(numnod)
    logical :: shifted_ok
    integer :: status

    dt16=0.0025_real64
    dt32=0.00125_real64
    factors16=-1.0_real64
    factors32=-1.0_real64
    call build_forcings(factors16,conductivity_reference,forcings16)
    call build_forcings(factors32,conductivity_reference,forcings32)

    call pub_gc_run_macro_window_response(column,template,parameters,backend,config,origin,forcings16,dt16, &
         initial_time_day,initial_time_day+0.04_real64,-80.0_real64,950001_int64,q8a,status)
    call require(status==PUB_GC_MACRO_OK .and. q8a%completed,'Q8A 16 contribution complete')
    call require(q8a%native_contribution_count==16,'Q8A count')
    call require(size(q8a%actual_native_dt_day)==16,'Q8A actual duration telemetry')
    call require(all(ieee_is_finite(q8a%actual_native_dt_day)) .and. all(q8a%actual_native_dt_day>0.0_real64), &
         'Q8A actual durations finite positive')
    call require(same_bits(q8a%disposable_final_time,initial_time_day+0.04_real64),'Q8A exact final macro time')
    call require(q8a%authoritative_revision_before==q8a%authoritative_revision_after,'Q8A origin revision isolation')
    call require(same_bits(q8a%authoritative_time_before,q8a%authoritative_time_after),'Q8A origin time isolation')

    call pub_gc_run_macro_window_response(column,template,parameters,backend,config,origin,forcings32,dt32, &
         initial_time_day,initial_time_day+0.04_real64,-80.0_real64,950002_int64,q8b,status)
    call require(status==PUB_GC_MACRO_OK .and. q8b%completed,'Q8B 32 contribution complete')
    call require(q8b%native_contribution_count==32,'Q8B count')
    call require(size(q8b%actual_native_dt_day)==32,'Q8B actual duration telemetry')
    call require(all(ieee_is_finite(q8b%actual_native_dt_day)) .and. all(q8b%actual_native_dt_day>0.0_real64), &
         'Q8B actual durations finite positive')
    call require(same_bits(q8b%disposable_final_time,initial_time_day+0.04_real64),'Q8B exact final macro time')
    call require(q8b%authoritative_revision_before==q8b%authoritative_revision_after,'Q8B origin revision isolation')
    call require(same_bits(q8b%authoritative_time_before,q8b%authoritative_time_after),'Q8B origin time isolation')

    shifted_time=initial_time_day+10000.0_real64
    shifted_predecessor=0.0_real64
    call fmr_new_b110_temporal_indicator_committed_state(shifted_origin,950003_int64,initial_state,shifted_time, &
         shifted_ok,shifted_predecessor)
    call require(shifted_ok .and. shifted_origin%ready(),'Q8C shifted origin init')
    call pub_gc_run_macro_window_response(column,template,parameters,backend,config,shifted_origin,forcings32,dt32, &
         shifted_time,shifted_time+0.04_real64,-80.0_real64,950004_int64,q8c,status)
    call require(status==PUB_GC_MACRO_OK .and. q8c%completed,'Q8C shifted 32 contribution complete')
    call require(q8c%native_contribution_count==32,'Q8C count')
    call require(all(ieee_is_finite(q8c%actual_native_dt_day)) .and. all(q8c%actual_native_dt_day>0.0_real64), &
         'Q8C actual durations finite positive')
    call require(same_bits(q8c%disposable_final_time,shifted_time+0.04_real64),'Q8C exact final macro time')
    call require(q8c%authoritative_revision_before==q8c%authoritative_revision_after,'Q8C origin revision isolation')
    call require(same_bits(q8c%authoritative_time_before,q8c%authoritative_time_after),'Q8C origin time isolation')

    write(*,'(a,es26.17e3)') 'PUB_GC_MACRO_Q8A_MAX_DT_REP_ERROR_DAY=',q8a%max_abs_native_dt_representation_error_day
    write(*,'(a,es26.17e3)') 'PUB_GC_MACRO_Q8B_MAX_DT_REP_ERROR_DAY=',q8b%max_abs_native_dt_representation_error_day
    write(*,'(a,es26.17e3)') 'PUB_GC_MACRO_Q8C_MAX_DT_REP_ERROR_DAY=',q8c%max_abs_native_dt_representation_error_day
  end subroutine test_q8_temporal_coordinate

  subroutine test_failure_controls()
    type(pub_gc_macro_window_response_t) :: response
    type(fmr_b110_physical_forcing_t), allocatable :: forcings(:)
    real(real64) :: dt1(1), dt2(2), nan_value
    integer :: status

    call build_forcings([-1.0_real64],conductivity_reference,forcings)
    dt1=[0.01_real64]
    call pub_gc_run_macro_window_response(column,template,parameters,backend,config,origin,forcings,dt1, &
         initial_time_day,initial_time_day,-80.0_real64,940001_int64,response,status)
    call require(status==PUB_GC_MACRO_INVALID .and. .not.response%completed,'failure nonpositive macro')

    dt1=[-0.01_real64]
    call pub_gc_run_macro_window_response(column,template,parameters,backend,config,origin,forcings,dt1, &
         initial_time_day,initial_time_day+0.01_real64,-80.0_real64,940002_int64,response,status)
    call require(status==PUB_GC_MACRO_INVALID .and. .not.response%completed,'failure nonpositive native')

    deallocate(forcings)
    call build_forcings([-1.0_real64,-1.0_real64],conductivity_reference,forcings)
    dt2=[0.004_real64,0.004_real64]
    call pub_gc_run_macro_window_response(column,template,parameters,backend,config,origin,forcings,dt2, &
         initial_time_day,initial_time_day+0.01_real64,-80.0_real64,940003_int64,response,status)
    call require(status==PUB_GC_MACRO_INVALID .and. .not.response%completed,'failure interval sum mismatch')

    nan_value = ieee_value(0.0_real64, ieee_quiet_nan)
    dt2=[0.005_real64,0.005_real64]
    call pub_gc_run_macro_window_response(column,template,parameters,backend,config,origin,forcings,dt2, &
         initial_time_day,initial_time_day+0.01_real64,nan_value,940004_int64,response,status)
    call require(status==PUB_GC_MACRO_INVALID .and. .not.response%completed,'failure nonfinite head')
  end subroutine test_failure_controls

  subroutine independent_sequential_response(authoritative, forcings, dt, t_start, bottom_head, lineage, &
       q, terminal, endpoint)
    type(kernel_committed_state_t), intent(in) :: authoritative
    type(fmr_b110_physical_forcing_t), intent(in) :: forcings(:)
    real(real64), intent(in) :: dt(:), t_start, bottom_head
    integer(int64), intent(in) :: lineage
    real(real64), intent(out) :: q(:), terminal(:)
    class(transaction_state_t), allocatable, intent(out) :: endpoint
    type(kernel_committed_state_t) :: local
    type(kernel_checkpoint_t) :: cp
    type(kernel_result_t) :: result
    type(kernel_candidate_state_t) :: candidate
    type(kernel_diagnostics_t) :: diagnostics, discard_diag
    type(kernel_executor_t) :: commit_kernel, discard_kernel
    type(fmr_accepted_commit_receipt_t) :: receipt
    type(fmr_b110_physical_forcing_t) :: forcing
    class(transaction_state_t), allocatable :: snapshot
    logical :: available, initialized, did_commit
    integer :: i, receipt_status, commit_status
    real(real64) :: t0,t1

    call authoritative%snapshot(snapshot,available)
    call require(available,'Q1 independent origin snapshot')
    call local%initialize(lineage,snapshot,initialized,t_start)
    call require(initialized,'Q1 independent local init')
    t0=t_start
    do i=1,size(dt)
      t1=t0+dt(i)
      call fmr_capture_checkpoint(local,cp,available)
      call require(available,'Q1 independent checkpoint')
      forcing=forcings(i)
      forcing%bottom_head=bottom_head
      call poison_legacy_bottom_context()
      call backend%run_trial(column,template,parameters,local,forcing,config,t0,t1,cp,result,candidate,diagnostics)
      call require(result%completed .and. candidate%ready() .and. result%bottom_interface_exchange_available, &
           'Q1 independent trial')
      q(i)=result%bottom_outward_exchange_native
      terminal(i)=result%terminal_bottom_outward_flux_native
      call fmr_commit_candidate_with_receipt(commit_kernel,cp,local,candidate,diagnostics,did_commit,receipt, &
           receipt_status,commit_status)
      call require(did_commit .and. receipt_status==FMR_COMMIT_RECEIPT_OK,'Q1 independent commit')
      t0=t1
    end do
    call local%snapshot(endpoint,available)
    call require(available,'Q1 independent endpoint')
  end subroutine independent_sequential_response

  subroutine direct_trial_snapshot(authoritative, forcing_in, t0, t1, bottom_head, result, endpoint)
    type(kernel_committed_state_t), intent(in) :: authoritative
    type(fmr_b110_physical_forcing_t), intent(in) :: forcing_in
    real(real64), intent(in) :: t0,t1,bottom_head
    type(kernel_result_t), intent(out) :: result
    class(transaction_state_t), allocatable, intent(out) :: endpoint
    type(kernel_checkpoint_t) :: cp
    type(kernel_candidate_state_t) :: candidate
    type(kernel_diagnostics_t) :: diagnostics, discard_diag
    type(kernel_executor_t) :: discard_kernel
    type(fmr_b110_physical_forcing_t) :: forcing
    logical :: available

    call fmr_capture_checkpoint(authoritative,cp,available)
    call require(available,'direct checkpoint')
    forcing=forcing_in
    forcing%bottom_head=bottom_head
    call poison_legacy_bottom_context()
    call backend%run_trial(column,template,parameters,authoritative,forcing,config,t0,t1,cp,result,candidate,diagnostics)
    call require(result%completed .and. candidate%ready(),'direct trial')
    call candidate%snapshot(endpoint,available)
    call require(available,'direct candidate snapshot')
    discard_diag=diagnostics
    call fmr_discard_candidate(discard_kernel,candidate,discard_diag)
    call require(.not.candidate%ready(),'direct discard')
  end subroutine direct_trial_snapshot

  subroutine commit_one(target, forcing_in, t0, t1, bottom_head)
    type(kernel_committed_state_t), intent(inout) :: target
    type(fmr_b110_physical_forcing_t), intent(in) :: forcing_in
    real(real64), intent(in) :: t0,t1,bottom_head
    type(kernel_checkpoint_t) :: cp
    type(kernel_result_t) :: result
    type(kernel_candidate_state_t) :: candidate
    type(kernel_diagnostics_t) :: diagnostics
    type(kernel_executor_t) :: commit_kernel
    type(fmr_accepted_commit_receipt_t) :: receipt
    type(fmr_b110_physical_forcing_t) :: forcing
    logical :: available,did_commit
    integer :: receipt_status,commit_status

    call fmr_capture_checkpoint(target,cp,available)
    call require(available,'seed checkpoint')
    forcing=forcing_in
    forcing%bottom_head=bottom_head
    call poison_legacy_bottom_context()
    call backend%run_trial(column,template,parameters,target,forcing,config,t0,t1,cp,result,candidate,diagnostics)
    call require(result%completed .and. candidate%ready(),'seed trial')
    call fmr_commit_candidate_with_receipt(commit_kernel,cp,target,candidate,diagnostics,did_commit,receipt,receipt_status,commit_status)
    call require(did_commit .and. receipt_status==FMR_COMMIT_RECEIPT_OK,'seed commit')
  end subroutine commit_one

  subroutine clone_origin(source,lineage,target)
    type(kernel_committed_state_t), intent(in) :: source
    integer(int64), intent(in) :: lineage
    type(kernel_committed_state_t), intent(out) :: target
    class(transaction_state_t), allocatable :: snapshot
    real(real64) :: t
    logical :: available,initialized
    call source%snapshot(snapshot,available)
    call require(available,'clone source snapshot')
    call source%current_time(t,available)
    call require(available,'clone source time')
    call target%initialize(lineage,snapshot,initialized,t)
    call require(initialized,'clone target init')
  end subroutine clone_origin

  subroutine build_forcings(factors,k0,forcings)
    real(real64), intent(in) :: factors(:), k0
    type(fmr_b110_physical_forcing_t), allocatable, intent(out) :: forcings(:)
    integer :: i
    allocate(forcings(size(factors)))
    do i=1,size(factors)
      forcings(i)=base_forcing
      forcings(i)%top_flux=factors(i)*k0
    end do
  end subroutine build_forcings

  logical function states_same(a,b) result(equal)
    class(transaction_state_t), allocatable, intent(in) :: a,b
    real(real64), allocatable :: da(:),db(:)
    logical :: aa,ab
    equal=.false.
    if(.not.allocated(a) .or. .not.allocated(b)) return
    select type(sa=>a)
    type is(fmr_b110_temporal_indicator_state_t)
      select type(sb=>b)
      type is(fmr_b110_temporal_indicator_state_t)
        if(sa%active_nodes/=sb%active_nodes) return
        if(.not.real_arrays_same(sa%pressure_head,sb%pressure_head)) return
        if(.not.real_arrays_same(sa%water_content,sb%water_content)) return
        if(.not.same_bits(sa%ponding_depth,sb%ponding_depth)) return
        if(.not.same_bits(sa%groundwater_level,sb%groundwater_level)) return
        call sa%temporal_history_snapshot(da,aa)
        call sb%temporal_history_snapshot(db,ab)
        if(aa .neqv. ab) return
        if(aa) then
          if(.not.real_arrays_same(da,db)) return
        end if
        equal=.true.
      class default
        return
      end select
    type is(fmr_b110_physical_state_t)
      select type(sb=>b)
      type is(fmr_b110_physical_state_t)
        if(sa%active_nodes/=sb%active_nodes) return
        if(.not.real_arrays_same(sa%pressure_head,sb%pressure_head)) return
        if(.not.real_arrays_same(sa%water_content,sb%water_content)) return
        if(.not.same_bits(sa%ponding_depth,sb%ponding_depth)) return
        if(.not.same_bits(sa%groundwater_level,sb%groundwater_level)) return
        equal=.true.
      class default
        return
      end select
    class default
      return
    end select
  end function states_same

  logical function real_arrays_same(a,b) result(equal)
    real(real64), intent(in) :: a(:),b(:)
    integer :: i
    equal=.false.
    if(size(a)/=size(b)) return
    do i=1,size(a)
      if(.not.same_bits(a(i),b(i))) return
    end do
    equal=.true.
  end function real_arrays_same

  subroutine configure_column(c,tpl)
    type(fmr_logical_column_t),intent(out)::c
    type(fmr_template_t),intent(out)::tpl
    tpl%template_id=9101_int64
    tpl%physics_topology_id=910101_int64
    tpl%vertical_layout_id=910102_int64
    tpl%state_layout_id=910103_int64
    tpl%solver_interface_id=910104_int64
    tpl%optional_state_layout_id=0_int64
    tpl%numerical_continuation_layout_id=FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY
    tpl%compatible_backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
    c%column_id=origin_lineage
    c%template_id=tpl%template_id
    c%parameter_ref=1_int64
    c%state_handle=1_int64
    c%forcing_handle=1_int64
    c%backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
  end subroutine configure_column

  subroutine configure_transaction(cfg)
    type(canonical_numerical_config_t),intent(out)::cfg
    cfg%transaction%temporal_mode=TX_TEMPORAL_MODEL_CERTIFICATE
    cfg%transaction%temporal_tolerance=0.0_real64
    cfg%transaction%mass_tolerance=hard_mass_gate
    cfg%transaction%retry_scale=0.5_real64
    cfg%transaction%max_retries=4
    cfg%max_committed_substeps=64
    cfg%progress_tolerance=0.0_real64
    cfg%model_temporal_indicator_budget_available=.true.
    cfg%model_temporal_indicator_budget=qualification_head_budget
  end subroutine configure_transaction

  subroutine configure_case(p,state,forcing,head,dt,kref)
    type(fmr_b110_physical_parameters_t),intent(out)::p
    type(fmr_b110_physical_state_t),intent(out)::state
    type(fmr_b110_physical_forcing_t),intent(out)::forcing
    real(real64),intent(in)::head,dt
    real(real64),intent(out)::kref
    real(real64)::heads(numnod),conductivity(numnod)
    integer::k
    call configure_base_parameters(p)
    heads=head
    call evaluate_state(p,heads,state,conductivity,dt)
    kref=conductivity(1)
    do k=2,numnod
      call require(same_bits(conductivity(k),kref),'uniform conductivity fixture')
    end do
    forcing%top_flux=-kref
    forcing%top_head=head
    forcing%bottom_flux=12345.0_real64
    forcing%bottom_head=head
    call allocate_zero_forcing(forcing)
  end subroutine configure_case

  subroutine configure_base_parameters(p)
    type(fmr_b110_physical_parameters_t),intent(out)::p
    integer::k
    p%parameter_set_id=910101_int64
    p%active_nodes=numnod
    allocate(p%z(numnod),p%dz(numnod),p%node_distance(numnod),p%cofgen(24,numnod))
    p%z=z; p%dz=dz; p%node_distance=disnod(1:numnod); p%cofgen=0.0_real64
    do k=1,numnod
      p%cofgen(1,k)=0.032_real64; p%cofgen(2,k)=0.423_real64; p%cofgen(3,k)=4.75_real64
      p%cofgen(4,k)=0.0135_real64; p%cofgen(5,k)=0.365_real64; p%cofgen(6,k)=1.455_real64
      p%cofgen(7,k)=1.0_real64-1.0_real64/p%cofgen(6,k); p%cofgen(8,k)=p%cofgen(4,k)
      p%cofgen(9,k)=0.0_real64; p%cofgen(10,k)=p%cofgen(3,k); p%cofgen(11,k)=0.999_real64
      p%cofgen(12,k)=0.99_real64*p%cofgen(3,k); p%cofgen(22,k)=-1.0e6_real64; p%cofgen(23,k)=1.0e-12_real64
    end do
    p%bottom_mode=5; p%swkimpl=0; p%swkmean=1; p%swsophy=0
    p%root_extraction_active=.false.; p%macropore_active=.false.; p%snow_active=.false.
    p%hysteresis_active=.false.; p%tabulated_hydraulics_active=.false.; p%elasticity_active=.false.
    p%frost_active=.false.; p%soil_temperature_active=.false.; p%drainage_response_active=.false.
    p%max_iterations=12; p%max_backtracking=8; p%min_step_duration=1.0e-7_real64
    p%compartment_balance_tolerance=hard_mass_gate; p%total_balance_tolerance=hard_mass_gate
    p%head_abs_tolerance=1.0e-10_real64; p%head_rel_tolerance=1.0e-10_real64; p%ponding_tolerance=1.0e-10_real64
  end subroutine configure_base_parameters

  subroutine evaluate_state(p,heads,state,conductivity,dt)
    type(fmr_b110_physical_parameters_t),intent(in)::p
    real(real64),intent(in)::heads(:),dt
    type(fmr_b110_physical_state_t),intent(out)::state
    real(real64),intent(out)::conductivity(:)
    type(b110_default_mvg_parameters_t),target::hydraulic_parameters
    type(b110_default_mvg_provider_t)::constitutive
    real(real64)::water(numnod),capacity(numnod),dkdh(numnod)
    call initialize_b110_default_mvg_parameters(hydraulic_parameters,p%cofgen)
    call bind_b110_default_mvg_provider(constitutive,hydraulic_parameters,dt)
    call constitutive%evaluate(heads,water,conductivity,capacity,dkdh)
    state%active_nodes=numnod
    allocate(state%pressure_head(numnod),state%water_content(numnod))
    state%pressure_head=heads; state%water_content=water
    state%ponding_depth=0.0_real64; state%groundwater_level=-2.0_real64
  end subroutine evaluate_state

  subroutine allocate_zero_forcing(f)
    type(fmr_b110_physical_forcing_t),intent(inout)::f
    allocate(f%drainage_flux_by_level(1,numnod),f%subsurface_irrigation_source(numnod),f%root_extraction_sink(numnod))
    f%drainage_flux_by_level=0.0_real64; f%subsurface_irrigation_source=0.0_real64; f%root_extraction_sink=0.0_real64
  end subroutine allocate_zero_forcing

  subroutine poison_legacy_bottom_context()
    swmacro=0; legacy_melt=0.0_real64; legacy_qdra=24680.0_real64; legacy_qssdi=-13579.0_real64
    legacy_qrot=0.0_real64; legacy_swbotb=3; legacy_hbot=99999.0_real64; legacy_qbot=-99999.0_real64
  end subroutine poison_legacy_bottom_context

  pure logical function same_bits(a,b) result(equal)
    real(real64),intent(in)::a,b
    equal=transfer(a,0_int64)==transfer(b,0_int64)
  end function same_bits

  subroutine require(condition,label)
    logical,intent(in)::condition
    character(len=*),intent(in)::label
    if(.not.condition) then
      write(*,'(a)') 'PUB_GC_MACRO_QUAL_FAIL='//trim(label)
      error stop 7
    end if
  end subroutine require

end program test_pub_gc_macro_window_response
