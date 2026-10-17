! Experimental pure budget evaluator. Not an accepted hydraulic or chemical state owner.
module mod_b111_surface_loss_budget
 use iso_fortran_env, only: real64
 use ieee_arithmetic, only: ieee_is_finite
 implicit none
 private
 integer,parameter,public :: SURFACE_LOSS_OK=0,SURFACE_LOSS_INVALID=1,SURFACE_LOSS_WATER=2,SURFACE_LOSS_MASS=3
 type,public :: surface_loss_receipt_t
  integer :: status=SURFACE_LOSS_INVALID
  real(real64) :: depth_end=0d0,mass_end=0d0,evaporated_water=0d0,runoff_water=0d0
  real(real64) :: infiltrated_mass=0d0,runoff_mass=0d0,external_mass=0d0
  real(real64) :: water_residual=0d0,mass_residual=0d0
 end type
 public :: evaluate_surface_loss_budget
contains
 pure subroutine evaluate_surface_loss_budget(depth_start,mass_start,dt,rain,irrigation, &
      infiltrate,evaporate,runoff,rain_conc,irrigation_conc,dry_deposit,r)
  real(real64),intent(in)::depth_start,mass_start,dt,rain,irrigation,infiltrate,evaporate,runoff
  real(real64),intent(in)::rain_conc,irrigation_conc,dry_deposit
  type(surface_loss_receipt_t),intent(out)::r
  real(real64)::available_water,available_mass,withdrawal,c,scale
  r=surface_loss_receipt_t()
  if(.not.all(ieee_is_finite([depth_start,mass_start,dt,rain,irrigation,infiltrate, &
       evaporate,runoff,rain_conc,irrigation_conc,dry_deposit])))return
  if(dt<=0d0.or.dt>1d3.or.min(depth_start,mass_start,rain,irrigation,infiltrate, &
       evaporate,runoff,rain_conc,irrigation_conc,dry_deposit)<0d0)return
  if(maxval([depth_start,mass_start,rain,irrigation,infiltrate,evaporate,runoff, &
       rain_conc,irrigation_conc,dry_deposit])>1d12)return
  available_water=depth_start+(rain+irrigation)*dt
  r%external_mass=(rain*rain_conc+irrigation*irrigation_conc+dry_deposit)*dt
  available_mass=mass_start+r%external_mass
  if(.not.ieee_is_finite(available_water).or..not.ieee_is_finite(available_mass))return
  r%status=SURFACE_LOSS_WATER
  withdrawal=(infiltrate+evaporate+runoff)*dt
  if(withdrawal>available_water+1d-10)return
  if(withdrawal>available_water)withdrawal=available_water
  r%depth_end=available_water-withdrawal
  r%evaporated_water=evaporate*dt
  r%runoff_water=runoff*dt
  ! Explicit well-mixed event assumption: infiltration and runoff take equal concentration.
  ! Evaporation removes water only; no dissolved mass is volatilized by this operation.
  c=0d0
  if(available_water>0d0)c=available_mass/available_water
  r%infiltrated_mass=min(available_mass,c*infiltrate*dt)
  r%runoff_mass=min(max(0d0,available_mass-r%infiltrated_mass),c*runoff*dt)
  r%mass_end=available_mass-r%infiltrated_mass-r%runoff_mass
  r%water_residual=r%depth_end-depth_start-(rain+irrigation-infiltrate-evaporate-runoff)*dt
  r%mass_residual=r%mass_end-mass_start-r%external_mass+r%infiltrated_mass+r%runoff_mass
  scale=max(1d0,available_mass)
  r%status=SURFACE_LOSS_MASS
  if(abs(r%water_residual)>1d-10.or.abs(r%mass_residual)>8192d0*epsilon(1d0)*scale)return
  r%status=SURFACE_LOSS_OK
 end subroutine
end module
