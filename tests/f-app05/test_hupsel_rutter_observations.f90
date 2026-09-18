program test_hupsel_rutter_observations
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_rutter_interception_process
  implicit none
  type(rutter_state_t)::s
  type(rutter_interval_input_t)::x
  type(rutter_interval_result_t)::y
  type(rutter_diagnostics_t)::d
  real(real64),parameter::tol=1d-12
  call check(0d0,0.94508105761722561d0,0.073127803283203521d0,0d0,0.53714123774061084d0, &
             0.36989155956560815d0,0.11806407365914319d0,0.04d0,0d0,0d0,0.36989155956560815d0,1)
  call check(0.56d0,0.28387460881418058d0,0.021072800000000003d0,0.021072800000000003d0,0.010184502512019959d0, &
             0.011621209174202582d0,0.0047014973566050335d0,0.04d0,0.010184502512019959d0,0.54981549748798d0,0.0047014973566050335d0,2)
  call check(0.47d0,0.63562099391997362d0,0.063714499249828235d0,0.063714499249828235d0,0.052357843735008791d0, &
             0.081800915911193900d0,0.037493984426385220d0,0.04d0,0.052357843735008791d0,0.41764215626499124d0,0.037493984426385220d0,3)
  print '(A)','F-APP05_HUPSEL_SUPPORTING_OBSERVATIONS_PASS'
contains
  subroutine check(rain,vcover,cap,storage,eintc,pdry,pwet,dt,aint,nrain,ptra,n)
    real(real64),intent(in)::rain,vcover,cap,storage,eintc,pdry,pwet,dt,aint,nrain,ptra
    integer,intent(in)::n
    x=rutter_interval_input_t();s=rutter_state_t()
    x%gross_rain_cm_per_day=rain;x%vegetation_cover_fraction=vcover;x%canopy_storage_capacity_cm=cap
    x%interception_evaporation_capacity_cm_per_day=eintc;x%potential_transpiration_dry_cm_per_day=pdry
    x%potential_transpiration_wet_cm_per_day=pwet;x%interval_days=dt;s%canopy_storage_cm=storage
    call evaluate_rutter_interval(s,x,y,d)
    if(d%status/=RUTTER_OK.or..not.d%result_produced) error stop 1
    if(abs(y%interception_rate_cm_per_day-aint)>tol) error stop 2
    if(abs(y%net_rain_cm_per_day-nrain)>tol) error stop 3
    if(abs(y%potential_transpiration_cm_per_day-ptra)>tol) error stop 4
    if(n<0) error stop 5
  end subroutine
end program
