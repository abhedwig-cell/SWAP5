program test_fpe_elastic37_row_application_binding
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_parameters_t
  use mod_fmr_elastic_storage_row_application_binding, only: &
       fmr_elastic_storage_row_application_diagnostics_t, fmr_bind_elastic_storage_from_row_interchange, &
       FMR_ELAS_ROW_APP_OK, FMR_ELAS_ROW_APP_INACTIVE, FMR_ELAS_ROW_APP_ROW_FILE_REJECTED, &
       FMR_ELAS_ROW_APP_GRID_REJECTED, FMR_ELAS_ROW_APP_MAP_REJECTED, FMR_ELAS_ROW_APP_ASSEMBLY_REJECTED
  use mod_fmr_elastic_storage_row_interchange_file_adapter, only: &
       fmr_elastic_storage_bro_horizon_row_t, fmr_elastic_storage_row_file_diagnostics_t, &
       fmr_read_elastic_storage_row_interchange_file, FMR_ELAS_ROWS_FILE_OK, &
       FMR_ELAS_ROWS_MAGIC, FMR_ELAS_ROWS_SOURCE_HASH, FMR_ELAS_ROWS_COLUMNS
  use mod_fmr_elastic_storage_explicit_profile_source, only: &
       fmr_elastic_storage_profile_source_diagnostics_t, fmr_build_explicit_bro_profile_horizons, &
       FMR_ELAS_PROFILE_SOURCE_OK
  use mod_fmr_elastic_storage_horizon_node_mapper, only: &
       fmr_elastic_storage_horizon_t, fmr_elastic_storage_mapping_diagnostics_t, &
       fmr_map_elastic_storage_horizons_to_nodes, FMR_ELAS_MAP_OK
  use mod_fmr_elastic_storage_swap_grid_normalization, only: &
       fmr_elastic_storage_grid_diagnostics_t, fmr_normalize_swap_grid_geometry, FMR_ELAS_GRID_OK
  use mod_fmr_elastic_storage_descriptor_assembly, only: &
       fmr_elastic_storage_descriptor_t, fmr_elastic_storage_assembly_diagnostics_t, &
       fmr_assemble_generated_elastic_storage, FMR_ELAS_ASSEMBLY_OK
  implicit none

  type(fmr_b110_physical_parameters_t) :: base, bound, manual, conflict, one_node
  type(fmr_elastic_storage_row_application_diagnostics_t) :: diag
  integer(int64) :: a,b

  call write_interchange('elastic37-valid.rows',.false.)
  call write_interchange('elastic37-peat.rows',.true.)
  call init_base(base,2)

  call fmr_bind_elastic_storage_from_row_interchange('does-not-exist.rows',.false.,base,bound,diag)
  call req(diag%status==FMR_ELAS_ROW_APP_INACTIVE.and..not.diag%request_present,'A1 status')
  call req(same_relevant(base,bound),'A1 identity')
  write(*,'(A)')'F_PE_ELASTIC37_A1_DEFAULT_OFF_NO_IO=PASS'

  call fmr_bind_elastic_storage_from_row_interchange('elastic37-valid.rows',.true.,base,bound,diag)
  call req(diag%status==FMR_ELAS_ROW_APP_OK.and.diag%generated_prior_applied,'A2 status')
  call req(bound%elasticity_active,'A2 active')
  call req(all(bound%cofgen(24,1:2)>0.0_real64),'A2 priors')
  write(*,'(A)')'F_PE_ELASTIC37_A2_ACTIVE_BINDING=PASS'

  call manual_compose('elastic37-valid.rows',base,manual)
  call req(bound%elasticity_active.eqv.manual%elasticity_active,'A3 active identity')
  do i=1,2
    a=transfer(bound%cofgen(24,i),a); b=transfer(manual%cofgen(24,i),b)
    call req(a==b,'A3 row24 bits')
  end do
  write(*,'(A)')'F_PE_ELASTIC37_A3_MANUAL_COMPOSITION_IDENTITY=PASS'

  conflict=base
  conflict%elasticity_active=.true.
  conflict%cofgen(24,1:2)=[1.0e-6_real64,2.0e-6_real64]
  call fmr_bind_elastic_storage_from_row_interchange('elastic37-valid.rows',.true.,conflict,bound,diag)
  call req(diag%status==FMR_ELAS_ROW_APP_ASSEMBLY_REJECTED,'A4 status')
  call req(same_relevant(conflict,bound),'A4 preserve')
  write(*,'(A)')'F_PE_ELASTIC37_A4_EXPLICIT_OWNER_PRESERVED=PASS'

  call fmr_bind_elastic_storage_from_row_interchange('elastic37-peat.rows',.true.,base,bound,diag)
  call req(diag%status==FMR_ELAS_ROW_APP_ASSEMBLY_REJECTED,'A5 peat reject')
  call req(same_relevant(base,bound),'A5 atomic')
  write(*,'(A)')'F_PE_ELASTIC37_A5_PEAT_FAIL_CLOSED=PASS'

  call fmr_bind_elastic_storage_from_row_interchange('does-not-exist.rows',.true.,base,bound,diag)
  call req(diag%status==FMR_ELAS_ROW_APP_ROW_FILE_REJECTED,'A6 file reject')
  call req(same_relevant(base,bound),'A6 atomic')
  write(*,'(A)')'F_PE_ELASTIC37_A6_ROW_FILE_FAIL_CLOSED=PASS'

  call init_base(conflict,2)
  conflict%z(1)=-20.0_real64
  call fmr_bind_elastic_storage_from_row_interchange('elastic37-valid.rows',.true.,conflict,bound,diag)
  call req(diag%status==FMR_ELAS_ROW_APP_GRID_REJECTED,'A7 grid reject')
  call req(same_relevant(conflict,bound),'A7 atomic')
  write(*,'(A)')'F_PE_ELASTIC37_A7_GRID_FAIL_CLOSED=PASS'

  call init_base(one_node,1)
  one_node%z(1)=-50.0_real64
  one_node%dz(1)=100.0_real64
  call fmr_bind_elastic_storage_from_row_interchange('elastic37-valid.rows',.true.,one_node,bound,diag)
  call req(diag%status==FMR_ELAS_ROW_APP_MAP_REJECTED,'A8 map reject')
  call req(same_relevant(one_node,bound),'A8 atomic')
  write(*,'(A)')'F_PE_ELASTIC37_A8_STRADDLE_FAIL_CLOSED=PASS'

  call execute_command_line('rm -f elastic37-valid.rows elastic37-peat.rows')
  write(*,'(A)')'F_PE_ELASTIC37=PASS'

contains

  integer :: i

  subroutine init_base(p,n)
    type(fmr_b110_physical_parameters_t),intent(out)::p
    integer,intent(in)::n
    integer::j
    p%active_nodes=n
    allocate(p%cofgen(24,n),p%z(n),p%dz(n))
    p%cofgen=0.0_real64
    p%cofgen(1,:)=0.05_real64
    p%cofgen(2,:)=0.45_real64
    do j=1,n
      p%z(j)=-(real(j,real64)-0.5_real64)*50.0_real64
      p%dz(j)=50.0_real64
    end do
    p%elasticity_active=.false.
    p%prepared_default_mvg_available=.true.
  end subroutine init_base

  logical function same_relevant(x,y) result(ok)
    type(fmr_b110_physical_parameters_t),intent(in)::x,y
    integer::j,k
    integer(int64)::u,v
    ok=.false.
    if(x%active_nodes/=y%active_nodes)return
    if(x%elasticity_active.neqv.y%elasticity_active)return
    if(x%prepared_default_mvg_available.neqv.y%prepared_default_mvg_available)return
    if(allocated(x%cofgen).neqv.allocated(y%cofgen))return
    if(allocated(x%z).neqv.allocated(y%z))return
    if(allocated(x%dz).neqv.allocated(y%dz))return
    if(.not.allocated(x%cofgen).or..not.allocated(x%z).or..not.allocated(x%dz))return
    if(any(shape(x%cofgen)/=shape(y%cofgen)))return
    if(size(x%z)/=size(y%z).or.size(x%dz)/=size(y%dz))return
    do j=1,size(x%cofgen,2)
      do k=1,size(x%cofgen,1)
        u=transfer(x%cofgen(k,j),u);v=transfer(y%cofgen(k,j),v)
        if(u/=v)return
      end do
      u=transfer(x%z(j),u);v=transfer(y%z(j),v);if(u/=v)return
      u=transfer(x%dz(j),u);v=transfer(y%dz(j),v);if(u/=v)return
    end do
    ok=.true.
  end function same_relevant

  subroutine write_interchange(path,peat_second)
    character(len=*),intent(in)::path
    logical,intent(in)::peat_second
    integer::unit
    open(newunit=unit,file=path,status='replace',action='write',form='formatted')
    write(unit,'(A)')FMR_ELAS_ROWS_MAGIC
    write(unit,'(A)')'source_artifact_sha256='//FMR_ELAS_ROWS_SOURCE_HASH
    write(unit,'(A)')'normalsoilprofile_id=101'
    write(unit,'(A)')'row_count=2'
    write(unit,'(A)')'columns='//FMR_ELAS_ROWS_COLUMNS
    write(unit,'(A)')'101|1|0|0.5|101|1.45|1|2|0'
    if(peat_second)then
      write(unit,'(A)')'101|2|0.5|1|201|1.3|1|3|1'
    else
      write(unit,'(A)')'101|2|0.5|1|201|1.3|1|3|0'
    end if
    close(unit)
  end subroutine write_interchange

  subroutine manual_compose(path,base_parameters,result)
    character(len=*),intent(in)::path
    type(fmr_b110_physical_parameters_t),intent(in)::base_parameters
    type(fmr_b110_physical_parameters_t),intent(out)::result
    type(fmr_elastic_storage_bro_horizon_row_t),allocatable::rows(:)
    type(fmr_elastic_storage_horizon_t),allocatable::horizons(:)
    type(fmr_elastic_storage_descriptor_t),allocatable::descriptors(:)
    real(real64),allocatable::depth(:),thickness(:)
    integer,allocatable::layers(:),catalog(:),owners(:)
    type(fmr_elastic_storage_row_file_diagnostics_t)::fdiag
    type(fmr_elastic_storage_profile_source_diagnostics_t)::pdiag
    type(fmr_elastic_storage_grid_diagnostics_t)::gdiag
    type(fmr_elastic_storage_mapping_diagnostics_t)::mdiag
    type(fmr_elastic_storage_assembly_diagnostics_t)::adiag

    call fmr_read_elastic_storage_row_interchange_file(path,rows,fdiag)
    call req(fdiag%status==FMR_ELAS_ROWS_FILE_OK,'manual file')
    call fmr_build_explicit_bro_profile_horizons(rows,fdiag%profile_id,horizons,layers,catalog,pdiag)
    call req(pdiag%status==FMR_ELAS_PROFILE_SOURCE_OK,'manual profile')
    call fmr_normalize_swap_grid_geometry(base_parameters%z,base_parameters%dz,depth,thickness,gdiag)
    call req(gdiag%status==FMR_ELAS_GRID_OK,'manual grid')
    call fmr_map_elastic_storage_horizons_to_nodes(horizons,depth,thickness,descriptors,owners,mdiag)
    call req(mdiag%status==FMR_ELAS_MAP_OK,'manual map')
    call fmr_assemble_generated_elastic_storage(base_parameters,.true.,descriptors,result,adiag)
    call req(adiag%status==FMR_ELAS_ASSEMBLY_OK,'manual assembly')
  end subroutine manual_compose

  subroutine req(cond,msg)
    logical,intent(in)::cond
    character(len=*),intent(in)::msg
    if(.not.cond)then
      write(*,'(A,1X,A)')'F_PE_ELASTIC37_FAIL',trim(msg)
      error stop 1
    end if
  end subroutine req

end program test_fpe_elastic37_row_application_binding
