! Adapter only: original SWP/TTUTIL interpretation before physical owners exist.
module mod_column_swp_chemistry
 use iso_fortran_env,only:real64
 use ieee_arithmetic,only:ieee_is_finite
 use mod_b111_reactive_solute_substep,only:b111_reactive_solute_substep_forcing_t
 use mod_swp_original_chemistry
 implicit none
 private
 public::import_column_swp_chemistry
contains
 subroutine require(ok,message)
  logical,intent(in)::ok
  character(*),intent(in)::message
  if(.not.ok)then
   print '(A)','SWP_IMPORT_REJECTED: '//message
   error stop 1
  end if
 end subroutine
 subroutine import_column_swp_chemistry(path,dz,z,dynamic_heat,f,concentration,rain_c,drain_c,bottom_c)
  character(*),intent(in)::path
  real(real64),intent(in)::dz(:),z(:)
  logical,intent(in)::dynamic_heat
  type(b111_reactive_solute_substep_forcing_t),intent(inout)::f
  real(real64),intent(out)::concentration(:),rain_c,drain_c,bottom_c
  integer::swmacro,swsnow,swhea,swinco,nsub,n,found,i,j,k,pos
  integer::sublayers(256),layers(256),counts(256),node_layer(size(dz))
  real(real64)::heights(256),density(256),value
  real(real64),allocatable::expected_dz(:)
  logical::rdinqr,rdinar
  call rdinit(72,0,trim(path))
  call rdsinr('swsolu',0,2,swsolu)
  call require(swsolu==1,'SWSOLU must select reactive solute')
  call rdsinr('swmacro',0,1,swmacro);call require(swmacro==0,'historical solute/macropore exclusion')
  call rdsinr('swsnow',0,1,swsnow);call require(swsnow==0,'snow chemistry not admitted')
  call rdsinr('swhea',0,2,swhea);call require(swhea==merge(1,0,dynamic_heat),'SWHEA must match explicit numeric heat owner')
  call rdsinr('swinco',1,3,swinco);call require(swinco/=3,'loose historical restart not admitted')
  call rdsinr('swcrop',0,2,swcrop);call require(swcrop<=1,'unsupported crop input branch')
  call rdsinr('swbr',0,1,swbr);call require(swbr==0,'aquifer excluded')
  swbotbc=0
  if(rdinqr('swbotbc'))call rdsinr('swbotbc',0,2,swbotbc)
  call require(swbotbc<=1,'time-varying bottom concentration needs its external forcing owner')
  call rdinne('isublay',nsub);call require(nsub>=1.and.nsub<=256,'sublayer count')
  call rdfinr('isublay',1,256,sublayers,256,nsub)
  call rdfinr('isoillay',1,256,layers,256,nsub)
  call rdfinr('ncomp',1,256,counts,256,nsub)
  call rdfdor('hsublay',1d-4,1d4,heights,256,nsub)
  call require(all(sublayers(:nsub)==[(i,i=1,nsub)]),'ordered sublayer identities')
  n=sum(counts(:nsub));call require(n==size(dz).and.size(z)==n,'SWP and water owner grid size differ')
  allocate(expected_dz(n));k=0
  do i=1,nsub
   do j=1,counts(i)
    k=k+1;expected_dz(k)=heights(i)/counts(i);node_layer(k)=layers(i)
   end do
  end do
  call require(all(abs(expected_dz-dz)<=16d0*epsilon(1d0)*max(1d0,maxval(dz))),'SWP and water owner cell thickness differ')
  numlay=maxval(layers(:nsub));density=0d0
  call rdsinr('swsp',0,1,swsp)
  if(rdinqr('bdens'))then
   if(rdinar('bdens'))then
    call rdfdor('bdens',100d0,10000d0,density,numlay,numlay)
   else
    call rdsdor('bdens',100d0,10000d0,value);density(:numlay)=value
   end if
  else
   call require(swsp==0,'sorption requires original BDENS')
  end if
  close(72)
  swpfilnam=path;fl_initialize=.false.
  if(allocated(kf))deallocate(kf,ldis,decpot,fdepth)
  allocate(kf(numlay),ldis(numlay),decpot(numlay),fdepth(numlay))
  kf=0d0;ldis=0d0;decpot=0d0;fdepth=0d0
  call read_solute_CDE()
  call require(frexp>=.5d0.and.frexp<=2d0.and.cref>=1d-8,'sorption outside admitted numeric envelope')
  call require(tscf<=1d0.and.rtheta>0d0,'uptake/moisture outside admitted envelope')
  call require(nconc>=2.and.mod(nconc,2)==0,'initial concentration table length')
  call require(all(ieee_is_finite(cmltb)),'nonfinite initial table')
  call require(all(cmltb(3:nconc:2)>cmltb(1:nconc-2:2)),'initial depths must increase after original absolute-depth conversion')
  pos=0
  do i=1,n
   call afgen_2(cmltb,nconc,abs(z(i)),concentration(i),pos)
  end do
  ! Original BDENS is mg/cm3 and KF is cm3/mg. Preserve BDENS*KF;
  ! the typed application's convention is g/cm3 and cm3/g.
  f%bulk_density=density(node_layer)/1000d0
  f%kf=1000d0*kf(node_layer)
  if(swsp==0)then
   f%bulk_density=1.3d0 ! unused positive density; sorption product remains zero
   f%kf=0d0
  end if
  f%frexp=frexp;f%cref_mg_cm3=cref
  f%gampar=spread(gampar,1,n);f%rtheta=spread(rtheta,1,n);f%bexp=spread(bexp,1,n)
  f%decpot=decpot(node_layer);f%fdepth=fdepth(node_layer);f%tscf=tscf
  f%molecular_diffusion_cm2_day=ddif
  ! Original transport uses the upstream node's layer for each internal face.
  f%dispersivity_cm=ldis(node_layer(1:n-1))
  f%cdrain_mg_cm3=cdrain;f%cseep_mg_cm3=cseep
  rain_c=cpre;drain_c=cdrain;bottom_c=cseep
  print '(A)','SWP_ORIGINAL_CHEMISTRY_GRID_UNITS_IMPORTED'
 end subroutine
end module
