program test_fpe_elastic44_application_host_binding
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_parameters_t
  use mod_fmr_elastic_storage_application_config, only: fmr_elastic_storage_application_request_t
  use mod_fmr_elastic_storage_application_request_discovery, only: &
       fmr_elastic_storage_request_discovery_diagnostics_t, fmr_discover_elastic_storage_application_request, &
       FMR_ELAS_DISCOVERY_OK, FMR_ELAS_DISCOVERY_INACTIVE
  use mod_fmr_elastic_storage_row_application_binding, only: &
       fmr_elastic_storage_row_application_diagnostics_t, fmr_bind_elastic_storage_from_row_interchange, &
       FMR_ELAS_ROW_APP_OK, FMR_ELAS_ROW_APP_ROW_FILE_REJECTED, FMR_ELAS_ROW_APP_ASSEMBLY_REJECTED
  use mod_fmr_elastic_storage_application_host_binding, only: &
       fmr_elastic_storage_application_host_diagnostics_t, &
       fmr_prepare_application_parameters_with_elastic_storage, &
       FMR_ELAS_HOST_BINDING_OK, FMR_ELAS_HOST_BINDING_INACTIVE, &
       FMR_ELAS_HOST_BINDING_DISCOVERY_REJECTED, FMR_ELAS_HOST_BINDING_ROW_BINDING_REJECTED
  use mod_fmr_elastic_storage_row_interchange_file_adapter, only: &
       FMR_ELAS_ROWS_MAGIC, FMR_ELAS_ROWS_SOURCE_HASH, FMR_ELAS_ROWS_COLUMNS
  implicit none

  character(len=32) :: scenario
  type(fmr_b110_physical_parameters_t) :: base, prepared, direct, conflict
  type(fmr_elastic_storage_application_host_diagnostics_t) :: diag
  type(fmr_elastic_storage_application_request_t) :: request
  type(fmr_elastic_storage_request_discovery_diagnostics_t) :: ddiag
  type(fmr_elastic_storage_row_application_diagnostics_t) :: rdiag

  call get_command_argument(1, scenario)
  call write_config('elastic44-request.cfg', .false.)
  call write_config('elastic44-bad.cfg', .true.)
  call write_rows('elastic44-valid.rows')
  call init_base(base, 2)

  select case (trim(scenario))
  case ('inactive')
    call fmr_prepare_application_parameters_with_elastic_storage('', 'does-not-exist.rows', base, prepared, diag)
    call req(diag%status == FMR_ELAS_HOST_BINDING_INACTIVE, 'inactive status')
    call req(diag%discovery_status == FMR_ELAS_DISCOVERY_INACTIVE, 'inactive discovery')
    call req(same_relevant(base, prepared), 'inactive identity')
    write(*,'(A)') 'F_PE_ELASTIC44_A1_INACTIVE_IDENTITY=PASS'

  case ('explicit')
    call fmr_prepare_application_parameters_with_elastic_storage('elastic44-request.cfg', 'elastic44-valid.rows', &
                                                                 base, prepared, diag)
    call req(diag%status == FMR_ELAS_HOST_BINDING_OK, 'explicit status')
    call req(diag%generated_prior_requested .and. diag%generated_prior_applied, 'explicit applied')
    call req(prepared%elasticity_active .and. all(prepared%cofgen(24,1:2) > 0.0_real64), 'explicit priors')
    call fmr_discover_elastic_storage_application_request('elastic44-request.cfg', request, ddiag)
    call req(ddiag%status == FMR_ELAS_DISCOVERY_OK, 'direct discovery')
    call fmr_bind_elastic_storage_from_row_interchange('elastic44-valid.rows', request%generated_prior_requested, &
                                                       base, direct, rdiag)
    call req(rdiag%status == FMR_ELAS_ROW_APP_OK, 'direct row binding')
    call req(same_relevant(prepared, direct), 'direct composition identity')
    write(*,'(A)') 'F_PE_ELASTIC44_A2_EXPLICIT_DIRECT_IDENTITY=PASS'

  case ('cli')
    call fmr_prepare_application_parameters_with_elastic_storage('', 'elastic44-valid.rows', base, prepared, diag)
    call req(diag%status == FMR_ELAS_HOST_BINDING_OK, 'cli status')
    call req(diag%generated_prior_applied .and. prepared%elasticity_active, 'cli applied')
    write(*,'(A)') 'F_PE_ELASTIC44_A3_CLI_COMPOSITION=PASS'

  case ('environment')
    call fmr_prepare_application_parameters_with_elastic_storage('', 'elastic44-valid.rows', base, prepared, diag)
    call req(diag%status == FMR_ELAS_HOST_BINDING_OK, 'environment status')
    call req(diag%generated_prior_applied .and. prepared%elasticity_active, 'environment applied')
    write(*,'(A)') 'F_PE_ELASTIC44_A3_ENVIRONMENT_COMPOSITION=PASS'

  case ('conflict')
    call fmr_prepare_application_parameters_with_elastic_storage('elastic44-request.cfg', 'elastic44-valid.rows', &
                                                                 base, prepared, diag)
    call req(diag%status == FMR_ELAS_HOST_BINDING_DISCOVERY_REJECTED, 'conflict status')
    call req(same_relevant(base, prepared), 'conflict atomic')
    write(*,'(A)') 'F_PE_ELASTIC44_A4_SOURCE_CONFLICT_FAIL_CLOSED=PASS'

  case ('bad-config')
    call fmr_prepare_application_parameters_with_elastic_storage('elastic44-bad.cfg', 'elastic44-valid.rows', &
                                                                 base, prepared, diag)
    call req(diag%status == FMR_ELAS_HOST_BINDING_DISCOVERY_REJECTED, 'bad config status')
    call req(same_relevant(base, prepared), 'bad config atomic')
    write(*,'(A)') 'F_PE_ELASTIC44_A5_REQUEST_REJECTION_FAIL_CLOSED=PASS'

  case ('missing-row')
    call fmr_prepare_application_parameters_with_elastic_storage('elastic44-request.cfg', 'does-not-exist.rows', &
                                                                 base, prepared, diag)
    call req(diag%status == FMR_ELAS_HOST_BINDING_ROW_BINDING_REJECTED, 'missing row status')
    call req(diag%row_binding_status == FMR_ELAS_ROW_APP_ROW_FILE_REJECTED, 'missing row provenance')
    call req(same_relevant(base, prepared), 'missing row atomic')
    write(*,'(A)') 'F_PE_ELASTIC44_A6_ROW_REJECTION_FAIL_CLOSED=PASS'

  case ('explicit-owner')
    conflict = base
    conflict%elasticity_active = .true.
    conflict%cofgen(24,1:2) = [1.0e-6_real64, 2.0e-6_real64]
    call fmr_prepare_application_parameters_with_elastic_storage('elastic44-request.cfg', 'elastic44-valid.rows', &
                                                                 conflict, prepared, diag)
    call req(diag%status == FMR_ELAS_HOST_BINDING_ROW_BINDING_REJECTED, 'owner status')
    call req(diag%row_binding_status == FMR_ELAS_ROW_APP_ASSEMBLY_REJECTED, 'owner provenance')
    call req(same_relevant(conflict, prepared), 'owner preserve')
    write(*,'(A)') 'F_PE_ELASTIC44_A7_EXPLICIT_OWNER_PRESERVED=PASS'

  case default
    call req(.false., 'unknown scenario')
  end select

  call execute_command_line('rm -f elastic44-request.cfg elastic44-bad.cfg elastic44-valid.rows')
  write(*,'(A)') 'F_PE_ELASTIC44=PASS'

contains

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
        u=transfer(x%cofgen(k,j),u); v=transfer(y%cofgen(k,j),v)
        if(u/=v)return
      end do
      u=transfer(x%z(j),u); v=transfer(y%z(j),v); if(u/=v)return
      u=transfer(x%dz(j),u); v=transfer(y%dz(j),v); if(u/=v)return
    end do
    ok=.true.
  end function same_relevant

  subroutine write_config(path,bad)
    character(len=*),intent(in)::path
    logical,intent(in)::bad
    integer::unit
    open(newunit=unit,file=path,status='replace',action='write',form='formatted')
    if(bad)then
      write(unit,'(A)') 'ELASTIC_STORAGE_SOURCE=NOT_SUPPORTED'
    else
      write(unit,'(A)') 'ELASTIC_STORAGE_SOURCE=GENERATED_BOFEK_BRO_PRIOR'
    end if
    close(unit)
  end subroutine write_config

  subroutine write_rows(path)
    character(len=*),intent(in)::path
    integer::unit
    open(newunit=unit,file=path,status='replace',action='write',form='formatted')
    write(unit,'(A)') FMR_ELAS_ROWS_MAGIC
    write(unit,'(A)') 'source_artifact_sha256='//FMR_ELAS_ROWS_SOURCE_HASH
    write(unit,'(A)') 'normalsoilprofile_id=101'
    write(unit,'(A)') 'row_count=2'
    write(unit,'(A)') 'columns='//FMR_ELAS_ROWS_COLUMNS
    write(unit,'(A)') '101|1|0|0.5|101|1.45|1|2|0'
    write(unit,'(A)') '101|2|0.5|1|201|1.3|1|3|0'
    close(unit)
  end subroutine write_rows

  subroutine req(cond,msg)
    logical,intent(in)::cond
    character(len=*),intent(in)::msg
    if(.not.cond)then
      write(*,'(A,1X,A)') 'F_PE_ELASTIC44_FAIL',trim(msg)
      error stop 1
    end if
  end subroutine req

end program test_fpe_elastic44_application_host_binding
