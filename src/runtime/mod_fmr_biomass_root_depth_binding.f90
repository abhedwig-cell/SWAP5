module mod_fmr_biomass_root_depth_binding
  use, intrinsic :: iso_fortran_env, only: real64
  use mod_fmr_wofost_crop_transaction, only: fmr_wofost_crop_transaction_state_t
  use mod_wofost_crop_owner_state, only: wofost_crop_owner_state_t, WOFOST_CROP_OWNER_OK
  use mod_wofost_potential_shadow_state, only: wofost_potential_shadow_state_t, WOFOST_POTENTIAL_SHADOW_OK
  use mod_wofost_rate_table, only: wofost_rate_table_t
  use mod_crop_root_depth_biomass, only: crop_root_depth_biomass_result_t
  implicit none
  private

  integer, parameter, public :: FMR_BIOMASS_ROOT_DEPTH_BIND_OK=0
  integer, parameter, public :: FMR_BIOMASS_ROOT_DEPTH_BIND_INVALID_TRANSACTION=1
  integer, parameter, public :: FMR_BIOMASS_ROOT_DEPTH_BIND_MISSING_SHADOW=2
  integer, parameter, public :: FMR_BIOMASS_ROOT_DEPTH_BIND_EVALUATION_ERROR=3

  public :: bind_committed_biomass_root_depth

contains

  subroutine bind_committed_biomass_root_depth(crop_state,depth_table,soil_maximum_root_depth_cm, &
       maximum_root_biomass,result,status)
    type(fmr_wofost_crop_transaction_state_t),intent(in)::crop_state
    type(wofost_rate_table_t),intent(in)::depth_table
    real(real64),intent(in)::soil_maximum_root_depth_cm,maximum_root_biomass
    type(crop_root_depth_biomass_result_t),intent(out)::result
    integer,intent(out)::status

    type(wofost_crop_owner_state_t)::owner
    type(wofost_potential_shadow_state_t)::shadow
    logical::owner_available,shadow_available,depth_available
    integer::owner_status
    real(real64)::potential_root_biomass

    result=crop_root_depth_biomass_result_t()
    status=FMR_BIOMASS_ROOT_DEPTH_BIND_INVALID_TRANSACTION
    if(.not.crop_state%ready())return

    call crop_state%snapshot_owner(owner,owner_available)
    if(.not.owner_available.or.owner%validate()/=WOFOST_CROP_OWNER_OK)return

    call crop_state%snapshot_potential_shadow(shadow,shadow_available)
    if(.not.shadow_available.or.shadow%validate()/=WOFOST_POTENTIAL_SHADOW_OK)then
      status=FMR_BIOMASS_ROOT_DEPTH_BIND_MISSING_SHADOW
      return
    end if
    potential_root_biomass=shadow%root_biomass()

    call owner%derive_biomass_root_depth(depth_table,soil_maximum_root_depth_cm,maximum_root_biomass, &
         potential_root_biomass,result,depth_available,owner_status)
    if(owner_status/=WOFOST_CROP_OWNER_OK.or..not.depth_available)then
      result=crop_root_depth_biomass_result_t()
      status=FMR_BIOMASS_ROOT_DEPTH_BIND_EVALUATION_ERROR
      return
    end if
    status=FMR_BIOMASS_ROOT_DEPTH_BIND_OK
  end subroutine bind_committed_biomass_root_depth

end module mod_fmr_biomass_root_depth_binding
