program test_mig431_tillage_reference_material
  use, intrinsic :: iso_fortran_env, only: int64, real64
  use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_parameters_t, &
       fmr_b110_physical_state_t, prepare_fmr_b110_default_mvg
  use mod_fmr_tillage_event_transaction, only: tillage_event_candidate_t
  use mod_fmr_tillage_reference_material_candidate
  implicit none
  type(fmr_b110_physical_parameters_t) :: prior, changed, invalid
  type(fmr_b110_physical_state_t) :: state, applied, untouched
  type(tillage_event_candidate_t) :: event
  integer :: status
  logical :: prepared

  prior%active_nodes=2
  prior%parameter_set_id=17_int64
  allocate(prior%cofgen(41,2),prior%dz(2))
  prior%cofgen=0.0_real64
  prior%dz=[10.0_real64,20.0_real64]
  prior%cofgen(1,:)=0.05_real64
  prior%cofgen(2,:)=0.4_real64
  prior%cofgen(3,:)=10.0_real64
  prior%cofgen(4,:)=0.02_real64
  prior%cofgen(5,:)=0.5_real64
  prior%cofgen(6,:)=2.0_real64
  prior%cofgen(7,:)=0.5_real64
  prior%cofgen(8,:)=0.03_real64
  prior%cofgen(10,:)=20.0_real64
  prior%cofgen(11,:)=0.9_real64
  prior%cofgen(12,:)=8.0_real64
  state%active_nodes=2
  allocate(state%water_content(2),state%pressure_head(2))
  state%water_content=[0.2_real64,0.3_real64]
  state%pressure_head=[-100.0_real64,-30.0_real64]
  allocate(event%hydraulic_parameters(2),event%hydraulic%water_content(2), &
       event%hydraulic%pressure_head_cm(2))
  event%hydraulic_parameters%theta_residual=0.06_real64
  event%hydraulic_parameters%theta_saturated=0.42_real64
  event%hydraulic_parameters%saturated_conductivity=7.0_real64
  event%hydraulic_parameters%alpha=0.025_real64
  event%hydraulic_parameters%lambda=0.5_real64
  event%hydraulic_parameters%n=2.0_real64
  event%hydraulic_parameters%m=0.5_real64
  event%hydraulic%water_content=[0.22_real64,0.29_real64]
  event%hydraulic%pressure_head_cm=[-80.0_real64,-35.0_real64]
  call build_tillage_reference_material_candidate(prior,state,event,18_int64,changed,applied,status)
  if(status /= TILLAGE_REFERENCE_CANDIDATE_OK) error stop 1
  if(changed%parameter_set_id /= 18_int64 .or. changed%prepared_default_mvg_available) error stop 2
  if(any(changed%cofgen(1,:) /= 0.06_real64) .or. any(changed%cofgen(4,:) /= 0.025_real64) .or. &
     any(changed%cofgen(3,:) /= 7.0_real64)) error stop 3
  if(any(changed%cofgen(8,:) /= prior%cofgen(8,:)) .or. &
     any(changed%cofgen(10,:) /= prior%cofgen(10,:)) .or. &
     any(changed%cofgen(12,:) /= prior%cofgen(12,:))) error stop 4
  if(abs(sum(applied%water_content*prior%dz)-sum(state%water_content*prior%dz)) > 1.e-12_real64) error stop 5
  if(any(applied%pressure_head /= event%hydraulic%pressure_head_cm)) error stop 6
  call prepare_fmr_b110_default_mvg(changed,prepared)
  if(.not. prepared .or. .not. changed%prepared_default_mvg_available) error stop 7
  if(any(changed%prepared_default_mvg%cofgen(4,:) /= 0.025_real64)) error stop 8
  if(prior%parameter_set_id /= 17_int64 .or. any(prior%cofgen(4,:) /= 0.02_real64)) error stop 9
  event%hydraulic%mass_residual_cm=1.e-6_real64
  call build_tillage_reference_material_candidate(prior,state,event,19_int64,invalid,untouched,status)
  if(status /= TILLAGE_REFERENCE_CANDIDATE_INVALID .or. allocated(invalid%cofgen) .or. &
     allocated(untouched%water_content)) error stop 10
  event%hydraulic%mass_residual_cm=0.0_real64
  prior%macropore_active=.true.
  call build_tillage_reference_material_candidate(prior,state,event,19_int64,invalid,untouched,status)
  if(status /= TILLAGE_REFERENCE_CANDIDATE_INVALID) error stop 11
  print *, 'F_MIG431_TILLAGE_REFERENCE_MATERIAL_CANDIDATE=PASS'
end program
