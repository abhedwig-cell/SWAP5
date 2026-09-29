program test_fpe_elastic21_staringblock
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_fmr_elastic_storage_staringblock_association, only: fmr_staringseriesblock_to_code, &
       FMR_STARINGBLOCK_OK, FMR_STARINGBLOCK_NOT_FOUND, &
       FMR_STARINGBLOCK_FAMILY_TOPSOIL, FMR_STARINGBLOCK_FAMILY_SUBSOIL
  use mod_fmr_elastic_storage_staringreeks_catalog, only: fmr_lookup_staringreeks_retention, &
       FMR_STARINGREEKS_CATALOG_OK
  use mod_fmr_elastic_storage_horizon_descriptor_builder, only: fmr_elastic_storage_retention_t, &
       fmr_build_elastic_storage_horizon_descriptor, FMR_ELAS_DESCRIPTOR_OK
  use mod_fmr_elastic_storage_horizon_node_mapper, only: fmr_elastic_storage_horizon_t
  implicit none

  character(len=3) :: code
  type(fmr_elastic_storage_retention_t) :: retention
  type(fmr_elastic_storage_horizon_t) :: h1, h2
  integer :: family, family_index, catalog_index, status, cstatus, dstatus, i, block
  character(len=3) :: expected

  do i=1,18
    block=100+i
    write(expected,'("B",I2.2)') i
    call fmr_staringseriesblock_to_code(block,code,family,family_index,catalog_index,status)
    call require(status==FMR_STARINGBLOCK_OK,'A1 status')
    call require(code==expected,'A1 code')
    call require(family==FMR_STARINGBLOCK_FAMILY_TOPSOIL.and.family_index==i,'A1 family')
    call require(catalog_index==i,'A1 catalog index')
  end do
  write(*,'(A)')'F_PE_ELASTIC21_A1_TOPSOIL=PASS'

  do i=1,18
    block=200+i
    write(expected,'("O",I2.2)') i
    call fmr_staringseriesblock_to_code(block,code,family,family_index,catalog_index,status)
    call require(status==FMR_STARINGBLOCK_OK,'A2 status')
    call require(code==expected,'A2 code')
    call require(family==FMR_STARINGBLOCK_FAMILY_SUBSOIL.and.family_index==i,'A2 family')
    call require(catalog_index==18+i,'A2 catalog index')
  end do
  write(*,'(A)')'F_PE_ELASTIC21_A2_SUBSOIL=PASS'

  call fmr_staringseriesblock_to_code(101,code,family,family_index,catalog_index,status)
  call require(code=='B01'.and.catalog_index==1,'A3 101')
  call fmr_staringseriesblock_to_code(118,code,family,family_index,catalog_index,status)
  call require(code=='B18'.and.catalog_index==18,'A3 118')
  call fmr_staringseriesblock_to_code(201,code,family,family_index,catalog_index,status)
  call require(code=='O01'.and.catalog_index==19,'A3 201')
  call fmr_staringseriesblock_to_code(218,code,family,family_index,catalog_index,status)
  call require(code=='O18'.and.catalog_index==36,'A3 218')
  write(*,'(A)')'F_PE_ELASTIC21_A3_ENDPOINTS=PASS'

  do block=-1,220
    if ((block>=101.and.block<=118).or.(block>=201.and.block<=218)) cycle
    if (block/=0.and.block/=100.and.block/=119.and.block/=199.and.block/=200.and.block/=219.and.block/=-1) cycle
    call fmr_staringseriesblock_to_code(block,code,family,family_index,catalog_index,status)
    call require(status==FMR_STARINGBLOCK_NOT_FOUND,'A4 unsupported')
    call require(code=='   '.and.family==0.and.family_index==0.and.catalog_index==0,'A4 reset')
  end do
  call fmr_staringseriesblock_to_code(9999,code,family,family_index,catalog_index,status)
  call require(status==FMR_STARINGBLOCK_NOT_FOUND,'A4 large')
  write(*,'(A)')'F_PE_ELASTIC21_A4_FAIL_CLOSED=PASS'

  do i=1,18
    call fmr_staringseriesblock_to_code(100+i,code,family,family_index,catalog_index,status)
    call fmr_lookup_staringreeks_retention(code,retention,cstatus,status)
    call require(cstatus>=1,'A5 catalog index')
  end do
  write(*,'(A)')'F_PE_ELASTIC21_A5_CATALOG_COMPOSITION=PASS'

  call fmr_staringseriesblock_to_code(101,code,family,family_index,catalog_index,status)
  call fmr_lookup_staringreeks_retention(code,retention,catalog_index,cstatus)
  call require(cstatus==FMR_STARINGREEKS_CATALOG_OK,'A6 B01 catalog')
  call fmr_build_elastic_storage_horizon_descriptor(0.0_real64,0.5_real64,1.45_real64,.true.,2.0_real64,.false., &
       retention,h1,dstatus)
  call require(dstatus==FMR_ELAS_DESCRIPTOR_OK,'A6 B01 build')
  call fmr_build_elastic_storage_horizon_descriptor(0.0_real64,0.5_real64,1.45_real64,.true.,2.0_real64,.false., &
       retention,h2,dstatus)
  call require(h1%theta_ref_cm3_cm3==h2%theta_ref_cm3_cm3,'A6 B01 identity')

  call fmr_staringseriesblock_to_code(218,code,family,family_index,catalog_index,status)
  call fmr_lookup_staringreeks_retention(code,retention,catalog_index,cstatus)
  call require(cstatus==FMR_STARINGREEKS_CATALOG_OK,'A6 O18 catalog')
  call fmr_build_elastic_storage_horizon_descriptor(0.5_real64,1.0_real64,1.35_real64,.true.,3.0_real64,.false., &
       retention,h1,dstatus)
  call require(dstatus==FMR_ELAS_DESCRIPTOR_OK,'A6 O18 build')
  write(*,'(A)')'F_PE_ELASTIC21_A6_DESCRIPTOR_COMPOSITION=PASS'

  write(*,'(A)')'F_PE_ELASTIC21=PASS'

contains
  subroutine require(condition,label)
    logical,intent(in)::condition
    character(len=*),intent(in)::label
    if(.not.condition)then
      write(*,'(A,1X,A)')'F_PE_ELASTIC21_FAIL',trim(label)
      error stop 1
    end if
  end subroutine require
end program test_fpe_elastic21_staringblock
