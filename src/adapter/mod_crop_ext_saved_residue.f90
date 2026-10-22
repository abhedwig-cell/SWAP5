! Original task6 ordering: add yesterday, save today, optionally report/reset.
! Diagnostic memory only. These values are never an organic or mineral stock.
module mod_crop_ext_saved_residue
 use iso_fortran_env,only:real64
 use ieee_arithmetic,only:ieee_is_finite
 use mod_soil_n_crop_extended_output
 implicit none
 private
 type,public::crop_ext_saved_residue_t
  private
  logical::initialized=.false.
  real(real64)::values(9)=0d0 ! clock, root/leaf/stem/storage DM, then N, kg/ha
 contains
  procedure::snapshot=>snapshot_saved
 end type
 public::restore_crop_ext_saved_residue,observe_crop_ext_saved_residue
contains
 pure subroutine snapshot_saved(self,values,ready)
  class(crop_ext_saved_residue_t),intent(in)::self
  real(real64),intent(out)::values(9)
  logical,intent(out)::ready
  values=self%values;ready=self%initialized
 end subroutine
 pure subroutine restore_crop_ext_saved_residue(values,state,status)
  real(real64),intent(in)::values(9)
  type(crop_ext_saved_residue_t),intent(inout)::state
  integer,intent(out)::status
  status=CROP_EXT_INVALID
  if(.not.all(ieee_is_finite(values)))return
  if(abs(values(1))>1d8)return
  if(any(values(2:5)<0d0).or.any(values(2:5)>1d6))return
  if(any(values(6:9)<0d0).or.any(values(6:9)>values(2:5)))return
  state%values=values;state%initialized=.true.;status=CROP_EXT_OK
 end subroutine
 pure subroutine observe_crop_ext_saved_residue(output,saved,t0,t1,uptake,current_dm,current_n,report,row,status)
  type(crop_ext_state_t),intent(inout)::output
  type(crop_ext_saved_residue_t),intent(inout)::saved
  real(real64),intent(in)::t0,t1,uptake(2),current_dm(4),current_n(4)
  logical,intent(in)::report
  type(crop_ext_row_t),intent(out)::row
  integer,intent(out)::status
  type(crop_ext_state_t)::trial
  type(crop_ext_saved_residue_t)::next
  integer::code
  row=crop_ext_row_t();status=CROP_EXT_INVALID
  if(.not.saved%initialized)return
  if(.not.all(ieee_is_finite([t0,t1])))return
  if(t0/=saved%values(1).or.t1-t0/=1d0)return
  next=saved
  call restore_crop_ext_saved_residue([t1,current_dm,current_n],next,code)
  if(code/=CROP_EXT_OK)return
  trial=output
  call observe_crop_ext(trial,t0,t1,uptake,saved%values(2:5),saved%values(6:9),report,row,code)
  if(code/=CROP_EXT_OK)return
  output=trial;saved=next;status=CROP_EXT_OK
 end subroutine
end module
