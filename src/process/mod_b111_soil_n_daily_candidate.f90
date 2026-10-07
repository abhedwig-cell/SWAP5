module mod_b111_soil_n_daily_candidate
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_soil_n_pool_state, only: soil_n_inventory_parameters_t, soil_n_pool_state_t, soil_n_transfer_t, &
       soil_n_receipt_t, apply_soil_n_transfer, SOIL_N_OK
  use mod_b111_soil_organic_turnover, only: b111_organic_turnover_parameters_t
  use mod_b111_soil_n_organic_turnover_transfer, only: b111_organic_n_turnover_receipt_t, &
       build_b111_organic_n_turnover_transfer, B111_ORGN_TURNOVER_OK
  use mod_b111_soil_organic_dissimilation, only: b111_organic_dissimilation_result_t, &
       evaluate_b111_organic_dissimilation, B111_ORG_DISS_OK
  use mod_b111_soil_n_rate_factors, only: b111_soil_n_rate_result_t, evaluate_b111_soil_n_rate_constants, &
       B111_NRATE_OK
  use mod_b111_soil_n_storage_conversion, only: b111_soil_n_concentration_state_t, &
       b111_soil_n_concentrations_from_mass, b111_soil_n_mass_from_concentrations, B111_NSTORE_OK
  use mod_b111_soil_n_daily_exchange, only: b111_soil_n_exchange_forcing_t, b111_soil_n_exchange_result_t, &
       evaluate_b111_soil_n_daily_exchange, B111_NEXCHANGE_OK
  implicit none
  private

  integer,parameter,public::B111_NDAY_OK=0
  integer,parameter,public::B111_NDAY_INVALID=1
  integer,parameter,public::B111_NDAY_ORGANIC_FAILED=2
  integer,parameter,public::B111_NDAY_DISSIMILATION_FAILED=3
  integer,parameter,public::B111_NDAY_RATE_FAILED=4
  integer,parameter,public::B111_NDAY_STORAGE_FAILED=5
  integer,parameter,public::B111_NDAY_EXCHANGE_FAILED=6
  integer,parameter,public::B111_NDAY_OWNER_REJECTED=7

  type,public::b111_soil_n_rate_environment_t
    real(real64)::temperature_c=0.0_real64
    real(real64)::temperature_reference_c=0.0_real64
    real(real64)::wfrac_sat=0.0_real64
    real(real64)::wfpscrit2=0.0_real64
    real(real64)::cdissi_half_kg_m2=0.0_real64
    real(real64)::nitrification_ref_per_day=0.0_real64
    real(real64)::denitrification_ref_per_day=0.0_real64
  end type

  type,public::b111_soil_n_daily_candidate_result_t
    integer::status=B111_NDAY_INVALID
    type(b111_organic_n_turnover_receipt_t)::organic
    type(b111_organic_dissimilation_result_t)::dissimilation
    type(b111_soil_n_rate_result_t)::rates
    type(b111_soil_n_exchange_result_t)::exchange
    type(soil_n_receipt_t)::owner_receipt
  end type

  public::evaluate_b111_soil_n_daily_candidate

contains

  subroutine evaluate_b111_soil_n_daily_candidate(owner_params,committed,turnover_params, &
       cfrac_fom,cfrac_biomass,cfrac_humus,rate_environment,exchange_forcing,candidate,result)
    type(soil_n_inventory_parameters_t),intent(in)::owner_params
    type(soil_n_pool_state_t),intent(in)::committed
    type(b111_organic_turnover_parameters_t),intent(in)::turnover_params
    real(real64),intent(in)::cfrac_fom(:),cfrac_biomass,cfrac_humus
    type(b111_soil_n_rate_environment_t),intent(in)::rate_environment
    type(b111_soil_n_exchange_forcing_t),intent(in)::exchange_forcing
    type(soil_n_pool_state_t),intent(out)::candidate
    type(b111_soil_n_daily_candidate_result_t),intent(out)::result

    type(soil_n_transfer_t)::organic_transfer,combined
    type(b111_soil_n_concentration_state_t)::initial_c
    type(b111_soil_n_exchange_forcing_t)::exchange
    real(real64)::nh4_end,no3_end
    integer::storage_status

    candidate=committed
    result=b111_soil_n_daily_candidate_result_t()
    if(.not.owner_params%valid().or..not.committed%valid())return
    if(size(cfrac_fom)/=size(committed%fom_kg_m3))return
    if(.not.all(ieee_is_finite(cfrac_fom)).or. &
       .not.all(ieee_is_finite([cfrac_biomass,cfrac_humus,rate_environment%temperature_c, &
       rate_environment%temperature_reference_c,rate_environment%wfrac_sat,rate_environment%wfpscrit2, &
       rate_environment%cdissi_half_kg_m2,rate_environment%nitrification_ref_per_day, &
       rate_environment%denitrification_ref_per_day])))return

    call build_b111_organic_n_turnover_transfer(owner_params,committed,exchange_forcing%dt_day, &
         turnover_params,organic_transfer,result%organic)
    if(result%organic%status/=B111_ORGN_TURNOVER_OK)then
      result%status=B111_NDAY_ORGANIC_FAILED
      return
    end if

    call evaluate_b111_organic_dissimilation(committed%fom_kg_m3,committed%biomass_kg_m3, &
         committed%humus_kg_m3,owner_params%depth_m,exchange_forcing%dt_day,turnover_params, &
         result%organic%organic,cfrac_fom,cfrac_biomass,cfrac_humus,result%dissimilation)
    if(result%dissimilation%status/=B111_ORG_DISS_OK)then
      result%status=B111_NDAY_DISSIMILATION_FAILED
      return
    end if

    call evaluate_b111_soil_n_rate_constants(rate_environment%temperature_c, &
         rate_environment%temperature_reference_c,exchange_forcing%wfrac_t,exchange_forcing%wfrac_t0, &
         rate_environment%wfrac_sat,rate_environment%wfpscrit2,result%dissimilation%carbon_dissimilation_kg_m2, &
         rate_environment%cdissi_half_kg_m2,rate_environment%nitrification_ref_per_day, &
         rate_environment%denitrification_ref_per_day,result%rates)
    if(result%rates%status/=B111_NRATE_OK)then
      result%status=B111_NDAY_RATE_FAILED
      return
    end if

    call b111_soil_n_concentrations_from_mass(owner_params%depth_m,exchange_forcing%wfrac_t0, &
         exchange_forcing%drybd,exchange_forcing%sorpcoef,committed%ammonium_n_kg_m2, &
         committed%nitrate_n_kg_m2,initial_c)
    if(initial_c%status/=B111_NSTORE_OK)then
      result%status=B111_NDAY_STORAGE_FAILED
      return
    end if

    exchange=exchange_forcing
    exchange%depth_m=owner_params%depth_m
    exchange%nminer_kg_m3=result%organic%nitrogen%mineralized_n_kg_m2/owner_params%depth_m
    exchange%ratecon_nitrif=result%rates%nitrification_rate_constant
    exchange%ratecon_denitr=result%rates%denitrification_rate_constant
    call evaluate_b111_soil_n_daily_exchange(exchange,initial_c%cnh4_kg_m3,initial_c%cno3_kg_m3,result%exchange)
    if(result%exchange%status/=B111_NEXCHANGE_OK)then
      result%status=B111_NDAY_EXCHANGE_FAILED
      return
    end if

    call b111_soil_n_mass_from_concentrations(owner_params%depth_m,exchange_forcing%wfrac_t, &
         exchange_forcing%drybd,exchange_forcing%sorpcoef,result%exchange%cnh4_end,result%exchange%cno3_end, &
         nh4_end,no3_end,storage_status)
    if(storage_status/=B111_NSTORE_OK)then
      result%status=B111_NDAY_STORAGE_FAILED
      return
    end if

    combined=organic_transfer
    combined%ammonium_n_delta_kg_m2=nh4_end-committed%ammonium_n_kg_m2
    combined%nitrate_n_delta_kg_m2=no3_end-committed%nitrate_n_kg_m2
    combined%external_n_input_kg_m2=result%exchange%external_input_kg_m2
    combined%external_n_output_kg_m2=result%exchange%external_output_kg_m2

    call apply_soil_n_transfer(owner_params,committed,combined,candidate,result%owner_receipt)
    if(result%owner_receipt%status/=SOIL_N_OK)then
      candidate=committed
      result%status=B111_NDAY_OWNER_REJECTED
      return
    end if
    result%status=B111_NDAY_OK
  end subroutine
end module
