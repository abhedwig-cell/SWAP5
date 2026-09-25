program test_fpe_zero_waste01_gwplan01
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_groundwater_coupling_contract, only: groundwater_coupling_window_t
  use mod_groundwater_topology_composition, only: groundwater_topology_tile_t, groundwater_topology_cell_t, &
       groundwater_topology_t, materialize_groundwater_topology, GW_TOPOLOGY_OK
  use mod_groundwater_application_plan, only: groundwater_tile_predictor_input_t, groundwater_cell_area_input_t, &
       groundwater_application_plan_t, groundwater_application_cell_plan_t, materialize_groundwater_application_plan, &
       GW_APP_PLAN_OK
  use mod_modflow6_api_binding, only: modflow6_api_slot_binding_t
  use mod_modflow6_linear_response_backend, only: modflow6_linear_boundary_term_t
  use mod_modflow6_swap_predictor_response, only: modflow6_swap_predictor_lineage_t, &
       modflow6_derivative_coverage_t, compose_modflow6_swap_predictor_response, MODFLOW6_PREDICTOR_OK, &
       MODFLOW6_DERIVATIVE_TRAJECTORY_TANGENT
  implicit none

  integer :: n, i, status, rep, copy_reps
  integer(int64) :: c0, c1, rate
  character(len=32) :: arg
  type(groundwater_topology_tile_t), allocatable :: tiles(:)
  type(groundwater_topology_cell_t), allocatable :: cells(:)
  type(groundwater_tile_predictor_input_t), allocatable :: predictors(:)
  type(groundwater_cell_area_input_t), allocatable :: areas(:)
  type(groundwater_topology_t) :: topology
  type(groundwater_application_plan_t) :: plan
  type(groundwater_topology_tile_t), allocatable :: copy_tiles(:)
  integer(int64), allocatable :: copy_revisions(:)
  type(groundwater_application_cell_plan_t), allocatable :: copy_cells(:)
  type(modflow6_api_slot_binding_t), allocatable :: copy_api(:)
  type(modflow6_linear_boundary_term_t), allocatable :: copy_terms(:)
  real(real64) :: seconds, ns_total, checksum, topology_seconds, topology_ns_total, copy_seconds
  real(real64) :: copy_tiles_seconds, copy_revisions_seconds, copy_cells_seconds, copy_api_seconds, copy_terms_seconds

  call get_command_argument(1,arg)
  read(arg,*) n
  if (n <= 0) error stop 'GWPLAN01 invalid N'

  allocate(tiles(n),cells(n),predictors(n),areas(n))
  do i=1,n
    call set_tile(tiles(i),int(i,int64),100000_int64+int(i,int64),200000_int64+int(i,int64), &
         300000_int64+int(i,int64))
    call set_cell(cells(i),300000_int64+int(i,int64),400000_int64+int(i,int64),9001_int64, &
         500000_int64+int(i,int64),i,i)
    call make_predictor(predictors(i),tiles(i),cells(i))
    areas(i)%groundwater_cell_id=cells(i)%groundwater_cell_id
    areas(i)%cell_area_m2=100.0_real64+real(mod(i,17),real64)
  end do

  call system_clock(c0,rate)
  call materialize_groundwater_topology(tiles,cells,topology,status)
  call system_clock(c1)
  if (status /= GW_TOPOLOGY_OK .or. .not. topology%ready()) error stop 'GWPLAN01 topology setup failed'
  topology_seconds=real(c1-c0,real64)/real(rate,real64)
  topology_ns_total=1.0e9_real64*topology_seconds
  write(*,'(A,I0,A,ES24.16,A,ES24.16)') &
       'GWTOPO01_CURRENT,n=',n,',seconds=',topology_seconds,',ns_total=',topology_ns_total

  call system_clock(c0,rate)
  call materialize_groundwater_application_plan(topology,predictors,areas,plan,status)
  call system_clock(c1)
  if (status /= GW_APP_PLAN_OK .or. .not. plan%ready()) error stop 'GWPLAN01 plan materialization failed'
  if (plan%tile_count() /= n .or. plan%cell_count() /= n) error stop 'GWPLAN01 count mismatch'

  seconds=real(c1-c0,real64)/real(rate,real64)
  ns_total=1.0e9_real64*seconds
  checksum=real(plan%tile_count()+plan%cell_count(),real64)
  write(*,'(A,I0,A,ES24.16,A,ES24.16,A,ES24.16)') &
       'GWPLAN01_CURRENT,n=',n,',seconds=',seconds,',ns_total=',ns_total,',checksum=',checksum

  copy_reps=max(1,100000/max(1,n))
  call system_clock(c0,rate)
  do rep=1,copy_reps
    call plan%copy_tiles(copy_tiles,status)
    if(status/=GW_APP_PLAN_OK) error stop 'GWCTX02 copy tiles failed'
  end do
  call system_clock(c1)
  copy_tiles_seconds=real(c1-c0,real64)/real(rate,real64)

  call system_clock(c0)
  do rep=1,copy_reps
    call plan%copy_tile_swap_origin_revisions(copy_revisions,status)
    if(status/=GW_APP_PLAN_OK) error stop 'GWCTX02 copy revisions failed'
  end do
  call system_clock(c1)
  copy_revisions_seconds=real(c1-c0,real64)/real(rate,real64)

  call system_clock(c0)
  do rep=1,copy_reps
    call plan%copy_cells(copy_cells,status)
    if(status/=GW_APP_PLAN_OK) error stop 'GWCTX02 copy cells failed'
  end do
  call system_clock(c1)
  copy_cells_seconds=real(c1-c0,real64)/real(rate,real64)

  call system_clock(c0)
  do rep=1,copy_reps
    call plan%copy_api_bindings(copy_api,status)
    if(status/=GW_APP_PLAN_OK) error stop 'GWCTX02 copy api failed'
  end do
  call system_clock(c1)
  copy_api_seconds=real(c1-c0,real64)/real(rate,real64)

  call system_clock(c0)
  do rep=1,copy_reps
    call plan%copy_linear_terms(copy_terms,status)
    if(status/=GW_APP_PLAN_OK) error stop 'GWCTX02 copy terms failed'
  end do
  call system_clock(c1)
  copy_terms_seconds=real(c1-c0,real64)/real(rate,real64)

  copy_seconds=copy_tiles_seconds+copy_revisions_seconds+copy_cells_seconds+copy_api_seconds+copy_terms_seconds
  checksum=real(size(copy_tiles)+size(copy_revisions)+size(copy_cells)+size(copy_api)+size(copy_terms),real64)
  write(*,'(A,I0,A,I0,A,ES24.16,A,ES24.16,A,ES24.16)') &
       'GWCTX02_COPY,n=',n,',reps=',copy_reps,',seconds=',copy_seconds, &
       ',seconds_per_bind=',copy_seconds/real(copy_reps,real64),',checksum=',checksum
  write(*,'(A,I0,A,ES24.16,A,ES24.16,A,ES24.16,A,ES24.16,A,ES24.16)') &
       'GWCTX02_COMPONENTS,n=',n, &
       ',tiles_per_bind=',copy_tiles_seconds/real(copy_reps,real64), &
       ',revisions_per_bind=',copy_revisions_seconds/real(copy_reps,real64), &
       ',cells_per_bind=',copy_cells_seconds/real(copy_reps,real64), &
       ',api_per_bind=',copy_api_seconds/real(copy_reps,real64), &
       ',terms_per_bind=',copy_terms_seconds/real(copy_reps,real64)

contains

  subroutine set_tile(tile,tile_id,lineage_id,ledger_id,cell_id)
    type(groundwater_topology_tile_t),intent(out)::tile
    integer(int64),intent(in)::tile_id,lineage_id,ledger_id,cell_id
    tile%tile_id=tile_id
    tile%swap_lineage_id=lineage_id
    tile%ledger_id=ledger_id
    tile%groundwater_cell_id=cell_id
    tile%area_fraction=1.0_real64
  end subroutine set_tile

  subroutine set_cell(cell,cell_id,coupling_id,service_id,lineage_id,slot,node)
    type(groundwater_topology_cell_t),intent(out)::cell
    integer(int64),intent(in)::cell_id,coupling_id,service_id,lineage_id
    integer,intent(in)::slot,node
    cell%groundwater_cell_id=cell_id
    cell%coupling_id=coupling_id
    cell%groundwater_service_id=service_id
    cell%groundwater_lineage_id=lineage_id
    cell%package_slot=slot
    cell%modflow_node_id=node
    cell%storage_state_role=1
    cell%drainage_owner=1
  end subroutine set_cell

  subroutine make_predictor(input,tile,cell)
    type(groundwater_tile_predictor_input_t),intent(out)::input
    type(groundwater_topology_tile_t),intent(in)::tile
    type(groundwater_topology_cell_t),intent(in)::cell
    type(groundwater_coupling_window_t)::window
    type(modflow6_swap_predictor_lineage_t)::lineage
    type(modflow6_derivative_coverage_t)::coverage
    integer::local_status

    input%tile_id=tile%tile_id
    window%t0=0.0_real64
    window%t1=1.0_real64
    lineage%coupling_id=cell%coupling_id
    lineage%swap_lineage_id=tile%swap_lineage_id
    lineage%swap_origin_revision=7_int64
    lineage%groundwater_service_id=cell%groundwater_service_id
    lineage%groundwater_lineage_id=cell%groundwater_lineage_id
    lineage%groundwater_origin_revision=9_int64
    coverage%lower_face_head_semantics_covered=.true.
    coverage%richards_hydraulic_response_covered=.true.
    coverage%constitutive_response_covered=.true.
    call compose_modflow6_swap_predictor_response(window,lineage,0.001_real64,1.0_real64,1.001_real64,0.25_real64, &
         MODFLOW6_DERIVATIVE_TRAJECTORY_TANGENT,coverage,'gwplan01','scale-benchmark',input%response,local_status)
    if (local_status /= MODFLOW6_PREDICTOR_OK .or. .not. input%response%valid) error stop 'GWPLAN01 predictor setup failed'
  end subroutine make_predictor

end program test_fpe_zero_waste01_gwplan01
