program test_fmr34_parallel_root_extraction
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use, intrinsic :: ieee_arithmetic, only: ieee_value, ieee_quiet_nan
  use MOD_grid, only: numnod, z, dz, disnod
  use mod_transaction_reference, only: transaction_state_t, TX_MASS_MISSING_NONE
  use mod_canonical_contracts, only: canonical_numerical_config_t, canonical_mass_accounting_t
  use mod_kernel_transactions, only: kernel_committed_state_t
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, fmr_column_diagnostics_t, &
       fmr_aggregate_diagnostics_t, FMR_BACKEND_SERIALIZED_REFERENCE, FMR_NUMERICAL_CONTINUATION_NONE
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_state_t, fmr_b110_physical_parameters_t, &
       fmr_b110_physical_forcing_t, fmr_new_b110_committed_state
  use mod_fmr_serialized_multiswap_runtime, only: fmr_serialized_column_result_t, fmr_serialized_batch_diagnostics_t, &
       fmr_run_serialized_physical_multiswap, FMR_SERIAL_DISPATCH_OK
  use mod_fmr_parallel_worker_pool, only: fmr_run_parallel_physical_multiswap, FMR_PARALLEL_POOL_OK, &
       FMR_PARALLEL_POOL_MULTIWORKER_NOT_ADMITTED
  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  implicit none

  real(real64), parameter :: t0 = 5300.1875_real64
  real(real64), parameter :: t1 = 5300.6875_real64
  real(real64), parameter :: head0 = -75.0_real64
  real(real64), parameter :: hard_mass_gate = 1.0e-12_real64
  integer, parameter :: ncases = 4
  integer, parameter :: counts(ncases) = [2,7,17,32]
  integer, parameter :: batches(ncases) = [1,3,5,9]
  integer :: k

  do k = 1, ncases
    call run_identity_case(counts(k), batches(k), mod(k-1,3), .true.)
    write(*,'(A,I0,A)') 'FMR34_ALL_ACTIVE_N',counts(k),'=PASS'
    call run_identity_case(counts(k), batches(k), mod(k,3), .false.)
    write(*,'(A,I0,A)') 'FMR34_MIXED_ACTIVE_N',counts(k),'=PASS'
  end do

  call run_negative_matrix()
  write(*,'(A)') 'FMR34_ROOT_QROT_FAIL_CLOSED_MATRIX=PASS'
  call run_rejection_isolation()
  write(*,'(A)') 'FMR34_PROBLEM_COLUMN_ISOLATION=PASS'
  call run_overlap_control()
  write(*,'(A)') 'FMR34_TRUE_MULTIWORKER_ROOT_OVERLAP=PASS'
  write(*,'(A)') 'FMR34_HARD_MASS_CONSERVATION=PASS'
  write(*,'(A)') 'FMR34_SERIAL_2_4_ROOT_SCIENTIFIC_IDENTITY=PASS'
  write(*,'(A)') 'FMR34_CANONICAL_PUBLICATION=PASS'
  write(*,'(A)') 'FMR34_OWNER_REAL_PHYSICS_ROOT_SENTINEL PASS'

contains

  subroutine run_identity_case(n, batch_size, order_code, all_active)
    integer, intent(in) :: n, batch_size, order_code
    logical, intent(in) :: all_active
    type(fmr_logical_column_t), allocatable :: base(:), columns(:)
    type(fmr_template_t) :: templates(1)
    type(fmr_b110_physical_parameters_t) :: parameters(2), before(2)
    type(fmr_b110_physical_forcing_t), allocatable :: forcings(:)
    type(fmr_b110_physical_state_t) :: seed
    type(kernel_committed_state_t), allocatable :: ss(:), s2(:), s4(:)
    type(fmr_serialized_column_result_t), allocatable :: rs(:), r2(:), r4(:)
    type(fmr_column_diagnostics_t), allocatable :: ds(:), d2(:), d4(:)
    type(fmr_aggregate_diagnostics_t) :: as, a2, a4
    type(fmr_serialized_batch_diagnostics_t) :: rts, rt2, rt4
    type(fixed_flux_top_boundary_provider_t), target :: top
    type(canonical_numerical_config_t) :: config
    real(real64) :: k0
    integer :: status, pool

    call build_fixture(n, all_active, base, templates, parameters, forcings, seed, k0)
    before = parameters
    call permute_columns(base, order_code, columns)
    call configure_transaction(config)
    call initialize_states(ss, base, seed)
    call initialize_states(s2, base, seed)
    call initialize_states(s4, base, seed)

    call fmr_run_serialized_physical_multiswap(columns,templates,parameters,forcings,ss,config,top, &
         t0,t1,batch_size,rs,ds,as,status,rts)
    call require(status == FMR_SERIAL_DISPATCH_OK .and. all_committed(rs),'serialized root reference')

    call fmr_run_parallel_physical_multiswap(columns,templates,parameters,forcings,s2,config,top, &
         t0,t1,batch_size,2,r2,d2,a2,status,pool,rt2)
    call require(pool == FMR_PARALLEL_POOL_OK .and. status == FMR_SERIAL_DISPATCH_OK,'2-worker root status')
    call require(all_committed(r2),'2-worker all committed')

    call fmr_run_parallel_physical_multiswap(columns,templates,parameters,forcings,s4,config,top, &
         t0,t1,batch_size,4,r4,d4,a4,status,pool,rt4)
    call require(pool == FMR_PARALLEL_POOL_OK .and. status == FMR_SERIAL_DISPATCH_OK,'4-worker root status')
    call require(all_committed(r4),'4-worker all committed')

    call require(result_sets_equal(rs,r2) .and. result_sets_equal(rs,r4),'serial/2/4 scientific results')
    call require(diag_sets_equal(ds,d2) .and. diag_sets_equal(ds,d4),'serial/2/4 scientific diagnostics')
    call require(states_equal(ss,s2) .and. states_equal(ss,s4),'serial/2/4 committed states')
    call require(runtime_science_equal(rts,rt2) .and. runtime_science_equal(rts,rt4),'serial/2/4 runtime mass')
    call require(parameters_equal(parameters,before),'shared immutable parameters')
    call require(max_abs_residual(rs) <= hard_mass_gate .and. max_abs_residual(r2) <= hard_mass_gate .and. &
         max_abs_residual(r4) <= hard_mass_gate,'hard per-column mass residual')
    call require(rt2%authoritative_aggregate_mass%complete .and. rt4%authoritative_aggregate_mass%complete, &
         'parallel authoritative aggregate mass complete')
    call require(abs(rt2%authoritative_aggregate_mass%residual) <= real(n,real64)*hard_mass_gate .and. &
         abs(rt4%authoritative_aggregate_mass%residual) <= real(n,real64)*hard_mass_gate,'aggregate mass bounded')
    call validate_attribution(r2,base,parameters,forcings)
    call validate_attribution(r4,base,parameters,forcings)
    call require(canonical_publication(r2,d2) .and. canonical_publication(r4,d4),'canonical result publication')
  end subroutine run_identity_case

  subroutine run_negative_matrix()
    type(fmr_logical_column_t), allocatable :: columns(:)
    type(fmr_template_t) :: templates(1)
    type(fmr_b110_physical_parameters_t) :: parameters(2), bad_parameters(2)
    type(fmr_b110_physical_forcing_t), allocatable :: forcings(:), bad_forcings(:)
    type(fmr_b110_physical_state_t) :: seed
    type(kernel_committed_state_t), allocatable :: states(:), initial(:)
    type(fmr_serialized_column_result_t), allocatable :: results(:)
    type(fmr_column_diagnostics_t), allocatable :: diagnostics(:)
    type(fmr_aggregate_diagnostics_t) :: aggregate
    type(fmr_serialized_batch_diagnostics_t) :: runtime
    type(fixed_flux_top_boundary_provider_t), target :: top
    type(canonical_numerical_config_t) :: config
    real(real64) :: k0
    integer :: mode, workers, status, pool

    call build_fixture(7,.false.,columns,templates,parameters,forcings,seed,k0)
    call configure_transaction(config)
    do mode = 1,5
      do workers = 2,4,2
        bad_parameters = parameters
        bad_forcings = forcings
        select case(mode)
        case(1)
          bad_forcings(1)%root_extraction_sink(1) = -1.0e-6_real64
        case(2)
          bad_forcings(1)%root_extraction_sink(1) = ieee_value(0.0_real64,ieee_quiet_nan)
        case(3)
          ! Column 2 is root-inactive in the mixed profile.
          bad_forcings(2)%root_extraction_sink(1) = 1.0e-6_real64
        case(4)
          bad_parameters(1)%snow_active = .true.
        case(5)
          bad_parameters(1)%macropore_active = .true.
        end select
        call initialize_states(states,columns,seed)
        call initialize_states(initial,columns,seed)
        call fmr_run_parallel_physical_multiswap(columns,templates,bad_parameters,bad_forcings,states,config,top, &
             t0,t1,3,workers,results,diagnostics,aggregate,status,pool,runtime)
        call require(pool == FMR_PARALLEL_POOL_MULTIWORKER_NOT_ADMITTED,'negative profile rejected')
        call require(status == -1,'negative profile no serialized fallback')
        call require(runtime%physical_solve_count == 0 .and. runtime%number_committed == 0,'negative zero solves/commits')
        call require(no_solver_execution(results),'negative no solver execution')
        call require(states_equal(states,initial),'negative state nonmutation')
      end do
    end do
  end subroutine run_negative_matrix

  subroutine run_rejection_isolation()
    integer, parameter :: n = 17, rejected = 5
    type(fmr_logical_column_t), allocatable :: columns(:)
    type(fmr_template_t) :: templates(1)
    type(fmr_b110_physical_parameters_t) :: parameters(2)
    type(fmr_b110_physical_forcing_t), allocatable :: forcings(:), bad(:)
    type(fmr_b110_physical_state_t) :: seed
    type(kernel_committed_state_t), allocatable :: sref(:), sbad(:), initial(:)
    type(fmr_serialized_column_result_t), allocatable :: rref(:), rbad(:)
    type(fmr_column_diagnostics_t), allocatable :: dref(:), dbad(:)
    type(fmr_aggregate_diagnostics_t) :: aref, abad
    type(fmr_serialized_batch_diagnostics_t) :: rtref, rtbad
    type(fixed_flux_top_boundary_provider_t), target :: top
    type(canonical_numerical_config_t) :: config
    real(real64) :: k0
    integer :: status, pool, j, idx

    call build_fixture(n,.false.,columns,templates,parameters,forcings,seed,k0)
    bad = forcings
    bad(rejected)%top_flux = 0.95_real64*bad(rejected)%top_flux
    call configure_transaction(config)
    call initialize_states(sref,columns,seed)
    call initialize_states(sbad,columns,seed)
    call initialize_states(initial,columns,seed)
    call fmr_run_parallel_physical_multiswap(columns,templates,parameters,forcings,sref,config,top, &
         t0,t1,4,4,rref,dref,aref,status,pool,rtref)
    call require(pool == FMR_PARALLEL_POOL_OK .and. all_committed(rref),'isolation reference committed')
    call fmr_run_parallel_physical_multiswap(columns,templates,parameters,bad,sbad,config,top, &
         t0,t1,4,4,rbad,dbad,abad,status,pool,rtbad)
    call require(pool == FMR_PARALLEL_POOL_OK,'isolation perturbed pool')
    call require(rtbad%number_rejected == 1,'isolation exactly one rejected')
    do j=1,n
      idx = find_result(rbad,columns(j)%column_id)
      call require(idx > 0,'isolation result lookup')
      if (j == rejected) then
        call require(.not. rbad(idx)%committed,'isolation target rejected')
        call require(state_equal(sbad(j),initial(j)),'isolation target rollback')
      else
        call require(rbad(idx)%committed,'isolation unaffected committed')
        call require(result_equal(rbad(idx),rref(find_result(rref,columns(j)%column_id))),'isolation result unchanged')
        call require(state_equal(sbad(j),sref(j)),'isolation state unchanged')
      end if
    end do
  end subroutine run_rejection_isolation

  subroutine run_overlap_control()
    type(fmr_logical_column_t), allocatable :: columns(:)
    type(fmr_template_t) :: templates(1)
    type(fmr_b110_physical_parameters_t) :: parameters(2)
    type(fmr_b110_physical_forcing_t), allocatable :: forcings(:)
    type(fmr_b110_physical_state_t) :: seed
    type(kernel_committed_state_t), allocatable :: states(:)
    type(fmr_serialized_column_result_t), allocatable :: results(:)
    type(fmr_column_diagnostics_t), allocatable :: diagnostics(:)
    type(fmr_aggregate_diagnostics_t) :: aggregate
    type(fmr_serialized_batch_diagnostics_t) :: runtime
    type(fixed_flux_top_boundary_provider_t), target :: top
    type(canonical_numerical_config_t) :: config
    real(real64) :: k0
    integer :: workers, status, pool

    call build_fixture(32,.true.,columns,templates,parameters,forcings,seed,k0)
    call configure_transaction(config)
    do workers=2,4,2
      call initialize_states(states,columns,seed)
      call fmr_run_parallel_physical_multiswap(columns,templates,parameters,forcings,states,config,top, &
           t0,t1,9,workers,results,diagnostics,aggregate,status,pool,runtime)
      call require(pool == FMR_PARALLEL_POOL_OK .and. all_committed(results),'overlap committed')
      call require(runtime%max_simultaneous_real_physical_solves >= 2,'root overlap observed')
      call require(runtime%max_simultaneous_real_physical_solves <= workers,'root overlap worker bound')
    end do
  end subroutine run_overlap_control

  subroutine build_fixture(n,all_active,columns,templates,parameters,forcings,seed,k0)
    integer, intent(in) :: n
    logical, intent(in) :: all_active
    type(fmr_logical_column_t), allocatable, intent(out) :: columns(:)
    type(fmr_template_t), intent(out) :: templates(1)
    type(fmr_b110_physical_parameters_t), intent(out) :: parameters(2)
    type(fmr_b110_physical_forcing_t), allocatable, intent(out) :: forcings(:)
    type(fmr_b110_physical_state_t), intent(out) :: seed
    real(real64), intent(out) :: k0
    integer :: j

    allocate(columns(n),forcings(n))
    call configure_template(templates(1))
    call configure_parameters(parameters(1),seed,k0)
    parameters(2) = parameters(1)
    parameters(2)%parameter_set_id = 934002_int64
    parameters(2)%root_extraction_active = .false.
    do j=1,n
      columns(j)%column_id = 934000_int64 + int(37*j,int64)
      columns(j)%template_id = templates(1)%template_id
      columns(j)%parameter_ref = 1_int64
      if (.not. all_active .and. mod(j,2) == 0) columns(j)%parameter_ref = 2_int64
      columns(j)%state_handle = int(j,int64)
      columns(j)%forcing_handle = int(j,int64)
      columns(j)%backend_id = FMR_BACKEND_SERIALIZED_REFERENCE
      call configure_forcing(forcings(j),k0,1.0_real64+0.013_real64*real(j,real64), &
           columns(j)%parameter_ref == 1_int64)
    end do
  end subroutine build_fixture

  subroutine configure_template(template)
    type(fmr_template_t), intent(out) :: template
    template%template_id = 9340_int64
    template%physics_topology_id = 934001_int64
    template%vertical_layout_id = 934002_int64
    template%state_layout_id = 934003_int64
    template%solver_interface_id = 934004_int64
    template%optional_state_layout_id = 0_int64
    template%numerical_continuation_layout_id = FMR_NUMERICAL_CONTINUATION_NONE
    template%compatible_backend_id = FMR_BACKEND_SERIALIZED_REFERENCE
  end subroutine configure_template

  subroutine configure_parameters(value,state,k0)
    type(fmr_b110_physical_parameters_t), intent(out) :: value
    type(fmr_b110_physical_state_t), intent(out) :: state
    real(real64), intent(out) :: k0
    type(b110_default_mvg_parameters_t), target :: hyd
    type(b110_default_mvg_provider_t) :: constitutive
    real(real64) :: heads(numnod), water(numnod), conductivity(numnod), capacity(numnod), dkdh(numnod)
    integer :: j

    value%parameter_set_id = 934001_int64
    value%active_nodes = numnod
    allocate(value%z(numnod),value%dz(numnod),value%node_distance(numnod),value%cofgen(24,numnod))
    value%z=z; value%dz=dz; value%node_distance=disnod(1:numnod); value%cofgen=0.0_real64
    do j=1,numnod
      value%cofgen(1,j)=0.032_real64; value%cofgen(2,j)=0.423_real64; value%cofgen(3,j)=4.75_real64
      value%cofgen(4,j)=0.0135_real64; value%cofgen(5,j)=0.365_real64; value%cofgen(6,j)=1.455_real64
      value%cofgen(7,j)=1.0_real64-1.0_real64/value%cofgen(6,j); value%cofgen(8,j)=value%cofgen(4,j)
      value%cofgen(10,j)=value%cofgen(3,j); value%cofgen(11,j)=0.999_real64; value%cofgen(12,j)=0.99_real64*value%cofgen(3,j)
      value%cofgen(22,j)=-1.0e6_real64; value%cofgen(23,j)=1.0e-12_real64
    end do
    value%bottom_mode=7; value%swkimpl=0; value%swkmean=1; value%swsophy=0
    value%root_extraction_active=.true.; value%macropore_active=.false.; value%snow_active=.false.
    value%hysteresis_active=.false.; value%tabulated_hydraulics_active=.false.; value%elasticity_active=.false.; value%frost_active=.false.
    call initialize_b110_default_mvg_parameters(hyd,value%cofgen)
    call bind_b110_default_mvg_provider(constitutive,hyd,t1-t0)
    heads=head0
    call constitutive%evaluate(heads,water,conductivity,capacity,dkdh)
    k0=conductivity(1)
    state%active_nodes=numnod
    allocate(state%pressure_head(numnod),state%water_content(numnod))
    state%pressure_head=heads; state%water_content=water; state%ponding_depth=0.0_real64; state%groundwater_level=-2.0_real64
  end subroutine configure_parameters

  subroutine configure_forcing(forcing,k0,scale,root_active)
    type(fmr_b110_physical_forcing_t), intent(out) :: forcing
    real(real64), intent(in) :: k0, scale
    logical, intent(in) :: root_active
    integer :: j
    forcing%top_flux=-k0; forcing%top_head=head0; forcing%bottom_flux=-k0; forcing%bottom_head=-100.0_real64
    allocate(forcing%drainage_flux_by_level(2,numnod),forcing%subsurface_irrigation_source(numnod), &
         forcing%root_extraction_sink(numnod))
    do j=1,numnod
      forcing%drainage_flux_by_level(1,j)=scale*1.0e-5_real64*real(j,real64)
      forcing%drainage_flux_by_level(2,j)=-scale*2.0e-6_real64*real(j+1,real64)
      forcing%subsurface_irrigation_source(j)=forcing%drainage_flux_by_level(1,j)+forcing%drainage_flux_by_level(2,j)
      forcing%root_extraction_sink(j)=0.0_real64
      if (root_active) forcing%root_extraction_sink(j)=scale*2.0e-7_real64*real(j,real64)
    end do
  end subroutine configure_forcing

  subroutine configure_transaction(value)
    type(canonical_numerical_config_t), intent(out) :: value
    value%transaction%temporal_tolerance=0.0_real64
    value%transaction%mass_tolerance=hard_mass_gate
    value%transaction%retry_scale=0.5_real64
    value%transaction%max_retries=2
    value%max_committed_substeps=8
    value%progress_tolerance=0.0_real64
  end subroutine configure_transaction

  subroutine initialize_states(states,base,seed)
    type(kernel_committed_state_t), allocatable, intent(out) :: states(:)
    type(fmr_logical_column_t), intent(in) :: base(:)
    type(fmr_b110_physical_state_t), intent(in) :: seed
    type(fmr_b110_physical_state_t) :: state
    logical :: ok
    integer :: j
    allocate(states(size(base)))
    do j=1,size(base)
      state=seed
      state%groundwater_level=-2.0_real64-0.007_real64*real(j,real64)
      call fmr_new_b110_committed_state(states(j),base(j)%column_id,state,t0,ok)
      call require(ok,'committed state initialization')
    end do
  end subroutine initialize_states

  subroutine permute_columns(base,code,ordered)
    type(fmr_logical_column_t), intent(in) :: base(:)
    integer, intent(in) :: code
    type(fmr_logical_column_t), allocatable, intent(out) :: ordered(:)
    integer, allocatable :: p(:)
    integer :: n,j,k
    n=size(base); allocate(ordered(n),p(n))
    select case(code)
    case(0)
      p=[(j,j=1,n)]
    case(1)
      p=[(j,j=n,1,-1)]
    case default
      k=0
      do j=1,n,2; k=k+1; p(k)=j; end do
      do j=2,n,2; k=k+1; p(k)=j; end do
    end select
    ordered=base(p)
  end subroutine permute_columns

  subroutine validate_attribution(results,base,parameters,forcings)
    type(fmr_serialized_column_result_t), intent(in) :: results(:)
    type(fmr_logical_column_t), intent(in) :: base(:)
    type(fmr_b110_physical_parameters_t), intent(in) :: parameters(:)
    type(fmr_b110_physical_forcing_t), intent(in) :: forcings(:)
    integer :: j, idx, pidx, fidx
    real(real64) :: expected
    do j=1,size(base)
      idx=find_result(results,base(j)%column_id); pidx=int(base(j)%parameter_ref); fidx=int(base(j)%forcing_handle)
      call require(idx>0,'attribution result lookup')
      if (parameters(pidx)%root_extraction_active) then
        expected=sum(forcings(fidx)%root_extraction_sink)*(t1-t0)
        call require(results(idx)%actual_transpiration_available,'active attribution available')
        call require(same_bits(results(idx)%actual_transpiration_amount,expected),'exact runtime qrot attribution')
      else
        call require(.not. results(idx)%actual_transpiration_available,'inactive attribution unavailable')
        call require(same_bits(results(idx)%actual_transpiration_amount,0.0_real64),'inactive zero attribution')
      end if
    end do
  end subroutine validate_attribution

  logical function canonical_publication(results,diagnostics) result(ok)
    type(fmr_serialized_column_result_t), intent(in) :: results(:)
    type(fmr_column_diagnostics_t), intent(in) :: diagnostics(:)
    integer :: j
    ok=size(results)==size(diagnostics)
    if (.not.ok)return
    do j=1,size(results)
      if (results(j)%column_id /= diagnostics(j)%column_id) then; ok=.false.; return; end if
      if (j>1) then
        if (results(j)%column_id <= results(j-1)%column_id) then; ok=.false.; return; end if
      end if
    end do
  end function canonical_publication

  logical function all_committed(results) result(ok)
    type(fmr_serialized_column_result_t), intent(in) :: results(:)
    integer :: j
    ok=.true.
    do j=1,size(results)
      if(.not.results(j)%completed .or. .not.results(j)%committed .or. .not.results(j)%mass%complete)then; ok=.false.; return; end if
    end do
  end function all_committed

  logical function no_solver_execution(results) result(ok)
    type(fmr_serialized_column_result_t), intent(in) :: results(:)
    integer :: j
    ok=.true.
    do j=1,size(results)
      if(results(j)%solver_executed .or. results(j)%committed)then; ok=.false.; return; end if
    end do
  end function no_solver_execution

  real(real64) function max_abs_residual(results) result(value)
    type(fmr_serialized_column_result_t), intent(in) :: results(:)
    integer :: j
    value=0.0_real64
    do j=1,size(results); if(results(j)%committed)value=max(value,abs(results(j)%mass%residual)); end do
  end function max_abs_residual

  integer function find_result(values,column_id) result(index)
    type(fmr_serialized_column_result_t), intent(in) :: values(:)
    integer(int64), intent(in) :: column_id
    integer :: j
    index=0
    do j=1,size(values); if(values(j)%column_id==column_id)then; index=j; return; end if; end do
  end function find_result

  integer function find_diag(values,column_id) result(index)
    type(fmr_column_diagnostics_t), intent(in) :: values(:)
    integer(int64), intent(in) :: column_id
    integer :: j
    index=0
    do j=1,size(values); if(values(j)%column_id==column_id)then; index=j; return; end if; end do
  end function find_diag

  logical function result_sets_equal(left,right) result(equal)
    type(fmr_serialized_column_result_t), intent(in) :: left(:),right(:)
    integer :: i,j
    equal=size(left)==size(right); if(.not.equal)return
    do i=1,size(left)
      j=find_result(right,left(i)%column_id)
      if(j<=0 .or. .not.result_equal(left(i),right(j)))then; equal=.false.; return; end if
    end do
  end function result_sets_equal

  logical function result_equal(left,right) result(equal)
    type(fmr_serialized_column_result_t), intent(in) :: left,right
    equal=left%column_id==right%column_id .and. left%dispatch_ordinal==right%dispatch_ordinal .and. &
      same_bits(left%requested_t0,right%requested_t0) .and. same_bits(left%requested_t1,right%requested_t1) .and. &
      (left%admission_assessed.eqv.right%admission_assessed) .and. (left%admitted.eqv.right%admitted) .and. &
      trim(left%admission_status)==trim(right%admission_status) .and. left%kernel_status==right%kernel_status .and. &
      left%commit_status==right%commit_status .and. (left%completed.eqv.right%completed) .and. &
      (left%committed.eqv.right%committed) .and. (left%solver_executed.eqv.right%solver_executed) .and. &
      trim(left%solver_route)==trim(right%solver_route) .and. left%solver_iterations==right%solver_iterations .and. &
      left%accepted_substeps==right%accepted_substeps .and. left%solver_nonlinear_iterations==right%solver_nonlinear_iterations .and. &
      left%solver_internal_retries==right%solver_internal_retries .and. left%solver_headcalc_calls==right%solver_headcalc_calls .and. &
      left%solver_jacobian_builds==right%solver_jacobian_builds .and. left%solver_linear_solves==right%solver_linear_solves .and. &
      left%solver_backtracking_attempts==right%solver_backtracking_attempts .and. &
      left%solver_alternative_solver_calls==right%solver_alternative_solver_calls .and. &
      left%initial_revision==right%initial_revision .and. left%final_revision==right%final_revision .and. &
      same_bits(left%final_committed_time,right%final_committed_time) .and. &
      (left%final_committed_time_bound.eqv.right%final_committed_time_bound) .and. &
      (left%actual_transpiration_available.eqv.right%actual_transpiration_available) .and. &
      same_bits(left%actual_transpiration_amount,right%actual_transpiration_amount) .and. mass_equal(left%mass,right%mass)
  end function result_equal

  logical function mass_equal(left,right) result(equal)
    type(canonical_mass_accounting_t), intent(in) :: left,right
    equal=(left%complete.eqv.right%complete) .and. left%missing_contribution_mask==right%missing_contribution_mask .and. &
      left%origin_lineage_id==right%origin_lineage_id .and. left%origin_revision==right%origin_revision .and. &
      left%accepted_transaction_count==right%accepted_transaction_count .and. same_bits(left%interval_t0,right%interval_t0) .and. &
      same_bits(left%interval_t1,right%interval_t1) .and. same_bits(left%storage_start,right%storage_start) .and. &
      same_bits(left%storage_end,right%storage_end) .and. same_bits(left%storage_change,right%storage_change) .and. &
      same_bits(left%total_in,right%total_in) .and. same_bits(left%total_out,right%total_out) .and. same_bits(left%residual,right%residual)
  end function mass_equal

  logical function diag_sets_equal(left,right) result(equal)
    type(fmr_column_diagnostics_t), intent(in) :: left(:),right(:)
    integer :: i,j
    equal=size(left)==size(right); if(.not.equal)return
    do i=1,size(left)
      j=find_diag(right,left(i)%column_id)
      if(j<=0 .or. .not.diag_equal(left(i),right(j)))then; equal=.false.; return; end if
    end do
  end function diag_sets_equal

  logical function diag_equal(left,right) result(equal)
    type(fmr_column_diagnostics_t), intent(in) :: left,right
    equal=left%column_id==right%column_id .and. left%template_id==right%template_id .and. left%backend==right%backend .and. &
      left%execution_class==right%execution_class .and. left%committed_revision==right%committed_revision .and. &
      same_bits(left%committed_time,right%committed_time) .and. (left%committed_time_bound.eqv.right%committed_time_bound) .and. &
      left%checkpoint_captures==right%checkpoint_captures .and. left%checkpoint_replays==right%checkpoint_replays .and. &
      left%runtime_attempts==right%runtime_attempts .and. left%attempts==right%attempts .and. left%retries==right%retries .and. &
      left%accepted==right%accepted .and. left%rejected==right%rejected .and. &
      trim(left%failure_classification)==trim(right%failure_classification) .and. &
      same_bits(left%unrounded_mass_residual,right%unrounded_mass_residual)
  end function diag_equal

  logical function runtime_science_equal(left,right) result(equal)
    type(fmr_serialized_batch_diagnostics_t), intent(in) :: left,right
    equal=left%number_requested==right%number_requested .and. left%number_admitted==right%number_admitted .and. &
      left%number_executed==right%number_executed .and. left%number_committed==right%number_committed .and. &
      left%number_rejected==right%number_rejected .and. left%physical_solve_count==right%physical_solve_count .and. &
      (left%deterministic_collection.eqv.right%deterministic_collection) .and. same_bits(left%effective_t0,right%effective_t0) .and. &
      same_bits(left%effective_t1,right%effective_t1) .and. same_bits(left%max_abs_column_mass_residual,right%max_abs_column_mass_residual) .and. &
      mass_equal(left%authoritative_aggregate_mass,right%authoritative_aggregate_mass)
  end function runtime_science_equal

  logical function states_equal(left,right) result(equal)
    type(kernel_committed_state_t), intent(in) :: left(:),right(:)
    integer :: j
    equal=size(left)==size(right); if(.not.equal)return
    do j=1,size(left); if(.not.state_equal(left(j),right(j)))then; equal=.false.; return; end if; end do
  end function states_equal

  logical function state_equal(left,right) result(equal)
    type(kernel_committed_state_t), intent(in) :: left,right
    class(transaction_state_t), allocatable :: ls,rs
    real(real64) :: lt,rt
    logical :: lok,rok,la,ra
    equal=left%current_lineage_id()==right%current_lineage_id() .and. left%current_revision()==right%current_revision()
    if(.not.equal)return
    call left%current_time(lt,la); call right%current_time(rt,ra)
    equal=(la.eqv.ra); if(equal.and.la)equal=same_bits(lt,rt); if(.not.equal)return
    call left%snapshot(ls,lok); call right%snapshot(rs,rok)
    equal=lok.and.rok; if(.not.equal)return
    select type(l=>ls)
    class is(fmr_b110_physical_state_t)
      select type(r=>rs)
      class is(fmr_b110_physical_state_t)
        equal=l%active_nodes==r%active_nodes .and. allocated(l%pressure_head).eqv.allocated(r%pressure_head) .and. &
          allocated(l%water_content).eqv.allocated(r%water_content) .and. same_bits(l%ponding_depth,r%ponding_depth) .and. &
          same_bits(l%groundwater_level,r%groundwater_level)
        if(equal.and.allocated(l%pressure_head))equal=all(l%pressure_head==r%pressure_head)
        if(equal.and.allocated(l%water_content))equal=all(l%water_content==r%water_content)
      class default
        equal=.false.
      end select
    class default
      equal=.false.
    end select
  end function state_equal

  logical function parameters_equal(left,right) result(equal)
    type(fmr_b110_physical_parameters_t), intent(in) :: left(:),right(:)
    integer :: j
    equal=size(left)==size(right); if(.not.equal)return
    do j=1,size(left)
      equal=left(j)%parameter_set_id==right(j)%parameter_set_id .and. left(j)%active_nodes==right(j)%active_nodes .and. &
        left(j)%bottom_mode==right(j)%bottom_mode .and. left(j)%swkimpl==right(j)%swkimpl .and. &
        left(j)%swsophy==right(j)%swsophy .and. (left(j)%root_extraction_active.eqv.right(j)%root_extraction_active) .and. &
        (left(j)%snow_active.eqv.right(j)%snow_active) .and. (left(j)%macropore_active.eqv.right(j)%macropore_active) .and. &
        all(left(j)%z==right(j)%z) .and. all(left(j)%dz==right(j)%dz) .and. &
        all(left(j)%node_distance==right(j)%node_distance) .and. all(left(j)%cofgen==right(j)%cofgen)
      if(.not.equal)return
    end do
  end function parameters_equal

  logical function same_bits(left,right) result(equal)
    real(real64), intent(in) :: left,right
    equal=transfer(left,0_int64)==transfer(right,0_int64)
  end function same_bits

  subroutine require(condition,label)
    logical, intent(in) :: condition
    character(len=*), intent(in) :: label
    if(.not.condition)then
      write(*,'(A)') 'FMR34_FAIL '//trim(label)
      error stop 1
    end if
  end subroutine require

end program test_fmr34_parallel_root_extraction
