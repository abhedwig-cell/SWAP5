program test_fpe_elastic23_maparea_profile
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_fmr_elastic_storage_maparea_profile_association, only: &
       fmr_elastic_storage_maparea_profile_row_t, fmr_elastic_storage_maparea_profile_diagnostics_t, &
       fmr_resolve_maparea_profile, &
       FMR_ELAS_MAPAREA_PROFILE_OK, FMR_ELAS_MAPAREA_PROFILE_INVALID_REQUEST, &
       FMR_ELAS_MAPAREA_PROFILE_NOT_FOUND, FMR_ELAS_MAPAREA_PROFILE_AMBIGUOUS, &
       FMR_ELAS_MAPAREA_PROFILE_INVALID_SOURCE
  use mod_fmr_elastic_storage_explicit_profile_source, only: &
       fmr_elastic_storage_bro_horizon_row_t, fmr_elastic_storage_profile_source_diagnostics_t, &
       fmr_build_explicit_bro_profile_horizons, FMR_ELAS_PROFILE_SOURCE_OK
  use mod_fmr_elastic_storage_horizon_node_mapper, only: fmr_elastic_storage_horizon_t
  implicit none

  type(fmr_elastic_storage_maparea_profile_row_t) :: rel(4), dup(5), badrel(4)
  type(fmr_elastic_storage_bro_horizon_row_t) :: rows(4)
  type(fmr_elastic_storage_maparea_profile_diagnostics_t) :: diag
  type(fmr_elastic_storage_profile_source_diagnostics_t) :: pdiag
  type(fmr_elastic_storage_horizon_t), allocatable :: h1(:), h2(:)
  integer, allocatable :: layers1(:), layers2(:), cat1(:), cat2(:)
  integer :: profile_id, direct_id, i

  call init_rel(rel)
  call init_rows(rows)

  call fmr_resolve_maparea_profile(rel,'V2025-1..soilarea.0000005485',profile_id,diag)
  call req(diag%status==FMR_ELAS_MAPAREA_PROFILE_OK,'A1 status')
  call req(profile_id==2110.and.diag%matched_row==1,'A1 exact profile')
  write(*,'(A)')'F_PE_ELASTIC23_A1_EXACT_SELECTION=PASS'

  call fmr_resolve_maparea_profile(rel,'V2025-1..soilarea.0000005485   ',profile_id,diag)
  call req(diag%status==FMR_ELAS_MAPAREA_PROFILE_OK.and.profile_id==2110,'A2 trailing padding')
  write(*,'(A)')'F_PE_ELASTIC23_A2_TRAILING_PADDING=PASS'

  call fmr_resolve_maparea_profile(rel,' V2025-1..soilarea.0000005485',profile_id,diag)
  call req(diag%status==FMR_ELAS_MAPAREA_PROFILE_INVALID_REQUEST,'A3 leading')
  call fmr_resolve_maparea_profile(rel,'v2025-1..soilarea.0000005485',profile_id,diag)
  call req(diag%status==FMR_ELAS_MAPAREA_PROFILE_NOT_FOUND,'A3 case')
  call fmr_resolve_maparea_profile(rel,'V2025-1..soilarea.9999999999',profile_id,diag)
  call req(diag%status==FMR_ELAS_MAPAREA_PROFILE_NOT_FOUND,'A3 missing')
  call fmr_resolve_maparea_profile(rel,'',profile_id,diag)
  call req(diag%status==FMR_ELAS_MAPAREA_PROFILE_INVALID_REQUEST,'A3 empty')
  write(*,'(A)')'F_PE_ELASTIC23_A3_REQUEST_FAIL_CLOSED=PASS'

  dup(1:4)=rel
  dup(5)=rel(1)
  call fmr_resolve_maparea_profile(dup,'V2025-1..soilarea.0000005485',profile_id,diag)
  call req(diag%status==FMR_ELAS_MAPAREA_PROFILE_AMBIGUOUS.and.diag%matches==2,'A4 duplicate same')
  dup(5)=rel(1)
  dup(5)%normalsoilprofile_id=9999
  call fmr_resolve_maparea_profile(dup,'V2025-1..soilarea.0000005485',profile_id,diag)
  call req(diag%status==FMR_ELAS_MAPAREA_PROFILE_AMBIGUOUS.and.diag%matches==2,'A4 duplicate different')
  write(*,'(A)')'F_PE_ELASTIC23_A4_AMBIGUOUS_FAIL_CLOSED=PASS'

  badrel=rel
  badrel(2)%normalsoilprofile_id=0
  call fmr_resolve_maparea_profile(badrel,'V2025-1..soilarea.0000009940',profile_id,diag)
  call req(diag%status==FMR_ELAS_MAPAREA_PROFILE_INVALID_SOURCE.and.profile_id==0,'A5 invalid source')
  write(*,'(A)')'F_PE_ELASTIC23_A5_INVALID_SOURCE=PASS'

  call fmr_resolve_maparea_profile(rel,'V2025-1..soilarea.0000005485',profile_id,diag)
  call req(diag%status==FMR_ELAS_MAPAREA_PROFILE_OK,'A6 resolve')
  call fmr_build_explicit_bro_profile_horizons(rows,profile_id,h1,layers1,cat1,pdiag)
  call req(pdiag%status==FMR_ELAS_PROFILE_SOURCE_OK,'A6 profile')
  direct_id=2110
  call fmr_build_explicit_bro_profile_horizons(rows,direct_id,h2,layers2,cat2,pdiag)
  call req(pdiag%status==FMR_ELAS_PROFILE_SOURCE_OK,'A6 direct')
  call req(size(h1)==size(h2).and.all(layers1==layers2).and.all(cat1==cat2),'A6 metadata')
  do i=1,size(h1)
    call req(h1(i)%top_depth_m==h2(i)%top_depth_m.and.h1(i)%bottom_depth_m==h2(i)%bottom_depth_m,'A6 geom')
    call req(h1(i)%rho_dry_g_cm3==h2(i)%rho_dry_g_cm3,'A6 density')
    call req(h1(i)%theta_ref_cm3_cm3==h2(i)%theta_ref_cm3_cm3,'A6 theta')
    call req(h1(i)%regime==h2(i)%regime,'A6 regime')
  end do
  write(*,'(A)')'F_PE_ELASTIC23_A6_ELASTIC22_COMPOSITION=PASS'

  call fmr_resolve_maparea_profile(rel,'V2025-1..soilarea.0000005713',profile_id,diag)
  call req(diag%status==FMR_ELAS_MAPAREA_PROFILE_OK.and.profile_id==90210030,'A7 unrelated')
  write(*,'(A)')'F_PE_ELASTIC23_A7_UNRELATED_ROWS=PASS'

  write(*,'(A)')'F_PE_ELASTIC23=PASS'

contains

  subroutine init_rel(r)
    type(fmr_elastic_storage_maparea_profile_row_t),intent(out)::r(4)
    r(1)%maparea_id='V2025-1..soilarea.0000005485';r(1)%normalsoilprofile_id=2110
    r(2)%maparea_id='V2025-1..soilarea.0000009940';r(2)%normalsoilprofile_id=9024090
    r(3)%maparea_id='V2025-1..soilarea.0000005713';r(3)%normalsoilprofile_id=90210030
    r(4)%maparea_id='V2025-1..soilarea.0000005718';r(4)%normalsoilprofile_id=90310030
  end subroutine init_rel

  subroutine init_rows(r)
    type(fmr_elastic_storage_bro_horizon_row_t),intent(out)::r(4)
    r(1)=fmr_elastic_storage_bro_horizon_row_t(2110,1,0.0_real64,0.5_real64,101,1.45_real64,.true.,2.0_real64,.false.)
    r(2)=fmr_elastic_storage_bro_horizon_row_t(2110,2,0.5_real64,1.0_real64,201,1.30_real64,.true.,3.0_real64,.false.)
    r(3)=fmr_elastic_storage_bro_horizon_row_t(90210030,1,0.0_real64,0.4_real64,102,1.40_real64,.true.,2.0_real64,.false.)
    r(4)=fmr_elastic_storage_bro_horizon_row_t(90210030,2,0.4_real64,1.0_real64,202,1.35_real64,.true.,3.0_real64,.false.)
  end subroutine init_rows

  subroutine req(cond,msg)
    logical,intent(in)::cond
    character(len=*),intent(in)::msg
    if(.not.cond)then
      write(*,'(A,1X,A)')'F_PE_ELASTIC23_FAIL',trim(msg)
      error stop 1
    end if
  end subroutine req

end program test_fpe_elastic23_maparea_profile
