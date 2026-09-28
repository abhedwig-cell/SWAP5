program test_ppa_wu05a3_macrostate_composed_candidate_source_oracle
  use, intrinsic :: iso_fortran_env, only: real64,int32
  use mod_ppa_wu05a3_macrostate_storage_candidate
  use mod_ppa_wu05a3_macrostate_wetting_candidate
  use mod_ppa_wu05a3_macrostate_flux_candidate
  use mod_ppa_wu05a3_macrostate_aggregate_candidate
  implicit none
  real(real64)::previous_storage(2),qlat(2),qvrt(2),exchange(2,3),drain(3)
  real(real64)::cell_volume(2,3),profile_volume(2,3),profile_previous(2,3)
  real(real64)::water_profile_previous(2,3),water_unsat(2),storage_sat(2),storage_unsat(2)
  real(real64)::total
  real(real64)::fraction(2,3),water(2,3),level(2),flux_previous(2,3),flux(2,3)
  real(real64)::domain_volume(2),main_level,main_volume,main_storage,main_cells(3)
  real(real64)::internal_volume,internal_storage,internal_cells(3)
  integer(int32)::bottom(2),bottom_previous(2),water_top(2),status_storage
  integer(int32)::status_wetting,status_flux,status_aggregate

  call compose_swmbf1_candidate_route()
  print '(A)','PPA_WU05A3_MACROSTATE_COMPOSED_CDE_SOURCE_ORACLE=PASS'
  print '(A)','PPA_WU05A3_MACROSTATE_COMPOSED_STORAGE_TO_WETTING=PASS'
  print '(A)','PPA_WU05A3_MACROSTATE_COMPOSED_WETTING_TO_FLUX=PASS'
  print '(A)','PPA_WU05A3_MACROSTATE_COMPOSED_INTERFACE_AGGREGATES=PASS'
contains
  subroutine require(ok,code)
    logical,intent(in)::ok
    integer,intent(in)::code
    if(.not.ok)then
      write(*,'(A,I0)')'PPA_WU05A3_MACROSTATE_COMPOSED_FAIL=',code
      error stop 1
    end if
  end subroutine

  subroutine compose_swmbf1_candidate_route()
    previous_storage=[0.4_real64,0.1_real64]
    qlat=[0.2_real64,0.1_real64]; qvrt=[0.1_real64,0.0_real64]
    exchange=0.0_real64; exchange(1,1)=0.1_real64; exchange(2,1)=0.2_real64
    drain=[0.05_real64,0.05_real64,0.0_real64]
    bottom=[2_int32,2_int32]; bottom_previous=bottom
    cell_volume=0.0_real64; cell_volume(1,1:2)=[0.2_real64,0.3_real64]
    cell_volume(2,1:2)=[0.1_real64,0.2_real64]
    profile_volume=cell_volume; profile_previous=cell_volume
    water_profile_previous=0.0_real64; water_unsat=0.0_real64
    flux_previous=0.0_real64

    call ppa_wu05a3_macrostate_storage_candidate(3_int32,2_int32,1_int32,1_int32,bottom, &
        1.0_real64,previous_storage,qlat,qvrt,exchange,drain,cell_volume,profile_volume, &
        water_unsat,storage_sat,storage_unsat,water_top,total,status_storage)
    call require(status_storage==PPA_WU05A3_MACROSTATE_STORAGE_OK,1)
    call require(abs(storage_sat(1)-0.5_real64)<1.0e-12_real64 .and. &
        abs(storage_sat(2))<1.0e-12_real64,2)

    call ppa_wu05a3_macrostate_wetting_candidate(3_int32,2_int32,1_int32,1_int32,bottom, &
        storage_sat,[-20.0_real64,-20.0_real64],cell_volume,[10.0_real64,10.0_real64,10.0_real64], &
        0.0_real64*cell_volume,water_profile_previous,fraction,water,water_top,level,status_wetting)
    call require(status_wetting==PPA_WU05A3_MACROSTATE_WETTING_OK,3)
    call require(all(water_top==[1_int32,2_int32]) .and. &
        abs(sum(water(1,:))-0.5_real64)<1.0e-12_real64 .and. &
        abs(sum(water(2,:)))<1.0e-12_real64,4)
    call require(abs(level(1))<1.0e-12_real64 .and. &
        abs(level(2)-(-20.0_real64))<1.0e-12_real64,5)

    call ppa_wu05a3_macrostate_flux_candidate(3_int32,2_int32,1_int32,1_int32,bottom, &
        bottom_previous,water_top,1.0_real64,qlat,qvrt,exchange,water,water_profile_previous, &
        cell_volume,profile_previous,flux_previous,flux,status_flux)
    call require(status_flux==PPA_WU05A3_MACROSTATE_FLUX_OK,6)
    call require(abs(flux(1,1)-0.3_real64)<1.0e-12_real64 .and. &
        abs(flux(1,2))<1.0e-12_real64 .and. abs(flux(2,1)-0.1_real64)<1.0e-12_real64,7)

    domain_volume=[sum(cell_volume(1,:)),sum(cell_volume(2,:))]
    call ppa_wu05a3_macrostate_aggregate_candidate(3_int32,2_int32,level,domain_volume, &
        storage_unsat,cell_volume,main_level,main_volume,main_storage,main_cells, &
        internal_volume,internal_storage,internal_cells,status_aggregate)
    call require(status_aggregate==PPA_WU05A3_MACROSTATE_AGGREGATE_OK,8)
    call require(abs(main_volume-0.5_real64)<1.0e-12_real64 .and. &
        abs(internal_volume-0.3_real64)<1.0e-12_real64 .and. &
        abs(main_storage-0.5_real64)<1.0e-12_real64,9)
    call require(maxval(abs(internal_cells-cell_volume(2,:)))<1.0e-12_real64 .and. &
        maxval(abs(main_cells-cell_volume(1,:)))<1.0e-12_real64,10)
  end subroutine
end program test_ppa_wu05a3_macrostate_composed_candidate_source_oracle
