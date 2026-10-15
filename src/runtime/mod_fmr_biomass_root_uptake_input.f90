module mod_fmr_biomass_root_uptake_input
 use, intrinsic :: iso_fortran_env, only: real64
 use mod_fmr_wofost_crop_transaction, only: fmr_wofost_crop_transaction_state_t
 use mod_fmr_biomass_root_depth_binding, only: bind_committed_biomass_root_depth,FMR_BIOMASS_ROOT_DEPTH_BIND_OK
 use mod_crop_root_depth_biomass, only: crop_root_depth_biomass_result_t
 use mod_crop_root_profile_static, only: materialize_static_root_profile,CROP_ROOT_PROFILE_OK
 use mod_crop_root_uptake_input_contract, only: crop_root_uptake_input_t,validate_crop_root_uptake_input,CROP_ROOT_INPUT_OK
 use mod_wofost_crop_owner_state, only: wofost_crop_owner_state_t
 use mod_wofost_rate_table, only: wofost_rate_table_t
 implicit none
 private
 public :: bind_committed_biomass_root_uptake_input
contains
 subroutine bind_committed_biomass_root_uptake_input(crop,depth_table,density_table,maximum_depth, &
   maximum_biomass,zbot,input,status)
 type(fmr_wofost_crop_transaction_state_t),intent(in)::crop
 type(wofost_rate_table_t),intent(in)::depth_table,density_table
 real(real64),intent(in)::maximum_depth,maximum_biomass,zbot(:)
 type(crop_root_uptake_input_t),intent(out)::input
 integer,intent(out)::status
 type(crop_root_depth_biomass_result_t)::depth
 type(wofost_crop_owner_state_t)::owner
 logical::available
 integer::s
 input=crop_root_uptake_input_t();status=1
 if(.not.crop%ready())return
 call crop%snapshot_owner(owner,available)
 if(.not.available)return
 if(.not.owner%crop_emerged)then
   status=0;return
 end if
 call bind_committed_biomass_root_depth(crop,depth_table,maximum_depth,maximum_biomass,depth,s)
 if(s/=FMR_BIOMASS_ROOT_DEPTH_BIND_OK)return
 call materialize_static_root_profile(density_table,zbot,depth%maximum_root_depth_cm,depth%actual_root_depth_cm, &
   input%rooted_nodes,input%cumulative_root_fraction,s)
 if(s/=CROP_ROOT_PROFILE_OK)then
   input=crop_root_uptake_input_t();return
 end if
 input%crop_emerged=.true.
 call validate_crop_root_uptake_input(input,size(zbot),s)
 if(s/=CROP_ROOT_INPUT_OK)then
   input=crop_root_uptake_input_t();return
 end if
 status=0
 end subroutine
end module
