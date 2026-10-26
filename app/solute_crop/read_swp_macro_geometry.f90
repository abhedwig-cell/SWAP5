! Isolated original macropore input preparation. Never advances accepted water.
program read_swp_macro_geometry
 use iso_fortran_env,only:real64
 use ieee_arithmetic,only:ieee_is_finite
 use MOD_arrays,only:macp,maho
 use MOD_grid
 use variables,only:ksatfit
 use MOD_swap_base,only:swsolu
 use MOD_macropore
 use mod_column_swp_water,only:import_column_swp_water
 implicit none
 character(1024)::swp,bbc,output
 integer::mode,bottom_mode,nsub,m,k,j,i,u,nn
 integer::layers(256),counts(256)
 real(real64)::width(256),pond,gwl,depth
 real(real64),allocatable::heads(:),cofgen(:,:)
 logical::rdinqr
 call get_command_argument(1,swp);call get_command_argument(2,bbc);call get_command_argument(3,output)
 call require(len_trim(swp)>0.and.len_trim(output)>0,'SWP and output required')
 call rdinit(74,0,trim(swp));call rdsinr('swmacro',0,1,mode);call require(mode==1,'requires original active SWMACRO')
 call rdsinr('swsolu',0,1,swsolu);call require(swsolu==0,'original macro requires SWSOLU0')
 if(rdinqr('swbotb'))then
  call rdsinr('swbotb',1,9,bottom_mode);close(74)
 else
  close(74);call require(len_trim(bbc)>0,'original external BBC required')
  call rdinit(74,0,trim(bbc));call rdsinr('swbotb',1,9,bottom_mode);close(74)
 end if
 call require(bottom_mode==3,'geometry bootstrap currently selects original Cauchy3')
 call import_column_swp_water(trim(swp),nn,width,heads,cofgen,pond,bottom_mode,gwl,allow_ksatexm=.true.)
 numnod=nn;allocate(z(nn),dz(nn),zbotcp(nn),layer(nn));dz=width(:nn);depth=0d0
 do i=1,nn
  z(i)=-(depth+.5d0*dz(i));depth=depth+dz(i);zbotcp(i)=-depth
 end do
 call rdinit(74,0,trim(swp));call rdinne('isoillay',nsub)
 call require(nsub>=1.and.nsub<=256,'sublayer capacity')
 call rdfinr('isoillay',1,maho,layers,256,nsub);call rdinne('ncomp',m);call require(m==nsub,'sublayer counts')
 call rdfinr('ncomp',1,256,counts,256,m);call require(sum(counts(:m))==nn,'node mapping')
 numlay=maxval(layers(:m));k=0
 do i=1,m
  do j=1,counts(i)
   k=k+1;layer(k)=layers(i);ksatfit(layer(k))=cofgen(3,k)
  end do
 end do
 call read_macropore()
 call require(swmbf==1.and.swabs==1,'source geometry selected for instantaneous/sorptivity route')
 call MACROGEOM()
 call require(numdm>=1.and.numdm<=size(ppdmcp,1),'source domains')
 call require(all(ieee_is_finite(vlmpstcp(:nn))).and.all(ieee_is_finite(dipocp(:nn))),'finite source geometry')
 call require(all(vlmpstcp(:nn)>=0d0).and.all(frarmtrx(:nn)>0d0).and.all(dipocp(:nn)>0d0),'positive source geometry')
 call require(all(abs(sum(ppdmcp(:numdm,ictopmp:nn),dim=1)-1d0)<1d-12),'source domain partition')
 close(74)
 ! All input and geometry checks precede output creation.
 open(newunit=u,file=trim(output),status='new',action='write')
 write(u,'(a)')'&macro_geometry'
 write(u,'(a,i0)')' nodes=',nn
 write(u,'(a,i0)')' domains=',numdm
 write(u,'(a,i0)')' top_node=',ictopmp
 write(u,'(a,*(i0,a))')' potential_bottom=',(icpbtdmpot(i),',',i=1,numdm)
 write(u,'(a,*(es25.17e3,a))')' dz=',(dz(i),',',i=1,nn)
 write(u,'(a,*(es25.17e3,a))')' z=',(z(i),',',i=1,nn)
 write(u,'(a,*(es25.17e3,a))')' static_volume=',(vlmpstcp(i),',',i=1,nn)
 write(u,'(a,*(es25.17e3,a))')' matrix_fraction=',(frarmtrx(i),',',i=1,nn)
 write(u,'(a,*(es25.17e3,a))')' diameter=',(dipocp(i),',',i=1,nn)
 write(u,'(a,*(es25.17e3,a))')' fractions=',((ppdmcp(j,i),',',j=1,numdm),i=1,nn)
 write(u,'(a)')'/'
 close(u)
 write(*,'(a,i0,a,i0)')'SWP_ORIGINAL_MACRO_GEOMETRY_PREPARED nodes=',nn,' domains=',numdm
contains
 subroutine require(ok,message)
 logical,intent(in)::ok
 character(*),intent(in)::message
 if(.not.ok)then;print '(a)','SWP_MACRO_GEOMETRY_REJECTED: '//message;error stop 1;end if
 end subroutine
end program
subroutine swap_error(name,message)
 implicit none
 character(*),intent(in)::name,message
 print '(a)',trim(name)//': '//trim(message)
 error stop 1
end subroutine
