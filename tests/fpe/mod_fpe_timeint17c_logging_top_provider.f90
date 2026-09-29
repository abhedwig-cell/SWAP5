module mod_fpe_timeint17c_logging_top_provider
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_soil_water_solver_contract, only: dynamic_top_boundary_provider_t, soil_water_boundary_conditions_t, &
       soil_water_top_boundary_result_t, SW_TOP_BOUNDARY_AVAILABLE
  use mod_b110_dynamic_top_boundary_solver_adapter, only: b110_dynamic_top_boundary_solver_provider_t
  implicit none
  private

  integer,parameter :: MAX_LOG=4096
  integer,save :: nlog=0
  integer,save :: route_code_log(MAX_LOG)=0
  real(real64),save :: head_log(MAX_LOG)=0.0_real64
  real(real64),save :: pond_log(MAX_LOG)=0.0_real64
  real(real64),save :: flux_log(MAX_LOG)=0.0_real64
  integer,save :: unavailable_count=0

  type,extends(dynamic_top_boundary_provider_t),public :: fpe_timeint17c_logging_top_provider_t
    type(b110_dynamic_top_boundary_solver_provider_t),pointer :: delegate=>null()
   contains
    procedure :: evaluate => logging_evaluate
  end type

  public :: bind_fpe_timeint17c_logging_top_provider
  public :: reset_fpe_timeint17c_log
  public :: summarize_fpe_timeint17c_log

contains

  subroutine bind_fpe_timeint17c_logging_top_provider(self,delegate)
    type(fpe_timeint17c_logging_top_provider_t),intent(out)::self
    type(b110_dynamic_top_boundary_solver_provider_t),target,intent(in)::delegate
    self%delegate=>delegate
  end subroutine

  subroutine reset_fpe_timeint17c_log()
    nlog=0
    unavailable_count=0
    route_code_log=0
    head_log=0.0_real64
    pond_log=0.0_real64
    flux_log=0.0_real64
  end subroutine

  subroutine logging_evaluate(self,pressure_head_top,water_content_top,candidate_ponding_depth,requested,result)
    class(fpe_timeint17c_logging_top_provider_t),intent(in)::self
    real(real64),intent(in)::pressure_head_top,water_content_top,candidate_ponding_depth
    type(soil_water_boundary_conditions_t),intent(in)::requested
    type(soil_water_top_boundary_result_t),intent(out)::result
    integer::i
    if(.not.associated(self%delegate))then
      result=soil_water_top_boundary_result_t()
      unavailable_count=unavailable_count+1
      return
    end if
    call self%delegate%evaluate(pressure_head_top,water_content_top,candidate_ponding_depth,requested,result)
    if(nlog<MAX_LOG)then
      nlog=nlog+1
      i=nlog
      route_code_log(i)=route_code(trim(result%route))
      head_log(i)=pressure_head_top
      pond_log(i)=candidate_ponding_depth
      flux_log(i)=result%actual_top_flux
    end if
    if(result%status/=SW_TOP_BOUNDARY_AVAILABLE) unavailable_count=unavailable_count+1
  end subroutine

  integer function route_code(route) result(code)
    character(len=*),intent(in)::route
    if(index(route,'linear-runoff')>0)then
      code=3
    else if(index(route,'ponded-head')>0)then
      code=2
    else if(index(route,'surface-flux')>0)then
      code=1
    else if(index(route,'atmospheric-head')>0)then
      code=4
    else
      code=5
    end if
  end function

  subroutine summarize_fpe_timeint17c_log(eval_count,distinct_routes,route_transitions,first_route,last_route, &
       flux_count,head_count,runoff_count,atmos_count,other_count,unavailable, &
       min_head,max_head,min_pond,max_pond,min_flux,max_flux)
    integer,intent(out)::eval_count,distinct_routes,route_transitions,first_route,last_route
    integer,intent(out)::flux_count,head_count,runoff_count,atmos_count,other_count,unavailable
    real(real64),intent(out)::min_head,max_head,min_pond,max_pond,min_flux,max_flux
    logical::seen(5)
    integer::i
    eval_count=nlog
    seen=.false.
    route_transitions=0
    flux_count=0;head_count=0;runoff_count=0;atmos_count=0;other_count=0
    unavailable=unavailable_count
    first_route=0;last_route=0
    min_head=0.0_real64;max_head=0.0_real64
    min_pond=0.0_real64;max_pond=0.0_real64
    min_flux=0.0_real64;max_flux=0.0_real64
    if(nlog<=0)then
      distinct_routes=0
      return
    end if
    first_route=route_code_log(1);last_route=route_code_log(nlog)
    min_head=minval(head_log(1:nlog));max_head=maxval(head_log(1:nlog))
    min_pond=minval(pond_log(1:nlog));max_pond=maxval(pond_log(1:nlog))
    min_flux=minval(flux_log(1:nlog));max_flux=maxval(flux_log(1:nlog))
    do i=1,nlog
      if(route_code_log(i)>=1 .and. route_code_log(i)<=5) seen(route_code_log(i))=.true.
      select case(route_code_log(i))
      case(1);flux_count=flux_count+1
      case(2);head_count=head_count+1
      case(3);runoff_count=runoff_count+1
      case(4);atmos_count=atmos_count+1
      case default;other_count=other_count+1
      end select
      if(i>1)then
        if(route_code_log(i)/=route_code_log(i-1)) route_transitions=route_transitions+1
      end if
    end do
    distinct_routes=count(seen)
  end subroutine

end module mod_fpe_timeint17c_logging_top_provider
