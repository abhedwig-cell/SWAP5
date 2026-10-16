  ! Explicitly different research profile: retain the reported GWL carrier
  ! during a head-driven window. This is not an F-GC31 projection repair.
  subroutine check_fixed_gwl_head_drainage()
    use mod_fmr_serialized_reference_backend, only: fmr_serialized_physical_observation_t
    type(fmr_b110_physical_parameters_t) :: p
    type(fmr_b110_physical_forcing_t) :: base
    type(fmr_groundwater_head_forcing_materializer_t) :: materializer
    class(canonical_forcing_t), allocatable :: forcing
    type(kernel_committed_state_t) :: origin
    type(kernel_checkpoint_t) :: checkpoint
    type(kernel_result_t) :: result
    type(kernel_candidate_state_t) :: candidate
    type(kernel_diagnostics_t) :: diag
    type(canonical_numerical_config_t) :: config
    type(fmr_serialized_reference_backend_t) :: backend
    type(fmr_serialized_physical_observation_t) :: observation
    type(fmr_b110_physical_state_t) :: physical
    class(transaction_state_t), allocatable :: before, after, candidate_snapshot
    real(real64) :: heads(numnod), water(numnod), conductivity(numnod), capacity(numnod), dkdh(numnod)
    real(real64) :: levels(2), offsets(3), expected_rate(2), drainage(3,2), bottom(3,2)
    real(real64) :: previous_right(numnod), t_before, t_after, h, q_slope
    integer(int64) :: revision
    integer :: i, j, forcing_status
    logical :: ok
    levels=[-0.3_real64,-1.5_real64]
    offsets=[-1.0e-5_real64,0.0_real64,1.0e-5_real64]
    ! Original two tabulated laws: clamped shallow rate and interior rate.
    expected_rate=[6.0e-3_real64,3.0e-3_real64]
    p=parameters; p%bottom_mode=5; p%drainage_qbot_smooth_freatic_projection=.false.
    call initialize_forcing(base,qbot0)
    call materializer%initialize(base)
    call initialize_config(config,.false.)
    do j=1,2
      heads=[-2.2_real64,-1.2_real64,-0.2_real64,0.8_real64]
      call constitutive%evaluate(heads,water,conductivity,capacity,dkdh)
      physical%active_nodes=numnod
      if(allocated(physical%pressure_head))deallocate(physical%pressure_head,physical%water_content)
      allocate(physical%pressure_head(numnod),physical%water_content(numnod))
      physical%pressure_head=heads; physical%water_content=water
      physical%ponding_depth=0.0_real64; physical%groundwater_level=levels(j)
      previous_right=0.0_real64
      call fmr_new_b110_temporal_indicator_committed_state(origin,column_id,physical,0.0_real64,ok,previous_right)
      call require(ok,'fixed GWL origin initialized')
      call fmr_capture_checkpoint(origin,checkpoint,ok)
      call require(ok,'fixed GWL checkpoint captured')
      revision=origin%current_revision()
      call origin%current_time(t_before,ok)
      call require(ok,'fixed GWL origin time bound')
      call origin%snapshot(before,ok)
      call require(ok,'fixed GWL origin snapshot')
      do i=1,3
        h=endpoint%bottom_face%hydraulic_head_m+offsets(i)
        call materializer%materialize(h,datum,forcing,forcing_status)
        call require(forcing_status==GW_SWAP_FORCING_OK,'fixed GWL head forcing')
        call backend%initialize(top)
        select type(f=>forcing)
        type is(fmr_b110_physical_forcing_t)
          call backend%run_trial(column,template,p,origin,f,config,0.0_real64,duration, &
               checkpoint,result,candidate,diag)
        class default
          call require(.false.,'fixed GWL forcing type')
        end select
        call require(result%completed .and. result%status==CANONICAL_STATUS_COMPLETED,'fixed GWL physical completion')
        call require(candidate%ready(),'fixed GWL physical candidate ready')
        call require(result%mass%complete .and. result%mass%missing_contribution_mask==0_int64, &
             'fixed GWL complete component mass')
        call require(abs(result%mass%residual)<=mass_tolerance,'fixed GWL hard mass closure')
        observation=backend%observation()
        call require(observation%drainage_response_active,'fixed GWL physical drainage observed')
        call require(observation%drainage_response_window_exchange_available,'fixed GWL accepted window drainage')
        drainage(i,j)=observation%drainage_response_window_signed_exchange_native
        call require(abs(drainage(i,j)-duration*expected_rate(j))<=1.0e-14_real64, &
             'fixed GWL original laws integrated exactly once')
        call require(result%bottom_interface_exchange_available,'fixed GWL separate bottom exchange')
        bottom(i,j)=result%bottom_outward_exchange_native
        call candidate%snapshot(candidate_snapshot,ok)
        call require(ok,'fixed GWL candidate snapshot')
        select type(s=>candidate_snapshot)
        class is(fmr_b110_physical_state_t)
          call require(bit_identical_scalar(s%groundwater_level,levels(j)),'fixed GWL carrier retained')
        class default
          call require(.false.,'fixed GWL candidate type')
        end select
        call require(origin%current_revision()==revision,'fixed GWL trial did not commit')
        call origin%current_time(t_after,ok)
        call require(ok .and. bit_identical_scalar(t_before,t_after),'fixed GWL origin time retained')
        call origin%snapshot(after,ok)
        call require(ok,'fixed GWL after snapshot')
        select type(b=>before)
        class is(fmr_b110_physical_state_t)
          select type(a=>after)
          class is(fmr_b110_physical_state_t)
            call require(bit_identical_vector(b%pressure_head,a%pressure_head),'fixed GWL origin pressure preserved')
            call require(bit_identical_vector(b%water_content,a%water_content),'fixed GWL origin water preserved')
            call require(bit_identical_scalar(b%groundwater_level,a%groundwater_level),'fixed GWL origin carrier preserved')
          class default
            call require(.false.,'fixed GWL after type')
          end select
        class default
          call require(.false.,'fixed GWL before type')
        end select
        write(*,'(A,2I3,6(1X,ES23.15))') 'FGC_FIXED_GWL_CASE=',j,i,h,levels(j),drainage(i,j), &
             bottom(i,j),result%mass%storage_change,result%mass%residual
      end do
      call require(bit_identical_scalar(drainage(1,j),drainage(3,j)),'fixed GWL drainage has no head response')
      q_slope=(bottom(3,j)-bottom(1,j))/(2.0_real64*offsets(3)*duration)
      call require(ieee_is_finite(q_slope) .and. abs(q_slope)>1.0e-12_real64,'bottom head response remains nonzero')
      write(*,'(A,I2,1X,ES23.15)') 'FGC_FIXED_GWL_BOTTOM_NATIVE_SLOPE_PER_METRE=',j,q_slope
    end do
    call require(abs(drainage(2,1)-drainage(2,2))>1.0e-6_real64,'changing GWL carrier changes drainage')
    write(*,'(A)') 'FGC_FIXED_GWL_HEAD_SIX_PHYSICAL_TRIALS=PASS'
    write(*,'(A)') 'FGC_FIXED_GWL_HEAD_COMPONENT_MASS=PASS'
    write(*,'(A)') 'FGC_FIXED_GWL_HEAD_DRAINAGE_RESPONSE_SEPARATION=PASS'
    write(*,'(A)') 'FGC_FIXED_GWL_HEAD_ORIGIN_IMMUTABILITY=PASS'
  end subroutine check_fixed_gwl_head_drainage
