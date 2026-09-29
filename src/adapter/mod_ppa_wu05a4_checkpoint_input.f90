! Restricted static, surface-connected, single-domain checkpoint translation.
! Candidate preparation only: no independent state owner or production admission.
module mod_ppa_wu05a4_checkpoint_input
  use, intrinsic::iso_fortran_env,only:real64,int32
  use, intrinsic::ieee_arithmetic,only:ieee_is_finite
  use mod_ppa_wu05a2_macropore_state,only:ppa_wu05a2_macropore_checkpoint_t
  use mod_ppa_wu05a3_macrostate_wetting_candidate
  use mod_ppa_wu05a4_saturated_trial,only:saturated_domain_inputs
  use mod_ppa_wu05a4_static_geometry
  implicit none
  private
  public::prepare_static_checkpoint_input
contains
  subroutine prepare_static_checkpoint_input(checkpoint,z,dz,static_volume,diameter,resistance_inverse, &
      input,geometry,ok)
    type(ppa_wu05a2_macropore_checkpoint_t),intent(in)::checkpoint
    real(real64),intent(in)::z(:),dz(:),static_volume(:),diameter(:),resistance_inverse(:)
    type(saturated_domain_inputs),intent(out)::input
    type(static_macro_geometry),intent(out)::geometry
    logical,intent(out)::ok
    type(saturated_domain_inputs)::trial
    type(static_macro_geometry)::trial_geometry
    real(real64),allocatable::zero(:,:),wet(:,:),water(:,:)
    real(real64)::level(1),tolerance,storage
    integer(int32)::top(1),status,n
    integer::i
    ok=.false.; n=int(size(dz),int32)
    if(n<1.or.size(z)/=n.or.size(resistance_inverse)/=n)return
    if(checkpoint%lineage_id<=0.or.checkpoint%revision<0)return
    if(.not.checkpoint%payload%ready())return
    if(checkpoint%payload%n_domains/=1.or.checkpoint%payload%n_compartments/=n)return
    if(checkpoint%payload%bottom_domain(1)/=n)return
    if(.not.all(ieee_is_finite(z)).or..not.all(ieee_is_finite(resistance_inverse)))return
    if(any(resistance_inverse<0))return
    call prepare_static_macro_geometry(static_volume,dz,diameter,trial_geometry,ok)
    if(.not.ok)return
    ok=.false.
    ! Origin is the soil surface; the source volume-to-level helper accumulates
    ! dz from bottom. Reject inconsistent centers rather than mixing geometries.
    tolerance=32*epsilon(1.0_real64)*max(1.0_real64,maxval(abs(z)),maxval(dz))
    if(abs(z(1)+0.5_real64*dz(1))>tolerance)return
    do i=2,n
      if(abs(z(i-1)-0.5_real64*dz(i-1)-z(i)-0.5_real64*dz(i))>tolerance)return
    end do
    tolerance=32*epsilon(1.0_real64)*max(1.0_real64,maxval(static_volume))
    if(any(abs(checkpoint%payload%pore_volume(1,:)-static_volume)>tolerance))return
    storage=checkpoint%payload%domain_water_storage(1)
    if(storage>sum(static_volume))return
    allocate(zero(1,n),wet(1,n),water(1,n)); zero=0
    trial%bottom=z(n)-0.5_real64*dz(n)
    call ppa_wu05a3_macrostate_wetting_candidate(n,1_int32,1_int32,1_int32,[n], &
        [storage],[trial%bottom],checkpoint%payload%pore_volume,dz,zero,zero,wet,water,top,level,status)
    if(status/=PPA_WU05A3_MACROSTATE_WETTING_OK)return
    if(top(1)<1.or.top(1)>n)return
    ! Source threshold branches can leave an inadmissible wet fraction. Do not
    ! clamp or silently correct source output in this restricted translation.
    if(any(wet<0).or.any(wet>1))return
    tolerance=32*epsilon(1.0_real64)*max(1.0_real64,storage)
    if(any(abs(water-checkpoint%payload%pore_water)>tolerance))return
    trial%z=z; trial%dz=dz; trial%volume=static_volume
    trial%resistance_inverse=resistance_inverse
    trial%storage=storage; trial%pore_level=level(1)
    trial%pore_saturated_top=top(1); trial%saturated_fraction=wet(1,top(1))
    ! Matrix metadata is deliberately absent: the caller must use the
    ! head-derived evaluator. Numerical reduction policy remains caller-owned.
    input=trial; geometry=trial_geometry; ok=.true.
  end subroutine
end module
