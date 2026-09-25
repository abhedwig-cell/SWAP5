program test_fahl49_failclosed
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use MOD_grid, only: numnod,z,dz,disnod
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_parameters_t, prepare_fmr_b110_default_mvg
  implicit none
  type(fmr_b110_physical_parameters_t) :: p
  logical :: prepared

  call make_valid(p)
  p%direct_retention_active=.true.
  call prepare_fmr_b110_default_mvg(p,prepared)
  call require(prepared .and. p%prepared_direct_retention_slot>0,'valid mode5 direct-retention prepares')

  call make_valid(p); p%direct_retention_active=.true.; p%bottom_mode=7
  call prepare_fmr_b110_default_mvg(p,prepared)
  call rejected(prepared,p,'standalone mode rejected')

  call make_valid(p); p%direct_retention_active=.true.; p%swkimpl=1
  call prepare_fmr_b110_default_mvg(p,prepared)
  call rejected(prepared,p,'swkimpl1 rejected')

  call make_valid(p); p%direct_retention_active=.true.; p%tabulated_hydraulics_active=.true.
  call prepare_fmr_b110_default_mvg(p,prepared)
  call rejected(prepared,p,'tabulated hydraulics rejected')

  call make_valid(p); p%direct_retention_active=.true.; p%hysteresis_active=.true.
  call prepare_fmr_b110_default_mvg(p,prepared)
  call rejected(prepared,p,'hysteresis rejected')

  call make_valid(p); p%direct_retention_active=.true.; p%ksatexm_extension_active=.true.
  call prepare_fmr_b110_default_mvg(p,prepared)
  call rejected(prepared,p,'ksatexm rejected')

  call make_valid(p); p%direct_retention_active=.true.
  p%cofgen(4,numnod)=p%cofgen(4,numnod)*1.01_real64
  call prepare_fmr_b110_default_mvg(p,prepared)
  call rejected(prepared,p,'heterogeneous authority rejected')

  write(*,'(A)') 'FAHL49_FAILCLOSED=PASS'
contains
  subroutine make_valid(x)
    type(fmr_b110_physical_parameters_t),intent(out)::x
    integer::i
    x%parameter_set_id=949001_int64
    x%active_nodes=numnod
    allocate(x%z(numnod),x%dz(numnod),x%node_distance(numnod),x%cofgen(24,numnod))
    x%z=z;x%dz=dz;x%node_distance=disnod(1:numnod);x%cofgen=0.0_real64
    do i=1,numnod
      x%cofgen(1,i)=0.02_real64;x%cofgen(2,i)=0.427494_real64;x%cofgen(3,i)=31.225016_real64
      x%cofgen(4,i)=0.021659_real64;x%cofgen(5,i)=0.98087_real64;x%cofgen(6,i)=1.734737_real64
      x%cofgen(7,i)=1.0_real64-1.0_real64/x%cofgen(6,i);x%cofgen(8,i)=x%cofgen(4,i)
      x%cofgen(10,i)=x%cofgen(3,i);x%cofgen(11,i)=0.999_real64;x%cofgen(12,i)=0.99_real64*x%cofgen(3,i)
      x%cofgen(22,i)=-1.0e6_real64;x%cofgen(23,i)=1.0e-12_real64
    end do
    x%bottom_mode=5;x%swkimpl=0;x%swkmean=1;x%swsophy=0
    x%max_iterations=16;x%max_backtracking=8;x%min_step_duration=1.0e-8_real64
    x%compartment_balance_tolerance=1.0e-12_real64;x%total_balance_tolerance=1.0e-12_real64
    x%head_abs_tolerance=1.0e-12_real64;x%head_rel_tolerance=1.0e-12_real64;x%ponding_tolerance=1.0e-12_real64
    x%root_extraction_active=.false.;x%macropore_active=.false.;x%snow_active=.false.;x%hysteresis_active=.false.
    x%tabulated_hydraulics_active=.false.;x%ksatexm_extension_active=.false.;x%elasticity_active=.false.
    x%frost_active=.false.;x%soil_temperature_active=.false.;x%drainage_response_active=.false.
  end subroutine
  subroutine rejected(ok,x,label)
    logical,intent(in)::ok
    type(fmr_b110_physical_parameters_t),intent(in)::x
    character(len=*),intent(in)::label
    call require(.not.ok .and. x%prepared_direct_retention_slot==0,label)
  end subroutine
  subroutine require(cond,label)
    logical,intent(in)::cond
    character(len=*),intent(in)::label
    if(.not.cond)then
      write(*,'(A,1X,A)')'FAHL49_FAILCLOSED_FAIL',trim(label)
      error stop 1
    end if
  end subroutine
end program
