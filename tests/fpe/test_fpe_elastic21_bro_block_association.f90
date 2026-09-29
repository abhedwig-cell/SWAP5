program test_fpe_elastic21_bro_block_association
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_fmr_elastic_storage_bro_block_association, only: &
       fmr_resolve_bro_staringreeks_block, &
       FMR_ELAS_BRO_BLOCK_OK, FMR_ELAS_BRO_BLOCK_NOT_FOUND, &
       FMR_ELAS_BRO_FAMILY_B, FMR_ELAS_BRO_FAMILY_O, FMR_ELAS_BRO_FAMILY_NONE
  use mod_fmr_elastic_storage_staringreeks_catalog, only: &
       fmr_lookup_staringreeks_retention, FMR_STARINGREEKS_CATALOG_OK
  use mod_fmr_elastic_storage_horizon_descriptor_builder, only: &
       fmr_elastic_storage_retention_t, fmr_build_elastic_storage_horizon_descriptor, &
       FMR_ELAS_DESCRIPTOR_OK
  use mod_fmr_elastic_storage_horizon_node_mapper, only: fmr_elastic_storage_horizon_t
  implicit none

  character(len=3), parameter :: B_CODES(18) = [ character(len=3) :: &
       'B01','B02','B03','B04','B05','B06','B07','B08','B09', &
       'B10','B11','B12','B13','B14','B15','B16','B17','B18' ]
  character(len=3), parameter :: O_CODES(18) = [ character(len=3) :: &
       'O01','O02','O03','O04','O05','O06','O07','O08','O09', &
       'O10','O11','O12','O13','O14','O15','O16','O17','O18' ]

  character(len=3) :: code
  integer :: family, family_index, catalog_index, status
  integer :: i, lookup_index, lookup_status, builder_status
  type(fmr_elastic_storage_retention_t) :: mapped_ret, direct_ret
  type(fmr_elastic_storage_horizon_t) :: mapped_horizon, direct_horizon
  integer(int64) :: ba, bb

  do i=1,18
    call fmr_resolve_bro_staringreeks_block(100+i,code,family,family_index,catalog_index,status)
    call req(status==FMR_ELAS_BRO_BLOCK_OK,'A1 status')
    call req(code==B_CODES(i),'A1 code')
    call req(family==FMR_ELAS_BRO_FAMILY_B.and.family_index==i,'A1 family')
    call req(catalog_index==i,'A3 B catalog index')
  end do
  write(*,'(A)')'F_PE_ELASTIC21_A1_B_FAMILY=PASS'

  do i=1,18
    call fmr_resolve_bro_staringreeks_block(200+i,code,family,family_index,catalog_index,status)
    call req(status==FMR_ELAS_BRO_BLOCK_OK,'A2 status')
    call req(code==O_CODES(i),'A2 code')
    call req(family==FMR_ELAS_BRO_FAMILY_O.and.family_index==i,'A2 family')
    call req(catalog_index==18+i,'A3 O catalog index')
  end do
  write(*,'(A)')'F_PE_ELASTIC21_A2_O_FAMILY=PASS'
  write(*,'(A)')'F_PE_ELASTIC21_A3_CATALOG_INDEX=PASS'

  call reject(0); call reject(100); call reject(119); call reject(120)
  call reject(199); call reject(200); call reject(219); call reject(-1)
  call reject(9999)
  write(*,'(A)')'F_PE_ELASTIC21_A4_INVALID_BLOCKS=PASS'

  do i=1,18
    call fmr_resolve_bro_staringreeks_block(100+i,code,family,family_index,catalog_index,status)
    call fmr_lookup_staringreeks_retention(code,mapped_ret,lookup_index,lookup_status)
    call req(lookup_status==FMR_STARINGREEKS_CATALOG_OK.and.lookup_index==catalog_index,'A5 B lookup')
  end do
  do i=1,18
    call fmr_resolve_bro_staringreeks_block(200+i,code,family,family_index,catalog_index,status)
    call fmr_lookup_staringreeks_retention(code,mapped_ret,lookup_index,lookup_status)
    call req(lookup_status==FMR_STARINGREEKS_CATALOG_OK.and.lookup_index==catalog_index,'A5 O lookup')
  end do
  write(*,'(A)')'F_PE_ELASTIC21_A5_ELASTIC20_COMPOSITION=PASS'

  call compare_builder(101,'B01')
  call compare_builder(218,'O18')
  write(*,'(A)')'F_PE_ELASTIC21_A6_ELASTIC19_COMPOSITION=PASS'

  call fmr_resolve_bro_staringreeks_block(118,code,family,family_index,catalog_index,status)
  call req(status==FMR_ELAS_BRO_BLOCK_OK.and.family==FMR_ELAS_BRO_FAMILY_B.and.code=='B18','A7 B end')
  call fmr_resolve_bro_staringreeks_block(201,code,family,family_index,catalog_index,status)
  call req(status==FMR_ELAS_BRO_BLOCK_OK.and.family==FMR_ELAS_BRO_FAMILY_O.and.code=='O01','A7 O start')
  write(*,'(A)')'F_PE_ELASTIC21_A7_FAMILY_SEPARATION=PASS'

  write(*,'(A)')'F_PE_ELASTIC21=PASS'

contains

  subroutine reject(block)
    integer,intent(in)::block
    character(len=3)::c
    integer::f,fi,ci,s
    call fmr_resolve_bro_staringreeks_block(block,c,f,fi,ci,s)
    call req(s==FMR_ELAS_BRO_BLOCK_NOT_FOUND,'A4 status')
    call req(c=='   '.and.f==FMR_ELAS_BRO_FAMILY_NONE.and.fi==0.and.ci==0,'A4 clean outputs')
  end subroutine reject

  subroutine compare_builder(block,direct_code)
    integer,intent(in)::block
    character(len=3),intent(in)::direct_code
    character(len=3)::mapped_code
    integer::f,fi,ci,s,idx1,idx2,ls1,ls2,bs1,bs2

    call fmr_resolve_bro_staringreeks_block(block,mapped_code,f,fi,ci,s)
    call req(s==FMR_ELAS_BRO_BLOCK_OK,'A6 map')
    call fmr_lookup_staringreeks_retention(mapped_code,mapped_ret,idx1,ls1)
    call fmr_lookup_staringreeks_retention(direct_code,direct_ret,idx2,ls2)
    call req(ls1==FMR_STARINGREEKS_CATALOG_OK.and.ls2==FMR_STARINGREEKS_CATALOG_OK,'A6 lookup')

    ba=transfer(mapped_ret%wcr,ba);bb=transfer(direct_ret%wcr,bb);call req(ba==bb,'A6 wcr')
    ba=transfer(mapped_ret%wcs,ba);bb=transfer(direct_ret%wcs,bb);call req(ba==bb,'A6 wcs')
    ba=transfer(mapped_ret%alpha_cm_inv,ba);bb=transfer(direct_ret%alpha_cm_inv,bb);call req(ba==bb,'A6 alpha')
    ba=transfer(mapped_ret%npar,ba);bb=transfer(direct_ret%npar,bb);call req(ba==bb,'A6 n')

    call fmr_build_elastic_storage_horizon_descriptor(0.0_real64,0.5_real64,1.45_real64, &
         .true.,5.0_real64,.false.,mapped_ret,mapped_horizon,bs1)
    call fmr_build_elastic_storage_horizon_descriptor(0.0_real64,0.5_real64,1.45_real64, &
         .true.,5.0_real64,.false.,direct_ret,direct_horizon,bs2)
    call req(bs1==FMR_ELAS_DESCRIPTOR_OK.and.bs2==FMR_ELAS_DESCRIPTOR_OK,'A6 builder')
    ba=transfer(mapped_horizon%theta_ref_cm3_cm3,ba)
    bb=transfer(direct_horizon%theta_ref_cm3_cm3,bb)
    call req(ba==bb.and.mapped_horizon%regime==direct_horizon%regime,'A6 horizon identity')
  end subroutine compare_builder

  subroutine req(cond,msg)
    logical,intent(in)::cond
    character(len=*),intent(in)::msg
    if(.not.cond)then
      write(*,'(A,1X,A)')'F_PE_ELASTIC21_FAIL',trim(msg)
      error stop 1
    end if
  end subroutine req

end program test_fpe_elastic21_bro_block_association
