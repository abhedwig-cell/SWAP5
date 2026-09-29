program test_fpe_elastic35_row_interchange_parser
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_fmr_elastic_storage_row_interchange_file_adapter, only: &
       fmr_elastic_storage_row_file_diagnostics_t, fmr_read_elastic_storage_row_interchange_file, &
       FMR_ELAS_ROWS_FILE_OK, FMR_ELAS_ROWS_FILE_EXTRA_RECORD
  use mod_fmr_elastic_storage_explicit_profile_source, only: &
       fmr_elastic_storage_bro_horizon_row_t, fmr_elastic_storage_profile_source_diagnostics_t, &
       fmr_build_explicit_bro_profile_horizons, FMR_ELAS_PROFILE_SOURCE_OK
  use mod_fmr_elastic_storage_horizon_node_mapper, only: fmr_elastic_storage_horizon_t
  implicit none

  character(len=32) :: scenario
  character(len=1024) :: path
  type(fmr_elastic_storage_bro_horizon_row_t), allocatable :: rows(:)
  type(fmr_elastic_storage_row_file_diagnostics_t) :: diag

  call get_command_argument(1,scenario)
  call get_command_argument(2,path)

  select case(trim(scenario))
  case('valid')
    call validate_file(trim(path))
  case('invalid')
    call fmr_read_elastic_storage_row_interchange_file(trim(path),rows,diag)
    call req(diag%status/=FMR_ELAS_ROWS_FILE_OK,'invalid accepted')
    call req(.not.allocated(rows),'invalid partial rows')
    write(*,'(A)')'F_PE_ELASTIC35_INVALID_FAIL_CLOSED=PASS'
  case('extra')
    call fmr_read_elastic_storage_row_interchange_file(trim(path),rows,diag)
    call req(diag%status==FMR_ELAS_ROWS_FILE_EXTRA_RECORD,'extra status')
    call req(.not.allocated(rows),'extra partial rows')
    write(*,'(A)')'F_PE_ELASTIC35_EXTRA_RECORD=PASS'
  case default
    call req(.false.,'unknown scenario')
  end select

contains

  subroutine validate_file(file_path)
    character(len=*),intent(in)::file_path
    type(fmr_elastic_storage_bro_horizon_row_t), allocatable :: parsed(:)
    type(fmr_elastic_storage_horizon_t), allocatable :: horizons(:)
    type(fmr_elastic_storage_row_file_diagnostics_t) :: pdiag
    type(fmr_elastic_storage_profile_source_diagnostics_t) :: sdiag
    integer, allocatable :: layers(:),catalog(:)
    character(len=4096) :: line
    integer :: unit,ios,i,j,pid,layer,block,omflag,peatflag
    real(real64) :: top,bottom,density,organic
    integer(int64) :: a,b

    call fmr_read_elastic_storage_row_interchange_file(file_path,parsed,pdiag)
    call req(pdiag%status==FMR_ELAS_ROWS_FILE_OK,'valid parse status')
    call req(allocated(parsed),'valid rows allocated')
    call req(size(parsed)==pdiag%expected_rows.and.pdiag%parsed_rows==pdiag%expected_rows,'valid row count')

    open(newunit=unit,file=file_path,status='old',action='read',form='formatted',iostat=ios)
    call req(ios==0,'reference open')
    do i=1,5
      read(unit,'(A)',iostat=ios)line
      call req(ios==0,'reference header read')
    end do

    do i=1,size(parsed)
      line=''
      read(unit,'(A)',iostat=ios)line
      call req(ios==0,'reference row read')
      do j=1,len_trim(line)
        if(line(j:j)=='|')line(j:j)=' '
      end do
      read(line,*,iostat=ios)pid,layer,top,bottom,block,density,omflag,organic,peatflag
      call req(ios==0,'reference row decode')
      call req(parsed(i)%normalsoilprofile_id==pid,'profile identity')
      call req(parsed(i)%layer_number==layer,'layer identity')
      call req(parsed(i)%staringseriesblock==block,'block identity')
      a=transfer(parsed(i)%top_depth_m,a); b=transfer(top,b); call req(a==b,'top bits')
      a=transfer(parsed(i)%bottom_depth_m,a); b=transfer(bottom,b); call req(a==b,'bottom bits')
      a=transfer(parsed(i)%rho_dry_g_cm3,a); b=transfer(density,b); call req(a==b,'density bits')
      a=transfer(parsed(i)%organic_matter_pct,a); b=transfer(organic,b); call req(a==b,'organic bits')
      call req(parsed(i)%organic_matter_available.eqv.(omflag==1),'organic flag')
      call req(parsed(i)%peat_type_present.eqv.(peatflag==1),'peat flag')
    end do
    close(unit)

    call fmr_build_explicit_bro_profile_horizons(parsed,pdiag%profile_id,horizons,layers,catalog,sdiag)
    call req(sdiag%status==FMR_ELAS_PROFILE_SOURCE_OK,'ELASTIC22 composition')
    call req(size(horizons)==size(parsed).and.size(layers)==size(parsed),'ELASTIC22 shape')
    do i=1,size(parsed)
      call req(layers(i)==parsed(i)%layer_number,'ELASTIC22 layer identity')
      a=transfer(horizons(i)%top_depth_m,a); b=transfer(parsed(i)%top_depth_m,b); call req(a==b,'ELASTIC22 top')
      a=transfer(horizons(i)%bottom_depth_m,a); b=transfer(parsed(i)%bottom_depth_m,b); call req(a==b,'ELASTIC22 bottom')
      a=transfer(horizons(i)%rho_dry_g_cm3,a); b=transfer(parsed(i)%rho_dry_g_cm3,b); call req(a==b,'ELASTIC22 density')
    end do

    write(*,'(A,I0,A,I0)')'F_PE_ELASTIC35_VALID_PROFILE=',pdiag%profile_id,'|',size(parsed)
  end subroutine validate_file

  subroutine req(cond,msg)
    logical,intent(in)::cond
    character(len=*),intent(in)::msg
    if(.not.cond)then
      write(*,'(A,1X,A)')'F_PE_ELASTIC35_FAIL',trim(msg)
      error stop 1
    end if
  end subroutine req

end program test_fpe_elastic35_row_interchange_parser
