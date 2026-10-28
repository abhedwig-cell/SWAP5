! Isolated original macropore input preparation. Never advances accepted water.
program read_swp_macro_initial
 use iso_fortran_env,only:real64
 use ieee_arithmetic,only:ieee_is_finite
 use MOD_arrays,only:macp,maho
 use MOD_grid
 use variables,only:ksatfit,h,theta,thetas,thetar,thetm1,thetsl,swbotb,pond,fluseksatexm
 use MOD_swap_base,only:swsolu
 use MOD_macropore
 use MOD_MvG,only:source_cof=>cofgen,paramvg,set_cofgen_pointers,calc_cofgen_extra,watcon, &
  swsophy,sw_use_elas,fl_use_tables,fl_use_kh_power,iHWCKmodel,hconduc
 use MOD_gwl,only:calcgwl
 use MOD_drain,only:swdtyp
 use mod_column_swp_water,only:import_column_swp_water
 implicit none
 character(1024)::swp,bbc,output,dra
 character(32)::config_mode
 logical::full_config
 integer::mode,bottom_mode,nsub,m,k,j,i,u,nn
 integer::layers(256),counts(256)
 real(real64)::width(256),gwl,depth,minimum_surface_conductivity
 real(real64),allocatable::initial_theta(:)
 real(real64),allocatable::heads(:),cofgen(:,:)
 logical::rdinqr
 call get_command_argument(1,swp);call get_command_argument(2,bbc);call get_command_argument(3,output);call get_command_argument(4,dra)
 call get_command_argument(5,config_mode)
 call require(len_trim(config_mode)==0.or.trim(config_mode)=='native-water'.or. &
  trim(config_mode)=='native-water-experimental','unknown configuration option')
 full_config=len_trim(config_mode)>0
 call require(len_trim(swp)>0.and.len_trim(output)>0,'SWP and output required')
 call rdinit(74,0,trim(swp));call rdsinr('swmacro',0,1,mode);call require(mode==1,'requires original active SWMACRO')
 call rdsinr('swfrost',0,1,m);call require(m==0,'frost not selected')
 call rdsinr('swsolu',0,1,swsolu);call require(swsolu==0,'original macro requires SWSOLU0')
 if(rdinqr('swbotb'))then
  call rdsinr('swbotb',1,9,bottom_mode);close(74)
 else
  close(74);call require(len_trim(bbc)>0,'original external BBC required')
  call rdinit(74,0,trim(bbc));call rdsinr('swbotb',1,9,bottom_mode);close(74)
 end if
 call require(bottom_mode==3,'geometry bootstrap currently selects original Cauchy3')
 call import_column_swp_water(trim(swp),nn,width,heads,cofgen,pond,bottom_mode,gwl,allow_ksatexm=.true.)
 numnod=nn;allocate(z(nn),dz(nn),zbotcp(nn),layer(nn),disnod(nn));dz=width(:nn);depth=0d0
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
 do i=1,nn
  if(nod1lay(layer(i))==0)nod1lay(layer(i))=i
  botcom(layer(i))=i
 end do
 call read_macropore()
 call require(swmbf==1.and.swabs==1,'source geometry selected for instantaneous/sorptivity route')
 call MACROGEOM()
 call require(numdm>=1.and.numdm<=size(ppdmcp,1),'source domains')
 call require(all(ieee_is_finite(vlmpstcp(:nn))).and.all(ieee_is_finite(dipocp(:nn))),'finite source geometry')
 call require(all(vlmpstcp(:nn)>=0d0).and.all(frarmtrx(:nn)>0d0).and.all(dipocp(:nn)>0d0),'positive source geometry')
 call require(all(abs(sum(ppdmcp(:numdm,ictopmp:nn),dim=1)-1d0)<1d-12),'source domain partition')
 call require(all(swsoilshr(:numlay)==1).and.all(swshrinp(:numlay)==2),'original clay option2 only')
 call require(all(swsorp(:numlay)==1),'original computed Parlange only')
 call require(swdrRap==1.and.numlevrapdra==1,'original one-level rapid drainage')
 call require(all(thetcrmp(:numlay)<=cofgen(2,nod1lay(:numlay))),'cracking theta exceeds saturation')
 close(74)
 call require(len_trim(dra)>0,'original drainage input required')
 call rdinit(74,0,trim(dra));call rdsinr('dramet',1,3,m);call require(m==3,'original resistance drainage only')
 call rdsinr('nrlevs',1,25,m);call require(m==1,'original one drainage level')
 call rdsinr('swdtyp1',1,2,swdtyp(1));call require(swdtyp(1)==1,'original tube drainage only')
 call rdsdor('zbotdr1',-10000d0,0d0,zdrabas);close(74)
 source_cof(:24,:nn)=cofgen;paramvg=0d0
 do i=1,numlay
  paramvg(:,i)=source_cof(:,nod1lay(i));thetsl(i)=paramvg(2,i)
 end do
 h(:nn)=heads;thetar(:nn)=cofgen(1,:);thetas(:nn)=cofgen(2,:);swbotb=bottom_mode
 fluseksatexm(:nn)=cofgen(10,:)>cofgen(3,:)
 swsophy=0;sw_use_elas=0;fl_use_tables=.false.;fl_use_kh_power=.false.;iHWCKmodel=1
 call set_cofgen_pointers();call calc_cofgen_extra(nn)
 do i=1,nn
  theta(i)=watcon(i,h(i));thetm1(i)=theta(i)
  disnod(i)=dz(i)
  if(i>1)disnod(i)=z(i-1)-z(i)
 end do
 call calcgwl()
 call require(nodgwlflcpzo>=1.and.nodgwlflcpzo<=nn,'initial saturated zone required')
 call MACROINIT()
 call require(all(ieee_is_finite(sorpmax(:numlay))).and.all(sorpmax(:numlay)>0d0),'computed Parlange')
 call require(all(ieee_is_finite(sorpalfa(:numlay))).and.all(sorpalfa(:numlay)>0d0),'computed Parlange exponent')
 call require(all(ieee_is_finite(vlmpdycp(:nn))).and.all(vlmpdycp(:nn)>=0d0),'initial dynamic volumes')
 call require(ieee_is_finite(kdcrrlref(1)).and.kdcrrlref(1)>0d0,'rapid reference')
 if(full_config)then
  call require(swdarcy==1,'native water requires original SWDARCY1')
  ! Original MPVOLUME supplies the static-only lower bound. This project's
  ! conductivity is already at the original1000 cm/day cap at that bound.
  initial_theta=theta(:nn);theta(:nn)=thetas(:nn);call MPVOLUME(1)
  minimum_surface_conductivity=ksmpss
  theta(:nn)=initial_theta;call MPVOLUME(1)
  call require(all(ieee_is_finite([minimum_surface_conductivity,ksmpss])).and. &
   minimum_surface_conductivity>=1d-14.and.ksmpss>=minimum_surface_conductivity.and.ksmpss<=1000d0, &
   'source surface conductivity bounds')
  if(minimum_surface_conductivity/=1000d0)call require(trim(config_mode)=='native-water-experimental', &
   'variable surface conductivity requires experimental mode')
 end if
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
 write(u,'(a)')'&macro_initial'
 write(u,'(a,i0)')' layers=',numlay
 write(u,'(a,*(i0,a))')' layer=',(layer(i),',',i=1,nn)
 write(u,'(a,i0)')' cutoff=',nodgwlflcpzo
 write(u,'(a,i0)')' surface_node=',nncrar
 write(u,'(a,es25.17e3)')' groundwater=',gwlflcpzo
 write(u,'(a,es25.17e3)')' static_bottom=',z_st
 write(u,'(a,es25.17e3)')' drain_level=',zdrabas
 write(u,'(a,es25.17e3)')' rapid_exponent=',rapdrareaexp
 write(u,'(a,es25.17e3)')' rapid_kd=',kdcrrlref(1)
 write(u,'(a,*(es25.17e3,a))')' theta=',(theta(i),',',i=1,nn)
 write(u,'(a,*(es25.17e3,a))')' theta_s=',(thetas(i),',',i=1,nn)
 write(u,'(a,*(es25.17e3,a))')' theta_r=',(thetar(i),',',i=1,nn)
 write(u,'(a,*(es25.17e3,a))')' theta_crack=',(thetcrmp(layer(i)),',',i=1,nn)
 write(u,'(a,*(es25.17e3,a))')' geometry_factor=',(geomfac(layer(i)),',',i=1,nn)
 write(u,'(a,*(es25.17e3,a))')' kim_a=',(shrpara(layer(i)),',',i=1,nn)
 write(u,'(a,*(es25.17e3,a))')' kim_b=',(shrparb(layer(i)),',',i=1,nn)
 write(u,'(a,*(es25.17e3,a))')' kim_c=',(shrparc(layer(i)),',',i=1,nn)
 write(u,'(a,*(es25.17e3,a))')' kim_d=',(shrpard(layer(i)),',',i=1,nn)
 write(u,'(a,*(es25.17e3,a))')' minimum_subsidence=',(subsidcpmin(i),',',i=1,nn)
 write(u,'(a,*(es25.17e3,a))')' dynamic_volume=',(vlmpdycp(i),',',i=1,nn)
 write(u,'(a,*(es25.17e3,a))')' subsidence=',(subsidcp(i),',',i=1,nn)
 write(u,'(a,*(es25.17e3,a))')' sorptivity_max=',(sorpmax(layer(i)),',',i=1,nn)
 write(u,'(a,*(es25.17e3,a))')' sorptivity_alpha=',(sorpalfa(layer(i)),',',i=1,nn)
 write(u,'(a,*(es25.17e3,a))')' hydrostatic_drain_theta=',(watcon(i,zdrabas-z(i)),',',i=1,nn)
 write(u,'(a,*(es25.17e3,a))')' volume=',((vlmpdmcp(j,i),',',j=1,numdm),i=1,nn)
 write(u,'(a,*(es25.17e3,a))')' water=',((waunmpdmcp(j,i),',',j=1,numdm),i=1,nn)
 write(u,'(a,*(es25.17e3,a))')' darcy=',((cdarcy(j,i),',',j=1,numdm),i=1,nn)
 write(u,'(a,*(es25.17e3,a))')' domain_water=',(wasrmpdm(i),',',i=1,numdm)
 write(u,'(a)')'/'
 if(full_config)then
  write(u,'(a)')'&macro_configuration'
  write(u,'(a,i0)')' seepage_option=',swsep
  write(u,'(a,es25.17e3)')' shape_factor=',shapefacmp
  write(u,'(a,es25.17e3)')' rapid_resistance=',rapdraresref(1)
  write(u,'(a,es25.17e3)')' critical_undersaturation=',critundsatvol
  write(u,'(a,es25.17e3)')' pond_threshold=',pndmxmp
  write(u,'(a,es25.17e3)')' source_surface_conductivity=',ksmpss
  write(u,'(a,es25.17e3)')' minimum_surface_conductivity=',minimum_surface_conductivity
  write(u,'(a,*(es25.17e3,a))')' conductivity=',(hconduc(i,h(i),theta(i),0d0),',',i=1,nn)
  write(u,'(a,*(es25.17e3,a))')' entry_head=',(cofgen(9,i),',',i=1,nn)
  write(u,'(a,*(es25.17e3,a))')' sorption_factor=',(sorpfacparl(layer(i)),',',i=1,nn)
  write(u,'(a,*(es25.17e3,a))')' horizontal_ksat=',(ksatfit(layer(i)),',',i=1,nn)
  write(u,'(a)')'/'
 end if
 close(u)
 write(*,'(a,i0,a,i0)')'SWP_ORIGINAL_MACRO_INITIAL_PREPARED nodes=',nn,' domains=',numdm
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
