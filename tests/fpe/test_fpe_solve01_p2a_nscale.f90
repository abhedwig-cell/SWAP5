program test_fpe_solve01_p2a_nscale
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use MOD_grid, only: numnod, z, dz, disnod
  use mod_transaction_reference, only: transaction_state_t, TX_TEMPORAL_MODEL_CERTIFICATE
  use mod_canonical_contracts, only: canonical_numerical_config_t
  use mod_kernel_transactions, only: kernel_committed_state_t
  use mod_fmr_runtime_core, only: fmr_logical_column_t, fmr_template_t, FMR_BACKEND_SERIALIZED_REFERENCE, &
       FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_parameters_t, fmr_b110_physical_forcing_t, &
       fmr_b110_physical_state_t, fmr_serialized_reference_backend_t, &
       fmr_new_b110_temporal_indicator_committed_state
  use mod_fmr_groundwater_head_forcing_adapter, only: fmr_groundwater_head_forcing_materializer_t
  use mod_fmr_groundwater_participant_registry, only: fmr_groundwater_participant_registry_t, FMR_GW_REGISTRY_OK
  use mod_fmr_groundwater_application_context, only: fmr_groundwater_application_context_t, FMR_GW_APP_CONTEXT_OK
  use mod_groundwater_interface_mass_ledger, only: groundwater_interface_mass_ledger_t, &
       groundwater_interface_mass_snapshot_t, GW_MASS_LEDGER_OK
  use mod_groundwater_coupling_contract, only: groundwater_head_datum_t, groundwater_coupling_window_t
  use mod_groundwater_topology_composition, only: groundwater_topology_tile_t, groundwater_topology_cell_t, &
       groundwater_topology_t, materialize_groundwater_topology, GW_TOPOLOGY_OK, &
       GW_STORAGE_STATE_ROLE_HEAD_STATE_CAPACITANCE, GW_DRAINAGE_OWNER_NONE
  use mod_groundwater_application_plan, only: groundwater_tile_predictor_input_t, groundwater_cell_area_input_t, &
       groundwater_application_plan_t, materialize_groundwater_application_plan, GW_APP_PLAN_OK
  use mod_modflow6_swap_predictor_response, only: modflow6_swap_predictor_lineage_t, modflow6_derivative_coverage_t, &
       compose_modflow6_swap_predictor_response, MODFLOW6_PREDICTOR_OK, MODFLOW6_DERIVATIVE_TRAJECTORY_TANGENT
  use mod_modflow6_swap_prescribed_qbot_bottom_face, only: modflow6_prescribed_qbot_bottom_face_t, &
       materialize_modflow6_prescribed_qbot_bottom_face, MODFLOW6_BOTTOM_FACE_OK
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  use mod_fixed_flux_top_boundary_provider, only: fixed_flux_top_boundary_provider_t
  implicit none

  real(real64), parameter :: H0_CM=-75.0_real64, DT=1.0e-4_real64
  real(real64), parameter :: BUDGET_CM=0.02_real64, TOL=max(1.0e-12_real64,2.8e-16_real64/DT)
  integer(int64), parameter :: CELL_ID=720001_int64, COUPLING_ID=720002_int64
  integer(int64), parameter :: GW_SERVICE_ID=720003_int64, GW_LINEAGE_ID=720004_int64
  real(real64), parameter :: BLOCK_CM(8)=[0.001_real64,0.01_real64,-0.001_real64,-0.01_real64, &
       0.001_real64,-0.001_real64,0.01_real64,-0.01_real64]

  integer :: n, nblock, status, i, j, k, exact_requests, approx_requests
  integer(int64) :: c0,c1,crate
  character(len=16) :: mode,arg
  type(fmr_b110_physical_parameters_t), target :: parameters
  type(fmr_b110_physical_forcing_t) :: forcing
  type(fmr_logical_column_t), allocatable :: columns(:)
  type(fmr_template_t), allocatable :: templates(:)
  type(kernel_committed_state_t), allocatable, target :: committed(:)
  type(fmr_serialized_reference_backend_t), target :: backend
  type(fmr_groundwater_head_forcing_materializer_t), target :: materializer
  type(fmr_groundwater_participant_registry_t), target :: registry
  type(groundwater_interface_mass_ledger_t), allocatable, target :: ledgers(:)
  type(groundwater_topology_tile_t), allocatable :: tiles(:)
  type(groundwater_topology_cell_t) :: cells(1)
  type(groundwater_topology_t) :: topology
  type(groundwater_tile_predictor_input_t), allocatable :: predictors(:)
  type(groundwater_cell_area_input_t) :: areas(1)
  type(groundwater_application_plan_t), target :: plan
  type(fmr_groundwater_application_context_t) :: context
  type(groundwater_head_datum_t) :: datum
  type(groundwater_coupling_window_t) :: window
  type(fixed_flux_top_boundary_provider_t), target :: top
  integer(int64), allocatable :: handles(:)
  real(real64) :: href, head(1), q(1), tangent(1), q_anchor, t_anchor, h_anchor
  real(real64) :: qchecksum, qfinal, elapsed_s, pressure_checksum, theta_checksum
  logical :: ready, ok
  type(groundwater_interface_mass_snapshot_t) :: ledger_snapshot
  class(transaction_state_t), allocatable :: snapshot

  call get_command_argument(1,arg); read(arg,*) n
  call get_command_argument(2,mode)
  call get_command_argument(3,arg); read(arg,*) nblock
  call require(n>0 .and. nblock>0,'positive N and block count')
  call require(trim(mode)=='e0' .or. trim(mode)=='e4','mode e0/e4')

  allocate(columns(n),templates(n),committed(n),ledgers(n),tiles(n),predictors(n),handles(n))
  call initialize_parameters(parameters)
  call initialize_forcing(forcing)
  call backend%initialize(top)
  call materializer%initialize(forcing)
  datum%available=.true.; datum%datum_id=720010_int64; datum%bottom_boundary_elevation_m=0.0_real64
  window%t0=0.0_real64; window%t1=DT
  call compute_reference_head(parameters,datum,href,status)
  call require(status==MODFLOW6_BOTTOM_FACE_OK,'reference head')

  call registry%initialize(n,status); call require(status==FMR_GW_REGISTRY_OK,'registry init')
  do i=1,n
    call initialize_column_template(columns(i),templates(i),i)
    call initialize_committed(committed(i),parameters,720100_int64+int(i,int64),ok)
    call require(ok,'committed init')
    call registry%bind(720100_int64+int(i,int64),backend,columns(i),templates(i),parameters,committed(i), &
         materializer,numerical_config(),datum,handles(i),status,immutable_parameters=.true.)
    call require(status==FMR_GW_REGISTRY_OK,'registry bind')
    call ledgers(i)%bind_identity(820100_int64+int(i,int64),status)
    call require(status==GW_MASS_LEDGER_OK,'ledger bind')
    tiles(i)%tile_id=720100_int64+int(i,int64)
    tiles(i)%swap_lineage_id=tiles(i)%tile_id
    tiles(i)%ledger_id=820100_int64+int(i,int64)
    tiles(i)%groundwater_cell_id=CELL_ID
    tiles(i)%area_fraction=1.0_real64/real(n,real64)
    call make_predictor(predictors(i),tiles(i),href)
  end do

  cells(1)%groundwater_cell_id=CELL_ID
  cells(1)%coupling_id=COUPLING_ID
  cells(1)%groundwater_service_id=GW_SERVICE_ID
  cells(1)%groundwater_lineage_id=GW_LINEAGE_ID
  cells(1)%package_slot=1
  cells(1)%modflow_node_id=1
  cells(1)%storage_state_role=GW_STORAGE_STATE_ROLE_HEAD_STATE_CAPACITANCE
  cells(1)%drainage_owner=GW_DRAINAGE_OWNER_NONE
  call materialize_groundwater_topology(tiles,cells,topology,status)
  call require(status==GW_TOPOLOGY_OK .and. topology%ready(),'topology')
  areas(1)%groundwater_cell_id=CELL_ID; areas(1)%cell_area_m2=1.0_real64
  call materialize_groundwater_application_plan(topology,predictors,areas,plan,status)
  call require(status==GW_APP_PLAN_OK .and. plan%ready(),'plan')
  call context%bind(plan,registry,handles,ledgers,status)
  call require(status==FMR_GW_APP_CONTEXT_OK .and. context%ready(),'context')
  call context%capture_origins(status); call require(status==FMR_GW_APP_CONTEXT_OK,'capture origins')

  exact_requests=0; approx_requests=0; qchecksum=0.0_real64
  call system_clock(c0,crate)
  do j=1,nblock
    q_anchor=0.0_real64; t_anchor=0.0_real64; h_anchor=0.0_real64
    do k=1,size(BLOCK_CM)
      head(1)=href+BLOCK_CM(k)/100.0_real64
      if(trim(mode)=='e0' .or. k==1 .or. k==5 .or. k==8)then
        call context%trial_cell_heads(head,q,status)
        call require(status==FMR_GW_APP_CONTEXT_OK,'exact trial')
        call context%trial_response_tangents(tangent,status)
        call require(status==FMR_GW_APP_CONTEXT_OK,'exact tangent')
        exact_requests=exact_requests+1
        q_anchor=q(1); t_anchor=tangent(1); h_anchor=head(1)
        qchecksum=qchecksum+q(1)
        call context%discard_candidates(status); call require(status==FMR_GW_APP_CONTEXT_OK,'discard')
      else
        q(1)=q_anchor+t_anchor*(head(1)-h_anchor)
        qchecksum=qchecksum+q(1); approx_requests=approx_requests+1
      end if
    end do
  end do
  call system_clock(c1)
  elapsed_s=real(c1-c0,real64)/real(crate,real64)

  ! Exact final validation and exact publication.
  head(1)=href+BLOCK_CM(8)/100.0_real64
  call context%trial_cell_heads(head,q,status); call require(status==FMR_GW_APP_CONTEXT_OK,'final exact trial')
  qfinal=q(1)
  call context%swap_preflight(ready,status); call require(status==FMR_GW_APP_CONTEXT_OK .and. ready,'swap preflight')
  call context%prepare_ledgers(status); call require(status==FMR_GW_APP_CONTEXT_OK,'prepare ledgers')
  call context%ledgers_preflight(ready,status); call require(status==FMR_GW_APP_CONTEXT_OK .and. ready,'ledger preflight')
  call context%commit_swaps(status); call require(status==FMR_GW_APP_CONTEXT_OK,'commit swaps')
  call context%commit_ledgers(status); call require(status==FMR_GW_APP_CONTEXT_OK,'commit ledgers')

  do i=1,n
    call require(committed(i)%current_revision()==1_int64,'one SWAP commit per tile')
    call ledgers(i)%snapshot(ledger_snapshot)
    call require(ledger_snapshot%available .and. ledger_snapshot%committed_exchange_count==1,'one ledger commit per tile')
  end do

  call committed(1)%snapshot(snapshot,ready); call require(ready .and. allocated(snapshot),'state snapshot')
  pressure_checksum=0.0_real64; theta_checksum=0.0_real64
  select type(s=>snapshot)
  class is(fmr_b110_physical_state_t)
    pressure_checksum=sum(s%pressure_head); theta_checksum=sum(s%water_content)
  class default
    call require(.false.,'typed final state')
  end select

  write(*,'(A,I0,A,A,A,I0,A,ES24.16E3,A,I0,A,I0,A,I0,A,ES24.16E3,A,ES24.16E3,A,ES24.16E3,A,ES24.16E3)') &
       'SOLVE01_P2A|N=',n,'|MODE=',trim(mode),'|BLOCKS=',nblock,'|ELAPSED_S=',elapsed_s, &
       '|EXACT_REQUESTS=',exact_requests,'|EXACT_TILE_TRIALS=',exact_requests*n+n, &
       '|APPROX_AGG=',approx_requests,'|QCHECKSUM=',qchecksum,'|QFINAL=',qfinal, &
       '|PRESSURE_SUM=',pressure_checksum,'|THETA_SUM=',theta_checksum
  write(*,'(A)') 'FPE_SOLVE01_P2A_CASE=PASS'

contains

  function numerical_config() result(c)
    type(canonical_numerical_config_t) :: c
    c%transaction%temporal_mode=TX_TEMPORAL_MODEL_CERTIFICATE
    c%transaction%temporal_tolerance=0.0_real64
    c%transaction%mass_tolerance=TOL
    c%transaction%retry_scale=0.5_real64
    c%transaction%max_retries=8
    c%max_committed_substeps=32
    c%progress_tolerance=0.0_real64
    c%model_temporal_indicator_budget_available=.true.
    c%model_temporal_indicator_budget=BUDGET_CM
    c%accepted_trajectory_direction%requested=.false.
  end function numerical_config

  subroutine initialize_column_template(c,t,slot)
    type(fmr_logical_column_t),intent(out)::c
    type(fmr_template_t),intent(out)::t
    integer,intent(in)::slot
    t%template_id=730000_int64+int(slot,int64); t%physics_topology_id=730010_int64
    t%vertical_layout_id=730020_int64; t%state_layout_id=730030_int64; t%solver_interface_id=730040_int64
    t%optional_state_layout_id=0_int64
    t%numerical_continuation_layout_id=FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY
    t%compatible_backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
    c%column_id=720100_int64+int(slot,int64); c%template_id=t%template_id
    c%parameter_ref=1_int64; c%state_handle=int(slot,int64); c%forcing_handle=1_int64
    c%backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
  end subroutine initialize_column_template

  subroutine initialize_parameters(p)
    type(fmr_b110_physical_parameters_t),intent(out)::p
    integer::m
    p%parameter_set_id=730100_int64; p%active_nodes=numnod
    allocate(p%z(numnod),p%dz(numnod),p%node_distance(numnod),p%cofgen(24,numnod))
    p%z=z; p%dz=dz; p%node_distance=disnod(1:numnod); p%cofgen=0.0_real64
    do m=1,numnod
      p%cofgen(1,m)=0.01_real64; p%cofgen(2,m)=0.393878_real64; p%cofgen(3,m)=2.495984_real64
      p%cofgen(4,m)=0.003288_real64; p%cofgen(5,m)=0.514012_real64; p%cofgen(6,m)=1.616573_real64
      p%cofgen(7,m)=1.0_real64-1.0_real64/p%cofgen(6,m); p%cofgen(8,m)=p%cofgen(4,m)
      p%cofgen(10,m)=p%cofgen(3,m); p%cofgen(11,m)=0.999_real64
      p%cofgen(12,m)=0.99_real64*p%cofgen(3,m); p%cofgen(22,m)=-1.0e6_real64; p%cofgen(23,m)=1.0e-12_real64
    end do
    p%bottom_mode=5; p%swkimpl=0; p%swkmean=1; p%swsophy=0
    p%max_iterations=48; p%max_backtracking=16; p%min_step_duration=1.0e-10_real64
    p%compartment_balance_tolerance=TOL; p%total_balance_tolerance=TOL
    p%head_abs_tolerance=1.0e-10_real64; p%head_rel_tolerance=1.0e-10_real64; p%ponding_tolerance=1.0e-10_real64
    p%root_extraction_active=.false.; p%macropore_active=.false.; p%snow_active=.false.
    p%hysteresis_active=.false.; p%tabulated_hydraulics_active=.false.; p%elasticity_active=.false.
    p%frost_active=.false.; p%soil_temperature_active=.false.; p%drainage_response_active=.false.
  end subroutine initialize_parameters

  subroutine initialize_forcing(f)
    type(fmr_b110_physical_forcing_t),intent(out)::f
    f%top_flux=1.0e-6_real64; f%top_head=H0_CM; f%bottom_flux=1.0e-6_real64; f%bottom_head=H0_CM
    allocate(f%drainage_flux_by_level(1,numnod),f%subsurface_irrigation_source(numnod),f%root_extraction_sink(numnod))
    f%drainage_flux_by_level=0.0_real64; f%subsurface_irrigation_source=0.0_real64; f%root_extraction_sink=0.0_real64
  end subroutine initialize_forcing

  subroutine initialize_committed(state,p,lineage,initialized)
    type(kernel_committed_state_t),intent(out)::state
    type(fmr_b110_physical_parameters_t),intent(in)::p
    integer(int64),intent(in)::lineage
    logical,intent(out)::initialized
    type(fmr_b110_physical_state_t)::physical
    type(b110_default_mvg_parameters_t),target::hp
    type(b110_default_mvg_provider_t)::provider
    real(real64)::heads(numnod),water(numnod),conductivity(numnod),capacity(numnod),dkdh(numnod),prev(numnod)
    heads=H0_CM
    call initialize_b110_default_mvg_parameters(hp,p%cofgen); call bind_b110_default_mvg_provider(provider,hp,DT)
    call provider%evaluate(heads,water,conductivity,capacity,dkdh)
    physical%active_nodes=numnod; allocate(physical%pressure_head(numnod),physical%water_content(numnod))
    physical%pressure_head=heads; physical%water_content=water; physical%ponding_depth=0.0_real64
    physical%groundwater_level=-1.0_real64; prev=0.0_real64
    call fmr_new_b110_temporal_indicator_committed_state(state,lineage,physical,0.0_real64,initialized,prev)
  end subroutine initialize_committed

  subroutine compute_reference_head(p,d,head_m,s)
    type(fmr_b110_physical_parameters_t),intent(in)::p
    type(groundwater_head_datum_t),intent(in)::d
    real(real64),intent(out)::head_m
    integer,intent(out)::s
    type(b110_default_mvg_parameters_t),target::hp
    type(b110_default_mvg_provider_t)::provider
    type(modflow6_prescribed_qbot_bottom_face_t)::face
    real(real64)::heads(numnod),water(numnod),conductivity(numnod),capacity(numnod),dkdh(numnod)
    heads=H0_CM
    call initialize_b110_default_mvg_parameters(hp,p%cofgen); call bind_b110_default_mvg_provider(provider,hp,DT)
    call provider%evaluate(heads,water,conductivity,capacity,dkdh)
    call materialize_modflow6_prescribed_qbot_bottom_face(heads(numnod),conductivity(numnod),1.0e-6_real64, &
         0.5_real64*p%dz(numnod),d,face,s)
    if(s==MODFLOW6_BOTTOM_FACE_OK)head_m=face%hydraulic_head_m
  end subroutine compute_reference_head

  subroutine make_predictor(input,tile,href0)
    type(groundwater_tile_predictor_input_t),intent(out)::input
    type(groundwater_topology_tile_t),intent(in)::tile
    real(real64),intent(in)::href0
    type(modflow6_swap_predictor_lineage_t)::lineage
    type(modflow6_derivative_coverage_t)::coverage
    type(groundwater_coupling_window_t)::w
    integer::s
    input%tile_id=tile%tile_id; w%t0=0.0_real64; w%t1=DT
    lineage%coupling_id=COUPLING_ID; lineage%swap_lineage_id=tile%swap_lineage_id
    lineage%swap_origin_revision=0_int64; lineage%groundwater_service_id=GW_SERVICE_ID
    lineage%groundwater_lineage_id=GW_LINEAGE_ID; lineage%groundwater_origin_revision=0_int64
    coverage%lower_face_head_semantics_covered=.true.; coverage%richards_hydraulic_response_covered=.true.
    coverage%constitutive_response_covered=.true.
    call compose_modflow6_swap_predictor_response(w,lineage,0.001_real64,href0,href0+0.001_real64,0.25_real64, &
         MODFLOW6_DERIVATIVE_TRAJECTORY_TANGENT,coverage,'solve01-p2a','nscale',input%response,s)
    if(s/=MODFLOW6_PREDICTOR_OK .or. .not.input%response%valid)error stop 'predictor'
  end subroutine make_predictor

  subroutine require(cond,msg)
    logical,intent(in)::cond
    character(len=*),intent(in)::msg
    if(.not.cond)then
      write(*,'(A,1X,A)')'SOLVE01_P2A_FAIL',trim(msg); error stop 1
    end if
  end subroutine require
end program test_fpe_solve01_p2a_nscale
