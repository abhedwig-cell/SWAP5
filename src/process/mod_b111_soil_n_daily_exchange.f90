module mod_b111_soil_n_daily_exchange
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_b111_soil_n_transport, only: b111_soil_n_transport_result_t, evaluate_b111_soil_n_transport, B111_NTRANS_OK
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
    logical::juvenile

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
           f%cnh4_seep,f%cnh4_top,f%cnh4_lat,cnh4_t0,r_demand)
      if(r_demand%status/=B111_NTRANS_OK)then
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

      if(c_demand<c_supply)then
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
           f%cno3_seep,f%cno3_top,f%cno3_lat,cno3_t0,r_demand)
      if(r_demand%status/=B111_NTRANS_OK)then
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

      if(c_demand<c_supply)then
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
    result%nsupply_total_kg_m2_day=(result%nsupply_nh4_kg_m3_day+result%nsupply_no3_kg_m3_day)*f%depth_m
    if(.not.all(ieee_is_finite([result%cnh4_end,result%cnh4_average,result%cno3_end,result%cno3_average, &
         result%nsupply_nh4_kg_m3_day,result%nsupply_no3_kg_m3_day,result%nsupply_total_kg_m2_day, &
         result%nitrification_production_rate_kg_m3_day])))return
    result%status=B111_NEXCHANGE_OK
  end subroutine

  subroutine run_transport(f,tcsf,ratecon,producpot,drybd,sorpcoef,cseep,ctop,clat,c0,r)
    type(b111_soil_n_exchange_forcing_t),intent(in)::f
    real(real64),intent(in)::tcsf,ratecon,producpot,drybd,sorpcoef,cseep,ctop,clat,c0
    type(b111_soil_n_transport_result_t),intent(out)::r
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
    ok=f%depth_m>0.0_real64.and.abs(f%dt_day-1.0_real64)<=64.0_real64*epsilon(1.0_real64).and. &
       min(f%wfrac_t,f%wfrac_t0,f%wflux_out,f%wflux_transp,f%wflux_inbot,f%wflux_intop,f%wflux_inlat, &
       f%tcsf_n,f%root_depth_cm,f%crop_n_demand_kg_m2,f%lai,f%lai_crit_nupt,f%drybd,f%sorpcoef, &
       f%ratecon_nitrif,f%ratecon_denitr,f%cnh4_top,f%cnh4_lat,f%cnh4_seep,f%cno3_top,f%cno3_lat, &
       f%cno3_seep,cnh4_t0,cno3_t0)>=0.0_real64
  end function

end module
