module mod_ppa_solute_timestep
  use, intrinsic :: iso_fortran_env, only: real64
  use, intrinsic :: ieee_arithmetic, only: ieee_is_finite
  implicit none
  private
  integer,parameter,public::PPA_SOLUTE_TIMESTEP_OK=0
  integer,parameter,public::PPA_SOLUTE_TIMESTEP_INVALID_INPUT=1
  public::ppa_solute_timestep_candidate
contains
  pure subroutine ppa_solute_timestep_candidate(layer_thickness,dispersion,interval_days,minimum_step, &
       elapsed_days,solute_step,status)
    real(real64),intent(in)::layer_thickness(:),dispersion(:),interval_days,minimum_step,elapsed_days
    real(real64),intent(out)::solute_step
    integer,intent(out)::status
    real(real64)::candidate,local_dispersion,remaining,dummy
    integer::i

    solute_step=0.0_real64
    status=PPA_SOLUTE_TIMESTEP_INVALID_INPUT
    if(size(layer_thickness)==0.or.size(layer_thickness)/=size(dispersion))return
    if(.not.all(ieee_is_finite(layer_thickness)).or..not.all(ieee_is_finite(dispersion)).or. &
         .not.all(ieee_is_finite([interval_days,minimum_step,elapsed_days])))return
    if(any(layer_thickness<=0.0_real64).or.any(dispersion<0.0_real64).or. &
         interval_days<=0.0_real64.or.minimum_step<=0.0_real64.or.elapsed_days<0.0_real64.or. &
         elapsed_days>=interval_days)return

    ! Source: B1.11 solute.f90 task 2 stable dt min(dz^2/(2*dispr)), then
    ! clamp to remaining interval and dtmin. Source floors each dispr at 1e-8.
    candidate=interval_days
    do i=1,size(layer_thickness)
      local_dispersion=max(dispersion(i),1.0e-8_real64)
      if(local_dispersion>huge(1.0_real64)/2.0_real64)return
      if(layer_thickness(i)>sqrt(huge(1.0_real64)))return
      dummy=layer_thickness(i)*layer_thickness(i)/(2.0_real64*local_dispersion)
      candidate=min(candidate,dummy)
    end do
    remaining=interval_days-elapsed_days
    solute_step=min(candidate,remaining)
    solute_step=max(solute_step,minimum_step)
    if(.not.ieee_is_finite(solute_step))then
      solute_step=0.0_real64
      return
    end if
    status=PPA_SOLUTE_TIMESTEP_OK
  end subroutine ppa_solute_timestep_candidate
end module mod_ppa_solute_timestep
