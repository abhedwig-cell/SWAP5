program test_crop_certified_daily_preflight
 use, intrinsic :: iso_fortran_env, only: real64,int64
 use, intrinsic :: ieee_arithmetic, only: ieee_value,ieee_quiet_nan
 use mod_transaction_reference, only: transaction_state_t
 use mod_kernel_transactions, only: kernel_committed_state_t,kernel_parameter_identity_t, &
      kernel_reconstruct_committed_state_trusted,KERNEL_TRUSTED_RECONSTRUCTION_OK
 use mod_fmr_serialized_reference_backend, only: fmr_b110_physical_state_t, &
      fmr_b110_physical_parameters_t,fmr_new_b110_committed_state
 use mod_soil_temperature_contract, only: initialize_soil_temperature_state,SOIL_TEMP_OK
 use mod_fmr_crop_certified_germination_moisture
 use mod_fmr_crop_certified_daily_preflight
 implicit none
 type(kernel_committed_state_t) :: committed,plain,restarted,without_heat
 type(fmr_b110_physical_state_t) :: state
 type(fmr_b110_physical_parameters_t) :: pars,unheated
 type(kernel_parameter_identity_t) :: identity
 type(crop_certified_daily_preflight_t) :: candidate
 class(transaction_state_t),allocatable :: snapshot
 integer :: status,st
 logical :: ok,available,reconstructed
 real(real64) :: germ_head,missing
 state%active_nodes=2
 state%pressure_head=[-100.0_real64,-1000.0_real64]
 state%water_content=[0.2_real64,0.3_real64]
 allocate(state%soil_temperature)
 call initialize_soil_temperature_state([8.0_real64,12.0_real64],state%soil_temperature,st)
 if(st/=SOIL_TEMP_OK) error stop 'heat initialization'
 pars%parameter_set_id=101_int64
 pars%active_nodes=2
 pars%z=[-5.0_real64,-20.0_real64]
 pars%dz=[10.0_real64,20.0_real64]
 pars%soil_temperature_active=.true.
 call fmr_new_b110_committed_state(plain,41_int64,state,3.0_real64,ok)
 if(.not.ok) error stop 'plain initialization'
 call sample_certified_committed_germination_head(plain,41_int64,0_int64, &
       3.0_real64,-15.0_real64,germ_head,st)
 if(st/=CROP_CERT_GERM_UNCERTIFIED) error stop 'unbound moisture passed'
 call fmr_new_b110_committed_state(committed,41_int64,state,3.0_real64,ok,parameters=pars)
 if(.not.ok) error stop 'certified initialization'
 call sample_certified_committed_germination_head(committed,41_int64,0_int64, &
       3.0_real64,-15.0_real64,germ_head,st)
 if(st/=CROP_CERT_GERM_OK) error stop 'certified germ head'
 if(abs(germ_head+10.0_real64**(7.0_real64/3.0_real64))>1.0e-10_real64) &
      error stop 'source weighted pF'
 call daily(committed,41_int64,0_int64,3.0_real64,-15.0_real64,12.0_real64,candidate,status)
 if(status/=CROP_CERT_DAILY_OK.or..not.candidate%valid) error stop 'daily accepted physical'
 if(candidate%nodsow/=2.or.candidate%soil_temperature/=12.0_real64) error stop 'sow node'
 if(abs(candidate%hprep+100.0_real64)>1.0e-11_real64) error stop 'preparation pF'
 if(abs(candidate%hgerm-germ_head)>1.0e-11_real64) error stop 'germ moisture'
 if(.not.candidate%preparation%preparation_complete.or. &
       .not.candidate%preparation%sowing_complete) error stop 'prep sow proposal'
 if(candidate%germination%complete.or. &
       abs(candidate%germination%next_temperature_sum-7.0_real64)>1.0e-12_real64) &
       error stop 'germination temperature sum'
 call daily(committed,41_int64,1_int64,3.0_real64,-15.0_real64,12.0_real64,candidate,status)
 if(status/=CROP_CERT_DAILY_HYDRO.or.candidate%valid.or.candidate%nodsow/=0) &
       error stop 'stale revision'
 call daily(committed,42_int64,0_int64,3.0_real64,-15.0_real64,12.0_real64,candidate,status)
 if(status/=CROP_CERT_DAILY_HYDRO) error stop 'foreign lineage'
 call daily(committed,41_int64,0_int64,4.0_real64,-15.0_real64,12.0_real64,candidate,status)
 if(status/=CROP_CERT_DAILY_HYDRO) error stop 'wrong time'
 call daily(committed,41_int64,0_int64,3.0_real64,-40.0_real64,12.0_real64,candidate,status)
 if(status/=CROP_CERT_DAILY_MOISTURE.or.candidate%valid) error stop 'zgerm outside profile'
 missing=ieee_value(0.0_real64,ieee_quiet_nan)
 call daily(committed,41_int64,0_int64,3.0_real64,-15.0_real64,missing,candidate,status)
 if(status/=CROP_CERT_DAILY_GERM.or.candidate%valid) error stop 'nonfinite air forcing'
 call committed%certified_parameter_identity(identity,available)
 if(.not.available) error stop 'missing certificate'
 call committed%snapshot(snapshot,available)
 if(.not.available) error stop 'missing snapshot'
 call kernel_reconstruct_committed_state_trusted(restarted,41_int64,0_int64,snapshot,3.0_real64, &
      .true.,reconstructed,st,parameters=pars,persisted_identity=identity)
 if(.not.reconstructed.or.st/=KERNEL_TRUSTED_RECONSTRUCTION_OK) error stop 'restart'
 call daily(restarted,41_int64,0_int64,3.0_real64,-15.0_real64,12.0_real64,candidate,status)
 if(status/=CROP_CERT_DAILY_OK.or..not.candidate%valid) error stop 'restart daily'
 deallocate(state%soil_temperature)
 unheated=pars
 unheated%soil_temperature_active=.false.
 call fmr_new_b110_committed_state(without_heat,43_int64,state,3.0_real64,ok,parameters=unheated)
 if(.not.ok) error stop 'heat-off init'
 call sample_certified_committed_germination_head(without_heat,43_int64,0_int64, &
       3.0_real64,-15.0_real64,germ_head,st)
 if(st/=CROP_CERT_GERM_OK) error stop 'heat-off germination moisture'
 call daily(without_heat,43_int64,0_int64,3.0_real64,-15.0_real64,12.0_real64,candidate,status)
 if(status/=CROP_CERT_DAILY_HYDRO) error stop 'heat-off sowing must fail'
 ! SWHEA=0 is valid when SWSOW=0: certified SWPREP and SWGERM2
 ! only use the already accepted hydraulic state, not a fabricated heat field.
 call propose_certified_crop_daily_preflight(without_heat,43_int64,0_int64,3.0_real64, &
       -10.0_real64,-15.0_real64,-15.0_real64,-15.0_real64,1,0, &
       -50.0_real64,-200.0_real64,10.0_real64, &
       0,0,5,5,2,0.0_real64,50.0_real64,5.0_real64, &
       30.0_real64,12.0_real64,-1000.0_real64,-10.0_real64,20.0_real64, &
       candidate,status)
 if(status/=CROP_CERT_DAILY_OK.or..not.candidate%valid) error stop 'heat-off SWSOW0'
 if(candidate%nodsow/=0.or.candidate%soil_temperature/=0.0_real64) error stop 'no invented heat'
 if(.not.candidate%preparation%preparation_complete.or. &
       .not.candidate%preparation%sowing_complete) error stop 'heat-off prep sow'
 if(abs(candidate%hgerm-germ_head)>1.0e-11_real64) error stop 'heat-off germ head'
 call propose_certified_crop_daily_preflight(without_heat,43_int64,1_int64,3.0_real64, &
       -10.0_real64,-15.0_real64,-15.0_real64,-15.0_real64,1,0, &
       -50.0_real64,-200.0_real64,10.0_real64, &
       0,0,5,5,2,0.0_real64,50.0_real64,5.0_real64, &
       30.0_real64,12.0_real64,-1000.0_real64,-10.0_real64,20.0_real64, &
       candidate,status)
 if(status/=CROP_CERT_DAILY_HYDRO.or.candidate%valid) error stop 'heat-off stale revision'
 call propose_certified_crop_daily_preflight(without_heat,43_int64,0_int64,3.0_real64, &
       -40.0_real64,-15.0_real64,-15.0_real64,-15.0_real64,1,0, &
       -50.0_real64,-200.0_real64,10.0_real64, &
       0,0,5,5,2,0.0_real64,50.0_real64,5.0_real64, &
       30.0_real64,12.0_real64,-1000.0_real64,-10.0_real64,20.0_real64, &
       candidate,status)
 if(status/=CROP_CERT_DAILY_HYDRO.or.candidate%valid) error stop 'heat-off bad zprep'
 print '(a)','SW431_CROP_CERTIFIED_DAILY_PREFLIGHT=PASS'
contains
 subroutine daily(column,lineage,revision,time,zgerm,air,candidate,status)
    type(kernel_committed_state_t),intent(in):: column
    integer(int64),intent(in):: lineage,revision
    real(real64),intent(in):: time,zgerm,air
    type(crop_certified_daily_preflight_t),intent(out):: candidate
    integer,intent(out):: status
    call propose_certified_crop_daily_preflight(column,lineage,revision,time, &
         -10.0_real64,-15.0_real64,-15.0_real64,zgerm,1,1, &
         -50.0_real64,-200.0_real64,10.0_real64, &
         0,0,5,5,2,0.0_real64,50.0_real64,5.0_real64, &
         30.0_real64,air,-1000.0_real64,-10.0_real64,20.0_real64, &
         candidate,status)
 end subroutine
end program
