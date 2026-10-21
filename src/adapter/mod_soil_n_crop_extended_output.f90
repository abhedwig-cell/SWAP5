! Explicit diagnostic component for original management_soil task6.
! Caller supplies accepted uptake and the ORIGINAL saved (_1) residue values.
module mod_soil_n_crop_extended_output
 use iso_fortran_env,only:real64
 use ieee_arithmetic,only:ieee_is_finite
 implicit none
 private
 integer,parameter,public::CROP_EXT_OK=0,CROP_EXT_INVALID=1
 character(*),parameter,public::CROP_EXT_NAMES= &
  '    nishmi     nishma     niromi     niroma     poshmi     poshma     poromi     poroma'
 character(*),parameter,public::CROP_EXT_PLACEHOLDER=' to be replaced'
 character(*),parameter,public::CROP_EXT_COLUMNS= &
  'year-mo-da,Ntotuptake,Ptotuptake,DMcressurf,N-cressurf,P-cressurf,DMcresbott,N-cresbott,P-cresbott'
 type,public::crop_ext_state_t
  private
  logical::initialized=.false.
  real(real64)::clock=0d0
  real(real64)::totals(8)=0d0
  real(real64)::extrema(8)=[1d0,0d0,1d0,0d0,1d0,0d0,1d0,0d0]
 contains
  procedure::snapshot=>snapshot
 end type
 type,public::crop_ext_row_t
  logical::emitted=.false.
  real(real64)::values(8)=0d0
 end type
 public::initialize_crop_ext,observe_crop_ext,format_crop_ext_row,format_crop_ext_extrema
contains
 pure subroutine initialize_crop_ext(clock,state,status)
  real(real64),intent(in)::clock
  type(crop_ext_state_t),intent(out)::state
  integer,intent(out)::status
  state=crop_ext_state_t();status=CROP_EXT_INVALID
  if(.not.ieee_is_finite(clock))return
  if(abs(clock)>1d8)return
  state%clock=clock;state%initialized=.true.;status=CROP_EXT_OK
 end subroutine
 pure subroutine snapshot(self,clock,totals,extrema,initialized)
  class(crop_ext_state_t),intent(in)::self
  real(real64),intent(out)::clock,totals(8),extrema(8)
  logical,intent(out)::initialized
  clock=self%clock;totals=self%totals;extrema=self%extrema;initialized=self%initialized
 end subroutine
 pure subroutine observe_crop_ext(state,t0,t1,uptake_kg_m2,saved_dm_kg_ha,saved_n_kg_ha,report,row,status)
  type(crop_ext_state_t),intent(inout)::state
  real(real64),intent(in)::t0,t1,uptake_kg_m2(2),saved_dm_kg_ha(4),saved_n_kg_ha(4)
  logical,intent(in)::report
  type(crop_ext_row_t),intent(out)::row
  integer,intent(out)::status
  type(crop_ext_state_t)::trial
  real(real64)::u,sn
  row=crop_ext_row_t();status=CROP_EXT_INVALID
  if(.not.state%initialized)return
  if(.not.all(ieee_is_finite([t0,t1,uptake_kg_m2,saved_dm_kg_ha,saved_n_kg_ha])))return
  if(t0/=state%clock.or.t1<=t0.or.abs(t1)>1d8)return
  if(any(uptake_kg_m2<0d0).or.any(uptake_kg_m2>1d6))return
  if(any(saved_dm_kg_ha<0d0).or.any(saved_dm_kg_ha>1d6))return
  if(any(saved_n_kg_ha<0d0).or.any(saved_n_kg_ha>saved_dm_kg_ha))return
  trial=state
  ! Preserve original evaluation order; organs: root, leaf, stem, storage.
  u=uptake_kg_m2(1)+uptake_kg_m2(2)
  trial%totals(1)=trial%totals(1)+1d4*u
  trial%totals(2)=trial%totals(2)+0.1d0*1d4*u
  trial%totals(3)=trial%totals(3)+saved_dm_kg_ha(2)+saved_dm_kg_ha(3)+saved_dm_kg_ha(4)
  trial%totals(4)=trial%totals(4)+saved_n_kg_ha(2)+saved_n_kg_ha(3)+saved_n_kg_ha(4)
  sn=saved_n_kg_ha(2)+saved_n_kg_ha(3)+saved_n_kg_ha(4)
  trial%totals(5)=trial%totals(5)+0.1d0*sn
  trial%totals(6)=trial%totals(6)+saved_dm_kg_ha(1)
  trial%totals(7)=trial%totals(7)+saved_n_kg_ha(1)
  trial%totals(8)=trial%totals(8)+0.1d0*saved_n_kg_ha(1)
  if(any(trial%totals>1d12))return
  if(report)then
   row%values=trial%totals;row%emitted=.true.
   if(trial%totals(3)>=1d-6)then
    trial%extrema(1)=min(trial%extrema(1),trial%totals(4)/trial%totals(3))
    trial%extrema(2)=max(trial%extrema(2),trial%totals(4)/trial%totals(3))
    trial%extrema(5)=min(trial%extrema(5),trial%totals(5)/trial%totals(3))
    trial%extrema(6)=max(trial%extrema(6),trial%totals(5)/trial%totals(3))
   end if
   if(trial%totals(6)>=1d-6)then
    trial%extrema(3)=min(trial%extrema(3),trial%totals(7)/trial%totals(6))
    trial%extrema(4)=max(trial%extrema(4),trial%totals(7)/trial%totals(6))
    trial%extrema(7)=min(trial%extrema(7),trial%totals(8)/trial%totals(6))
    trial%extrema(8)=max(trial%extrema(8),trial%totals(8)/trial%totals(6))
   end if
   trial%totals=0d0
  end if
  trial%clock=t1;state=trial;status=CROP_EXT_OK
 end subroutine
 subroutine format_crop_ext_row(date,row,line,status)
  character(*),intent(in)::date
  type(crop_ext_row_t),intent(in)::row
  character(*),intent(out)::line
  integer,intent(out)::status
  integer::i,ios
  line='';status=CROP_EXT_INVALID
  if(len(date)/=10.or.len(line)<106.or..not.row%emitted)return
  do i=1,10
   if(i==5.or.i==8)then
    if(date(i:i)/='-')return
   else
    if(index('0123456789',date(i:i))==0)return
   end if
  end do
  if(.not.all(ieee_is_finite(row%values)))return
  if(any(row%values<0d0).or.any(row%values>1d12))return
  write(line,'(a10,8(a1,1pe11.4))',iostat=ios)date,(',',row%values(i),i=1,8)
  if(ios/=0)then;line='';return;end if
  status=CROP_EXT_OK
 end subroutine
 subroutine format_crop_ext_extrema(state,line,status)
  type(crop_ext_state_t),intent(in)::state
  character(*),intent(out)::line
  integer,intent(out)::status
  integer::ios
  line='';status=CROP_EXT_INVALID
  if(.not.state%initialized.or.len(line)<88)return
  write(line,'(8e11.4)',iostat=ios)state%extrema
  if(ios/=0)then;line='';return;end if
  status=CROP_EXT_OK
 end subroutine
end module
