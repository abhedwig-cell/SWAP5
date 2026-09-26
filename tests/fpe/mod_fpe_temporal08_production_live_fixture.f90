module mod_fpe_temporal08_production_live_fixture
  use, intrinsic :: iso_c_binding, only: c_double, c_int, c_int64_t
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use MOD_grid, only: numnod, z, dz, disnod
  use mod_transaction_reference, only: TX_TEMPORAL_MODEL_CERTIFICATE
  use mod_fmr_runtime_core, only: FMR_BACKEND_SERIALIZED_REFERENCE, FMR_OPTIONAL_STATE_LAYOUT_BASE, &
       FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_parameters_t, fmr_b110_physical_forcing_t, &
       fmr_b110_physical_state_t
  use mod_fmr_production_application_bootstrap, only: fmr_production_application_config_t, &
       fmr_production_application_bootstrap_t, FMR_APP_BOOT_OK
  use mod_groundwater_coupling_contract, only: groundwater_head_datum_t, groundwater_coupling_window_t
  use mod_groundwater_topology_composition, only: groundwater_topology_tile_t, groundwater_topology_cell_t, &
       groundwater_topology_t, materialize_groundwater_topology, GW_TOPOLOGY_OK, &
       GW_STORAGE_STATE_ROLE_HEAD_STATE_CAPACITANCE, GW_DRAINAGE_OWNER_NONE
  use mod_groundwater_application_plan, only: groundwater_tile_predictor_input_t, groundwater_cell_area_input_t
  use mod_modflow6_swap_predictor_response, only: modflow6_swap_predictor_lineage_t, modflow6_derivative_coverage_t, &
       compose_modflow6_swap_predictor_response, MODFLOW6_PREDICTOR_OK, MODFLOW6_DERIVATIVE_TRAJECTORY_TANGENT
  use mod_modflow6_swap_prescribed_qbot_bottom_face, only: modflow6_prescribed_qbot_bottom_face_t, &
       materialize_modflow6_prescribed_qbot_bottom_face, MODFLOW6_BOTTOM_FACE_OK
  use mod_b110_default_mvg_provider, only: b110_default_mvg_parameters_t, b110_default_mvg_provider_t, &
       initialize_b110_default_mvg_parameters, bind_b110_default_mvg_provider
  implicit none
  private

  integer, parameter :: NPART=3
  integer(int64), parameter :: TILE_ID(NPART)=[880201_int64,880202_int64,880203_int64]
  integer(int64), parameter :: LEDGER_ID(NPART)=[980201_int64,980202_int64,980203_int64]
  integer(int64), parameter :: CELL_ID(NPART)=[7001_int64,7001_int64,7002_int64]
  integer(int64), parameter :: COUPLING_ID(2)=[880301_int64,880302_int64]
  integer(int64), parameter :: GW_LINEAGE_ID(2)=[880401_int64,880402_int64]
  integer(int64), parameter :: GW_SERVICE_ID=880501_int64
  real(real64), parameter :: FRACTION(NPART)=[0.35_real64,0.65_real64,1.0_real64]
  real(real64), parameter :: H0_CM=-75.0_real64, DT=1.0e-4_real64, TOL=1.0e-12_real64
  real(real64), parameter :: PREDICTOR_QBOT=1.0e-6_real64
  real(real64), parameter :: HISTORY_RATE=400.0_real64

  type(fmr_production_application_bootstrap_t), save :: app
  logical, save :: initialized=.false.

  public :: fpe_temporal08_fixture_initialize_c
  public :: fpe_temporal08_fixture_state_c
  public :: fpe_temporal08_fixture_close_c

contains

  integer(c_int) function fpe_temporal08_fixture_initialize_c(context_handle,href1,href2) &
       bind(C,name="fpe_temporal08_fixture_initialize_c") result(c_status)
    integer(c_int64_t), intent(out) :: context_handle
    real(c_double), intent(out) :: href1,href2
    type(fmr_production_application_config_t) :: config
    type(groundwater_topology_tile_t) :: tiles(NPART)
    type(groundwater_topology_cell_t) :: cells(2)
    type(groundwater_topology_t) :: topology
    type(groundwater_tile_predictor_input_t) :: predictors(NPART)
    type(groundwater_cell_area_input_t) :: areas(2)
    real(real64) :: reference_head
    integer(int64) :: handle
    integer :: i,status

    c_status=1_c_int; context_handle=0_c_int64_t; href1=0.0_c_double; href2=0.0_c_double
    if(initialized)return

    call initialize_config(config)
    call app%initialize(config,status)
    if(status/=FMR_APP_BOOT_OK .or. .not.app%ready())return

    call compute_reference_head(config%tiles(1)%parameters,config%tiles(1)%groundwater_datum,reference_head,status)
    if(status/=MODFLOW6_BOTTOM_FACE_OK)return

    do i=1,NPART
      call set_tile(tiles(i),TILE_ID(i),LEDGER_ID(i),CELL_ID(i),FRACTION(i))
    end do
    call set_cell(cells(1),7001_int64,COUPLING_ID(1),GW_LINEAGE_ID(1),1,2,1,2)
    call set_cell(cells(2),7002_int64,COUPLING_ID(2),GW_LINEAGE_ID(2),2,3,3,1)
    call materialize_groundwater_topology(tiles,cells,topology,status)
    if(status/=GW_TOPOLOGY_OK .or. .not.topology%ready())return

    call make_predictor(predictors(1),tiles(1),cells(1),reference_head,1)
    call make_predictor(predictors(2),tiles(2),cells(1),reference_head,2)
    call make_predictor(predictors(3),tiles(3),cells(2),reference_head,3)
    areas(1)%groundwater_cell_id=7001_int64; areas(1)%cell_area_m2=1.0_real64
    areas(2)%groundwater_cell_id=7002_int64; areas(2)%cell_area_m2=1.0_real64

    call app%materialize_groundwater_context(topology,predictors,areas,handle,status)
    if(status/=FMR_APP_BOOT_OK .or. handle<=0_int64)return

    context_handle=int(handle,c_int64_t)
    href1=real(reference_head,c_double); href2=real(reference_head,c_double)
    initialized=.true.; c_status=0_c_int
  end function fpe_temporal08_fixture_initialize_c

  integer(c_int) function fpe_temporal08_fixture_state_c(r1,r2,r3) &
       bind(C,name="fpe_temporal08_fixture_state_c") result(c_status)
    integer(c_int), intent(out) :: r1,r2,r3
    integer(int64), allocatable :: revisions(:)
    integer :: status
    c_status=1_c_int; r1=-1_c_int; r2=-1_c_int; r3=-1_c_int
    if(.not.initialized)return
    call app%copy_committed_revisions(revisions,status)
    if(status/=FMR_APP_BOOT_OK .or. .not.allocated(revisions) .or. size(revisions)/=NPART)return
    r1=int(revisions(1),c_int); r2=int(revisions(2),c_int); r3=int(revisions(3),c_int)
    c_status=0_c_int
  end function fpe_temporal08_fixture_state_c

  integer(c_int) function fpe_temporal08_fixture_close_c() bind(C,name="fpe_temporal08_fixture_close_c") result(c_status)
    integer :: status
    c_status=1_c_int
    if(.not.initialized)return
    call app%release_groundwater_context(status)
    if(status/=FMR_APP_BOOT_OK)return
    call app%close(status)
    if(status/=FMR_APP_BOOT_OK)return
    initialized=.false.; c_status=0_c_int
  end function fpe_temporal08_fixture_close_c

  subroutine initialize_config(value)
    type(fmr_production_application_config_t),intent(out)::value
    integer :: i
    value%initial_time=0.0_real64
    value%numerical%transaction%temporal_mode=TX_TEMPORAL_MODEL_CERTIFICATE
    value%numerical%transaction%temporal_tolerance=0.0_real64
    value%numerical%transaction%mass_tolerance=TOL
    value%numerical%transaction%retry_scale=0.5_real64
    value%numerical%transaction%max_retries=8
    value%numerical%max_committed_substeps=32
    value%numerical%progress_tolerance=0.0_real64
    value%numerical%model_temporal_indicator_budget_available=.true.
    value%numerical%model_temporal_indicator_budget=1.0e-5_real64
    allocate(value%tiles(NPART))
    do i=1,NPART
      value%tiles(i)%tile_id=TILE_ID(i); value%tiles(i)%ledger_id=LEDGER_ID(i)
      value%tiles(i)%template%template_id=880600_int64+int(i,int64)
      value%tiles(i)%template%physics_topology_id=880610_int64
      value%tiles(i)%template%vertical_layout_id=880620_int64
      value%tiles(i)%template%state_layout_id=880630_int64
      value%tiles(i)%template%solver_interface_id=880640_int64
      value%tiles(i)%template%optional_state_layout_id=FMR_OPTIONAL_STATE_LAYOUT_BASE
      value%tiles(i)%template%numerical_continuation_layout_id=FMR_NUMERICAL_CONTINUATION_RICHARDS_TEMPORAL_HISTORY
      value%tiles(i)%template%compatible_backend_id=FMR_BACKEND_SERIALIZED_REFERENCE
      call initialize_parameters(value%tiles(i)%parameters,880700_int64+int(i,int64))
      call initialize_state_forcing(value%tiles(i)%parameters,value%tiles(i)%initial_state,value%tiles(i)%base_forcing)
      allocate(value%tiles(i)%initial_right_derivative(numnod))
      value%tiles(i)%initial_right_derivative=HISTORY_RATE
      value%tiles(i)%groundwater_datum%available=.true.
      value%tiles(i)%groundwater_datum%datum_id=880800_int64+int(i,int64)
      value%tiles(i)%groundwater_datum%bottom_boundary_elevation_m=0.0_real64
    end do
  end subroutine initialize_config

  subroutine initialize_parameters(p,id)
    type(fmr_b110_physical_parameters_t),intent(out)::p
    integer(int64),intent(in)::id
    integer :: k
    p%parameter_set_id=id; p%active_nodes=numnod
    allocate(p%z(numnod),p%dz(numnod),p%node_distance(numnod),p%cofgen(24,numnod))
    p%z=z; p%dz=dz; p%node_distance=disnod(1:numnod); p%cofgen=0.0_real64
    do k=1,numnod
      p%cofgen(1,k)=0.01_real64; p%cofgen(2,k)=0.393878_real64; p%cofgen(3,k)=2.495984_real64
      p%cofgen(4,k)=0.003288_real64; p%cofgen(5,k)=0.514012_real64; p%cofgen(6,k)=1.616573_real64
      p%cofgen(7,k)=1.0_real64-1.0_real64/p%cofgen(6,k); p%cofgen(8,k)=p%cofgen(4,k)
      p%cofgen(10,k)=p%cofgen(3,k); p%cofgen(11,k)=0.999_real64
      p%cofgen(12,k)=0.99_real64*p%cofgen(3,k); p%cofgen(22,k)=-1.0e6_real64; p%cofgen(23,k)=1.0e-12_real64
    end do
    p%bottom_mode=5; p%swkimpl=0; p%swkmean=1; p%swsophy=0
    p%max_iterations=48; p%max_backtracking=16; p%min_step_duration=1.0e-10_real64
    p%compartment_balance_tolerance=TOL; p%total_balance_tolerance=TOL
    p%head_abs_tolerance=TOL; p%head_rel_tolerance=TOL; p%ponding_tolerance=TOL
    p%root_extraction_active=.false.; p%macropore_active=.false.; p%snow_active=.false.
    p%hysteresis_active=.false.; p%tabulated_hydraulics_active=.false.; p%elasticity_active=.false.
    p%frost_active=.false.; p%soil_temperature_active=.false.; p%drainage_response_active=.false.
  end subroutine initialize_parameters

  subroutine initialize_state_forcing(p,state,forcing)
    type(fmr_b110_physical_parameters_t),intent(in)::p
    type(fmr_b110_physical_state_t),intent(out)::state
    type(fmr_b110_physical_forcing_t),intent(out)::forcing
    type(b110_default_mvg_parameters_t),target :: hp
    type(b110_default_mvg_provider_t) :: provider
    real(real64) :: heads(numnod),water(numnod),conductivity(numnod),capacity(numnod),dkdh(numnod)
    heads=H0_CM
    call initialize_b110_default_mvg_parameters(hp,p%cofgen)
    call bind_b110_default_mvg_provider(provider,hp,DT)
    call provider%evaluate(heads,water,conductivity,capacity,dkdh)
    state%active_nodes=numnod; allocate(state%pressure_head(numnod),state%water_content(numnod))
    state%pressure_head=heads; state%water_content=water; state%ponding_depth=0.0_real64; state%groundwater_level=-1.0_real64
    forcing%top_flux=PREDICTOR_QBOT; forcing%top_head=H0_CM
    forcing%bottom_flux=PREDICTOR_QBOT; forcing%bottom_head=H0_CM
    allocate(forcing%drainage_flux_by_level(1,numnod),forcing%subsurface_irrigation_source(numnod),forcing%root_extraction_sink(numnod))
    forcing%drainage_flux_by_level=0.0_real64; forcing%subsurface_irrigation_source=0.0_real64
    forcing%root_extraction_sink=0.0_real64
  end subroutine initialize_state_forcing

  subroutine compute_reference_head(p,datum,head_m,status)
    type(fmr_b110_physical_parameters_t),intent(in)::p
    type(groundwater_head_datum_t),intent(in)::datum
    real(real64),intent(out)::head_m
    integer,intent(out)::status
    type(b110_default_mvg_parameters_t),target :: hp
    type(b110_default_mvg_provider_t) :: provider
    type(modflow6_prescribed_qbot_bottom_face_t) :: face
    real(real64) :: heads(numnod),water(numnod),conductivity(numnod),capacity(numnod),dkdh(numnod)
    heads=H0_CM
    call initialize_b110_default_mvg_parameters(hp,p%cofgen)
    call bind_b110_default_mvg_provider(provider,hp,DT)
    call provider%evaluate(heads,water,conductivity,capacity,dkdh)
    call materialize_modflow6_prescribed_qbot_bottom_face(heads(numnod),conductivity(numnod),PREDICTOR_QBOT, &
         0.5_real64*p%dz(numnod),datum,face,status)
    if(status==MODFLOW6_BOTTOM_FACE_OK)then
      head_m=face%hydraulic_head_m
    else
      head_m=0.0_real64
    end if
  end subroutine compute_reference_head

  subroutine set_tile(tile,id,ledger,cell,fraction)
    type(groundwater_topology_tile_t),intent(out)::tile
    integer(int64),intent(in)::id,ledger,cell
    real(real64),intent(in)::fraction
    tile%tile_id=id; tile%swap_lineage_id=id; tile%ledger_id=ledger
    tile%groundwater_cell_id=cell; tile%area_fraction=fraction
  end subroutine set_tile

  subroutine set_cell(cell,id,coupling,lineage,slot,node,tile_begin,tile_count)
    type(groundwater_topology_cell_t),intent(out)::cell
    integer(int64),intent(in)::id,coupling,lineage
    integer,intent(in)::slot,node,tile_begin,tile_count
    cell%groundwater_cell_id=id; cell%coupling_id=coupling
    cell%groundwater_service_id=GW_SERVICE_ID; cell%groundwater_lineage_id=lineage
    cell%package_slot=slot; cell%modflow_node_id=node
    cell%storage_state_role=GW_STORAGE_STATE_ROLE_HEAD_STATE_CAPACITANCE
    cell%drainage_owner=GW_DRAINAGE_OWNER_NONE
    cell%tile_begin=tile_begin; cell%tile_count=tile_count
  end subroutine set_cell

  subroutine make_predictor(input,tile,cell,href,slot)
    type(groundwater_tile_predictor_input_t),intent(out)::input
    type(groundwater_topology_tile_t),intent(in)::tile
    type(groundwater_topology_cell_t),intent(in)::cell
    real(real64),intent(in)::href
    integer,intent(in)::slot
    type(modflow6_swap_predictor_lineage_t) :: lineage
    type(modflow6_derivative_coverage_t) :: coverage
    type(groundwater_coupling_window_t) :: window
    integer :: status
    input%tile_id=tile%tile_id
    window%t0=0.0_real64; window%t1=DT
    lineage%coupling_id=cell%coupling_id; lineage%swap_lineage_id=tile%swap_lineage_id
    lineage%swap_origin_revision=0_int64; lineage%groundwater_service_id=cell%groundwater_service_id
    lineage%groundwater_lineage_id=cell%groundwater_lineage_id; lineage%groundwater_origin_revision=0_int64
    coverage%lower_face_head_semantics_covered=.true.; coverage%richards_hydraulic_response_covered=.true.
    coverage%constitutive_response_covered=.true.
    call compose_modflow6_swap_predictor_response(window,lineage,0.001_real64,href, &
         href+real(slot,real64)*0.001_real64,0.25_real64,MODFLOW6_DERIVATIVE_TRAJECTORY_TANGENT, &
         coverage,'fpe-temporal08','production-bootstrap-live',input%response,status)
    if(status/=MODFLOW6_PREDICTOR_OK .or. .not.input%response%valid)error stop 'TEMPORAL08 predictor'
  end subroutine make_predictor

end module mod_fpe_temporal08_production_live_fixture
