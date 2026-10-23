module mod_b111_soil_n_daily_exchange
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_b111_soil_n_transport, only: b111_soil_n_transport_result_t, evaluate_b111_soil_n_transport, &
       evaluate_b111_soil_n_negative_boundary,B111_NTRANS_OK,B111_NTRANS_INVALID
  implicit none
  private

  integer,parameter,public::B111_NEXCHANGE_OK=0
  integer,parameter,public::B111_NEXCHANGE_INVALID=1
  integer,parameter,public::B111_NEXCHANGE_TRANSPORT_FAILED=2

  type,public::b111_soil_n_exchange_forcing_t
    real(real64)::depth_m=0.0_real64
    real(real64)::dt_day=1.0_real64
    real(real64)::wfrac_t=0.0_real64
    real(real64)::wfrac_t0=0.0_real64
    real(real64)::wflux_out=0.0_real64
    real(real64)::wflux_transp=0.0_real64
    real(real64)::wflux_inbot=0.0_real64
    real(real64)::wflux_intop=0.0_real64
    real(real64)::wflux_inlat=0.0_real64
    real(real64)::tcsf_n=0.0_real64
    real(real64)::root_depth_cm=0.0_real64
    real(real64)::crop_n_demand_kg_m2=0.0_real64
    real(real64)::dvs=0.0_real64
    real(real64)::lai=0.0_real64
    real(real64)::lai_crit_nupt=0.0_real64
    logical::crop_calendar_active=.false.
    logical::finite_donor_top=.false.
    logical::nondepleting_top=.false.
    real(real64)::drybd=0.0_real64
    real(real64)::sorpcoef=0.0_real64
    real(real64)::ratecon_nitrif=0.0_real64
    real(real64)::ratecon_denitr=0.0_real64
    real(real64)::nminer_kg_m3=0.0_real64
    real(real64)::cnh4_top=0.0_real64
    real(real64)::cnh4_lat=0.0_real64
    real(real64)::cnh4_seep=0.0_real64
    real(real64)::cno3_top=0.0_real64
    real(real64)::cno3_lat=0.0_real64
    real(real64)::cno3_seep=0.0_real64
  end type

  type,public::b111_soil_n_exchange_result_t
    integer::status=B111_NEXCHANGE_INVALID
    real(real64)::cnh4_end=0.0_real64
    real(real64)::cnh4_average=0.0_real64
    real(real64)::cno3_end=0.0_real64
    real(real64)::cno3_average=0.0_real64
    real(real64)::nsupply_nh4_kg_m3_day=0.0_real64
    real(real64)::nsupply_no3_kg_m3_day=0.0_real64
    real(real64)::nsupply_total_kg_m2_day=0.0_real64
    real(real64)::juvenile_factor=0.0_real64
    real(real64)::nitrification_production_rate_kg_m3_day=0.0_real64
    real(real64)::nh4_nitrified_kg_m2=0.0_real64
    real(real64)::no3_denitrified_kg_m2=0.0_real64
    real(real64)::nh4_boundary_input_kg_m2=0.0_real64
    real(real64)::no3_boundary_input_kg_m2=0.0_real64
    real(real64)::nh4_outflow_kg_m2=0.0_real64
    real(real64)::no3_outflow_kg_m2=0.0_real64
    real(real64)::nh4_crop_uptake_kg_m2=0.0_real64
    real(real64)::no3_crop_uptake_kg_m2=0.0_real64
    real(real64)::external_input_kg_m2=0.0_real64
    real(real64)::external_output_kg_m2=0.0_real64
    real(real64)::top_actual(2)=0d0,top_unmet(2)=0d0,top_requested(2)=0d0
  end type

  public::evaluate_b111_soil_n_daily_exchange

contains

  subroutine evaluate_b111_soil_n_daily_exchange(f,cnh4_t0,cno3_t0,result)
    type(b111_soil_n_exchange_forcing_t),intent(in)::f
    real(real64),intent(in)::cnh4_t0,cno3_t0
    type(b111_soil_n_exchange_result_t),intent(out)::result
    type(b111_soil_n_transport_result_t)::r_demand,r_supply,r_selected
    real(real64)::wavg,root_factor,prod_rate0,producpot,tcsf
    real(real64)::c_demand,c_supply,cav_demand,cav_supply
    real(real64)::supply_demand,supply_supply,remaining_demand
    logical::juvenile,demand_depleted

    result=b111_soil_n_exchange_result_t()
    if(.not.valid_forcing(f,cnh4_t0,cno3_t0))return
    wavg=0.5_real64*(f%wfrac_t+f%wfrac_t0)
    if(wavg<=0.0_real64)return
    root_factor=max(1.0_real64,0.01_real64*f%root_depth_cm/f%depth_m)

    juvenile=f%crop_calendar_active.and.f%dvs<1.0_real64.and.f%lai_crit_nupt>1.0e-2_real64.and. &
         f%lai<f%lai_crit_nupt
    if(juvenile)result%juvenile_factor=(f%lai_crit_nupt-f%lai)/f%lai_crit_nupt

    ! B1.11 mineralisation amount is converted to a volumetric production rate.
    prod_rate0=f%nminer_kg_m3/f%dt_day

    if(f%finite_donor_top)then
      call evaluate_b111_soil_n_negative_boundary(f%depth_m,f%dt_day,f%wfrac_t,f%wfrac_t0, &
        f%wflux_out,f%wflux_inbot,f%wflux_intop,f%wflux_inlat,f%ratecon_nitrif,prod_rate0, &
        f%drybd,f%sorpcoef,f%cnh4_seep,f%cnh4_top,f%cnh4_lat,cnh4_t0,r_selected)
      if(r_selected%status/=B111_NTRANS_OK)then
        result%status=B111_NEXCHANGE_TRANSPORT_FAILED;return
      end if
      result%cnh4_end=r_selected%concentration_end;result%cnh4_average=r_selected%concentration_average
      result%top_actual(1)=r_selected%top_actual_rate*f%dt_day
      result%top_unmet(1)=r_selected%top_unmet
      prod_rate0=wavg*f%ratecon_nitrif*result%cnh4_average
      result%nitrification_production_rate_kg_m3_day=prod_rate0
      call evaluate_b111_soil_n_negative_boundary(f%depth_m,f%dt_day,f%wfrac_t,f%wfrac_t0, &
        f%wflux_out,f%wflux_inbot,f%wflux_intop,f%wflux_inlat,f%ratecon_denitr,prod_rate0, &
        0d0,0d0,f%cno3_seep,f%cno3_top,f%cno3_lat,cno3_t0,r_selected)
      if(r_selected%status/=B111_NTRANS_OK)then
        result%status=B111_NEXCHANGE_TRANSPORT_FAILED;return
      end if
      result%cno3_end=r_selected%concentration_end;result%cno3_average=r_selected%concentration_average
      result%top_actual(2)=r_selected%top_actual_rate*f%dt_day
      result%top_unmet(2)=r_selected%top_unmet
      result%top_requested=f%wflux_intop*[f%cnh4_top,f%cno3_top]*f%dt_day
    else

    ! --- ammonium: demand-limited versus supply-limited source branches.
    if(juvenile)then
      producpot=prod_rate0-result%juvenile_factor*f%crop_n_demand_kg_m2/f%depth_m
      tcsf=f%tcsf_n*(wavg+f%drybd*f%sorpcoef)/wavg*(1.0_real64-result%juvenile_factor)*root_factor
      call run_transport(f,tcsf,f%ratecon_nitrif,producpot,f%drybd,f%sorpcoef, &
           f%cnh4_seep,f%cnh4_top,f%cnh4_lat,cnh4_t0,r_selected)
      if(r_selected%status/=B111_NTRANS_OK)then
        result%status=B111_NEXCHANGE_TRANSPORT_FAILED;return
      end if
      result%cnh4_end=r_selected%concentration_end
      result%cnh4_average=r_selected%concentration_average
      result%nsupply_nh4_kg_m3_day=tcsf*f%wflux_transp*result%cnh4_average/f%depth_m + &
           prod_rate0-r_selected%production_actual
    else
      producpot=prod_rate0-f%crop_n_demand_kg_m2/f%depth_m
      call run_transport(f,0.0_real64,f%ratecon_nitrif,producpot,f%drybd,f%sorpcoef, &
           f%cnh4_seep,f%cnh4_top,f%cnh4_lat,cnh4_t0,r_demand,demand_depleted)
      if(r_demand%status/=B111_NTRANS_OK.and..not.demand_depleted)then
        result%status=B111_NEXCHANGE_TRANSPORT_FAILED;return
      end if
      c_demand=r_demand%concentration_end
      cav_demand=r_demand%concentration_average
      supply_demand=prod_rate0-r_demand%production_actual

      producpot=prod_rate0
      tcsf=f%tcsf_n*(wavg+f%drybd*f%sorpcoef)/wavg*root_factor
      call run_transport(f,tcsf,f%ratecon_nitrif,producpot,f%drybd,f%sorpcoef, &
           f%cnh4_seep,f%cnh4_top,f%cnh4_lat,cnh4_t0,r_supply)
      if(r_supply%status/=B111_NTRANS_OK)then
        result%status=B111_NEXCHANGE_TRANSPORT_FAILED;return
      end if
      c_supply=r_supply%concentration_end
      cav_supply=r_supply%concentration_average
      supply_supply=tcsf*f%wflux_transp*cav_supply/f%depth_m

      if(demand_depleted.or.c_demand<c_supply)then
        result%cnh4_end=c_supply
        result%cnh4_average=cav_supply
        result%nsupply_nh4_kg_m3_day=supply_supply
      else
        result%cnh4_end=c_demand
        result%cnh4_average=cav_demand
        result%nsupply_nh4_kg_m3_day=supply_demand
      end if
    end if

    if(result%nsupply_nh4_kg_m3_day<0.0_real64.and.abs(result%nsupply_nh4_kg_m3_day)<1.0e-12_real64) &
         result%nsupply_nh4_kg_m3_day=0.0_real64
    if(result%nsupply_nh4_kg_m3_day<0.0_real64)return

    ! --- nitrate: nitrification is the production term for the NO3 equation.
    prod_rate0=wavg*f%ratecon_nitrif*result%cnh4_average
    result%nitrification_production_rate_kg_m3_day=prod_rate0
    remaining_demand=f%crop_n_demand_kg_m2/f%depth_m-result%nsupply_nh4_kg_m3_day

    if(juvenile)then
      producpot=prod_rate0-result%juvenile_factor*remaining_demand
      tcsf=f%tcsf_n*(1.0_real64-result%juvenile_factor)*root_factor
      call run_transport(f,tcsf,f%ratecon_denitr,producpot,0.0_real64,0.0_real64, &
           f%cno3_seep,f%cno3_top,f%cno3_lat,cno3_t0,r_selected)
      if(r_selected%status/=B111_NTRANS_OK)then
        result%status=B111_NEXCHANGE_TRANSPORT_FAILED;return
      end if
      result%cno3_end=r_selected%concentration_end
      result%cno3_average=r_selected%concentration_average
      result%nsupply_no3_kg_m3_day=tcsf*f%wflux_transp*result%cno3_average/f%depth_m + &
           prod_rate0-r_selected%production_actual
    else
      producpot=prod_rate0-remaining_demand
      call run_transport(f,0.0_real64,f%ratecon_denitr,producpot,0.0_real64,0.0_real64, &
           f%cno3_seep,f%cno3_top,f%cno3_lat,cno3_t0,r_demand,demand_depleted)
      if(r_demand%status/=B111_NTRANS_OK.and..not.demand_depleted)then
        result%status=B111_NEXCHANGE_TRANSPORT_FAILED;return
      end if
      c_demand=r_demand%concentration_end
      cav_demand=r_demand%concentration_average
      supply_demand=prod_rate0-r_demand%production_actual

      producpot=prod_rate0
      tcsf=f%tcsf_n*root_factor
      call run_transport(f,tcsf,f%ratecon_denitr,producpot,0.0_real64,0.0_real64, &
           f%cno3_seep,f%cno3_top,f%cno3_lat,cno3_t0,r_supply)
      if(r_supply%status/=B111_NTRANS_OK)then
        result%status=B111_NEXCHANGE_TRANSPORT_FAILED;return
      end if
      c_supply=r_supply%concentration_end
      cav_supply=r_supply%concentration_average
      supply_supply=tcsf*f%wflux_transp*cav_supply/f%depth_m

      if(demand_depleted.or.c_demand<c_supply)then
        result%cno3_end=c_supply
        result%cno3_average=cav_supply
        result%nsupply_no3_kg_m3_day=supply_supply
      else
        result%cno3_end=c_demand
        result%cno3_average=cav_demand
        result%nsupply_no3_kg_m3_day=supply_demand
      end if
    end if

    if(result%nsupply_no3_kg_m3_day<0.0_real64.and.abs(result%nsupply_no3_kg_m3_day)<1.0e-12_real64) &
         result%nsupply_no3_kg_m3_day=0.0_real64
    if(result%nsupply_no3_kg_m3_day<0.0_real64)return
    end if ! Explicit finite-donor fallow; incumbent active-crop path above.
    result%nsupply_total_kg_m2_day=(result%nsupply_nh4_kg_m3_day+result%nsupply_no3_kg_m3_day)*f%depth_m
    result%nh4_nitrified_kg_m2=wavg*f%ratecon_nitrif*result%cnh4_average*f%dt_day*f%depth_m
    result%no3_denitrified_kg_m2=wavg*f%ratecon_denitr*result%cno3_average*f%dt_day*f%depth_m
    result%nh4_boundary_input_kg_m2=(f%cnh4_top*f%wflux_intop+f%cnh4_lat*f%wflux_inlat+ &
         f%cnh4_seep*f%wflux_inbot)*f%dt_day
    result%no3_boundary_input_kg_m2=(f%cno3_top*f%wflux_intop+f%cno3_lat*f%wflux_inlat+ &
         f%cno3_seep*f%wflux_inbot)*f%dt_day
    result%nh4_outflow_kg_m2=result%cnh4_average*f%wflux_out*f%dt_day
    result%no3_outflow_kg_m2=result%cno3_average*f%wflux_out*f%dt_day
    result%nh4_crop_uptake_kg_m2=result%nsupply_nh4_kg_m3_day*f%depth_m
    result%no3_crop_uptake_kg_m2=result%nsupply_no3_kg_m3_day*f%depth_m
    result%external_input_kg_m2=result%nh4_boundary_input_kg_m2+result%no3_boundary_input_kg_m2
    result%external_output_kg_m2=result%nh4_outflow_kg_m2+result%no3_outflow_kg_m2+ &
         result%nh4_crop_uptake_kg_m2+result%no3_crop_uptake_kg_m2+result%no3_denitrified_kg_m2
    if(f%finite_donor_top.or.f%nondepleting_top)then
      result%nh4_boundary_input_kg_m2=(f%cnh4_lat*f%wflux_inlat+f%cnh4_seep*f%wflux_inbot)*f%dt_day
      result%no3_boundary_input_kg_m2=(f%cno3_lat*f%wflux_inlat+f%cno3_seep*f%wflux_inbot)*f%dt_day
      result%external_input_kg_m2=result%nh4_boundary_input_kg_m2+result%no3_boundary_input_kg_m2
      if(f%nondepleting_top)then
        result%top_requested=f%wflux_intop*[f%cnh4_top,f%cno3_top]*f%dt_day
        result%top_actual=result%top_requested
      end if
      result%external_output_kg_m2=result%external_output_kg_m2-sum(result%top_actual)
    end if
    if(.not.all(ieee_is_finite([result%cnh4_end,result%cnh4_average,result%cno3_end,result%cno3_average, &
         result%nsupply_nh4_kg_m3_day,result%nsupply_no3_kg_m3_day,result%nsupply_total_kg_m2_day, &
         result%nitrification_production_rate_kg_m3_day,result%nh4_nitrified_kg_m2,result%no3_denitrified_kg_m2, &
         result%external_input_kg_m2,result%external_output_kg_m2])))return
    result%status=B111_NEXCHANGE_OK
  end subroutine

  subroutine run_transport(f,tcsf,ratecon,producpot,drybd,sorpcoef,cseep,ctop,clat,c0,r,depleted)
    type(b111_soil_n_exchange_forcing_t),intent(in)::f
    real(real64),intent(in)::tcsf,ratecon,producpot,drybd,sorpcoef,cseep,ctop,clat,c0
    type(b111_soil_n_transport_result_t),intent(out)::r
    logical,intent(out),optional::depleted
    logical::empty_equilibrium
    if(present(depleted))depleted=.false.
    if(f%nondepleting_top)then
      ! Same unconstrained WaterN ODE, with root loss included in qout and
      ! a signed constant production included in the aggregate top sink.
      ! Competing constant sinks remain closed after exhaustion. The only
      ! bounded exception is a sole constant crop sink with no net immobilisation.
      call evaluate_b111_soil_n_negative_boundary(f%depth_m,f%dt_day,f%wfrac_t,f%wfrac_t0, &
           f%wflux_out+tcsf*f%wflux_transp,f%wflux_inbot,f%wflux_intop,f%wflux_inlat, &
           ratecon,max(0d0,producpot),drybd,sorpcoef,cseep, &
           ctop+min(0d0,producpot)*f%depth_m/f%wflux_intop,clat,c0,r)
      if(r%status/=B111_NTRANS_OK)return
      ! An empty homogeneous equation stays exactly zero. This is not donor
      ! exhaustion: no prescribed production, boundary loading or top sink
      ! needs to be partitioned.
      empty_equilibrium=c0==0d0.and.producpot==0d0.and.ctop==0d0.and. &
        (f%wflux_inbot==0d0.or.cseep==0d0).and.(f%wflux_inlat==0d0.or.clat==0d0)
      if(r%depletion_time<f%dt_day.or.r%top_unmet>0d0.or. &
         (r%concentration_end<=0d0.and..not.empty_equilibrium))then
        ! Preserve the selector's exhausted-demand ordering, including zero ties.
        if(present(depleted))depleted=.true.
        if(ctop==0d0.and.f%nminer_kg_m3>=0d0.and.producpot<0d0)then
          ! With no prescribed top-N sink and nonnegative net mineralisation,
          ! the only negative constant term is crop demand. The existing finite
          ! donor receipt therefore belongs wholly to that crop sink. Restore
          ! its actual signed production and remove the surrogate top receipt.
          r%production_actual=r%top_actual_rate/f%depth_m
          r%top_actual_rate=0d0;r%top_unmet=0d0
          return
        end if
        r%status=B111_NTRANS_INVALID;return
      end if
      r%production_actual=producpot
      r%top_actual_rate=f%wflux_intop*ctop
      return
    end if
    call evaluate_b111_soil_n_transport(f%depth_m,f%dt_day,f%wfrac_t,f%wfrac_t0,f%wflux_out, &
         f%wflux_transp,f%wflux_inbot,f%wflux_intop,f%wflux_inlat,tcsf,ratecon,producpot,drybd,sorpcoef, &
         cseep,ctop,clat,c0,r)
  end subroutine

  pure logical function valid_forcing(f,cnh4_t0,cno3_t0) result(ok)
    type(b111_soil_n_exchange_forcing_t),intent(in)::f
    real(real64),intent(in)::cnh4_t0,cno3_t0
    real(real64)::v(25)
    v=[f%depth_m,f%dt_day,f%wfrac_t,f%wfrac_t0,f%wflux_out,f%wflux_transp,f%wflux_inbot, &
       f%wflux_intop,f%wflux_inlat,f%tcsf_n,f%root_depth_cm,f%crop_n_demand_kg_m2,f%dvs,f%lai, &
       f%lai_crit_nupt,f%drybd,f%sorpcoef,f%ratecon_nitrif,f%ratecon_denitr,f%nminer_kg_m3, &
       f%cnh4_top,f%cnh4_lat,f%cnh4_seep,f%cno3_top,f%cno3_lat]
    ok=all(ieee_is_finite(v)).and.all(ieee_is_finite([f%cno3_seep,cnh4_t0,cno3_t0]))
    if(.not.ok)return
    if(f%finite_donor_top.and.f%nondepleting_top)then
      ok=.false.;return
    end if
    if(f%nondepleting_top)then
      if(f%wflux_intop>=0d0)then
        ok=.false.;return
      end if
    else if(f%finite_donor_top)then
      if(f%crop_calendar_active.or.abs(f%crop_n_demand_kg_m2)>0d0.or.abs(f%wflux_transp)>0d0.or. &
         f%wflux_intop>=0d0.or.f%nminer_kg_m3<0d0)then
        ok=.false.;return
      end if
    else if(f%wflux_intop<0d0)then
      ok=.false.;return
    end if
    ok=f%depth_m>0.0_real64.and.abs(f%dt_day-1.0_real64)<=64.0_real64*epsilon(1.0_real64).and. &
       min(f%wfrac_t,f%wfrac_t0,f%wflux_out,f%wflux_transp,f%wflux_inbot,f%wflux_inlat, &
       f%tcsf_n,f%root_depth_cm,f%crop_n_demand_kg_m2,f%lai,f%lai_crit_nupt,f%drybd,f%sorpcoef, &
       f%ratecon_nitrif,f%ratecon_denitr,f%cnh4_top,f%cnh4_lat,f%cnh4_seep,f%cno3_top,f%cno3_lat, &
       f%cno3_seep,cnh4_t0,cno3_t0)>=0.0_real64
  end function

end module
