! Read-only bridge from the actual original numerical heat solve to existing
! SWAP5 sensible-storage accounting. No temperature, water or flux is assigned.
module mod_hybrid_heat_accounting
 use iso_fortran_env, only: real64,int64
 use ieee_arithmetic, only: ieee_is_finite
 use mod_whole_column_sensible_energy_accounting
 implicit none
 private
 public :: observe_original_heat
contains
 subroutine observe_original_heat(n,t0,dt,dz,saturated,water0,water1,temp0,temp1,capacity,solid,face)
  integer,intent(in)::n
  real(real64),intent(in)::t0,dt,dz(n),saturated(n),water0(n),water1(n),temp0(n),temp1(n)
  real(real64),intent(in)::capacity(n),solid(n),face(n+1)
  type(whole_column_sensible_boundary_t)::boundary,zero_advection
  type(whole_column_sensible_energy_result_t)::actual,assumed
  real(real64)::frozen_storage,maximum_cell_residual,top,bottom
  integer::actual_status,assumed_status,i,unit
  if(n<2.or.dt<=0d0)error stop 'Invalid original heat observation'
  if(any(.not.ieee_is_finite(dz)).or.any(.not.ieee_is_finite(capacity)).or. &
     any(.not.ieee_is_finite(face)))error stop 'Nonfinite original heat observation'
  top=face(1)*1d4;bottom=face(n+1)*1d4
  boundary%top_conductive_available=.true.;boundary%top_conductive_into_j_m2=top
  boundary%bottom_conductive_available=.true.;boundary%bottom_conductive_outward_j_m2=bottom
  ! No mass-carried thermal donor was supplied by the original temperature call.
  ! Do not silently mark these unknown terms as complete or zero.
  call evaluate_whole_column_sensible_energy(1_int64,dz,saturated,solid,water0,water1, &
       temp0,temp1,4.18d0,.001212d0,0d0,boundary,actual,actual_status)
  ! Distinguishing counterfactual: what if an application asserted zero missing
  ! advection? Retain its ACTUAL projected residual, never call it conservation.
  zero_advection=boundary
  zero_advection%top_advective_available=.true.
  zero_advection%bottom_advective_available=.true.
  zero_advection%mass_carried_reference_available=.true.
  zero_advection%mass_carried_reference_temperature_c=0d0
  call evaluate_whole_column_sensible_energy(1_int64,dz,saturated,solid,water0,water1, &
       temp0,temp1,4.18d0,.001212d0,0d0,zero_advection,assumed,assumed_status)
  frozen_storage=sum(dz*capacity*(temp1-temp0))
  maximum_cell_residual=maxval(abs(dz*capacity*(temp1-temp0)-(face(1:n)-face(2:n+1))))
  open(newunit=unit,file='original-heat-accounting.txt',status='unknown',position='append',action='write')
  write(unit,'(a,1x,*(g0,1x))')'HEAT_STEP',t0,dt,n,actual_status,assumed_status, &
       frozen_storage,face(1)-face(n+1),maximum_cell_residual, &
       actual%exact_storage_change_j_m2*1d-4,actual%temperature_change_component_j_m2*1d-4, &
       actual%composition_change_component_j_m2*1d-4,actual%storage_decomposition_residual_j_m2*1d-4, &
       assumed%projected_balance%residual_j_m2*1d-4, &
       actual%storage_complete,actual%sensible_boundary_complete,actual%full_energy_balance_complete
  do i=1,n
   write(unit,'(a,1x,*(g0,1x))')'HEAT_NODE',i,dz(i),saturated(i),water0(i),water1(i),temp0(i),temp1(i), &
        capacity(i),solid(i),face(i),face(i+1)
  end do
  close(unit)
 end subroutine
end module
