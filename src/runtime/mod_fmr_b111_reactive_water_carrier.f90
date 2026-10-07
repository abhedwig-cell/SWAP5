module mod_fmr_b111_reactive_water_carrier
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  use mod_fmr_serialized_reference_backend, only: fmr_water_flux_substep_trace_t
  use mod_solute_water_face_flux_reconstruction, only: reconstruct_interval_water_face_flux, WATER_FACE_FLUX_OK
  use mod_b111_reactive_solute_substep, only: b111_reactive_solute_substep_forcing_t
  use mod_b111_age_tracer_substep, only: b111_age_tracer_substep_forcing_t
  use mod_fmr_b111_reactive_solute_transaction, only: fmr_b111_reactive_solute_model_t, &
       configure_fmr_b111_reactive_solute_model, FMR_B111_REACTIVE_OK
  implicit none
  private

  integer,parameter,public::FMR_B111_WATER_CARRIER_OK=0
  integer,parameter,public::FMR_B111_WATER_CARRIER_INVALID=1
  integer,parameter,public::FMR_B111_WATER_CARRIER_MACROPORE_UNSUPPORTED=2
  integer,parameter,public::FMR_B111_WATER_CARRIER_FLUX_RECONSTRUCTION_FAILED=3

  type,public::fmr_b111_reactive_static_forcing_t
    real(real64),allocatable::dz_cm(:)
    real(real64),allocatable::face_left_weight(:)
    real(real64),allocatable::face_right_weight(:)
    real(real64),allocatable::face_distance_cm(:)
    real(real64),allocatable::theta_sat_left(:)
    real(real64),allocatable::dispersivity_cm(:)
    real(real64)::molecular_diffusion_cm2_day=0.0_real64
    real(real64)::cdrain_mg_cm3=0.0_real64
    real(real64)::cseep_mg_cm3=0.0_real64
    real(real64)::tscf=0.0_real64
    real(real64)::rain_rate_cm_day=0.0_real64
    real(real64)::rain_c_mg_cm3=0.0_real64
    real(real64)::irrigation_rate_cm_day=0.0_real64
    real(real64)::irrigation_c_mg_cm3=0.0_real64
    real(real64)::macropore_area_fraction=0.0_real64
    logical::temperature_active=.false.
    real(real64),allocatable::temperature_c(:)
    real(real64),allocatable::gampar(:)
    real(real64),allocatable::rtheta(:)
    real(real64),allocatable::bexp(:)
    real(real64),allocatable::decpot(:)
    real(real64),allocatable::fdepth(:)
    real(real64),allocatable::bulk_density(:)
    real(real64),allocatable::kf(:)
    real(real64)::cref_mg_cm3=1.0_real64
    real(real64)::frexp=1.0_real64
    real(real64)::drain_age_day=0.0_real64
    real(real64)::rain_age_day=0.0_real64
    real(real64)::irrigation_age_day=0.0_real64
  end type

  public::build_fmr_b111_reactive_forcing_from_accepted_trace
  public::configure_fmr_b111_reactive_model_from_accepted_trace

contains

  subroutine build_fmr_b111_reactive_forcing_from_accepted_trace(trace,static,chemical,age,status, &
       closure_tolerance_cm_day)
    type(fmr_water_flux_substep_trace_t),intent(in)::trace
    type(fmr_b111_reactive_static_forcing_t),intent(in)::static
    type(b111_reactive_solute_substep_forcing_t),intent(out)::chemical
    type(b111_age_tracer_substep_forcing_t),intent(out)::age
    integer,intent(out)::status
    real(real64),intent(in),optional::closure_tolerance_cm_day

    real(real64),allocatable::faces_down(:)
    real(real64)::dt,closure,tolerance
    integer::n,face_status

    chemical=b111_reactive_solute_substep_forcing_t()
    age=b111_age_tracer_substep_forcing_t()
    status=FMR_B111_WATER_CARRIER_INVALID

    if(.not.ieee_is_finite(trace%t0).or..not.ieee_is_finite(trace%t1).or.trace%t1<=trace%t0)return
    if(.not.allocated(trace%water_start).or..not.allocated(trace%water_end).or. &
       .not.allocated(trace%net_node_source).or..not.allocated(trace%root_sink).or. &
       .not.allocated(trace%drainage_sink_by_level))return
    n=size(trace%water_start)
    if(n<1.or.size(trace%water_end)/=n.or.size(trace%net_node_source)/=n.or.size(trace%root_sink)/=n.or. &
       size(trace%drainage_sink_by_level,2)/=n)return
    if(.not.all(ieee_is_finite(trace%water_start)).or..not.all(ieee_is_finite(trace%water_end)).or. &
       .not.all(ieee_is_finite(trace%net_node_source)).or..not.all(ieee_is_finite(trace%root_sink)).or. &
       .not.all(ieee_is_finite(trace%drainage_sink_by_level)))return
    if(any(trace%water_start<=0.0_real64).or.any(trace%water_end<=0.0_real64).or. &
       any(trace%root_sink<0.0_real64))return
    if(.not.ieee_is_finite(trace%top_flux).or..not.ieee_is_finite(trace%bottom_flux).or. &
       .not.ieee_is_finite(trace%pond_start).or..not.ieee_is_finite(trace%pond_end).or. &
       trace%pond_start<0.0_real64.or.trace%pond_end<0.0_real64)return

    if(allocated(trace%macropore_matrix_exchange))then
      if(size(trace%macropore_matrix_exchange)/=n)return
      if(any(abs(trace%macropore_matrix_exchange)>0.0_real64))then
        status=FMR_B111_WATER_CARRIER_MACROPORE_UNSUPPORTED
        return
      end if
    end if
    if(allocated(trace%macropore_matrix_exchange_domain))then
      if(size(trace%macropore_matrix_exchange_domain,2)/=n)return
      if(size(trace%macropore_matrix_exchange_domain,1)>0)then
        status=FMR_B111_WATER_CARRIER_MACROPORE_UNSUPPORTED
        return
      end if
    end if

    if(.not.static_valid(static,n))return
    dt=trace%t1-trace%t0
    tolerance=1.0e-12_real64
    if(present(closure_tolerance_cm_day))tolerance=closure_tolerance_cm_day
    if(.not.ieee_is_finite(tolerance).or.tolerance<0.0_real64)return

    call reconstruct_interval_water_face_flux(static%dz_cm,trace%water_start,trace%water_end,trace%net_node_source, &
         -trace%top_flux,-trace%bottom_flux,dt,tolerance,faces_down,closure,face_status)
    if(face_status/=WATER_FACE_FLUX_OK)then
      status=FMR_B111_WATER_CARRIER_FLUX_RECONSTRUCTION_FAILED
      return
    end if

    chemical%dt_day=dt
    chemical%theta=trace%water_end
    chemical%dz_cm=static%dz_cm
    chemical%q_face_up_cm_day=-faces_down
    chemical%root_sink_cm_day=trace%root_sink
    chemical%qdra_cm_day=trace%drainage_sink_by_level
    chemical%cdrain_mg_cm3=static%cdrain_mg_cm3
    chemical%cseep_mg_cm3=static%cseep_mg_cm3
    chemical%tscf=static%tscf
    chemical%rain_rate_cm_day=static%rain_rate_cm_day
    chemical%rain_c_mg_cm3=static%rain_c_mg_cm3
    chemical%irrigation_rate_cm_day=static%irrigation_rate_cm_day
    chemical%irrigation_c_mg_cm3=static%irrigation_c_mg_cm3
    chemical%macropore_area_fraction=static%macropore_area_fraction
    chemical%pond_end_cm=trace%pond_end
    chemical%face_left_weight=static%face_left_weight
    chemical%face_right_weight=static%face_right_weight
    chemical%face_distance_cm=static%face_distance_cm
    chemical%theta_sat_left=static%theta_sat_left
    chemical%dispersivity_cm=static%dispersivity_cm
    chemical%molecular_diffusion_cm2_day=static%molecular_diffusion_cm2_day
    chemical%temperature_active=static%temperature_active
    chemical%temperature_c=static%temperature_c
    chemical%gampar=static%gampar
    chemical%rtheta=static%rtheta
    chemical%bexp=static%bexp
    chemical%decpot=static%decpot
    chemical%fdepth=static%fdepth
    chemical%bulk_density=static%bulk_density
    chemical%kf=static%kf
    chemical%cref_mg_cm3=static%cref_mg_cm3
    chemical%frexp=static%frexp

    age%dt_day=dt
    age%theta=trace%water_end
    age%theta_previous=trace%water_start
    age%dz_cm=static%dz_cm
    age%q_face_up_cm_day=-faces_down
    age%root_sink_cm_day=trace%root_sink
    age%qdra_cm_day=trace%drainage_sink_by_level
    age%drain_age_day=static%drain_age_day
    age%rain_rate_cm_day=static%rain_rate_cm_day
    age%rain_age_day=static%rain_age_day
    age%irrigation_rate_cm_day=static%irrigation_rate_cm_day
    age%irrigation_age_day=static%irrigation_age_day
    age%pond_previous_cm=trace%pond_start
    age%pond_end_cm=trace%pond_end
    age%macropore_area_fraction=static%macropore_area_fraction
    age%face_left_weight=static%face_left_weight
    age%face_right_weight=static%face_right_weight
    age%face_distance_cm=static%face_distance_cm
    age%theta_sat_left=static%theta_sat_left
    age%dispersivity_cm=static%dispersivity_cm
    age%molecular_diffusion_cm2_day=static%molecular_diffusion_cm2_day

    status=FMR_B111_WATER_CARRIER_OK
  end subroutine

  subroutine configure_fmr_b111_reactive_model_from_accepted_trace(trace,static,model,status, &
       closure_tolerance_cm_day)
    type(fmr_water_flux_substep_trace_t),intent(in)::trace
    type(fmr_b111_reactive_static_forcing_t),intent(in)::static
    type(fmr_b111_reactive_solute_model_t),intent(out)::model
    integer,intent(out)::status
    real(real64),intent(in),optional::closure_tolerance_cm_day
    type(b111_reactive_solute_substep_forcing_t)::chemical
    type(b111_age_tracer_substep_forcing_t)::age
    integer::carrier_status,model_status

    model=fmr_b111_reactive_solute_model_t()
    status=FMR_B111_WATER_CARRIER_INVALID
    if(present(closure_tolerance_cm_day))then
      call build_fmr_b111_reactive_forcing_from_accepted_trace(trace,static,chemical,age,carrier_status, &
           closure_tolerance_cm_day)
    else
      call build_fmr_b111_reactive_forcing_from_accepted_trace(trace,static,chemical,age,carrier_status)
    end if
    if(carrier_status/=FMR_B111_WATER_CARRIER_OK)then
      status=carrier_status
      return
    end if
    call configure_fmr_b111_reactive_solute_model(chemical,age,model,model_status)
    if(model_status/=FMR_B111_REACTIVE_OK)return
    status=FMR_B111_WATER_CARRIER_OK
  end subroutine

  logical function static_valid(s,n) result(ok)
    type(fmr_b111_reactive_static_forcing_t),intent(in)::s
    integer,intent(in)::n
    ok=.false.
    if(.not.allocated(s%dz_cm).or.size(s%dz_cm)/=n)return
    if(.not.allocated(s%temperature_c).or..not.allocated(s%gampar).or..not.allocated(s%rtheta).or. &
       .not.allocated(s%bexp).or..not.allocated(s%decpot).or..not.allocated(s%fdepth).or. &
       .not.allocated(s%bulk_density).or..not.allocated(s%kf))return
    if(any([size(s%temperature_c),size(s%gampar),size(s%rtheta),size(s%bexp),size(s%decpot), &
       size(s%fdepth),size(s%bulk_density),size(s%kf)]/=n))return
    if(n>1)then
      if(.not.allocated(s%face_left_weight).or..not.allocated(s%face_right_weight).or. &
         .not.allocated(s%face_distance_cm).or..not.allocated(s%theta_sat_left).or..not.allocated(s%dispersivity_cm))return
      if(any([size(s%face_left_weight),size(s%face_right_weight),size(s%face_distance_cm), &
         size(s%theta_sat_left),size(s%dispersivity_cm)]/=n-1))return
    end if
    if(.not.all(ieee_is_finite(s%dz_cm)).or.any(s%dz_cm<=0.0_real64))return
    if(.not.all(ieee_is_finite(s%temperature_c)).or..not.all(ieee_is_finite(s%gampar)).or. &
       .not.all(ieee_is_finite(s%rtheta)).or..not.all(ieee_is_finite(s%bexp)).or. &
       .not.all(ieee_is_finite(s%decpot)).or..not.all(ieee_is_finite(s%fdepth)).or. &
       .not.all(ieee_is_finite(s%bulk_density)).or..not.all(ieee_is_finite(s%kf)))return
    if(.not.all(ieee_is_finite([s%molecular_diffusion_cm2_day,s%cdrain_mg_cm3,s%cseep_mg_cm3,s%tscf, &
       s%rain_rate_cm_day,s%rain_c_mg_cm3,s%irrigation_rate_cm_day,s%irrigation_c_mg_cm3, &
       s%macropore_area_fraction,s%cref_mg_cm3,s%frexp,s%drain_age_day,s%rain_age_day,s%irrigation_age_day])))return
    if(any(s%rtheta<=0.0_real64).or.any(s%bexp<0.0_real64).or.any(s%decpot<0.0_real64).or. &
       any(s%fdepth<0.0_real64).or.any(s%bulk_density<0.0_real64).or.any(s%kf<0.0_real64))return
    if(min(s%molecular_diffusion_cm2_day,s%cdrain_mg_cm3,s%cseep_mg_cm3,s%tscf, &
       s%rain_rate_cm_day,s%rain_c_mg_cm3,s%irrigation_rate_cm_day,s%irrigation_c_mg_cm3, &
       s%cref_mg_cm3,s%frexp,s%drain_age_day,s%rain_age_day,s%irrigation_age_day)<0.0_real64)return
    if(s%macropore_area_fraction/=0.0_real64)return
    ok=.true.
  end function
end module
