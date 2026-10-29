module mod_ppa_wu05a15_exchange_derivative
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_ppa_wu05a6_rate_bundle, only: macropore_rate_bundle_request_t, macropore_rate_bundle_result_t
  use mod_ppa_wu05a6_unsat_absorption_rate,only:evaluate_entry_darcy_head_difference
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

  subroutine evaluate_macropore_exchange_derivative(request,rates,capacity,result,include_perched)
    type(macropore_rate_bundle_request_t),intent(in)::request
    type(macropore_rate_bundle_result_t),intent(in)::rates
    real(real64),intent(in)::capacity(:)
    type(macropore_exchange_derivative_result_t),intent(out)::result

    logical,intent(in),optional::include_perched
    logical::perched_enabled
    integer::nd,n,id,ic,ic_top,ic_bottom
    real(real64)::qout,denom,hmp,delh,qexc,ddelh,inflow_total,local_inflow,limiter_factor
    real(real64),allocatable::perched_dqdh(:,:)
    logical::projection_ok

    result=macropore_exchange_derivative_result_t()
    perched_enabled=.false.
    if(present(include_perched))perched_enabled=include_perched
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
    allocate(perched_dqdh(nd,n));perched_dqdh=0.0_real64

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
          call evaluate_entry_darcy_head_difference(request%unsaturated%pressure_head(ic), &
               request%unsaturated%entry_head(ic),hmp,request%unsaturated%entry_transition_width_cm,delh,ddelh)
          if(abs(delh)>HEAD_DIFFERENCE_THRESHOLD) &
               result%unsaturated_dqdh(id,ic)=qout*ddelh/delh
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
    ! Explicit numerical opt-in for local head dependence of
    ! matrix-to-macropore seepage in a perched saturated zone.
    ! The partially saturated top cell has a moving water-table fraction and
    ! is deliberately excluded until its additional derivative is qualified.
    if(perched_enabled.and.request%unsaturated%sorptivity%perched_active)then
      if(.not.request%interflow_sat%valid().or..not.allocated(rates%qin_interflow_rate))return
      if(any(shape(rates%qin_interflow_rate)/=[nd,n]))return
      do id=1,nd
        if(request%interflow_sat%matrix_bottom_saturated_node<=0)cycle
        ic_top=request%interflow_sat%matrix_top_saturated_node
        ic_bottom=min(request%interflow_sat%bottom_domain(id),request%interflow_sat%matrix_bottom_saturated_node)
        do ic=ic_top,ic_bottom
          if(ic==ic_top.and.request%interflow_sat%matrix_partial_top_active)cycle
          hmp=request%interflow_sat%macro_reference_level(id)-request%interflow_sat%z(ic)
          if(hmp<1.0e-8_real64)hmp=0.0_real64
          delh=hmp-request%interflow_sat%matrix_head(ic)
          if(request%interflow_sat%matrix_head(ic)<0.0_real64.or. &
             delh>=-HEAD_DIFFERENCE_THRESHOLD)cycle
          if(rates%qin_interflow_rate(id,ic)<=0.0_real64)cycle
          limiter_factor=1.0_real64
          if(allocated(rates%limiter%inflow_fraction))then
            if(size(rates%limiter%inflow_fraction)/=nd)return
            if(any(.not.ieee_is_finite(rates%limiter%inflow_fraction)).or. &
               any(rates%limiter%inflow_fraction<0.0_real64).or. &
               any(rates%limiter%inflow_fraction>1.0_real64))return
            if(rates%limiter%inflow_fraction(id)<1.0_real64.and. &
               .not.request%limiter%conservative_storage_bounds)then
              ! A capped domain shares its available storage among all
              ! inflows. Differentiate this factor for a local interior
              ! perched inflow, retaining the existing diagonal solver.
              ! Cases with another local exchange remain on the prior
              ! Jacobian until their coupled derivative is qualified.
              if(rates%qout_unsat_rate(id,ic)/=0.0_real64.or.rates%qout_sat_rate(id,ic)/=0.0_real64.or. &
                 rates%qin_matrix_sat_rate(id,ic)/=0.0_real64)cycle
              if(.not.allocated(rates%saturated%qin_interflow_rate).or. &
                 .not.allocated(rates%saturated%qin_matrix_sat_rate))return
              if(.not.allocated(request%limiter%potential_top_vertical_cm).or. &
                 .not.allocated(request%limiter%potential_top_lateral_cm))return
              if(any(shape(rates%saturated%qin_interflow_rate)/=[nd,n]).or. &
                 any(shape(rates%saturated%qin_matrix_sat_rate)/=[nd,n]))return
              if(size(request%limiter%potential_top_vertical_cm)/=nd.or. &
                 size(request%limiter%potential_top_lateral_cm)/=nd)return
              inflow_total=request%limiter%potential_top_vertical_cm(id)+ &
                request%limiter%potential_top_lateral_cm(id)+request%interflow_sat%step_duration * &
                (sum(rates%saturated%qin_interflow_rate(id,:))+sum(rates%saturated%qin_matrix_sat_rate(id,:)))
              local_inflow=request%interflow_sat%step_duration*rates%saturated%qin_interflow_rate(id,ic)
              if(.not.ieee_is_finite(inflow_total).or.inflow_total<=0.0_real64.or. &
                 .not.ieee_is_finite(local_inflow).or.local_inflow<0.0_real64)return
              if(local_inflow>inflow_total+64.0_real64*epsilon(1.0_real64)*max(1.0_real64,inflow_total))return
              limiter_factor=max(0.0_real64,min(1.0_real64,1.0_real64-local_inflow/inflow_total))
            end if
          end if
          perched_dqdh(id,ic)=limiter_factor*rates%qin_interflow_rate(id,ic)/delh
          result%total_dqdh_node(ic)=result%total_dqdh_node(ic)+perched_dqdh(id,ic)
          result%perched_derivative_included=.true.
        end do
      end do
    end if

    if(request%limiter%conservative_storage_bounds)then
      call project_conservative_storage_diagonal(request,rates,perched_dqdh,result,projection_ok)
      if(.not.projection_ok)return
    end if
    result%valid=.true.
  end subroutine evaluate_macropore_exchange_derivative

  subroutine project_conservative_storage_diagonal(request,rates,perched_dqdh,result,ok)
    type(macropore_rate_bundle_request_t),intent(in)::request
    type(macropore_rate_bundle_result_t),intent(in)::rates
    real(real64),intent(in)::perched_dqdh(:,:)
    type(macropore_exchange_derivative_result_t),intent(inout)::result
    logical,intent(out)::ok
    real(real64)::dt,total,local_amount,factor
    integer::nd,n,id,ic
    ok=.false.;nd=request%limiter%num_domains;n=size(result%total_dqdh_node)
    if(.not.allocated(rates%limiter%inflow_fraction).or..not.allocated(rates%limiter%outflow_fraction))return
    if(size(rates%limiter%inflow_fraction)/=nd.or.size(rates%limiter%outflow_fraction)/=nd)return
    if(any(.not.ieee_is_finite(rates%limiter%inflow_fraction)).or. &
       any(.not.ieee_is_finite(rates%limiter%outflow_fraction)))return
    if(any(rates%limiter%inflow_fraction<0d0).or.any(rates%limiter%inflow_fraction>1d0).or. &
       any(rates%limiter%outflow_fraction<0d0).or.any(rates%limiter%outflow_fraction>1d0))return
    if(.not.allocated(rates%saturated%qin_interflow_rate).or. &
       .not.allocated(rates%saturated%qin_matrix_sat_rate).or. &
       .not.allocated(rates%saturated%qout_matrix_sat_rate).or. &
       .not.allocated(rates%unsaturated%selected_rate_cm_per_day))return
    if(any(shape(rates%saturated%qin_interflow_rate)/=[nd,n]).or. &
       any(shape(rates%saturated%qin_matrix_sat_rate)/=[nd,n]).or. &
       any(shape(rates%saturated%qout_matrix_sat_rate)/=[nd,n]).or. &
       any(shape(rates%unsaturated%selected_rate_cm_per_day)/=[nd,n]))return
    if(.not.allocated(request%limiter%potential_top_vertical_cm).or. &
       .not.allocated(request%limiter%potential_top_lateral_cm))return
    if(size(request%limiter%potential_top_vertical_cm)/=nd.or.size(request%limiter%potential_top_lateral_cm)/=nd)return
    dt=request%matrix_sat%step_duration
    do id=1,nd
      if(rates%limiter%inflow_fraction(id)<1d0)then
        total=request%limiter%potential_top_vertical_cm(id)+request%limiter%potential_top_lateral_cm(id)+ &
          dt*sum(rates%saturated%qin_interflow_rate(id,:)+rates%saturated%qin_matrix_sat_rate(id,:))
      else if(rates%limiter%outflow_fraction(id)<1d0)then
        total=dt*sum(rates%saturated%qout_matrix_sat_rate(id,:)+rates%unsaturated%selected_rate_cm_per_day(id,:))
        if(id==1)total=total+rates%rapid%total_amount_cm
      else
        cycle
      end if
      if(.not.ieee_is_finite(total).or.total<=0d0)return
      do ic=1,n
        if(rates%limiter%inflow_fraction(id)<1d0)then
          local_amount=dt*(rates%saturated%qin_interflow_rate(id,ic)+rates%saturated%qin_matrix_sat_rate(id,ic))
        else
          local_amount=dt*(rates%saturated%qout_matrix_sat_rate(id,ic)+rates%unsaturated%selected_rate_cm_per_day(id,ic))
        end if
        if(.not.ieee_is_finite(local_amount).or.local_amount<0d0)return
        ! Differentiate the shared stock fraction. The numerator of an active
        ! inflow cap includes outgoing water; conversely an outflow cap includes
        ! incoming water. Hence the SAME local net-exchange derivative is
        ! multiplied by (1-local/total), including simultaneous local exchanges.
        ! Geometry, accepted storage and other-node heads are held fixed here.
        ! Component arrays retain frozen-fraction derivatives; only the total
        ! diagonal includes this limiter feedback. No process rate is changed.
        factor=max(0d0,min(1d0,1d0-local_amount/total))
        if(factor/=1d0)result%total_dqdh_node(ic)=result%total_dqdh_node(ic)+(factor-1d0)* &
          (result%unsaturated_dqdh(id,ic)+result%main_saturated_dqdh(id,ic)+perched_dqdh(id,ic))
      end do
    end do
    ok=.true.
  end subroutine project_conservative_storage_diagonal

end module mod_ppa_wu05a15_exchange_derivative
