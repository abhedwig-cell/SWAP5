program test_f_rom0ta5_prescribed_head_sample
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use MOD_grid, only: numnod, z, dz, disnod
  use mod_kernel_transactions, only: kernel_committed_state_t, kernel_reference_floor_result_t, &
       kernel_reference_floor_candidate_t, kernel_diagnostics_t, KERNEL_REFERENCE_FLOOR_STATUS_OK, &
       KERNEL_COMMIT_STATUS_COMMITTED
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, FMR_BACKEND_SERIALIZED_REFERENCE, &
       FMR_NUMERICAL_CONTINUATION_NONE, FMR_OPTIONAL_STATE_LAYOUT_BASE
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_parameters_t, fmr_b110_physical_forcing_t, &
       fmr_b110_physical_state_t, fmr_serialized_reference_backend_t, fmr_serialized_physical_observation_t, &
       fmr_new_b110_committed_state
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
  use mod_soil_water_solver_contract, only: SW_SOLVE_CONVERGED
  implicit none

  real(real64), parameter :: se0=0.85_real64
  real(real64), parameter :: dt=0.0008_real64
  real(real64), parameter :: hard_mass_gate=1.0e-12_real64
  integer(int64), parameter :: column_id=950501_int64
  character(len=8), parameter :: materials(2)=[character(len=8) :: 'B01','B14']
  integer :: imat

  call require(numnod==16,'TA5 geometry frozen at 16 nodes')
  do imat=1,size(materials)
    call qualify_material(trim(materials(imat)))
  end do
  write(*,'(A)') 'F_ROM0TA5_PRESCRIBED_HEAD_SAMPLE_GATE=PASS'

contains

  subroutine qualify_material(material_id)
    character(len=*),intent(in) :: material_id
    type(fmr_b110_physical_parameters_t) :: parameters
    type(fmr_b110_physical_forcing_t) :: forcing
    type(fmr_b110_physical_state_t) :: initial_state
    type(fmr_logical_column_t) :: column
    type(fmr_template_t) :: template
    real(real64) :: h0,k0,qeq

    call initialize_parameters(material_id,parameters)
    call initialize_state(parameters,h0,k0,initial_state)
    qeq=-k0
    call initialize_identity(column,template)

    parameters%bottom_mode=2
    call initialize_forcing(forcing,qeq,qeq,h0)
    call execute_one(material_id,'MODE2',parameters,forcing,initial_state,column,template)

    parameters%bottom_mode=5
    call initialize_forcing(forcing,qeq,qeq,h0)
    call execute_one(material_id,'MODE5',parameters,forcing,initial_state,column,template)
  end subroutine qualify_material

  subroutine execute_one(material_id,label,parameters,forcing,initial_state,column,template)
    character(len=*),intent(in) :: material_id,label
    type(fmr_b110_physical_parameters_t),intent(in) :: parameters
    type(fmr_b110_physical_forcing_t),intent(in) :: forcing
    type(fmr_b110_physical_state_t),intent(in) :: initial_state
    type(fmr_logical_column_t),intent(in) :: column
    type(fmr_template_t),intent(in) :: template

    type(fmr_serialized_reference_backend_t) :: backend
    type(fixed_flux_top_boundary_provider_t),target :: top_boundary
    type(kernel_committed_state_t) :: committed
    type(kernel_reference_floor_result_t) :: result
    type(kernel_reference_floor_candidate_t) :: candidate
    type(kernel_diagnostics_t) :: diagnostics
    type(fmr_serialized_physical_observation_t) :: observation
    logical :: ok,did_commit
    integer :: commit_status
    real(real64) :: t

    call fmr_new_b110_committed_state(committed,column_id,initial_state,0.0_real64,ok)
    call require(ok.and.committed%ready(),trim(label)//' committed seed')
    call backend%initialize(top_boundary)
    call backend%run_reference_floor_sample(column,template,parameters,committed,forcing,0.0_real64,dt,hard_mass_gate, &
         result,candidate,diagnostics)
    observation=backend%observation()

    call require(result%status==KERNEL_REFERENCE_FLOOR_STATUS_OK.and.result%sample_valid,trim(label)//' sample valid')
    call require(candidate%ready(),trim(label)//' candidate ready')
    call require(result%physical_advances==1,trim(label)//' one physical advance')
    call require(result%internal_retries==0,trim(label)//' zero solver internal retries')
    call require(diagnostics%retries==0,trim(label)//' zero transaction retries')
    call require(result%mass%complete.and.abs(result%mass%residual)<=hard_mass_gate,trim(label)//' hard mass gate')
    call require(observation%solver_executed.and.observation%solver_status==SW_SOLVE_CONVERGED,trim(label)//' solver converged')
    call require(trim(observation%solver_diagnostics%route)=='legacy-reference-bound',trim(label)//' Reference route')
    call require(result%bottom_interface_exchange_available,trim(label)//' bottom exchange available')
    call require(ieee_is_finite(result%bottom_outward_exchange_native).and. &
         ieee_is_finite(result%terminal_bottom_outward_flux_native),trim(label)//' bottom exchange finite')
    call require(same_bits(result%accepted_dt,dt),trim(label)//' fixed dt identity')

    call backend%commit_reference_floor_candidate(committed,candidate,diagnostics,did_commit,commit_status)
    call require(did_commit.and.commit_status==KERNEL_COMMIT_STATUS_COMMITTED,trim(label)//' candidate committed')
    call require(committed%current_revision()==1_int64,trim(label)//' exactly one revision')
    call committed%current_time(t,ok)
    call require(ok.and.same_bits(t,dt),trim(label)//' committed time identity')
    call require(.not.candidate%ready(),trim(label)//' candidate consumed')

    write(*,'(*(g0))') 'F_ROM0TA5_ROW|MATERIAL=',trim(material_id),'|MODE=',trim(label), &
         '|STATUS=PASS|MASS=',result%mass%residual,'|BOTTOM_EXCHANGE=',result%bottom_outward_exchange_native, &
         '|BOTTOM_FLUX=',result%terminal_bottom_outward_flux_native,'|NL=',result%nonlinear_iterations
  end subroutine execute_one

  subroutine initialize_parameters(material_id,p)
    character(len=*),intent(in) :: material_id
    type(fmr_b110_physical_parameters_t),intent(out) :: p
    real(real64) :: tr,ts,alpha,nn,ks,lam,mm
    integer :: k
    select case(trim(material_id))
    case('B01')
      tr=0.02_real64;ts=0.427494_real64;alpha=0.021659_real64
      nn=1.734737_real64;ks=31.225016_real64;lam=0.98087_real64
    case('B14')
      tr=0.01_real64;ts=0.416774_real64;alpha=0.00541_real64
      nn=1.301528_real64;ks=0.895023_real64;lam=-0.334926_real64
    case default
      call require(.false.,'TA5 known material')
      tr=0.0_real64;ts=0.0_real64;alpha=0.0_real64;nn=2.0_real64;ks=0.0_real64;lam=0.0_real64
    end select
    mm=1.0_real64-1.0_real64/nn
    p%parameter_set_id=950501_int64
    p%active_nodes=numnod
    allocate(p%z(numnod),p%dz(numnod),p%node_distance(numnod),p%cofgen(24,numnod))
    p%z=z;p%dz=dz;p%node_distance=disnod(1:numnod);p%cofgen=0.0_real64
    do k=1,numnod
      p%cofgen(1,k)=tr;p%cofgen(2,k)=ts;p%cofgen(3,k)=ks;p%cofgen(4,k)=alpha
      p%cofgen(5,k)=lam;p%cofgen(6,k)=nn;p%cofgen(7,k)=mm;p%cofgen(8,k)=alpha
      p%cofgen(9,k)=0.0_real64;p%cofgen(10,k)=ks;p%cofgen(11,k)=0.999_real64
      p%cofgen(12,k)=0.99_real64*ks;p%cofgen(22,k)=-1.0e6_real64;p%cofgen(23,k)=1.0e-12_real64
    end do
    p%bottom_mode=2;p%swkimpl=0;p%swkmean=1;p%swsophy=0
    p%max_iterations=16;p%max_backtracking=8;p%min_step_duration=1.0e-8_real64
    p%compartment_balance_tolerance=hard_mass_gate;p%total_balance_tolerance=hard_mass_gate
    p%head_abs_tolerance=hard_mass_gate;p%head_rel_tolerance=hard_mass_gate;p%ponding_tolerance=hard_mass_gate
    p%root_extraction_active=.false.;p%macropore_active=.false.;p%snow_active=.false.
    p%hysteresis_active=.false.;p%tabulated_hydraulics_active=.false.;p%ksatexm_extension_active=.false.
    p%elasticity_active=.false.;p%frost_active=.false.;p%soil_temperature_active=.false.
    p%drainage_response_active=.false.;p%drainage_qbot_smooth_freatic_projection=.false.
  end subroutine initialize_parameters

  subroutine initialize_state(p,h0,k0,state)
    type(fmr_b110_physical_parameters_t),intent(in) :: p
    real(real64),intent(out) :: h0,k0
    type(fmr_b110_physical_state_t),intent(out) :: state
    type(b110_default_mvg_parameters_t),target :: hp
    type(b110_default_mvg_provider_t) :: provider
    real(real64) :: m,heads(numnod),water(numnod),conductivity(numnod),capacity(numnod),dkdh(numnod)
    m=1.0_real64-1.0_real64/p%cofgen(6,1)
    h0=-(se0**(-1.0_real64/m)-1.0_real64)**(1.0_real64/p%cofgen(6,1))/p%cofgen(4,1)
    heads=h0
    call initialize_b110_default_mvg_parameters(hp,p%cofgen)
    call bind_b110_default_mvg_provider(provider,hp,dt)
    call provider%evaluate(heads,water,conductivity,capacity,dkdh)
    k0=conductivity(1)
    call require(k0>0.0_real64.and.all(ieee_is_finite(water)),'TA5 finite seed')
    state%active_nodes=numnod
    allocate(state%pressure_head(numnod),state%water_content(numnod))
    state%pressure_head=heads;state%water_content=water
    state%ponding_depth=0.0_real64;state%groundwater_level=-999.0_real64
  end subroutine initialize_state

  subroutine initialize_forcing(f,qt,qb,hb)
    type(fmr_b110_physical_forcing_t),intent(out) :: f
    real(real64),intent(in) :: qt,qb,hb
    f%top_flux=qt;f%top_head=0.0_real64;f%bottom_flux=qb;f%bottom_head=hb
    allocate(f%drainage_flux_by_level(1,numnod),f%subsurface_irrigation_source(numnod),f%root_extraction_sink(numnod))
    f%drainage_flux_by_level=0.0_real64
    f%subsurface_irrigation_source=0.0_real64
    f%root_extraction_sink=0.0_real64
  end subroutine initialize_forcing

  subroutine initialize_identity(col,tmpl)
    type(fmr_logical_column_t),intent(out) :: col
    type(fmr_template_t),intent(out) :: tmpl
    tmpl%template_id=950501_int64;tmpl%physics_topology_id=950502_int64
    tmpl%vertical_layout_id=950503_int64;tmpl%state_layout_id=950504_int64
    tmpl%solver_interface_id=950505_int64
    tmpl%optional_state_layout_id=FMR_OPTIONAL_STATE_LAYOUT_BASE
    tmpl%numerical_continuation_layout_id=FMR_NUMERICAL_CONTINUATION_NONE
    tmpl%compatible_backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
    col%column_id=column_id;col%template_id=tmpl%template_id;col%parameter_ref=1_int64
    col%state_handle=1_int64;col%forcing_handle=1_int64;col%backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
  end subroutine initialize_identity

  pure logical function same_bits(a,b)
    real(real64),intent(in) :: a,b
    integer(int64) :: ia,ib
    ia=transfer(a,ia);ib=transfer(b,ib)
    same_bits=ia==ib
  end function same_bits

  subroutine require(condition,label)
    logical,intent(in) :: condition
    character(len=*),intent(in) :: label
    if(.not.condition) then
      write(*,'(A,1X,A)') 'F_ROM0TA5_FAIL',trim(label)
      error stop 1
    end if
  end subroutine require
end program test_f_rom0ta5_prescribed_head_sample
