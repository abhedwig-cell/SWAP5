program test_fvq121_fgc49a_application_plan_independent
  use, intrinsic :: iso_fortran_env, only: int32, int64, real64
  use mod_groundwater_coupling_contract, only: groundwater_coupling_window_t
  use mod_groundwater_topology_composition, only: groundwater_topology_tile_t, groundwater_topology_cell_t, &
       groundwater_topology_t, materialize_groundwater_topology, GW_TOPOLOGY_OK
  use mod_groundwater_application_plan, only: groundwater_tile_predictor_input_t, groundwater_cell_area_input_t, &
       groundwater_application_plan_t, materialize_groundwater_application_plan, GW_APP_PLAN_OK
  use mod_groundwater_multiswap_types, only: groundwater_direct_tile_binding_t
  use mod_modflow6_swap_predictor_response, only: modflow6_swap_predictor_lineage_t, &
       modflow6_derivative_coverage_t, modflow6_swap_predictor_response_t, compose_modflow6_swap_predictor_response, &
       MODFLOW6_DERIVATIVE_TRAJECTORY_TANGENT, MODFLOW6_PREDICTOR_OK
  use mod_modflow6_multiswap_cell_response, only: modflow6_multiswap_cell_response_t, &
       compose_modflow6_multiswap_cell_response, MODFLOW6_MULTI_CELL_OK
  use mod_modflow6_linear_response_backend, only: modflow6_linear_boundary_term_t, &
       compose_modflow6_linear_boundary_term, MODFLOW6_LINEAR_BACKEND_OK
  use mod_modflow6_api_binding, only: modflow6_api_slot_binding_t, publish_modflow6_api_terms, MODFLOW6_API_BINDING_OK
  implicit none

  type(groundwater_topology_tile_t) :: tiles(3)
  type(groundwater_topology_cell_t) :: cells(2)
  type(groundwater_tile_predictor_input_t) :: predictors(3)
  type(groundwater_cell_area_input_t) :: areas(2)
  type(groundwater_topology_t) :: topology
  type(groundwater_application_plan_t) :: plan
  type(modflow6_linear_boundary_term_t), allocatable :: plan_terms(:)
  type(modflow6_api_slot_binding_t), allocatable :: api(:)
  type(groundwater_direct_tile_binding_t), allocatable :: b1(:), b2(:)
  type(modflow6_swap_predictor_response_t), allocatable :: r1(:), r2(:)
  type(modflow6_multiswap_cell_response_t) :: c1, c2
  type(modflow6_linear_boundary_term_t) :: direct(2)
  integer(int32) :: nodelist(4), nbound, maxbound
  real(real64) :: hcof(4), rhs(4)
  real(real64) :: href1, href2
  integer :: status

  call set_tile(tiles(1),303_int64,1303_int64,2303_int64,7002_int64,1.0_real64)
  call set_tile(tiles(2),302_int64,1302_int64,2302_int64,7001_int64,0.65_real64)
  call set_tile(tiles(3),301_int64,1301_int64,2301_int64,7001_int64,0.35_real64)
  call set_cell(cells(1),7002_int64,8302_int64,9001_int64,9302_int64,2,3)
  call set_cell(cells(2),7001_int64,8301_int64,9001_int64,9301_int64,1,2)

  call make_predictor(predictors(1),302_int64,1302_int64,8301_int64,9001_int64,9301_int64,1.006_real64)
  call make_predictor(predictors(2),303_int64,1303_int64,8302_int64,9001_int64,9302_int64,0.904_real64)
  call make_predictor(predictors(3),301_int64,1301_int64,8301_int64,9001_int64,9301_int64,1.002_real64)

  call set_area(areas(1),7002_int64,200.0_real64)
  call set_area(areas(2),7001_int64,100.0_real64)

  call materialize_groundwater_topology(tiles,cells,topology,status)
  call require(status==GW_TOPOLOGY_OK .and. topology%ready(),'topology materialized')

  call materialize_groundwater_application_plan(topology,predictors,areas,plan,status)
  call require(status==GW_APP_PLAN_OK .and. plan%ready(),'plan materialized')
  call plan%copy_linear_terms(plan_terms,status)
  call require(status==GW_APP_PLAN_OK .and. size(plan_terms)==2,'plan terms')
  call plan%copy_api_bindings(api,status)
  call require(status==GW_APP_PLAN_OK .and. size(api)==2,'plan api')

  call topology%direct_bindings_for_cell(7001_int64,b1,status)
  call require(status==GW_TOPOLOGY_OK .and. size(b1)==2,'direct cell1 bindings')
  allocate(r1(2))
  call response_for_tile(predictors,b1(1)%tile_id,r1(1))
  call response_for_tile(predictors,b1(2)%tile_id,r1(2))
  href1=b1(1)%area_fraction*r1(1)%h_bot_end_m+b1(2)%area_fraction*r1(2)%h_bot_end_m
  call compose_modflow6_multiswap_cell_response(b1,r1,href1,c1,status)
  call require(status==MODFLOW6_MULTI_CELL_OK .and. c1%valid,'direct F-GC40 cell1')
  call compose_modflow6_linear_boundary_term(c1,100.0_real64,direct(1),status)
  call require(status==MODFLOW6_LINEAR_BACKEND_OK .and. direct(1)%valid,'direct F-GC33 cell1')

  call topology%direct_bindings_for_cell(7002_int64,b2,status)
  call require(status==GW_TOPOLOGY_OK .and. size(b2)==1,'direct cell2 binding')
  allocate(r2(1))
  call response_for_tile(predictors,b2(1)%tile_id,r2(1))
  href2=r2(1)%h_bot_end_m
  call compose_modflow6_multiswap_cell_response(b2,r2,href2,c2,status)
  call require(status==MODFLOW6_MULTI_CELL_OK .and. c2%valid,'direct F-GC40 cell2')
  call compose_modflow6_linear_boundary_term(c2,200.0_real64,direct(2),status)
  call require(status==MODFLOW6_LINEAR_BACKEND_OK .and. direct(2)%valid,'direct F-GC33 cell2')

  call require(term_equal(plan_terms(1),direct(1)),'plan/direct term cell1 equivalence')
  call require(term_equal(plan_terms(2),direct(2)),'plan/direct term cell2 equivalence')

  nodelist=-99_int32
  hcof=-99.0_real64
  rhs=-99.0_real64
  nbound=0_int32
  maxbound=4_int32
  call publish_modflow6_api_terms(api,plan_terms,maxbound,nodelist,hcof,rhs,nbound,status)
  call require(status==MODFLOW6_API_BINDING_OK,'F-GC34 publication')
  call require(nbound==2_int32,'F-GC34 active prefix')
  call require(nodelist(1)==2_int32 .and. nodelist(2)==3_int32,'F-GC34 node mapping')
  call require(same(hcof(1),plan_terms(1)%hcof_m2_per_day) .and. same(rhs(1),plan_terms(1)%rhs_m3_per_day), &
       'F-GC34 term1 publication')
  call require(same(hcof(2),plan_terms(2)%hcof_m2_per_day) .and. same(rhs(2),plan_terms(2)%rhs_m3_per_day), &
       'F-GC34 term2 publication')
  call require(nodelist(3)==-99_int32 .and. nodelist(4)==-99_int32,'F-GC34 unmapped nodes untouched')
  call require(hcof(3)==-99.0_real64 .and. rhs(4)==-99.0_real64,'F-GC34 unmapped coefficients untouched')

  write(*,'(A)') 'FVQ121_PLAN_EQUALS_DIRECT_FGC40_FGC33=PASS'
  write(*,'(A)') 'FVQ121_MIXED_CELL1_N1_EQUIVALENCE=PASS'
  write(*,'(A)') 'FVQ121_MIXED_CELL2_1TO1_EQUIVALENCE=PASS'
  write(*,'(A)') 'FVQ121_PLAN_TO_FGC34_PUBLICATION=PASS'
  write(*,'(A)') 'FVQ121_API_SLOT_NODE_AND_TERM_IDENTITY=PASS'
  write(*,'(A)') 'FVQ121_UNMAPPED_API_TAIL_PRESERVED=PASS'
  write(*,'(A)') 'F-VQ121 F-GC49A INDEPENDENT QUALIFICATION PASS'

contains

  subroutine make_predictor(input,tile_id,swap_lineage,coupling_id,service_id,gw_lineage,h1)
    type(groundwater_tile_predictor_input_t),intent(out)::input
    integer(int64),intent(in)::tile_id,swap_lineage,coupling_id,service_id,gw_lineage
    real(real64),intent(in)::h1
    type(groundwater_coupling_window_t)::window
    type(modflow6_swap_predictor_lineage_t)::lineage
    type(modflow6_derivative_coverage_t)::coverage
    integer::status

    input%tile_id=tile_id
    window%t0=2.0_real64
    window%t1=2.5_real64
    lineage%coupling_id=coupling_id
    lineage%swap_lineage_id=swap_lineage
    lineage%swap_origin_revision=7_int64
    lineage%groundwater_service_id=service_id
    lineage%groundwater_lineage_id=gw_lineage
    lineage%groundwater_origin_revision=9_int64
    coverage%lower_face_head_semantics_covered=.true.
    coverage%richards_hydraulic_response_covered=.true.
    coverage%constitutive_response_covered=.true.
    call compose_modflow6_swap_predictor_response(window,lineage,0.001_real64,1.0_real64,h1,0.25_real64, &
         MODFLOW6_DERIVATIVE_TRAJECTORY_TANGENT,coverage,'fvq121','direct-equivalence',input%response,status)
    call require(status==MODFLOW6_PREDICTOR_OK .and. input%response%valid,'predictor fixture')
  end subroutine make_predictor

  subroutine response_for_tile(inputs,tile_id,response)
    type(groundwater_tile_predictor_input_t),intent(in)::inputs(:)
    integer(int64),intent(in)::tile_id
    type(modflow6_swap_predictor_response_t),intent(out)::response
    integer::i
    do i=1,size(inputs)
      if(inputs(i)%tile_id==tile_id)then
        response=inputs(i)%response
        return
      end if
    end do
    call require(.false.,'response tile lookup')
  end subroutine response_for_tile

  pure logical function term_equal(a,b) result(equal)
    type(modflow6_linear_boundary_term_t),intent(in)::a,b
    equal=a%valid .and. b%valid
    if(.not.equal)return
    equal=a%groundwater_cell_id==b%groundwater_cell_id .and. &
         a%coupling_id==b%coupling_id .and. &
         a%groundwater_service_id==b%groundwater_service_id .and. &
         a%groundwater_lineage_id==b%groundwater_lineage_id .and. &
         a%groundwater_origin_revision==b%groundwater_origin_revision .and. &
         same(a%cell_area_m2,b%cell_area_m2) .and. &
         same(a%reference_head_m,b%reference_head_m) .and. &
         same(a%q_u_at_reference_m_per_s,b%q_u_at_reference_m_per_s) .and. &
         same(a%dq_u_dh_per_s,b%dq_u_dh_per_s) .and. &
         same(a%hcof_m2_per_day,b%hcof_m2_per_day) .and. &
         same(a%rhs_m3_per_day,b%rhs_m3_per_day)
  end function term_equal

  subroutine set_tile(tile,tile_id,lineage_id,ledger_id,cell_id,fraction)
    type(groundwater_topology_tile_t),intent(out)::tile
    integer(int64),intent(in)::tile_id,lineage_id,ledger_id,cell_id
    real(real64),intent(in)::fraction
    tile%tile_id=tile_id
    tile%swap_lineage_id=lineage_id
    tile%ledger_id=ledger_id
    tile%groundwater_cell_id=cell_id
    tile%area_fraction=fraction
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
  end subroutine set_cell

  subroutine set_area(area,cell_id,value)
    type(groundwater_cell_area_input_t),intent(out)::area
    integer(int64),intent(in)::cell_id
    real(real64),intent(in)::value
    area%groundwater_cell_id=cell_id
    area%cell_area_m2=value
  end subroutine set_area

  pure logical function same(a,b) result(matches)
    real(real64),intent(in)::a,b
    real(real64)::scale
    scale=max(1.0_real64,abs(a),abs(b))
    matches=abs(a-b)<=128.0_real64*epsilon(1.0_real64)*scale
  end function same

  subroutine require(condition,message)
    logical,intent(in)::condition
    character(len=*),intent(in)::message
    if(.not.condition)then
      write(*,'(A,1X,A)')'FVQ121_FAIL',trim(message)
      error stop 1
    end if
  end subroutine require
end program test_fvq121_fgc49a_application_plan_independent
