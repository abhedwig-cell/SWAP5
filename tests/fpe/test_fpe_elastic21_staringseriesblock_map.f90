program test_fpe_elastic21_staringseriesblock_map
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_fmr_elastic_storage_staringseriesblock_map, only: &
       fmr_map_staringseriesblock_to_catalog, FMR_STARINGSERIESBLOCK_OK, FMR_STARINGSERIESBLOCK_NOT_FOUND
  use mod_fmr_elastic_storage_staringreeks_catalog, only: &
       fmr_lookup_staringreeks_retention, FMR_STARINGREEKS_CATALOG_OK
  use mod_fmr_elastic_storage_horizon_descriptor_builder, only: &
       fmr_elastic_storage_retention_t, fmr_build_elastic_storage_horizon_descriptor, FMR_ELAS_DESCRIPTOR_OK
  use mod_fmr_elastic_storage_horizon_node_mapper, only: fmr_elastic_storage_horizon_t
  implicit none

  character(len=3) :: code, expected
  type(fmr_elastic_storage_retention_t) :: retention_mapped, retention_direct
  type(fmr_elastic_storage_horizon_t) :: horizon_mapped, horizon_direct
  integer :: block, idx, status, cat_status, direct_status, i

  do i = 1, 18
    block = 100 + i
    write(expected,'(A1,I2.2)') 'B', i
    call fmr_map_staringseriesblock_to_catalog(block, code, idx, status)
    call require(status==FMR_STARINGSERIESBLOCK_OK,'A1 status')
    call require(code==expected,'A1 code')
    call require(idx==i,'A1 index')
  end do
  write(*,'(A)')'F_PE_ELASTIC21_A1_B_BLOCKS=PASS'

  do i = 1, 18
    block = 200 + i
    write(expected,'(A1,I2.2)') 'O', i
    call fmr_map_staringseriesblock_to_catalog(block, code, idx, status)
    call require(status==FMR_STARINGSERIESBLOCK_OK,'A2 status')
    call require(code==expected,'A2 code')
    call require(idx==18+i,'A2 index')
  end do
  write(*,'(A)')'F_PE_ELASTIC21_A2_O_BLOCKS=PASS'

  do block = 101, 118
    call fmr_map_staringseriesblock_to_catalog(block, code, idx, status)
    call require(status==FMR_STARINGSERIESBLOCK_OK,'A3 B map')
    call fmr_lookup_staringreeks_retention(code, retention_mapped, i, cat_status)
    call require(cat_status==FMR_STARINGREEKS_CATALOG_OK.and.i==idx,'A3 B catalog')
  end do
  do block = 201, 218
    call fmr_map_staringseriesblock_to_catalog(block, code, idx, status)
    call require(status==FMR_STARINGSERIESBLOCK_OK,'A3 O map')
    call fmr_lookup_staringreeks_retention(code, retention_mapped, i, cat_status)
    call require(cat_status==FMR_STARINGREEKS_CATALOG_OK.and.i==idx,'A3 O catalog')
  end do
  write(*,'(A)')'F_PE_ELASTIC21_A3_CATALOG_RESOLUTION=PASS'

  call reject(-1); call reject(0); call reject(1); call reject(36)
  call reject(100); call reject(119); call reject(150); call reject(199)
  call reject(200); call reject(219); call reject(999)
  write(*,'(A)')'F_PE_ELASTIC21_A4_INVALID_BLOCKS=PASS'

  call compose_case(101,'B01')
  call compose_case(218,'O18')
  write(*,'(A)')'F_PE_ELASTIC21_A5_ELASTIC19_COMPOSITION=PASS'

  write(*,'(A)')'F_PE_ELASTIC21=PASS'

contains

  subroutine reject(value)
    integer,intent(in)::value
    call fmr_map_staringseriesblock_to_catalog(value,code,idx,status)
    call require(status==FMR_STARINGSERIESBLOCK_NOT_FOUND,'A4 status')
    call require(code=='   '.and.idx==0,'A4 clean output')
  end subroutine reject

  subroutine compose_case(value,direct_code)
    integer,intent(in)::value
    character(len=*),intent(in)::direct_code
    integer :: mapped_index, mapped_status, direct_index

    call fmr_map_staringseriesblock_to_catalog(value,code,mapped_index,mapped_status)
    call require(mapped_status==FMR_STARINGSERIESBLOCK_OK,'A5 mapped status')

    call fmr_lookup_staringreeks_retention(code,retention_mapped,idx,cat_status)
    call fmr_lookup_staringreeks_retention(direct_code,retention_direct,direct_index,direct_status)
    call require(cat_status==FMR_STARINGREEKS_CATALOG_OK.and.direct_status==FMR_STARINGREEKS_CATALOG_OK,'A5 lookup')
    call require(idx==mapped_index.and.direct_index==mapped_index,'A5 index')

    call require(transfer(retention_mapped%wcr,0_8)==transfer(retention_direct%wcr,0_8),'A5 wcr')
    call require(transfer(retention_mapped%wcs,0_8)==transfer(retention_direct%wcs,0_8),'A5 wcs')
    call require(transfer(retention_mapped%alpha_cm_inv,0_8)==transfer(retention_direct%alpha_cm_inv,0_8),'A5 alpha')
    call require(transfer(retention_mapped%npar,0_8)==transfer(retention_direct%npar,0_8),'A5 npar')

    call fmr_build_elastic_storage_horizon_descriptor(0.0_real64,0.5_real64,1.45_real64, &
         .true.,2.0_real64,.false.,retention_mapped,horizon_mapped,status)
    call require(status==FMR_ELAS_DESCRIPTOR_OK,'A5 mapped builder')
    call fmr_build_elastic_storage_horizon_descriptor(0.0_real64,0.5_real64,1.45_real64, &
         .true.,2.0_real64,.false.,retention_direct,horizon_direct,status)
    call require(status==FMR_ELAS_DESCRIPTOR_OK,'A5 direct builder')

    call require(transfer(horizon_mapped%theta_ref_cm3_cm3,0_8)== &
         transfer(horizon_direct%theta_ref_cm3_cm3,0_8),'A5 theta')
    call require(horizon_mapped%regime==horizon_direct%regime,'A5 regime')
  end subroutine compose_case

  subroutine require(condition,label)
    logical,intent(in)::condition
    character(len=*),intent(in)::label
    if(.not.condition)then
      write(*,'(A,1X,A)')'F_PE_ELASTIC21_FAIL',trim(label)
      error stop 1
    end if
  end subroutine require

end program test_fpe_elastic21_staringseriesblock_map
