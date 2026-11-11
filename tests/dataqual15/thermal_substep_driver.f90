program test_thermal_substep_policy
 use iso_fortran_env,only:real64
 use mod_soil_temperature_contract
 use mod_process_hydraulic_view,only:process_hydraulic_view_t
 use mod_restricted_soil_temperature,only:trial_restricted_soil_temperature
 use mod_restricted_soil_temperature_control,only:initialize_soil_temperature_parameters, &
      original_trial=>trial_restricted_soil_temperature
 use mod_fmr_thermal_substep_receipt
 implicit none
 type(soil_temperature_parameters_t)::p
 type(soil_temperature_numerical_config_t)::num
 type(soil_temperature_forcing_t)::f
 type(soil_temperature_state_t)::initial,trial,control,next_state,other,other_trial
 type(soil_temperature_workspace_t)::w,wc,wb
 type(soil_temperature_result_t)::r,rc
 type(soil_temperature_diagnostics_t)::d,dc
 type(process_hydraulic_view_t)::h
 type(fmr_thermal_substep_receipt_t)::receipt
 real(real64),allocatable::v(:),vcontrol(:),saved(:)
 real(real64)::faces(3),a,b,dt,cell(2),defect
 integer::status,k,top,bottom,cases,nsteps,io
 character(16)::argument
 nsteps=4
 call get_command_argument(1,argument)
 if(len_trim(argument)>0)then
  read(argument,*,iostat=io)nsteps
  if(io/=0)error stop 'count argument'
 end if
 if(nsteps/=4.and.nsteps/=16)error stop 'unsupported test count'
 call initialize_soil_temperature_parameters([2d0,3d0],[1d0,2.5d0],[.45d0,.45d0], &
      [.35d0,.35d0],[.15d0,.15d0],[.05d0,.05d0],p,status)
 if(status/=SOIL_TEMP_OK)error stop 'parameters'
 call initialize_soil_temperature_state([12d0,9d0],initial,status)
 if(status/=SOIL_TEMP_OK)error stop 'initial'
 h%active_nodes=2;h%pressure_head=[-100d0,-125d0];h%water_content=[.3d0,.32d0]
 call copy_soil_temperature_profile(initial,saved,status)
 num%internal_heat_substeps=nsteps
 dt=.04d0;cases=0
 do top=SOIL_TEMP_TOP_PRESCRIBED_TEMPERATURE,SOIL_TEMP_TOP_TEMPERATURE_FLUX_CORRECTION
 do bottom=SOIL_TEMP_BOTTOM_ZERO_HEAT_FLUX,SOIL_TEMP_BOTTOM_PRESCRIBED_TEMPERATURE
  f%top_boundary_mode=top;f%bottom_boundary_mode=bottom
  f%prescribed_surface_temperature_c=15d0;f%prescribed_top_heat_flux_j_cm2_day=20d0
  f%prescribed_bottom_temperature_c=8d0
  call trial_restricted_soil_temperature(p,num,f,h,h,initial,0d0,dt,w,trial,r,d)
  if(r%status/=SOIL_TEMP_OK.or..not.r%produced)error stop 'private trial'
  if(d%tridiagonal_solves/=nsteps.or.d%constitutive_evaluations/=nsteps)error stop 'missing subsolve'
  control=initial;faces=0d0
  do k=1,nsteps
   a=dt*real(k-1,real64)/real(nsteps,real64);b=dt*real(k,real64)/real(nsteps,real64)
   if(k==nsteps)b=dt
   call original_trial(p,num,f,h,h,control,a,b,wc,next_state,rc,dc)
   if(rc%status/=SOIL_TEMP_OK)error stop 'original control'
   faces(1)=faces(1)+(b-a)*rc%top_heat_flux_into_soil_j_cm2_day
   faces(2)=faces(2)+(b-a)*wc%face_conductivity_j_cm_k_day(2)* &
        (wc%solution(1)-wc%solution(2))/p%distance_above_cm(2)
   faces(3)=faces(3)-(b-a)*rc%bottom_heat_flux_into_soil_j_cm2_day
   control=next_state
  end do
  call copy_soil_temperature_profile(trial,v,status)
  call copy_soil_temperature_profile(control,vcontrol,status)
  if(maxval(abs(v-vcontrol))>1d-12)error stop 'original subsolves differ'
  if(maxval(abs(faces-w%substep_conductive_face_energy_j_cm2))>1d-12)error stop 'integrated faces'
  call capture_fmr_thermal_substep(p,w,f,r,h%water_content,h%water_content,0d0,dt,receipt)
  if(.not.receipt%available)error stop 'missing receipt'
  cell=w%heat_capacity_j_cm3_k*p%dz_cm*(v-saved)
  defect=maxval(abs(cell-(faces(1:2)-faces(2:3))))
  ! The legacy temperature/flux correction explicitly reconstructs its top
  ! boundary from aggregate storage; it is not an independent boundary law.
  if(defect>num%energy_abs_tolerance_j_cm2)error stop 'cellwise energy'
  if(maxval(abs(receipt%conductive_face_energy_j_cm2-faces))>1d-12)error stop 'receipt faces'
  call copy_soil_temperature_profile(initial,vcontrol,status)
  if(maxval(abs(vcontrol-saved))>0d0)error stop 'committed state mutated'
  cases=cases+1
 end do
 end do
 ! A/B/A with distinct temperature profiles and private workspaces; a call for
 ! B must not influence A's repeated physical response or mutate A's source.
 call copy_soil_temperature_profile(trial,v,status)
 call initialize_soil_temperature_state([20d0,25d0],other,status)
 call trial_restricted_soil_temperature(p,num,f,h,h,other,0d0,dt,wb,other_trial,r,d)
 if(r%status/=SOIL_TEMP_OK)error stop 'B trial'
 call trial_restricted_soil_temperature(p,num,f,h,h,initial,0d0,dt,w,trial,r,d)
 if(r%status/=SOIL_TEMP_OK)error stop 'A repeat'
 call copy_soil_temperature_profile(trial,vcontrol,status)
 if(maxval(abs(vcontrol-v))>0d0)error stop 'A/B/A contamination'
 ! Default one-step policy is exactly the original single solve.
 num%internal_heat_substeps=1
 call trial_restricted_soil_temperature(p,num,f,h,h,initial,0d0,dt,w,trial,r,d)
 if(r%status/=SOIL_TEMP_OK.or.d%tridiagonal_solves/=1)error stop 'default one solve'
 call original_trial(p,num,f,h,h,initial,0d0,dt,wc,control,rc,dc)
 call copy_soil_temperature_profile(trial,v,status)
 call copy_soil_temperature_profile(control,vcontrol,status)
 if(maxval(abs(v-vcontrol))>0d0)error stop 'default temperature differs'
 if(allocated(w%substep_conductive_face_energy_j_cm2))error stop 'stale subcycled receipt in default'
 num%internal_heat_substeps=2
 call trial_restricted_soil_temperature(p,num,f,h,h,initial,0d0,dt,w,trial,r,d)
 if(r%status/=SOIL_TEMP_INVALID_PARAMETERS.or.r%produced)error stop 'invalid numerical count accepted'
 num%internal_heat_substeps=nsteps
 ! A rejected call cannot publish an old successful integrated-face receipt.
 f%top_boundary_mode=-999
 call trial_restricted_soil_temperature(p,num,f,h,h,initial,0d0,dt,w,trial,r,d)
 if(r%status==SOIL_TEMP_OK.or.r%produced)error stop 'invalid forcing accepted'
 if(allocated(w%substep_conductive_face_energy_j_cm2))error stop 'stale face receipt'
 call copy_soil_temperature_profile(initial,vcontrol,status)
 if(maxval(abs(vcontrol-saved))>0d0)error stop 'refusal mutated committed state'
 if(cases/=6)error stop 'boundary cases'
 print '(a)','THERMAL_SUBSTEP_POLICY_DEFAULT_FACES_AND_REFUSAL=PASS'
end program
