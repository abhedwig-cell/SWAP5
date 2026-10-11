program test_fvq120_fgc48_downstream_compatibility
  use, intrinsic :: iso_fortran_env, only: int32, int64, real64
  use mod_groundwater_topology_composition, only: groundwater_topology_tile_t, groundwater_topology_cell_t, &
       groundwater_topology_t, materialize_groundwater_topology, GW_TOPOLOGY_OK
  use mod_groundwater_multiswap_types, only: groundwater_direct_tile_binding_t
  use mod_groundwater_coupling_contract, only: groundwater_coupling_window_t
  use mod_modflow6_swap_predictor_response, only: modflow6_swap_predictor_lineage_t, &
       modflow6_derivative_coverage_t, modflow6_swap_predictor_response_t, &
       compose_modflow6_swap_predictor_response, MODFLOW6_DERIVATIVE_TRAJECTORY_TANGENT, MODFLOW6_PREDICTOR_OK
  use mod_modflow6_multiswap_cell_response, only: modflow6_multiswap_cell_response_t, &
       compose_modflow6_multiswap_cell_response, MODFLOW6_MULTI_CELL_OK
  use mod_modflow6_linear_response_backend, only: modflow6_linear_boundary_term_t, &
       compose_modflow6_linear_boundary_term, MODFLOW6_LINEAR_BACKEND_OK
  use mod_modflow6_api_binding, only: modflow6_api_slot_binding_t, publish_modflow6_api_terms, &
       MODFLOW6_API_BINDING_OK
  implicit none

  type(groundwater_topology_tile_t) :: tiles(3)
  type(groundwater_topology_cell_t) :: cells(2)
  type(groundwater_topology_t) :: topology
  type(groundwater_direct_tile_binding_t), allocatable :: b1(:), b2(:)
  type(modflow6_api_slot_binding_t), allocatable :: api(:)
  type(modflow6_swap_predictor_response_t) :: r1(2), r2(1)
  type(modflow6_multiswap_cell_response_t) :: c1, c2
  type(modflow6_linear_boundary_term_t) :: terms(2)
  integer(int32) :: nodelist(4), nbound, maxbound
  real(real64) :: hcof(4), rhs(4)
  integer :: status

  call set_tile(tiles(1), 570049_int64, 570049_int64, 770049_int64, 7002_int64, 1.0_real64)
  call set_tile(tiles(2), 570048_int64, 570048_int64, 770048_int64, 7001_int64, 0.65_real64)
  call set_tile(tiles(3), 570047_int64, 570047_int64, 770047_int64, 7001_int64, 0.35_real64)
  call set_cell(cells(1), 7002_int64, 470048_int64, 670046_int64, 670048_int64, 2, 3)
  call set_cell(cells(2), 7001_int64, 470047_int64, 670046_int64, 670047_int64, 1, 2)

  call materialize_groundwater_topology(tiles,cells,topology,status)
  call require(status==GW_TOPOLOGY_OK .and. topology%ready(),'generic topology materialization')

  call topology%direct_bindings_for_cell(7001_int64,b1,status)
  call require(status==GW_TOPOLOGY_OK .and. size(b1)==2,'cell 7001 binding materialization')
  call topology%direct_bindings_for_cell(7002_int64,b2,status)
  call require(status==GW_TOPOLOGY_OK .and. size(b2)==1,'cell 7002 binding materialization')

  call make_response(570047_int64,470047_int64,670047_int64,r1(1),0.004_real64,0.25_real64)
  call make_response(570048_int64,470047_int64,670047_int64,r1(2),0.006_real64,0.50_real64)
  call make_response(570049_int64,470048_int64,670048_int64,r2(1),0.005_real64,0.40_real64)

  call compose_modflow6_multiswap_cell_response(b1,r1,1.005_real64,c1,status)
  call require(status==MODFLOW6_MULTI_CELL_OK .and. c1%valid,'F-GC40 accepts generic N:1 bindings')
  call compose_modflow6_multiswap_cell_response(b2,r2,r2(1)%h_bot_end_m,c2,status)
  call require(status==MODFLOW6_MULTI_CELL_OK .and. c2%valid,'F-GC40 accepts generic 1:1 binding')

  call compose_modflow6_linear_boundary_term(c1,1.0_real64,terms(1),status)
  call require(status==MODFLOW6_LINEAR_BACKEND_OK .and. terms(1)%valid,'cell 7001 linear term')
  call compose_modflow6_linear_boundary_term(c2,1.0_real64,terms(2),status)
  call require(status==MODFLOW6_LINEAR_BACKEND_OK .and. terms(2)%valid,'cell 7002 linear term')

  call topology%api_bindings(api,status)
  call require(status==GW_TOPOLOGY_OK .and. size(api)==2,'generic API binding materialization')
  nodelist=-99_int32; hcof=-99.0_real64; rhs=-99.0_real64
  nbound=0_int32; maxbound=4_int32
  call publish_modflow6_api_terms(api,terms,maxbound,nodelist,hcof,rhs,nbound,status)
  call require(status==MODFLOW6_API_BINDING_OK,'F-GC34 accepts generic API bindings')
  call require(nbound==2_int32,'active API prefix count')
  call require(nodelist(1)==2_int32 .and. nodelist(2)==3_int32,'slot/node mapping')
  call require(nodelist(3)==-99_int32 .and. nodelist(4)==-99_int32,'unmapped nodelist tail preserved')
  call require(hcof(3)==-99.0_real64 .and. rhs(4)==-99.0_real64,'unmapped coefficient tail preserved')

  write(*,'(A)') 'FVQ120_GENERIC_TO_FGC40_N1_BINDING=PASS'
  write(*,'(A)') 'FVQ120_GENERIC_TO_FGC40_1TO1_BINDING=PASS'
  write(*,'(A)') 'FVQ120_GENERIC_TO_FGC34_API_BINDING=PASS'
  write(*,'(A)') 'FVQ120_CANONICAL_SLOT_NODE_PUBLICATION=PASS'
  write(*,'(A)') 'FVQ120_UNMAPPED_API_TAIL_PRESERVED=PASS'
  write(*,'(A)') 'F-VQ120 F-GC48 DOWNSTREAM COMPATIBILITY PASS'

contains

  subroutine make_response(swap_lineage,coupling_id,gw_lineage,response,head_delta,u)
    integer(int64),intent(in)::swap_lineage,coupling_id,gw_lineage
    type(modflow6_swap_predictor_response_t),intent(out)::response
    real(real64),intent(in)::head_delta,u
    type(groundwater_coupling_window_t)::window
    type(modflow6_swap_predictor_lineage_t)::lineage
    type(modflow6_derivative_coverage_t)::coverage
    integer::status

    window%t0=10.0_real64; window%t1=10.5_real64
    lineage%coupling_id=coupling_id
    lineage%swap_lineage_id=swap_lineage
    lineage%swap_origin_revision=7_int64
    lineage%groundwater_service_id=670046_int64
    lineage%groundwater_lineage_id=gw_lineage
    lineage%groundwater_origin_revision=9_int64
    coverage%lower_face_head_semantics_covered=.true.
    coverage%richards_hydraulic_response_covered=.true.
    coverage%constitutive_response_covered=.true.
    call compose_modflow6_swap_predictor_response(window,lineage,-0.1_real64,1.0_real64,1.0_real64+head_delta,u, &
         MODFLOW6_DERIVATIVE_TRAJECTORY_TANGENT,coverage,'fvq120','generic-topology-compatibility',response,status)
    call require(status==MODFLOW6_PREDICTOR_OK .and. response%valid,'response fixture')
  end subroutine make_response

  subroutine set_tile(tile,tile_id,lineage_id,ledger_id,cell_id,fraction)
    type(groundwater_topology_tile_t),intent(out)::tile
    integer(int64),intent(in)::tile_id,lineage_id,ledger_id,cell_id
    real(real64),intent(in)::fraction
    tile%tile_id=tile_id; tile%swap_lineage_id=lineage_id; tile%ledger_id=ledger_id
    tile%groundwater_cell_id=cell_id; tile%area_fraction=fraction
  end subroutine set_tile

  subroutine set_cell(cell,cell_id,coupling_id,service_id,lineage_id,slot,node)
    type(groundwater_topology_cell_t),intent(out)::cell
    integer(int64),intent(in)::cell_id,coupling_id,service_id,lineage_id
    integer,intent(in)::slot,node
    cell%groundwater_cell_id=cell_id; cell%coupling_id=coupling_id
    cell%groundwater_service_id=service_id; cell%groundwater_lineage_id=lineage_id
    cell%package_slot=slot; cell%modflow_node_id=node
  end subroutine set_cell

  subroutine require(condition,message)
    logical,intent(in)::condition
    character(len=*),intent(in)::message
    if(.not.condition)then
      write(*,'(A,1X,A)')'FVQ120_FAIL',trim(message)
      error stop 1
    end if
  end subroutine require
end program test_fvq120_fgc48_downstream_compatibility
