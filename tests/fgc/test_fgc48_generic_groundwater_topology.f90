program test_fgc48_generic_groundwater_topology
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_groundwater_topology_composition, only: groundwater_topology_tile_t, groundwater_topology_cell_t, &
       groundwater_topology_t, materialize_groundwater_topology, GW_TOPOLOGY_OK, GW_TOPOLOGY_INVALID_TILE, &
       GW_TOPOLOGY_INVALID_CELL, GW_TOPOLOGY_DUPLICATE_TILE_ID, GW_TOPOLOGY_DUPLICATE_SWAP_LINEAGE, &
       GW_TOPOLOGY_DUPLICATE_LEDGER_ID, GW_TOPOLOGY_DUPLICATE_CELL_ID, GW_TOPOLOGY_DUPLICATE_COUPLING_ID, &
       GW_TOPOLOGY_DUPLICATE_GROUNDWATER_LINEAGE, GW_TOPOLOGY_DUPLICATE_PACKAGE_SLOT, &
       GW_TOPOLOGY_DUPLICATE_MODFLOW_NODE, GW_TOPOLOGY_TILE_CELL_MISSING, GW_TOPOLOGY_CELL_WITHOUT_TILE, &
       GW_TOPOLOGY_FRACTION_SUM, GW_TOPOLOGY_INVALID_OUTPUT
  use mod_groundwater_multiswap_types, only: groundwater_direct_tile_binding_t
  use mod_modflow6_api_binding, only: modflow6_api_slot_binding_t
  implicit none

  call qualify_fgc45_n1_equivalent()
  call qualify_fgc46_multicell_equivalent()
  call qualify_fgc47_mixed_equivalent()
  call qualify_input_order_invariance()
  call qualify_canonical_fastpath_equivalence()
  call qualify_fail_closed_validation()

  write(*,'(A)') 'FGC48_FGC45_N1_TOPOLOGY_REGRESSION=PASS'
  write(*,'(A)') 'FGC48_FGC46_MULTICELL_TOPOLOGY_REGRESSION=PASS'
  write(*,'(A)') 'FGC48_FGC47_MIXED_TOPOLOGY_REGRESSION=PASS'
  write(*,'(A)') 'FGC48_CANONICAL_ORDER_INVARIANCE=PASS'
  write(*,'(A)') 'FGC48_CANONICAL_FASTPATH_EQUIVALENCE=PASS'
  write(*,'(A)') 'FGC48_GLOBAL_OWNERSHIP_FAIL_CLOSED=PASS'
  write(*,'(A)') 'FGC48_PER_CELL_FRACTION_CLOSURE=PASS'
  write(*,'(A)') 'FGC48_API_SLOT_NODE_MAPPING=PASS'
  write(*,'(A)') 'F-GC48 GENERIC GROUNDWATER TOPOLOGY GATE PASS'

contains

  subroutine qualify_fgc45_n1_equivalent()
    type(groundwater_topology_tile_t) :: tiles(2)
    type(groundwater_topology_cell_t) :: cells(1)
    type(groundwater_topology_t) :: topology
    type(groundwater_direct_tile_binding_t), allocatable :: bindings(:)
    type(modflow6_api_slot_binding_t), allocatable :: api(:)
    integer :: status

    call set_tile(tiles(1), 550045_int64, 550045_int64, 750045_int64, 7001_int64, 0.35_real64)
    call set_tile(tiles(2), 550046_int64, 550046_int64, 750046_int64, 7001_int64, 0.65_real64)
    call set_cell(cells(1), 7001_int64, 450045_int64, 650045_int64, 650046_int64, 1, 2)

    call materialize_groundwater_topology(tiles, cells, topology, status)
    call require(status == GW_TOPOLOGY_OK .and. topology%ready(), 'F-GC45-equivalent materialization')
    call require(topology%tile_count() == 2 .and. topology%cell_count() == 1, 'F-GC45-equivalent counts')
    call topology%direct_bindings_for_cell(7001_int64, bindings, status)
    call require(status == GW_TOPOLOGY_OK .and. size(bindings) == 2, 'F-GC45-equivalent direct bindings')
    call require(bindings(1)%tile_id == 550045_int64 .and. bindings(2)%tile_id == 550046_int64, &
         'F-GC45-equivalent canonical tile order')
    call require(same(bindings(1)%area_fraction,0.35_real64) .and. &
         same(bindings(2)%area_fraction,0.65_real64), 'F-GC45-equivalent fractions')
    call topology%api_bindings(api,status)
    call require(status == GW_TOPOLOGY_OK .and. size(api) == 1, 'F-GC45-equivalent api binding')
    call require(api(1)%groundwater_cell_id == 7001_int64 .and. api(1)%package_slot == 1 .and. &
         api(1)%modflow_node_id == 2, 'F-GC45-equivalent api values')
  end subroutine qualify_fgc45_n1_equivalent

  subroutine qualify_fgc46_multicell_equivalent()
    type(groundwater_topology_tile_t) :: tiles(2)
    type(groundwater_topology_cell_t) :: cells(2)
    type(groundwater_topology_t) :: topology
    type(groundwater_topology_tile_t), allocatable :: canonical_tiles(:)
    type(groundwater_topology_cell_t), allocatable :: canonical_cells(:)
    type(modflow6_api_slot_binding_t), allocatable :: api(:)
    integer :: status

    call set_tile(tiles(1), 550046_int64, 550046_int64, 750046_int64, 7002_int64, 1.0_real64)
    call set_tile(tiles(2), 550045_int64, 550045_int64, 750045_int64, 7001_int64, 1.0_real64)
    call set_cell(cells(1), 7002_int64, 460047_int64, 660046_int64, 660048_int64, 2, 3)
    call set_cell(cells(2), 7001_int64, 460046_int64, 660046_int64, 660047_int64, 1, 2)

    call materialize_groundwater_topology(tiles,cells,topology,status)
    call require(status == GW_TOPOLOGY_OK .and. topology%ready(), 'F-GC46-equivalent materialization')
    call topology%copy_cells(canonical_cells,status)
    call require(status == GW_TOPOLOGY_OK, 'F-GC46-equivalent copy cells')
    call require(canonical_cells(1)%groundwater_cell_id == 7001_int64 .and. &
         canonical_cells(2)%groundwater_cell_id == 7002_int64, 'F-GC46 canonical cell order')
    call topology%copy_tiles(canonical_tiles,status)
    call require(status == GW_TOPOLOGY_OK, 'F-GC46-equivalent copy tiles')
    call require(canonical_tiles(1)%groundwater_cell_id == 7001_int64 .and. &
         canonical_tiles(2)%groundwater_cell_id == 7002_int64, 'F-GC46 canonical tile order')
    call topology%api_bindings(api,status)
    call require(status == GW_TOPOLOGY_OK .and. size(api) == 2, 'F-GC46 api binding count')
    call require(api(1)%groundwater_cell_id == 7001_int64 .and. api(1)%modflow_node_id == 2, 'F-GC46 api slot 1')
    call require(api(2)%groundwater_cell_id == 7002_int64 .and. api(2)%modflow_node_id == 3, 'F-GC46 api slot 2')
  end subroutine qualify_fgc46_multicell_equivalent

  subroutine qualify_fgc47_mixed_equivalent()
    type(groundwater_topology_tile_t) :: tiles(3)
    type(groundwater_topology_cell_t) :: cells(2)
    type(groundwater_topology_t) :: topology
    type(groundwater_topology_tile_t), allocatable :: canonical_tiles(:)
    type(groundwater_direct_tile_binding_t), allocatable :: bindings(:)
    integer :: status

    ! Deliberately scrambled input. Materialization must be deterministic.
    call set_tile(tiles(1), 570049_int64, 570049_int64, 770049_int64, 7002_int64, 1.0_real64)
    call set_tile(tiles(2), 570048_int64, 570048_int64, 770048_int64, 7001_int64, 0.65_real64)
    call set_tile(tiles(3), 570047_int64, 570047_int64, 770047_int64, 7001_int64, 0.35_real64)
    call set_cell(cells(1), 7002_int64, 470048_int64, 670046_int64, 670048_int64, 2, 3)
    call set_cell(cells(2), 7001_int64, 470047_int64, 670046_int64, 670047_int64, 1, 2)

    call materialize_groundwater_topology(tiles,cells,topology,status)
    call require(status == GW_TOPOLOGY_OK .and. topology%ready(), 'F-GC47-equivalent materialization')
    call topology%copy_tiles(canonical_tiles,status)
    call require(status == GW_TOPOLOGY_OK .and. size(canonical_tiles) == 3, 'F-GC47 copy tiles')
    call require(canonical_tiles(1)%tile_id == 570047_int64 .and. canonical_tiles(2)%tile_id == 570048_int64 .and. &
         canonical_tiles(3)%tile_id == 570049_int64, 'F-GC47 canonical cell/tile order')
    call topology%direct_bindings_for_cell(7001_int64,bindings,status)
    call require(status == GW_TOPOLOGY_OK .and. size(bindings) == 2, 'F-GC47 N:1 bindings')
    call require(same(bindings(1)%area_fraction,0.35_real64) .and. &
         same(bindings(2)%area_fraction,0.65_real64), 'F-GC47 N:1 fractions')
    deallocate(bindings)
    call topology%direct_bindings_for_cell(7002_int64,bindings,status)
    call require(status == GW_TOPOLOGY_OK .and. size(bindings) == 1 .and. &
         same(bindings(1)%area_fraction,1.0_real64), 'F-GC47 1:1 binding')
  end subroutine qualify_fgc47_mixed_equivalent

  subroutine qualify_input_order_invariance()
    type(groundwater_topology_tile_t) :: a_tiles(3), b_tiles(3)
    type(groundwater_topology_cell_t) :: a_cells(2), b_cells(2)
    type(groundwater_topology_t) :: a, b
    type(groundwater_topology_tile_t), allocatable :: at(:), bt(:)
    type(groundwater_topology_cell_t), allocatable :: ac(:), bc(:)
    type(modflow6_api_slot_binding_t), allocatable :: aa(:), ba(:)
    integer :: status, i

    call set_tile(a_tiles(1), 13_int64, 113_int64, 213_int64, 22_int64, 1.0_real64)
    call set_tile(a_tiles(2), 12_int64, 112_int64, 212_int64, 21_int64, 0.6_real64)
    call set_tile(a_tiles(3), 11_int64, 111_int64, 211_int64, 21_int64, 0.4_real64)
    b_tiles = [a_tiles(3), a_tiles(1), a_tiles(2)]

    call set_cell(a_cells(1), 22_int64, 322_int64, 400_int64, 522_int64, 2, 8)
    call set_cell(a_cells(2), 21_int64, 321_int64, 400_int64, 521_int64, 1, 7)
    b_cells = [a_cells(2), a_cells(1)]

    call materialize_groundwater_topology(a_tiles,a_cells,a,status)
    call require(status == GW_TOPOLOGY_OK, 'order invariant topology A')
    call materialize_groundwater_topology(b_tiles,b_cells,b,status)
    call require(status == GW_TOPOLOGY_OK, 'order invariant topology B')

    call a%copy_tiles(at,status); call require(status == GW_TOPOLOGY_OK,'copy A tiles')
    call b%copy_tiles(bt,status); call require(status == GW_TOPOLOGY_OK,'copy B tiles')
    do i=1,size(at)
      call require(at(i)%tile_id == bt(i)%tile_id .and. at(i)%groundwater_cell_id == bt(i)%groundwater_cell_id .and. &
           at(i)%swap_lineage_id == bt(i)%swap_lineage_id .and. at(i)%ledger_id == bt(i)%ledger_id .and. &
           same(at(i)%area_fraction,bt(i)%area_fraction), 'tile order invariant values')
    end do
    call a%copy_cells(ac,status); call require(status == GW_TOPOLOGY_OK,'copy A cells')
    call b%copy_cells(bc,status); call require(status == GW_TOPOLOGY_OK,'copy B cells')
    do i=1,size(ac)
      call require(ac(i)%groundwater_cell_id == bc(i)%groundwater_cell_id .and. &
           ac(i)%coupling_id == bc(i)%coupling_id .and. ac(i)%groundwater_lineage_id == bc(i)%groundwater_lineage_id, &
           'cell order invariant values')
    end do
    call a%api_bindings(aa,status); call require(status == GW_TOPOLOGY_OK,'api A')
    call b%api_bindings(ba,status); call require(status == GW_TOPOLOGY_OK,'api B')
    do i=1,size(aa)
      call require(aa(i)%groundwater_cell_id == ba(i)%groundwater_cell_id .and. &
           aa(i)%package_slot == ba(i)%package_slot .and. aa(i)%modflow_node_id == ba(i)%modflow_node_id, &
           'api order invariant values')
    end do
  end subroutine qualify_input_order_invariance

  subroutine qualify_canonical_fastpath_equivalence()
    type(groundwater_topology_tile_t) :: fast_tiles(3), generic_tiles(3)
    type(groundwater_topology_cell_t) :: fast_cells(2), generic_cells(2)
    type(groundwater_topology_t) :: fast_topology, generic_topology
    type(groundwater_topology_tile_t), allocatable :: ft(:), gt(:)
    type(groundwater_topology_cell_t), allocatable :: fc(:), gc(:)
    type(modflow6_api_slot_binding_t), allocatable :: fa(:), ga(:)
    integer :: status, i

    call set_tile(fast_tiles(1),101_int64,1001_int64,2001_int64,7001_int64,0.4_real64)
    call set_tile(fast_tiles(2),102_int64,1002_int64,2002_int64,7001_int64,0.6_real64)
    call set_tile(fast_tiles(3),103_int64,1003_int64,2003_int64,7002_int64,1.0_real64)
    call set_cell(fast_cells(1),7001_int64,8001_int64,9001_int64,9101_int64,1,2)
    call set_cell(fast_cells(2),7002_int64,8002_int64,9001_int64,9102_int64,2,3)

    generic_tiles=[fast_tiles(3),fast_tiles(1),fast_tiles(2)]
    generic_cells=[fast_cells(2),fast_cells(1)]

    call materialize_groundwater_topology(fast_tiles,fast_cells,fast_topology,status)
    call require(status==GW_TOPOLOGY_OK .and. fast_topology%ready(),'topology fastpath candidate')
    call materialize_groundwater_topology(generic_tiles,generic_cells,generic_topology,status)
    call require(status==GW_TOPOLOGY_OK .and. generic_topology%ready(),'topology generic oracle')

    call fast_topology%copy_tiles(ft,status); call require(status==GW_TOPOLOGY_OK,'fastpath copy fast tiles')
    call generic_topology%copy_tiles(gt,status); call require(status==GW_TOPOLOGY_OK,'fastpath copy generic tiles')
    call fast_topology%copy_cells(fc,status); call require(status==GW_TOPOLOGY_OK,'fastpath copy fast cells')
    call generic_topology%copy_cells(gc,status); call require(status==GW_TOPOLOGY_OK,'fastpath copy generic cells')
    call fast_topology%api_bindings(fa,status); call require(status==GW_TOPOLOGY_OK,'fastpath copy fast api')
    call generic_topology%api_bindings(ga,status); call require(status==GW_TOPOLOGY_OK,'fastpath copy generic api')

    call require(size(ft)==size(gt) .and. size(fc)==size(gc) .and. size(fa)==size(ga), &
         'topology fastpath transcript shapes')
    do i=1,size(ft)
      call require(ft(i)%tile_id==gt(i)%tile_id .and. &
           ft(i)%swap_lineage_id==gt(i)%swap_lineage_id .and. &
           ft(i)%ledger_id==gt(i)%ledger_id .and. &
           ft(i)%groundwater_cell_id==gt(i)%groundwater_cell_id .and. &
           ft(i)%area_fraction==gt(i)%area_fraction, 'topology fastpath tile identity')
    end do
    do i=1,size(fc)
      call require(fc(i)%groundwater_cell_id==gc(i)%groundwater_cell_id .and. &
           fc(i)%coupling_id==gc(i)%coupling_id .and. &
           fc(i)%groundwater_service_id==gc(i)%groundwater_service_id .and. &
           fc(i)%groundwater_lineage_id==gc(i)%groundwater_lineage_id .and. &
           fc(i)%package_slot==gc(i)%package_slot .and. &
           fc(i)%modflow_node_id==gc(i)%modflow_node_id .and. &
           fc(i)%storage_state_role==gc(i)%storage_state_role .and. &
           fc(i)%drainage_owner==gc(i)%drainage_owner, 'topology fastpath cell identity')
      call require(fa(i)%groundwater_cell_id==ga(i)%groundwater_cell_id .and. &
           fa(i)%package_slot==ga(i)%package_slot .and. &
           fa(i)%modflow_node_id==ga(i)%modflow_node_id, 'topology fastpath api identity')
    end do
  end subroutine qualify_canonical_fastpath_equivalence

  subroutine qualify_fail_closed_validation()
    type(groundwater_topology_tile_t) :: tiles(3), bad_tiles(3), two_tiles(2)
    type(groundwater_topology_cell_t) :: cells(2), bad_cells(2)
    type(groundwater_topology_t) :: topology
    type(groundwater_direct_tile_binding_t), allocatable :: bindings(:)
    integer :: status

    call set_tile(tiles(1), 1_int64, 101_int64, 201_int64, 11_int64, 0.25_real64)
    call set_tile(tiles(2), 2_int64, 102_int64, 202_int64, 11_int64, 0.75_real64)
    call set_tile(tiles(3), 3_int64, 103_int64, 203_int64, 12_int64, 1.0_real64)
    call set_cell(cells(1), 11_int64, 301_int64, 401_int64, 501_int64, 1, 4)
    call set_cell(cells(2), 12_int64, 302_int64, 401_int64, 502_int64, 2, 5)

    bad_tiles=tiles; bad_tiles(1)%tile_id=0_int64
    call expect_status(bad_tiles,cells,GW_TOPOLOGY_INVALID_TILE,'invalid tile')

    bad_tiles=tiles; bad_tiles(2)%tile_id=bad_tiles(1)%tile_id
    call expect_status(bad_tiles,cells,GW_TOPOLOGY_DUPLICATE_TILE_ID,'duplicate tile')

    bad_tiles=tiles; bad_tiles(2)%tile_id=bad_tiles(1)%tile_id
    bad_cells=cells; bad_cells(1)%package_slot=0
    call expect_status(bad_tiles,bad_cells,GW_TOPOLOGY_DUPLICATE_TILE_ID,'duplicate tile precedes invalid cell')

    bad_tiles=tiles
    bad_tiles(2)%tile_id=bad_tiles(1)%tile_id
    bad_tiles(3)%groundwater_cell_id=0_int64
    call expect_status(bad_tiles,cells,GW_TOPOLOGY_DUPLICATE_TILE_ID,'duplicate tile precedes later invalid tile')

    bad_tiles=tiles; bad_tiles(2)%swap_lineage_id=bad_tiles(1)%swap_lineage_id
    call expect_status(bad_tiles,cells,GW_TOPOLOGY_DUPLICATE_SWAP_LINEAGE,'duplicate SWAP lineage')

    bad_tiles=tiles; bad_tiles(3)%ledger_id=bad_tiles(1)%ledger_id
    call expect_status(bad_tiles,cells,GW_TOPOLOGY_DUPLICATE_LEDGER_ID,'duplicate ledger')

    bad_cells=cells; bad_cells(1)%package_slot=0
    call expect_status(tiles,bad_cells,GW_TOPOLOGY_INVALID_CELL,'invalid cell slot zero')

    bad_cells=cells; bad_cells(2)%package_slot=3
    call expect_status(tiles,bad_cells,GW_TOPOLOGY_INVALID_CELL,'invalid sparse/out-of-range slot')

    bad_cells=cells; bad_cells(2)%groundwater_cell_id=bad_cells(1)%groundwater_cell_id
    call expect_status(tiles,bad_cells,GW_TOPOLOGY_DUPLICATE_CELL_ID,'duplicate cell')

    bad_cells=cells
    bad_cells(1)%groundwater_cell_id=cells(2)%groundwater_cell_id
    bad_cells(2)%package_slot=0
    call expect_status(tiles,bad_cells,GW_TOPOLOGY_DUPLICATE_CELL_ID,'duplicate cell precedes later invalid cell')

    bad_cells=cells; bad_cells(2)%coupling_id=bad_cells(1)%coupling_id
    call expect_status(tiles,bad_cells,GW_TOPOLOGY_DUPLICATE_COUPLING_ID,'duplicate coupling')

    bad_cells=cells; bad_cells(2)%groundwater_lineage_id=bad_cells(1)%groundwater_lineage_id
    call expect_status(tiles,bad_cells,GW_TOPOLOGY_DUPLICATE_GROUNDWATER_LINEAGE,'duplicate groundwater lineage')

    bad_cells=cells; bad_cells(2)%package_slot=bad_cells(1)%package_slot
    call expect_status(tiles,bad_cells,GW_TOPOLOGY_DUPLICATE_PACKAGE_SLOT,'duplicate package slot')

    bad_cells=cells; bad_cells(2)%modflow_node_id=bad_cells(1)%modflow_node_id
    call expect_status(tiles,bad_cells,GW_TOPOLOGY_DUPLICATE_MODFLOW_NODE,'duplicate MODFLOW node')

    bad_tiles=tiles; bad_tiles(3)%groundwater_cell_id=99_int64
    call expect_status(bad_tiles,cells,GW_TOPOLOGY_TILE_CELL_MISSING,'tile missing cell')

    two_tiles=tiles(1:2)
    call expect_status_two(two_tiles,cells,GW_TOPOLOGY_CELL_WITHOUT_TILE,'orphan cell')

    bad_tiles=tiles; bad_tiles(2)%area_fraction=0.70_real64
    call expect_status(bad_tiles,cells,GW_TOPOLOGY_FRACTION_SUM,'fraction sum')

    call materialize_groundwater_topology(tiles,cells,topology,status)
    call require(status==GW_TOPOLOGY_OK,'valid topology after failure matrix')
    call topology%direct_bindings_for_cell(99_int64,bindings,status)
    call require(status==GW_TOPOLOGY_INVALID_OUTPUT .and. .not.allocated(bindings),'unknown-cell output fail closed')
  end subroutine qualify_fail_closed_validation

  subroutine expect_status(tiles,cells,expected,label)
    type(groundwater_topology_tile_t),intent(in)::tiles(3)
    type(groundwater_topology_cell_t),intent(in)::cells(2)
    integer,intent(in)::expected
    character(len=*),intent(in)::label
    type(groundwater_topology_t)::topology
    integer::status
    call materialize_groundwater_topology(tiles,cells,topology,status)
    call require(status==expected,trim(label)//' status')
    call require(.not.topology%ready(),trim(label)//' not materialized')
  end subroutine expect_status

  subroutine expect_status_two(tiles,cells,expected,label)
    type(groundwater_topology_tile_t),intent(in)::tiles(2)
    type(groundwater_topology_cell_t),intent(in)::cells(2)
    integer,intent(in)::expected
    character(len=*),intent(in)::label
    type(groundwater_topology_t)::topology
    integer::status
    call materialize_groundwater_topology(tiles,cells,topology,status)
    call require(status==expected,trim(label)//' status')
    call require(.not.topology%ready(),trim(label)//' not materialized')
  end subroutine expect_status_two

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

  pure logical function same(a,b) result(matches)
    real(real64),intent(in)::a,b
    real(real64)::scale
    scale=max(1.0_real64,abs(a),abs(b))
    matches=abs(a-b)<=64.0_real64*epsilon(1.0_real64)*scale
  end function same

  subroutine require(condition,message)
    logical,intent(in)::condition
    character(len=*),intent(in)::message
    if(.not.condition)then
      write(*,'(A,1X,A)')'FGC48_FAIL',trim(message)
      error stop 1
    end if
  end subroutine require

end program test_fgc48_generic_groundwater_topology
