program test_multipool
 use iso_fortran_env,only:real64
 use mod_soil_n_pool_state
 use mod_b111_soil_organic_turnover
 use mod_multipool_limited_organic
 use mod_path_limited_organic
 implicit none
 type(soil_n_inventory_parameters_t)::p
 type(soil_n_pool_state_t)::s,c,a,b
 type(b111_organic_turnover_parameters_t)::k
 type(multipool_receipt_t)::r,ra,rb
 type(path_limited_result_t)::exact
 real(real64)::f(2),bi,hu,m,depth,nf(2),nb,nh,kf(2),kb,kh,afb(2),afh(2),ab,ah,dt,tol(3),err,exacterr
 character(1024)::filename
 integer::id,level,total,code,kind
 call get_command_argument(1,filename);open(20,file=trim(filename),status='old')
 read(20,*)total;tol=[1d-5,1d-7,1d-9]
 do id=1,total
  read(20,*)kind,f,bi,hu,m,depth,nf,nb,nh,kf,kb,kh,afb,afh,ab,ah,dt
  p%depth_m=depth;p%nfrac_fom=nf;p%nfrac_biomass=nb;p%nfrac_humus=nh
  k%ratecon_fom=kf;k%ratecon_bio=kb;k%ratecon_hum=kh
  k%asfa_fom_bio=afb;k%asfa_fom_hum=afh;k%asfa_bio=ab;k%asfa_hum=ah
  call initialize_soil_n_pool_state(p,f,bi,hu,m,.002d0,s,code);call require(code==0,'initial state')
  do level=1,3
   call advance_multipool_limited(p,s,k,dt,tol(level)*.001d0,tol(level),c,r)
   call require(r%status==0,'whole window')
   call advance_multipool_limited(p,s,k,dt*.37d0,tol(level)*.001d0,tol(level),a,ra)
   call require(ra%status==0,'first window')
   call advance_multipool_limited(p,a,k,dt*.63d0,tol(level)*.001d0,tol(level),b,rb)
   call require(rb%status==0,'second window')
   call require(c%nitrate_n_kg_m2==s%nitrate_n_kg_m2,'nitrate unchanged')
   err=maxval(abs([c%fom_kg_m3-b%fom_kg_m3,c%biomass_kg_m3-b%biomass_kg_m3, &
    c%humus_kg_m3-b%humus_kg_m3,c%ammonium_n_kg_m2-b%ammonium_n_kg_m2,r%carbon-ra%carbon-rb%carbon]))
   exacterr=0d0
   if(kind==0)then
    call advance_path_limited_organic(f(1),bi,m,kf(1),kb,dt,exact)
    call require(exact%status==0,'one-pool exact comparison')
    exacterr=maxval(abs([c%fom_kg_m3(1)-exact%fom,c%biomass_kg_m3-exact%bio, &
     c%ammonium_n_kg_m2-exact%nh4,r%carbon-exact%carbon]))
   end if
   print '(2(I0,1X),6(ES25.17E3,1X),3(I0,1X),4(ES25.17E3,1X))',id,level,c%fom_kg_m3, &
    c%biomass_kg_m3,c%humus_kg_m3,c%ammonium_n_kg_m2,r%carbon,r%accepted_steps,r%rejected_steps, &
    r%limited_steps,r%n_residual,r%c_residual,err,exacterr
  end do
  call advance_multipool_limited(p,s,k,dt,0d0,1d-7,c,r)
  call require(r%status/=0.and.all(c%fom_kg_m3==s%fom_kg_m3).and.c%biomass_kg_m3==s%biomass_kg_m3.and. &
   c%humus_kg_m3==s%humus_kg_m3.and.c%ammonium_n_kg_m2==s%ammonium_n_kg_m2.and. &
   c%nitrate_n_kg_m2==s%nitrate_n_kg_m2.and.r%carbon==0d0,'invalid tolerance exact rollback')
 end do
 print '(A)','MULTIPOOL_INVALID_ROLLBACK_PASS'
contains
 subroutine require(ok,label)
  logical,intent(in)::ok
  character(*),intent(in)::label
  if(.not.ok)then;print *,id,level,label;error stop 1;end if
 end subroutine
end program
