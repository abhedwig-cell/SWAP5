program test_fgc49a_groundwater_application_plan
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_groundwater_coupling_contract, only: groundwater_coupling_window_t
  use mod_groundwater_topology_composition, only: groundwater_topology_tile_t, groundwater_topology_cell_t, &
       groundwater_topology_t, materialize_groundwater_topology, GW_TOPOLOGY_OK
  use mod_groundwater_application_plan, only: groundwater_tile_predictor_input_t, groundwater_cell_area_input_t, &
       groundwater_application_cell_plan_t, groundwater_application_plan_t, materialize_groundwater_application_plan, &
       GW_APP_PLAN_OK, GW_APP_PLAN_INVALID_PREDICTOR_COUNT, GW_APP_PLAN_DUPLICATE_PREDICTOR_TILE, &
       GW_APP_PLAN_MISSING_PREDICTOR_TILE, GW_APP_PLAN_PREDICTOR_LINEAGE_MISMATCH, &
       GW_APP_PLAN_PREDICTOR_CELL_MISMATCH, GW_APP_PLAN_WINDOW_MISMATCH, GW_APP_PLAN_SERVICE_MISMATCH, &
       GW_APP_PLAN_INVALID_AREA_COUNT, GW_APP_PLAN_INVALID_AREA, GW_APP_PLAN_DUPLICATE_AREA_CELL, &
       GW_APP_PLAN_MISSING_AREA_CELL
  use mod_modflow6_swap_predictor_response, only: modflow6_swap_predictor_lineage_t, &
       modflow6_derivative_coverage_t, compose_modflow6_swap_predictor_response, MODFLOW6_PREDICTOR_OK, &
       MODFLOW6_DERIVATIVE_TRAJECTORY_TANGENT
  use mod_modflow6_linear_response_backend, only: modflow6_linear_boundary_term_t
  use mod_modflow6_api_binding, only: modflow6_api_slot_binding_t
  implicit none

  call qualify_one_to_one()
  call qualify_n_to_one()
  call qualify_multicell()
  call qualify_mixed()
  call qualify_order_invariance()
  call qualify_canonical_fastpath_equivalence()
  call qualify_fail_closed()

  write(*,'(A)') 'FGC49A_FGC44_ONE_TO_ONE_PLAN=PASS'
  write(*,'(A)') 'FGC49A_FGC45_N_TO_ONE_PLAN=PASS'
  write(*,'(A)') 'FGC49A_FGC46_MULTICELL_PLAN=PASS'
  write(*,'(A)') 'FGC49A_FGC47_MIXED_PLAN=PASS'
  write(*,'(A)') 'FGC49A_INPUT_ORDER_INVARIANCE=PASS'
  write(*,'(A)') 'FGC49A_CANONICAL_FASTPATH_EQUIVALENCE=PASS'
  write(*,'(A)') 'FGC49A_FAIL_CLOSED_PROVENANCE_AND_AREA=PASS'
  write(*,'(A)') 'F-GC49A APPLICATION PLAN GATE PASS'

contains

  subroutine qualify_one_to_one()
    type(groundwater_topology_tile_t) :: tiles(1)
    type(groundwater_topology_cell_t) :: cells(1)
    type(groundwater_tile_predictor_input_t) :: predictors(1)
    type(groundwater_cell_area_input_t) :: areas(1)
    type(groundwater_topology_t) :: topology
    type(groundwater_application_plan_t) :: plan
    type(groundwater_application_cell_plan_t), allocatable :: plans(:)
    type(modflow6_api_slot_binding_t), allocatable :: api(:)
    integer :: status

    call set_tile(tiles(1),101_int64,1001_int64,2001_int64,7001_int64,1.0_real64)
    call set_cell(cells(1),7001_int64,8001_int64,9001_int64,9101_int64,1,2)
    call build_topology(tiles,cells,topology)
    call make_predictor(predictors(1),101_int64,1001_int64,8001_int64,9001_int64,9101_int64, &
         0.0_real64,0.5_real64,1.000_real64,1.004_real64)
    call set_area(areas(1),7001_int64,100.0_real64)

    call materialize_groundwater_application_plan(topology,predictors,areas,plan,status)
    call require(status==GW_APP_PLAN_OK .and. plan%ready(),'1:1 plan materialized')
    call require(plan%tile_count()==1 .and. plan%cell_count()==1,'1:1 plan counts')
    call plan%copy_cells(plans,status)
    call require(status==GW_APP_PLAN_OK .and. size(plans)==1,'1:1 cell copy')
    call require(plans(1)%topology%groundwater_cell_id==7001_int64,'1:1 cell id')
    call require(plans(1)%tile_begin==1 .and. plans(1)%tile_count==1,'1:1 route')
    call require(same(plans(1)%reference_head_m,predictors(1)%response%h_bot_end_m),'1:1 reference head')
    call require(plans(1)%linear_term%valid .and. same(plans(1)%linear_term%cell_area_m2,100.0_real64), &
         '1:1 linear term')
    call plan%copy_api_bindings(api,status)
    call require(status==GW_APP_PLAN_OK .and. api(1)%package_slot==1 .and. api(1)%modflow_node_id==2,'1:1 API')
  end subroutine qualify_one_to_one

  subroutine qualify_n_to_one()
    type(groundwater_topology_tile_t) :: tiles(2)
    type(groundwater_topology_cell_t) :: cells(1)
    type(groundwater_tile_predictor_input_t) :: predictors(2)
    type(groundwater_cell_area_input_t) :: areas(1)
    type(groundwater_topology_t) :: topology
    type(groundwater_application_plan_t) :: plan
    type(groundwater_application_cell_plan_t), allocatable :: plans(:)
    real(real64) :: expected_reference
    integer :: status

    call set_tile(tiles(1),102_int64,1002_int64,2002_int64,7001_int64,0.65_real64)
    call set_tile(tiles(2),101_int64,1001_int64,2001_int64,7001_int64,0.35_real64)
    call set_cell(cells(1),7001_int64,8001_int64,9001_int64,9101_int64,1,2)
    call build_topology(tiles,cells,topology)
    call make_predictor(predictors(1),102_int64,1002_int64,8001_int64,9001_int64,9101_int64, &
         0.0_real64,0.5_real64,1.000_real64,1.006_real64)
    call make_predictor(predictors(2),101_int64,1001_int64,8001_int64,9001_int64,9101_int64, &
         0.0_real64,0.5_real64,1.000_real64,1.002_real64)
    call set_area(areas(1),7001_int64,125.0_real64)

    call materialize_groundwater_application_plan(topology,predictors,areas,plan,status)
    call require(status==GW_APP_PLAN_OK .and. plan%ready(),'N:1 plan materialized')
    call plan%copy_cells(plans,status)
    expected_reference=0.35_real64*predictors(2)%response%h_bot_end_m+0.65_real64*predictors(1)%response%h_bot_end_m
    call require(plans(1)%tile_begin==1 .and. plans(1)%tile_count==2,'N:1 route')
    call require(same(plans(1)%reference_head_m,expected_reference),'N:1 area-weighted reference')
    call require(plans(1)%response%tile_count==2 .and. same(plans(1)%response%fraction_sum,1.0_real64), &
         'N:1 F-GC40 response')
  end subroutine qualify_n_to_one

  subroutine qualify_multicell()
    type(groundwater_topology_tile_t) :: tiles(2)
    type(groundwater_topology_cell_t) :: cells(2)
    type(groundwater_tile_predictor_input_t) :: predictors(2)
    type(groundwater_cell_area_input_t) :: areas(2)
    type(groundwater_topology_t) :: topology
    type(groundwater_application_plan_t) :: plan
    type(groundwater_application_cell_plan_t), allocatable :: plans(:)
    type(modflow6_api_slot_binding_t), allocatable :: api(:)
    integer :: status

    call set_tile(tiles(1),202_int64,1202_int64,2202_int64,7002_int64,1.0_real64)
    call set_tile(tiles(2),201_int64,1201_int64,2201_int64,7001_int64,1.0_real64)
    call set_cell(cells(1),7002_int64,8202_int64,9001_int64,9202_int64,2,3)
    call set_cell(cells(2),7001_int64,8201_int64,9001_int64,9201_int64,1,2)
    call build_topology(tiles,cells,topology)

    call make_predictor(predictors(1),202_int64,1202_int64,8202_int64,9001_int64,9202_int64, &
         1.0_real64,1.5_real64,0.900_real64,0.905_real64)
    call make_predictor(predictors(2),201_int64,1201_int64,8201_int64,9001_int64,9201_int64, &
         1.0_real64,1.5_real64,1.100_real64,1.103_real64)
    call set_area(areas(1),7002_int64,200.0_real64)
    call set_area(areas(2),7001_int64,100.0_real64)

    call materialize_groundwater_application_plan(topology,predictors,areas,plan,status)
    call require(status==GW_APP_PLAN_OK .and. plan%ready(),'multi-cell plan materialized')
    call plan%copy_cells(plans,status)
    call require(plans(1)%topology%groundwater_cell_id==7001_int64 .and. &
         plans(2)%topology%groundwater_cell_id==7002_int64,'multi-cell canonical order')
    call require(plans(1)%tile_begin==1 .and. plans(2)%tile_begin==2,'multi-cell tile ranges')
    call require(same(plans(1)%linear_term%cell_area_m2,100.0_real64) .and. &
         same(plans(2)%linear_term%cell_area_m2,200.0_real64),'multi-cell area routing')
    call plan%copy_api_bindings(api,status)
    call require(api(1)%groundwater_cell_id==7001_int64 .and. api(1)%modflow_node_id==2,'multi-cell api slot1')
    call require(api(2)%groundwater_cell_id==7002_int64 .and. api(2)%modflow_node_id==3,'multi-cell api slot2')
  end subroutine qualify_multicell

  subroutine qualify_mixed()
    type(groundwater_topology_tile_t) :: tiles(3)
    type(groundwater_topology_cell_t) :: cells(2)
    type(groundwater_tile_predictor_input_t) :: predictors(3)
    type(groundwater_cell_area_input_t) :: areas(2)
    type(groundwater_topology_t) :: topology
    type(groundwater_application_plan_t) :: plan
    type(groundwater_application_cell_plan_t), allocatable :: plans(:)
    integer :: status

    call mixed_fixture(tiles,cells,predictors,areas)
    call build_topology(tiles,cells,topology)
    call materialize_groundwater_application_plan(topology,predictors,areas,plan,status)
    call require(status==GW_APP_PLAN_OK .and. plan%ready(),'mixed plan materialized')
    call plan%copy_cells(plans,status)
    call require(size(plans)==2,'mixed cell count')
    call require(plans(1)%topology%groundwater_cell_id==7001_int64 .and. plans(1)%tile_count==2,'mixed N:1 cell')
    call require(plans(2)%topology%groundwater_cell_id==7002_int64 .and. plans(2)%tile_count==1,'mixed 1:1 cell')
    call require(plans(1)%tile_begin==1 .and. plans(2)%tile_begin==3,'mixed canonical tile ranges')
  end subroutine qualify_mixed

  subroutine qualify_order_invariance()
    type(groundwater_topology_tile_t) :: tiles_a(3),tiles_b(3)
    type(groundwater_topology_cell_t) :: cells_a(2),cells_b(2)
    type(groundwater_tile_predictor_input_t) :: pred_a(3),pred_b(3)
    type(groundwater_cell_area_input_t) :: area_a(2),area_b(2)
    type(groundwater_topology_t) :: topology_a,topology_b
    type(groundwater_application_plan_t) :: plan_a,plan_b
    type(groundwater_application_cell_plan_t), allocatable :: ca(:),cb(:)
    type(modflow6_linear_boundary_term_t), allocatable :: ta(:),tb(:)
    type(modflow6_api_slot_binding_t), allocatable :: aa(:),ab(:)
    integer :: status,i

    call mixed_fixture(tiles_a,cells_a,pred_a,area_a)
    tiles_b=[tiles_a(2),tiles_a(3),tiles_a(1)]
    cells_b=[cells_a(2),cells_a(1)]
    pred_b=[pred_a(3),pred_a(1),pred_a(2)]
    area_b=[area_a(2),area_a(1)]

    call build_topology(tiles_a,cells_a,topology_a)
    call build_topology(tiles_b,cells_b,topology_b)
    call materialize_groundwater_application_plan(topology_a,pred_a,area_a,plan_a,status)
    call require(status==GW_APP_PLAN_OK,'order plan A')
    call materialize_groundwater_application_plan(topology_b,pred_b,area_b,plan_b,status)
    call require(status==GW_APP_PLAN_OK,'order plan B')

    call plan_a%copy_cells(ca,status); call require(status==GW_APP_PLAN_OK,'copy cells A')
    call plan_b%copy_cells(cb,status); call require(status==GW_APP_PLAN_OK,'copy cells B')
    call plan_a%copy_linear_terms(ta,status); call require(status==GW_APP_PLAN_OK,'copy terms A')
    call plan_b%copy_linear_terms(tb,status); call require(status==GW_APP_PLAN_OK,'copy terms B')
    call plan_a%copy_api_bindings(aa,status); call require(status==GW_APP_PLAN_OK,'copy api A')
    call plan_b%copy_api_bindings(ab,status); call require(status==GW_APP_PLAN_OK,'copy api B')

    do i=1,size(ca)
      call require(ca(i)%topology%groundwater_cell_id==cb(i)%topology%groundwater_cell_id,'order cell id')
      call require(ca(i)%tile_begin==cb(i)%tile_begin .and. ca(i)%tile_count==cb(i)%tile_count,'order tile range')
      call require(same(ca(i)%reference_head_m,cb(i)%reference_head_m),'order reference head')
      call require(same(ta(i)%hcof_m2_per_day,tb(i)%hcof_m2_per_day) .and. &
           same(ta(i)%rhs_m3_per_day,tb(i)%rhs_m3_per_day),'order linear term')
      call require(aa(i)%groundwater_cell_id==ab(i)%groundwater_cell_id .and. &
           aa(i)%package_slot==ab(i)%package_slot .and. aa(i)%modflow_node_id==ab(i)%modflow_node_id,'order api')
    end do
  end subroutine qualify_order_invariance

  subroutine qualify_canonical_fastpath_equivalence()
    type(groundwater_topology_tile_t) :: tiles(3)
    type(groundwater_topology_cell_t) :: cells(2)
    type(groundwater_tile_predictor_input_t) :: pred_generic(3),pred_fast(3)
    type(groundwater_cell_area_input_t) :: area_generic(2),area_fast(2)
    type(groundwater_topology_t) :: topology
    type(groundwater_application_plan_t) :: plan_generic,plan_fast
    type(groundwater_application_cell_plan_t), allocatable :: cg(:),cf(:)
    type(modflow6_linear_boundary_term_t), allocatable :: tg(:),tf(:)
    type(modflow6_api_slot_binding_t), allocatable :: ag(:),af(:)
    integer(int64), allocatable :: rg(:),rf(:)
    integer :: status,i

    call mixed_fixture(tiles,cells,pred_generic,area_generic)
    call build_topology(tiles,cells,topology)

    ! Topology canonicalizes mixed_fixture to tiles 301,302,303 and cells 7001,7002.
    ! Keep the original shuffled inputs as the generic-fallback oracle.
    pred_fast=[pred_generic(3),pred_generic(1),pred_generic(2)]
    area_fast=[area_generic(2),area_generic(1)]

    call materialize_groundwater_application_plan(topology,pred_generic,area_generic,plan_generic,status)
    call require(status==GW_APP_PLAN_OK .and. plan_generic%ready(),'fastpath generic oracle')
    call materialize_groundwater_application_plan(topology,pred_fast,area_fast,plan_fast,status)
    call require(status==GW_APP_PLAN_OK .and. plan_fast%ready(),'fastpath aligned candidate')

    call plan_generic%copy_cells(cg,status); call require(status==GW_APP_PLAN_OK,'fastpath generic cells')
    call plan_fast%copy_cells(cf,status); call require(status==GW_APP_PLAN_OK,'fastpath candidate cells')
    call plan_generic%copy_linear_terms(tg,status); call require(status==GW_APP_PLAN_OK,'fastpath generic terms')
    call plan_fast%copy_linear_terms(tf,status); call require(status==GW_APP_PLAN_OK,'fastpath candidate terms')
    call plan_generic%copy_api_bindings(ag,status); call require(status==GW_APP_PLAN_OK,'fastpath generic api')
    call plan_fast%copy_api_bindings(af,status); call require(status==GW_APP_PLAN_OK,'fastpath candidate api')
    call plan_generic%copy_tile_swap_origin_revisions(rg,status)
    call require(status==GW_APP_PLAN_OK,'fastpath generic revisions')
    call plan_fast%copy_tile_swap_origin_revisions(rf,status)
    call require(status==GW_APP_PLAN_OK,'fastpath candidate revisions')

    call require(size(cg)==size(cf) .and. size(tg)==size(tf) .and. size(ag)==size(af) .and. size(rg)==size(rf), &
         'fastpath transcript shapes')
    call require(all(rg==rf),'fastpath revision identity')
    do i=1,size(cg)
      call require(cg(i)%topology%groundwater_cell_id==cf(i)%topology%groundwater_cell_id, &
           'fastpath cell identity')
      call require(cg(i)%tile_begin==cf(i)%tile_begin .and. cg(i)%tile_count==cf(i)%tile_count, &
           'fastpath tile range identity')
      call require(cg(i)%reference_head_m==cf(i)%reference_head_m,'fastpath reference-head bit identity')
      call require(tg(i)%groundwater_cell_id==tf(i)%groundwater_cell_id .and. &
           tg(i)%hcof_m2_per_day==tf(i)%hcof_m2_per_day .and. tg(i)%rhs_m3_per_day==tf(i)%rhs_m3_per_day, &
           'fastpath linear-term bit identity')
      call require(ag(i)%groundwater_cell_id==af(i)%groundwater_cell_id .and. &
           ag(i)%package_slot==af(i)%package_slot .and. ag(i)%modflow_node_id==af(i)%modflow_node_id, &
           'fastpath api identity')
    end do
  end subroutine qualify_canonical_fastpath_equivalence

  subroutine qualify_fail_closed()
    type(groundwater_topology_tile_t) :: tiles(3)
    type(groundwater_topology_cell_t) :: cells(2),bad_cells(2)
    type(groundwater_tile_predictor_input_t) :: predictors(3),bad_predictors(3),short_predictors(2)
    type(groundwater_cell_area_input_t) :: areas(2),bad_areas(2),short_areas(1)
    type(groundwater_topology_t) :: topology,bad_topology
    type(groundwater_application_plan_t) :: plan
    integer :: status

    call mixed_fixture(tiles,cells,predictors,areas)
    call build_topology(tiles,cells,topology)

    short_predictors=predictors(1:2)
    call materialize_groundwater_application_plan(topology,short_predictors,areas,plan,status)
    call expect_failure(plan,status,GW_APP_PLAN_INVALID_PREDICTOR_COUNT,'predictor count')

    bad_predictors=predictors
    bad_predictors(3)%tile_id=bad_predictors(1)%tile_id
    call materialize_groundwater_application_plan(topology,bad_predictors,areas,plan,status)
    call expect_failure(plan,status,GW_APP_PLAN_DUPLICATE_PREDICTOR_TILE,'duplicate predictor tile')

    bad_predictors=predictors
    bad_predictors(3)%tile_id=9999_int64
    call materialize_groundwater_application_plan(topology,bad_predictors,areas,plan,status)
    call expect_failure(plan,status,GW_APP_PLAN_MISSING_PREDICTOR_TILE,'missing predictor tile')

    bad_predictors=predictors
    bad_predictors(1)%response%lineage%swap_lineage_id=9999_int64
    call materialize_groundwater_application_plan(topology,bad_predictors,areas,plan,status)
    call expect_failure(plan,status,GW_APP_PLAN_PREDICTOR_LINEAGE_MISMATCH,'predictor lineage')

    bad_predictors=predictors
    bad_predictors(1)%response%lineage%coupling_id=9999_int64
    call materialize_groundwater_application_plan(topology,bad_predictors,areas,plan,status)
    call expect_failure(plan,status,GW_APP_PLAN_PREDICTOR_CELL_MISMATCH,'predictor cell provenance')

    bad_predictors=predictors
    bad_predictors(3)%response%window%t1=bad_predictors(3)%response%window%t1+0.25_real64
    call materialize_groundwater_application_plan(topology,bad_predictors,areas,plan,status)
    call expect_failure(plan,status,GW_APP_PLAN_WINDOW_MISMATCH,'window mismatch')

    bad_cells=cells
    bad_cells(2)%groundwater_service_id=9002_int64
    call build_topology(tiles,bad_cells,bad_topology)
    bad_predictors=predictors
    bad_predictors(3)%response%lineage%groundwater_service_id=9002_int64
    call materialize_groundwater_application_plan(bad_topology,bad_predictors,areas,plan,status)
    call expect_failure(plan,status,GW_APP_PLAN_SERVICE_MISMATCH,'service mismatch')

    short_areas=areas(1:1)
    call materialize_groundwater_application_plan(topology,predictors,short_areas,plan,status)
    call expect_failure(plan,status,GW_APP_PLAN_INVALID_AREA_COUNT,'area count')

    bad_areas=areas
    bad_areas(1)%cell_area_m2=0.0_real64
    call materialize_groundwater_application_plan(topology,predictors,bad_areas,plan,status)
    call expect_failure(plan,status,GW_APP_PLAN_INVALID_AREA,'invalid area')

    bad_areas=areas
    bad_areas(2)%groundwater_cell_id=bad_areas(1)%groundwater_cell_id
    call materialize_groundwater_application_plan(topology,predictors,bad_areas,plan,status)
    call expect_failure(plan,status,GW_APP_PLAN_DUPLICATE_AREA_CELL,'duplicate area')

    bad_areas=areas
    bad_areas(2)%groundwater_cell_id=9999_int64
    call materialize_groundwater_application_plan(topology,predictors,bad_areas,plan,status)
    call expect_failure(plan,status,GW_APP_PLAN_MISSING_AREA_CELL,'missing area')
  end subroutine qualify_fail_closed

  subroutine mixed_fixture(tiles,cells,predictors,areas)
    type(groundwater_topology_tile_t),intent(out)::tiles(3)
    type(groundwater_topology_cell_t),intent(out)::cells(2)
    type(groundwater_tile_predictor_input_t),intent(out)::predictors(3)
    type(groundwater_cell_area_input_t),intent(out)::areas(2)

    call set_tile(tiles(1),303_int64,1303_int64,2303_int64,7002_int64,1.0_real64)
    call set_tile(tiles(2),302_int64,1302_int64,2302_int64,7001_int64,0.65_real64)
    call set_tile(tiles(3),301_int64,1301_int64,2301_int64,7001_int64,0.35_real64)
    call set_cell(cells(1),7002_int64,8302_int64,9001_int64,9302_int64,2,3)
    call set_cell(cells(2),7001_int64,8301_int64,9001_int64,9301_int64,1,2)

    call make_predictor(predictors(1),302_int64,1302_int64,8301_int64,9001_int64,9301_int64, &
         2.0_real64,2.5_real64,1.000_real64,1.006_real64)
    call make_predictor(predictors(2),303_int64,1303_int64,8302_int64,9001_int64,9302_int64, &
         2.0_real64,2.5_real64,0.900_real64,0.904_real64)
    call make_predictor(predictors(3),301_int64,1301_int64,8301_int64,9001_int64,9301_int64, &
         2.0_real64,2.5_real64,1.000_real64,1.002_real64)

    call set_area(areas(1),7002_int64,200.0_real64)
    call set_area(areas(2),7001_int64,100.0_real64)
  end subroutine mixed_fixture

  subroutine build_topology(tiles,cells,topology)
    type(groundwater_topology_tile_t),intent(in)::tiles(:)
    type(groundwater_topology_cell_t),intent(in)::cells(:)
    type(groundwater_topology_t),intent(out)::topology
    integer::status
    call materialize_groundwater_topology(tiles,cells,topology,status)
    call require(status==GW_TOPOLOGY_OK .and. topology%ready(),'fixture topology')
  end subroutine build_topology

  subroutine make_predictor(input,tile_id,swap_lineage,coupling_id,service_id,gw_lineage,t0,t1,h0,h1)
    type(groundwater_tile_predictor_input_t),intent(out)::input
    integer(int64),intent(in)::tile_id,swap_lineage,coupling_id,service_id,gw_lineage
    real(real64),intent(in)::t0,t1,h0,h1
    type(groundwater_coupling_window_t)::window
    type(modflow6_swap_predictor_lineage_t)::lineage
    type(modflow6_derivative_coverage_t)::coverage
    integer::status

    input%tile_id=tile_id
    window%t0=t0; window%t1=t1
    lineage%coupling_id=coupling_id
    lineage%swap_lineage_id=swap_lineage
    lineage%swap_origin_revision=7_int64
    lineage%groundwater_service_id=service_id
    lineage%groundwater_lineage_id=gw_lineage
    lineage%groundwater_origin_revision=9_int64
    coverage%lower_face_head_semantics_covered=.true.
    coverage%richards_hydraulic_response_covered=.true.
    coverage%constitutive_response_covered=.true.
    call compose_modflow6_swap_predictor_response(window,lineage,0.001_real64,h0,h1,0.25_real64, &
         MODFLOW6_DERIVATIVE_TRAJECTORY_TANGENT,coverage,'fgc49a','application-plan-fixture',input%response,status)
    call require(status==MODFLOW6_PREDICTOR_OK .and. input%response%valid,'predictor fixture')
  end subroutine make_predictor

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

  subroutine set_area(area,cell_id,value)
    type(groundwater_cell_area_input_t),intent(out)::area
    integer(int64),intent(in)::cell_id
    real(real64),intent(in)::value
    area%groundwater_cell_id=cell_id; area%cell_area_m2=value
  end subroutine set_area

  subroutine expect_failure(plan,status,expected,label)
    type(groundwater_application_plan_t),intent(in)::plan
    integer,intent(in)::status,expected
    character(len=*),intent(in)::label
    call require(status==expected,trim(label)//' status')
    call require(.not.plan%ready(),trim(label)//' plan not ready')
  end subroutine expect_failure

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
      write(*,'(A,1X,A)')'FGC49A_FAIL',trim(message)
      error stop 1
    end if
  end subroutine require
end program test_fgc49a_groundwater_application_plan
