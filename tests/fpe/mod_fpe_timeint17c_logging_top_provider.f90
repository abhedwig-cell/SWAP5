module mod_fpe_timeint17c_logging_top_provider
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_soil_water_solver_contract, only: dynamic_top_boundary_provider_t, soil_water_boundary_conditions_t, &
       soil_water_top_boundary_result_t, SW_TOP_BOUNDARY_AVAILABLE
  use mod_b110_dynamic_top_boundary_solver_adapter, only: b110_dynamic_top_boundary_solver_provider_t
  implicit none
  private
  integer,parameter,public :: T17C_ROUTE_OTHER=0,T17C_ROUTE_FLUX=1,T17C_ROUTE_HEAD=2,T17C_ROUTE_RUNOFF=3,T17C_ROUTE_ATMOS=4
  integer,parameter :: MAX_LOG=4096

  type,extends(dynamic_top_boundary_provider_t),public :: fpe_timeint17c_logging_top_provider_t
    type(b110_dynamic_top_boundary_solver_provider_t),pointer :: inner=>null()
    integer :: n=0
    integer :: unavailable=0
    integer :: route_code(MAX_LOG)=0
    real(real64) :: head(MAX_LOG)=0.0_real64
    real(real64) :: pond_in(MAX_LOG)=0.0_real64
    real(real64) :: pond_out(MAX_LOG)=0.0_real64
    real(real64) :: qtop(MAX_LOG)=0.0_real64
  contains
    procedure :: evaluate => logging_evaluate
  end type

  public :: bind_fpe_timeint17c_logging_top,reset_fpe_timeint17c_log,summarize_fpe_timeint17c_log
contains

  subroutine bind_fpe_timeint17c_logging_top(self,inner)
    type(fpe_timeint17c_logging_top_provider_t),intent(out)::self
    type(b110_dynamic_top_boundary_solver_provider_t),target,intent(in)::inner
    self%inner=>inner
    call reset_fpe_timeint17c_log(self)
  end subroutine

  subroutine reset_fpe_timeint17c_log(self)
    type(fpe_timeint17c_logging_top_provider_t),intent(inout)::self
    self%n=0; self%unavailable=0
    self%route_code=0; self%head=0.0_real64; self%pond_in=0.0_real64; self%pond_out=0.0_real64; self%qtop=0.0_real64
  end subroutine

  subroutine logging_evaluate(self,pressure_head_top,water_content_top,candidate_ponding_depth,requested,result)
    class(fpe_timeint17c_logging_top_provider_t),intent(inout)::self
    real(real64),intent(in)::pressure_head_top,water_content_top,candidate_ponding_depth
    type(soil_water_boundary_conditions_t),intent(in)::requested
    type(soil_water_top_boundary_result_t),intent(out)::result
    integer::j
    if(.not.associated(self%inner)) error stop 'TIMEINT17C logging top provider unbound'
    call self%inner%evaluate(pressure_head_top,water_content_top,candidate_ponding_depth,requested,result)
    if(self%n<MAX_LOG)then
      self%n=self%n+1; j=self%n
      self%head(j)=pressure_head_top
      self%pond_in(j)=candidate_ponding_depth
      self%pond_out(j)=result%candidate_ponding_depth
      self%qtop(j)=result%actual_top_flux
      self%route_code(j)=route_code_from_result(result)
    end if
    if(result%status/=SW_TOP_BOUNDARY_AVAILABLE)self%unavailable=self%unavailable+1
  end subroutine

  integer function route_code_from_result(result) result(code)
    type(soil_water_top_boundary_result_t),intent(in)::result
    character(len=:),allocatable::r
    r=trim(result%route); code=T17C_ROUTE_OTHER
    if(index(r,'surface-flux')>0)then
      code=T17C_ROUTE_FLUX
    else if(index(r,'linear-runoff')>0)then
      code=T17C_ROUTE_RUNOFF
    else if(index(r,'ponded-head')>0)then
      code=T17C_ROUTE_HEAD
    else if(index(r,'atmospheric-head')>0)then
      code=T17C_ROUTE_ATMOS
    end if
  end function

  subroutine summarize_fpe_timeint17c_log(self,distinct,transitions,first,last,minpond,maxpond,minhead,maxhead,minq,maxq, &
       nflx,nhead,nrunoff,natmos,nother)
    type(fpe_timeint17c_logging_top_provider_t),intent(in)::self
    integer,intent(out)::distinct,transitions,first,last,nflx,nhead,nrunoff,natmos,nother
    real(real64),intent(out)::minpond,maxpond,minhead,maxhead,minq,maxq
    logical::seen(0:4)
    integer::i
    seen=.false.; transitions=0
    if(self%n<=0)then
      distinct=0; first=0; last=0
      minpond=0;maxpond=0;minhead=0;maxhead=0;minq=0;maxq=0
      nflx=0;nhead=0;nrunoff=0;natmos=0;nother=0
      return
    end if
    first=self%route_code(1); last=self%route_code(self%n)
    minpond=minval(self%pond_in(1:self%n)); maxpond=maxval(self%pond_in(1:self%n))
    minhead=minval(self%head(1:self%n)); maxhead=maxval(self%head(1:self%n))
    minq=minval(self%qtop(1:self%n)); maxq=maxval(self%qtop(1:self%n))
    do i=1,self%n
      if(self%route_code(i)>=0 .and. self%route_code(i)<=4)seen(self%route_code(i))=.true.
      if(i>1)then
        if(self%route_code(i)/=self%route_code(i-1))transitions=transitions+1
      end if
    end do
    distinct=count(seen)
    nflx=count(self%route_code(1:self%n)==T17C_ROUTE_FLUX)
    nhead=count(self%route_code(1:self%n)==T17C_ROUTE_HEAD)
    nrunoff=count(self%route_code(1:self%n)==T17C_ROUTE_RUNOFF)
    natmos=count(self%route_code(1:self%n)==T17C_ROUTE_ATMOS)
    nother=count(self%route_code(1:self%n)==T17C_ROUTE_OTHER)
  end subroutine
end module
