program thermal_receipt_component
 use iso_fortran_env,only:real64
 use mod_restricted_soil_temperature
 use mod_process_hydraulic_view,only:process_hydraulic_view_t
 use mod_fmr_thermal_substep_receipt
 implicit none
 type(soil_temperature_parameters_t)::p
 type(soil_temperature_numerical_config_t)::policy
 type(soil_temperature_forcing_t)::f
 type(soil_temperature_state_t)::s,candidate
 type(soil_temperature_workspace_t)::w
 type(soil_temperature_result_t)::result
 type(soil_temperature_diagnostics_t)::d
 type(process_hydraulic_view_t)::h0,h1
 type(fmr_thermal_substep_receipt_t)::r,copy
 real(real64),allocatable::temperatures(:)
 real(real64)::error,storage,flux
 integer::status,i
 call initialize_soil_temperature_parameters([1d0,2d0,3d0],[.5d0,1.5d0,2.5d0], &
      [.45d0,.45d0,.45d0],[.3d0,.3d0,.3d0],[.2d0,.2d0,.2d0],[.05d0,.05d0,.05d0],p,status)
 if(status/=SOIL_TEMP_OK)error stop 'parameters'
 call initialize_soil_temperature_state([9d0,10d0,11d0],s,status)
 h0%active_nodes=3;h1%active_nodes=3;h0%water_content=[.2d0,.25d0,.3d0];h1%water_content=[.21d0,.24d0,.31d0]
 f%top_boundary_mode=SOIL_TEMP_TOP_PRESCRIBED_HEAT_FLUX;f%prescribed_top_heat_flux_j_cm2_day=.03d0
 call trial_restricted_soil_temperature(p,policy,f,h0,h1,s,0d0,.001d0,w,candidate,result,d)
 if(result%status/=SOIL_TEMP_OK)error stop 'actual thermal trial'
 call capture_fmr_thermal_substep(p,w,f,result,h0%water_content,h1%water_content,0d0,.001d0,r)
 if(.not.r%available.or..not.r%independent_boundary_heat)error stop 'numeric receipt'
 error=0d0
 do i=1,3
  storage=r%dz_cm(i)*r%heat_capacity_average_j_cm3_k(i)*(r%temperature_end_c(i)-r%temperature_start_c(i))
  flux=r%conductive_face_energy_j_cm2(i)-r%conductive_face_energy_j_cm2(i+1)
  error=max(error,abs(storage-flux))
 end do
 if(error>1d-12)error stop 'actual independent nodal conduction'
 copy=r;w%solution=999d0
 if(any(copy%temperature_end_c==999d0))error stop 'receipt aliases workspace'
 call copy_soil_temperature_profile(s,temperatures,status)
 if(any(temperatures/=[9d0,10d0,11d0]))error stop 'observation mutated committed state'
 ! Failed capture replaces rather than retaining old successful data.
 result%produced=.false.
 call capture_fmr_thermal_substep(p,w,f,result,h0%water_content,h1%water_content,0d0,.001d0,r)
 if(r%available.or.allocated(r%temperature_start_c))error stop 'stale observation'
 result%produced=.true.
 f%top_boundary_mode=SOIL_TEMP_TOP_TEMPERATURE_FLUX_CORRECTION
 call capture_fmr_thermal_substep(p,w,f,result,h0%water_content,h1%water_content,0d0,.001d0,r)
 if(.not.r%available.or.r%independent_boundary_heat)error stop 'storage-derived heat claimed independent'
 p%solution_mode=SOIL_TEMP_SOLUTION_ANALYTIC
 call capture_fmr_thermal_substep(p,w,f,result,h0%water_content,h1%water_content,0d0,.001d0,r)
 if(.not.r%available.or.r%independent_boundary_heat.or.r%conductive_profile_available.or. &
    allocated(r%conductive_face_energy_j_cm2))error stop 'analytic energy promoted to conductive receipt'
 if(r%gas_transport_available.or.r%advective_energy_complete.or.r%full_energy_balance_complete)error stop 'missing owners fabricated'
 print '(a,es25.17e3)','THERMAL_RECEIPT_COMPONENT_PASS_MAX_NODAL_ERROR=',error
end program
