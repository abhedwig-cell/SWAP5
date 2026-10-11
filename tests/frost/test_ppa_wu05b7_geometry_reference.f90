program geometry_reference
 use iso_fortran_env,only:int64
 use ieee_arithmetic,only:ieee_value,ieee_quiet_nan
 use MOD_frost,only:old_cond=>FrozenCond,old_bounds=>FrozenBounds,old_node=>nodfrostbot, &
      old_top=>zfrosttop,old_bottom=>zfrostbot,old_factor=>rfcp,old_start=>tfroststa,old_end=>tfrostend
 use MOD_frost_guarded,only:new_cond=>FrozenCond,new_bounds=>FrozenBounds,new_node=>nodfrostbot, &
      new_top=>zfrosttop,new_bottom=>zfrostbot,new_factor=>rfcp,new_start=>tfroststa,new_end=>tfrostend, &
      frost_geometry_valid,frost_geometry_status
 use MOD_grid
 use MOD_drain
 use MOD_swap_base
 use variables
 implicit none
 character(32)::mode
 real(8)::t(4),top,old_qdra(2,4),old_qbot
 integer::profile,grid,signum,cases
 call get_command_argument(1,mode)
 old_start=0.d0;new_start=0.d0;old_end=-2.d0;new_end=-2.d0
 cases=0
 select case(trim(mode))
 case('original_uniform','guarded_uniform','original_epsilon','guarded_epsilon','guarded_nan','guarded_grid','guarded_limits','guarded_distance')
  t=-4.d0
  if(index(mode,'epsilon')>0)t=[1.d0,-2.d0+9.999d-7,-2.d0+1.0001d-6,1.d0]
  if(trim(mode)=='guarded_limits')new_start=new_end
  if(trim(mode)=='guarded_distance')then
   t=[-4.d0,-4.d0,1.d0,1.d0];disnod(2)=2.d0
  end if
  if(trim(mode)=='guarded_nan')t(2)=ieee_value(0.d0,ieee_quiet_nan)
  if(trim(mode)=='guarded_grid')then
   t=[-4.d0,-4.d0,1.d0,1.d0];z(2)=z(1)
  end if
  if(index(mode,'original')==1)then
   call old_cond(t,-4.d0)
   print '(A,ES24.16)','ORIGINAL_FROST_BOTTOM=',old_bottom
  else
   call new_cond(t,-4.d0)
   call require(.not.frost_geometry_valid.and.frost_geometry_status/=0,'invalid geometry rejects without FP trap')
   print '(A)','GUARDED_INVALID_GEOMETRY_STATUS=PASS'
  end if
 case('original_drain_index','guarded_drain_index','guarded_stale_geometry')
  t=[-4.d0,-4.d0,1.d0,1.d0]
  theta=.5d0;thetas=.5d0;qdra=.1d0;qdrain=sum(qdra,dim=2);zbotdr=[0.d0,1.d0]
  if(trim(mode)=='original_drain_index')then
   call old_cond(t,-4.d0);call old_bounds
  else
   call new_cond(t,-4.d0)
   if(trim(mode)=='guarded_stale_geometry')then
    t=-4.d0;call new_cond(t,-4.d0)
   end if
   call new_bounds
  end if
  error stop 'invalid branch continued unexpectedly'
 case default
  do grid=1,2
   z=[-.5d0,-1.5d0,-2.5d0,-3.5d0];disnod=1.d0;dz=1.d0
   if(grid==2)then
    z=[-.3d0,-1.1d0,-2.4d0,-4.d0];disnod=[.3d0,.8d0,1.3d0,1.6d0];dz=[.6d0,1.d0,1.6d0,1.6d0]
   end if
   do profile=1,8
    select case(profile)
    case(1);t=[1.d0,2.d0,3.d0,4.d0]
    case(2);t=[1.d0,2.d0,3.d0,-4.d0]
    case(3);t=[-4.d0,1.d0,2.d0,3.d0]
    case(4);t=[-4.d0,-3.d0,1.d0,2.d0]
    case(5);t=[1.d0,-4.d0,1.d0,2.d0]
    case(6);t=[-4.d0,1.d0,-4.d0,1.d0]
    case(7);t=[1.d0,-2.d0,1.d0,2.d0]
    case(8);t=[-2.d0,-2.d0,1.d0,2.d0]
    end select
    do signum=-1,1
     top=real(signum,8)*4.d0
     call old_cond(t,top);call new_cond(t,top)
     if(.not.frost_geometry_valid)print *, 'invalid',grid,profile,signum,frost_geometry_status,new_top,new_bottom
     call require(frost_geometry_valid.and.frost_geometry_status==0,'valid physical brackets available')
     call require(old_node==new_node,'legacy deepest-index parity')
     call require(transfer(old_top,0_int64)==transfer(new_top,0_int64),'top depth bit parity')
     call require(transfer(old_bottom,0_int64)==transfer(new_bottom,0_int64),'bottom depth bit parity')
     call require(all(transfer(old_factor,[0_int64],4)==transfer(new_factor,[0_int64],4)),'factor bit parity')
     theta=.5d0;thetas=.5d0;qdra=.1d0;qdrain=sum(qdra,dim=2);qbot_nonfrozen=real(signum,8)*.01d0
     zbotdr=[-1.d0,-3.d0]
     call old_bounds;old_qdra=qdra;old_qbot=qbot
     qdra=.1d0;qdrain=sum(qdra,dim=2)
     call new_bounds
     call require(all(transfer(qdra,[0_int64],8)==transfer(old_qdra,[0_int64],8)),'corrected valid nodal physical parity')
     call require(transfer(qbot,0_int64)==transfer(old_qbot,0_int64),'corrected valid bottom physical parity')
     call require(abs(qdrtot-sum(qdra))<1.d-14,'bounded corrected reporting remains consistent')
     cases=cases+1
    end do
   end do
  end do
  print '(A,I0)','FROST_GEOMETRY_01_VALID_PHYSICAL_IDENTITY_CASES=',cases
  print '(A)','PPA_WU05B7_GUARDED_REFERENCE_GEOMETRY=PASS'
 end select
contains
 subroutine require(ok,label)
  logical,intent(in)::ok
  character(*),intent(in)::label
  if(.not.ok)then
   print *,label
   error stop 1
  end if
 end subroutine
end program
