program fvq114
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_rutter_interception_process
  implicit none
  integer :: i
  real(real64),parameter::tol=1.0e-12_real64
  type(rutter_state_t)::s
  type(rutter_interval_input_t)::x
  type(rutter_interval_result_t)::y
  type(rutter_diagnostics_t)::d
  real(real64),dimension(6)::rain=(/0d0,0.02d0,0.56d0,0.10d0,0.30d0,0.0d0/)
  real(real64),dimension(6)::stor=(/0d0,0d0,0.02d0,0.12d0,0.08d0,0.05d0/)
  real(real64),dimension(6)::evap=(/0d0,0.10d0,0.01d0,0.02d0,0.25d0,0.10d0/)
  do i=1,6
    x=rutter_interval_input_t()
    x%gross_rain_cm_per_day=rain(i); x%vegetation_cover_fraction=0.5d0
    x%canopy_storage_capacity_cm=0.12d0; x%interception_evaporation_capacity_cm_per_day=evap(i)
    x%potential_transpiration_dry_cm_per_day=0.08d0; x%potential_transpiration_wet_cm_per_day=0.03d0
    x%interval_days=0.04d0; s%canopy_storage_cm=stor(i)
    call evaluate_rutter_interval(s,x,y,d)
    call require(d%status==RUTTER_OK .and. d%result_produced,100+i)
    call independent_check(s,x,y,200+i)
    call require(abs(s%canopy_storage_cm-stor(i))<tol,300+i)
  end do
  print '(A)','F-VQ114_PASS'
contains
  subroutine independent_check(s,x,y,n)
    type(rutter_state_t),intent(in)::s
    type(rutter_interval_input_t),intent(in)::x
    type(rutter_interval_result_t),intent(in)::y
    integer,intent(in)::n
    real(real64)::fi,fo,ri,ro,w,aint,nr,ni,ptra,cs,den,evt
    ri=x%gross_rain_cm_per_day+x%surface_irrigation_cm_per_day
    if(.not.x%surface_irrigation_is_intercepted) ri=x%gross_rain_cm_per_day
    fi=ri*x%vegetation_cover_fraction; fo=x%interception_evaporation_capacity_cm_per_day; evt=1d0
    if(fi+fo<1d-10) then; ri=0d0;ro=0d0;w=0d0
    else if(fi>=fo) then
      if(x%canopy_storage_capacity_cm-s%canopy_storage_cm>1d-10) then
        ri=fi;ro=fo;den=ri-ro;if(den>0d0)evt=(x%canopy_storage_capacity_cm-s%canopy_storage_cm)/den
      else;ri=fo;ro=fo;endif;w=1d0
    else
      if(s%canopy_storage_cm>1d-10) then
        ri=fi;ro=fo;den=ro-ri;if(den>0d0)evt=s%canopy_storage_cm/den;w=1d0
      else;ri=fi;ro=fi;if(fo>0d0)then;w=fi/fo;else;w=0d0;endif;endif
    endif
    aint=ri
    if(aint<1d-6)then;nr=x%gross_rain_cm_per_day;ni=x%surface_irrigation_cm_per_day
    else if(x%gross_rain_cm_per_day+x%surface_irrigation_cm_per_day>1d-6)then
      if(x%surface_irrigation_is_intercepted)then
        den=x%gross_rain_cm_per_day+x%surface_irrigation_cm_per_day
        nr=x%gross_rain_cm_per_day-aint*x%gross_rain_cm_per_day/den
        ni=x%surface_irrigation_cm_per_day-aint*x%surface_irrigation_cm_per_day/den
      else;nr=x%gross_rain_cm_per_day-aint;ni=x%surface_irrigation_cm_per_day;endif
    else;nr=0d0;ni=0d0;endif
    ptra=w*x%potential_transpiration_wet_cm_per_day+(1d0-w)*x%potential_transpiration_dry_cm_per_day
    cs=min(max(0d0,s%canopy_storage_cm+(ri-ro)*x%interval_days),x%canopy_storage_capacity_cm)
    call require(abs(y%reservoir_inflow_cm_per_day-ri)<tol,n)
    call require(abs(y%reservoir_outflow_cm_per_day-ro)<tol,n+10)
    call require(abs(y%net_rain_cm_per_day-nr)<tol,n+20)
    call require(abs(y%net_surface_irrigation_cm_per_day-ni)<tol,n+30)
    call require(abs(y%wet_canopy_fraction-w)<tol,n+40)
    call require(abs(y%potential_transpiration_cm_per_day-ptra)<tol,n+50)
    call require(abs(y%candidate_state%canopy_storage_cm-cs)<tol,n+60)
    call require(abs(y%maximum_event_timestep_days-evt)<tol,n+70)
  end subroutine
  subroutine require(ok,n)
    logical,intent(in)::ok;integer,intent(in)::n
    if(.not.ok)then;write(*,'(A,I0)')'FAIL=',n;error stop 1;endif
  end subroutine
end program
