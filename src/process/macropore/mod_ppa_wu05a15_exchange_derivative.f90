module mod_ppa_wu05a15_exchange_derivative
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_ppa_wu05a6_rate_bundle, only: macropore_rate_bundle_request_t, macropore_rate_bundle_result_t
  implicit none
  private

  real(real64),parameter :: RATE_THRESHOLD=1.0e-7_real64
  real(real64),parameter :: HEAD_DIFFERENCE_THRESHOLD=1.0e-14_real64

  type,public :: macropore_exchange_derivative_result_t
    logical :: valid=.false.
    logical :: perched_derivative_included=.false.
    real(real64),allocatable :: unsaturated_dqdh(:,:)
    real(real64),allocatable :: main_saturated_dqdh(:,:)
    real(real64),allocatable :: total_dqdh_node(:)
  end type macropore_exchange_derivative_result_t

  public :: evaluate_macropore_exchange_derivative

contains

  subroutine evaluate_macropore_exchange_derivative(request,rates,capacity,result)
    type(macropore_rate_bundle_request_t),intent(in)::request
    type(macropore_rate_bundle_result_t),intent(in)::rates
    real(real64),intent(in)::capacity(:)
    type(macropore_exchange_derivative_result_t),intent(out)::result

    integer::nd,n,id,ic,ic_top,ic_bottom
    real(real64)::qout,denom,hmp,delh,qexc

    result=macropore_exchange_derivative_result_t()
    if(.not.rates%valid)return
    if(.not.request%unsaturated%valid())return
    if(.not.request%matrix_sat%valid())return

    nd=request%unsaturated%sorptivity%num_domains
    n=request%unsaturated%sorptivity%num_nodes
    if(size(capacity)/=n)return
    if(any(.not.ieee_is_finite(capacity)))return
    if(any(capacity<0.0_real64))return

    if(.not.allocated(rates%qout_unsat_rate) .or. .not.allocated(rates%qout_sat_rate) .or. &
       .not.allocated(rates%qin_matrix_sat_rate))return
    if(any(shape(rates%qout_unsat_rate)/=[nd,n]) .or. &
       any(shape(rates%qout_sat_rate)/=[nd,n]) .or. &
       any(shape(rates%qin_matrix_sat_rate)/=[nd,n]))return

    allocate(result%unsaturated_dqdh(nd,n),result%main_saturated_dqdh(nd,n),result%total_dqdh_node(n))
    result%unsaturated_dqdh=0.0_real64
    result%main_saturated_dqdh=0.0_real64
    result%total_dqdh_node=0.0_real64

    ! Exact B1.11 ABSORPTION(2), standard swabs=1 route.
    do id=1,nd
      ic_bottom=min(request%unsaturated%sorptivity%bottom_domain(id), &
           request%unsaturated%sorptivity%matrix_top_saturated_node-1)
      if(request%unsaturated%sorptivity%swmbf==2 .and. id==1)then
        ic_top=request%unsaturated%sorptivity%top_node
      else
        ic_top=request%unsaturated%sorptivity%top_water_node(id)
      end if
      if(ic_bottom<ic_top)cycle

      do ic=ic_top,ic_bottom
        if(request%unsaturated%sorptivity%perched_active)then
          if(ic>=request%unsaturated%sorptivity%perched_top_node .and. &
             ic<=request%unsaturated%sorptivity%perched_bottom_node)cycle
        end if

        qout=rates%qout_unsat_rate(id,ic)
        if(qout<=RATE_THRESHOLD)cycle

        if(rates%unsaturated%selected_by_sorptivity(id,ic))then
          denom=rates%unsaturated%seed_theta_ref(id,ic)-request%unsaturated%sorptivity%theta(ic)
          if(abs(denom)<=HEAD_DIFFERENCE_THRESHOLD)return
          result%unsaturated_dqdh(id,ic)= -qout*request%unsaturated%sorptivity%sorptivity_alpha(ic) / &
               denom*capacity(ic)
        else
          if(ic<=request%unsaturated%sorptivity%top_water_node(id))cycle
          hmp=max(0.0_real64,request%unsaturated%groundwater_level_domain(id)- &
               request%unsaturated%elevation(ic))
          if(request%unsaturated%pressure_head(ic)<request%unsaturated%entry_head(ic)-1.0e-8_real64 .and. &
             hmp>1.0e-8_real64)then
            delh=max(0.0_real64,hmp-request%unsaturated%pressure_head(ic))
          else
            delh=0.0_real64
          end if
          if(abs(delh)>HEAD_DIFFERENCE_THRESHOLD) &
               result%unsaturated_dqdh(id,ic)= -qout/delh
        end if
      end do
    end do

    ! Exact B1.11 MACRORATE derivative section calls SATFLOW(4) only for the
    ! ordinary/main saturated matrix zone. Perched QInIntSat is deliberately
    ! absent from dFdhMp and therefore contributes zero here.
    do id=1,nd
      if(request%matrix_sat%bottom_domain(id)<request%matrix_sat%matrix_top_saturated_node .or. &
         request%matrix_sat%matrix_bottom_saturated_node<=0)cycle
      ic_bottom=min(request%matrix_sat%bottom_domain(id),request%matrix_sat%matrix_bottom_saturated_node)

      do ic=request%matrix_sat%matrix_top_saturated_node,ic_bottom
        hmp=request%matrix_sat%macro_reference_level(id)-request%matrix_sat%z(ic)
        if(hmp<1.0e-8_real64)hmp=0.0_real64
        delh=hmp-request%matrix_sat%matrix_head(ic)
        if(hmp<1.0e-8_real64 .and. delh>0.0_real64)delh=0.0_real64
        if(abs(delh)<1.0e-8_real64)delh=0.0_real64
        if(request%matrix_sat%matrix_head(ic)<0.0_real64)delh=0.0_real64

        if(abs(delh)>HEAD_DIFFERENCE_THRESHOLD)then
          qexc=rates%qout_sat_rate(id,ic)-rates%qin_matrix_sat_rate(id,ic)
          result%main_saturated_dqdh(id,ic)= -qexc/delh
        end if
      end do
    end do

    result%total_dqdh_node=sum(result%unsaturated_dqdh+result%main_saturated_dqdh,dim=1)
    result%perched_derivative_included=.false.
    result%valid=.true.
  end subroutine evaluate_macropore_exchange_derivative

end module mod_ppa_wu05a15_exchange_derivative
