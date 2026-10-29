program probe
use iso_fortran_env,only:real64,int64
use mod_rutter_source_window_processor
use mod_interception_source_window_runtime
use mod_rutter_interception_process
implicit none
type(rutter_source_restart_t)::r
type(rutter_source_state_t)::s
type(rutter_source_trial_t)::trial
type(interception_source_window_t)::w,nw
type(rutter_interval_input_t)::f
type(rutter_interval_result_t)::v
type(rutter_diagnostics_t)::d
integer::u,n,sz,st
inquire(iolength=n)r
open(newunit=u,file='/tmp/dq07/diagnostic-rejected.bin',access='stream',form='unformatted')
inquire(unit=u,size=sz);read(u,pos=sz-4-n+1)r;close(u)
print *,'restart',n,r%schema,r%canopy_storage_cm,r%source_progress
call restore_rutter_source_restart(r,w,s,st);print *,'restore',st
f%vegetation_cover_fraction=r%parameters%vegetation_cover_fraction
f%canopy_storage_capacity_cm=r%parameters%canopy_storage_capacity_cm
f%interception_evaporation_capacity_cm_per_day=r%parameters%interception_evaporation_capacity_cm_per_day
f%potential_transpiration_dry_cm_per_day=r%parameters%potential_transpiration_dry_cm_per_day
f%potential_transpiration_wet_cm_per_day=r%parameters%potential_transpiration_wet_cm_per_day
f%surface_irrigation_cm_per_day=r%parameters%surface_irrigation_cm_per_day
f%surface_irrigation_is_intercepted=r%parameters%surface_irrigation_is_intercepted
print *,'forcing',f
call initialize_interception_window(r%source_progress%id+1_int64,r%source_progress%t1,1.4424999999973807d0,0d0,nw,st)
call prepare_rutter_source_trial(nw,s,1.4424999999973807d0,f,v,trial,d,st)
print *,'prepare',st,d,'result',v
end program
