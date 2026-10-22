! Native original root/stress and rain input, outside all physical owners.
program read_swp_root
  use iso_fortran_env,only:real64
  use ieee_arithmetic,only:ieee_is_finite
  implicit none
  integer,parameter::MAX_KNOTS=500
  integer::n,m,i,j,u,first,last,mode,root_table_points,upper_layer_bottom_node,datea(6)
  integer::layers(256),compartments(256)
  real(real64)::maximum_root_depth_cm,hlim3l,hlim3h,hlim4,adcrl,adcrh,hlim1=0d0,hlim2u=0d0,hlim2l=0d0
  real(real64)::root_relative_depth(MAX_KNOTS)=0d0,root_density(MAX_KNOTS)=0d0,tstart,tend
  real(real64),allocatable::flat(:),rain(:),times(:)
  integer,allocatable::dd(:),mm(:),yyyy(:)
  logical::empirical_oxygen_enabled=.false.,rdinqr
  character(1024)::swp,crp,met
  namelist /crop/ root_table_points,upper_layer_bottom_node,maximum_root_depth_cm,root_relative_depth,root_density, &
    hlim3l,hlim3h,hlim4,adcrl,adcrh,hlim1,hlim2u,hlim2l,empirical_oxygen_enabled
  call get_command_argument(1,swp);call get_command_argument(2,crp);call get_command_argument(3,met)
  call rdinit(74,0,trim(swp))
  call rdsinr('swcrop',0,2,mode);call require(mode==1,'crop must be native active')
  call rdsinr('swrain',0,3,mode);call require(mode==0,'only uniform daily rain selected')
  if(rdinqr('swevap'))then
    call rdsinr('swevap',0,1,mode);call require(mode==1,'disabled evaporation not selected')
  end if
  call zero_switch('swsnow',1);call zero_switch('swhea',2);call zero_switch('swmacro',1)
  call zero_switch('swfrost',1);call zero_switch('swtill',1);call zero_switch('swcropsnm',1)
  call rdsdor('rds',1d0,5000d0,maximum_root_depth_cm)
  call rdstim('tstart',tstart);call rdstim('tend',tend)
  call require(all(ieee_is_finite([tstart,tend])),'nonfinite calendar')
  call require(tstart==aint(tstart).and.tend==aint(tend).and.tend>=tstart.and.tend-tstart<2048d0,'calendar bounds')
  call rdinne('isoillay',n);call require(n>0.and.n<=256,'layer capacity')
  call rdfinr('isoillay',1,256,layers,256,n)
  call require(layers(1)==1.and.all(layers(2:n)>=layers(1:n-1)),'ordered soil layers starting at one')
  call rdinne('ncomp',m);call require(n==m,'grid count mismatch')
  call rdfinr('ncomp',1,256,compartments,256,n)
  call require(sum(compartments(:n))<=256,'node capacity')
  upper_layer_bottom_node=0
  do i=1,n
    if(layers(i)/=layers(1))exit
    upper_layer_bottom_node=upper_layer_bottom_node+compartments(i)
  end do
  close(74)
  call rdinit(74,0,trim(crp))
  mode=1
  if(rdinqr('swdrought'))call rdsinr('swdrought',1,3,mode)
  call require(mode==1,'only macro Feddes drought')
  mode=1
  if(rdinqr('swoxygen'))call rdsinr('swoxygen',0,2,mode)
  call require(mode<=1,'physical oxygen not selected')
  empirical_oxygen_enabled=mode==1
  call zero_switch('swsalinity',1);call zero_switch('swcompensate',2);call zero_switch('swjarvis',4)
  call zero_switch('swrdc',1);call zero_switch('swlrvconstant',1)
  call rdsdor('hlim3l',-10000d0,100d0,hlim3l);call rdsdor('hlim3h',-10000d0,100d0,hlim3h)
  call rdsdor('hlim4',-20000d0,100d0,hlim4)
  call rdsdor('adcrl',0d0,5d0,adcrl);call rdsdor('adcrh',0d0,5d0,adcrh)
  call require(adcrh>adcrl.and.hlim4<min(hlim3l,hlim3h),'invalid Feddes interval')
  if(empirical_oxygen_enabled)then
    call rdsdor('hlim1',-100d0,100d0,hlim1)
    call rdsdor('hlim2u',-1000d0,100d0,hlim2u);call rdsdor('hlim2l',-1000d0,100d0,hlim2l)
    call require(hlim1>max(hlim2u,hlim2l),'invalid oxygen interval')
  end if
  call rdinne('rdctb',m);call require(m>=4.and.m<=2*MAX_KNOTS.and.mod(m,2)==0,'root table size')
  allocate(flat(m));call rdfdou('rdctb',flat,m,m)
  call require(all(ieee_is_finite(flat)),'nonfinite root table')
  root_table_points=m/2
  root_relative_depth(:root_table_points)=flat(1::2);root_density(:root_table_points)=flat(2::2)
  call require(root_relative_depth(1)==0d0.and.root_relative_depth(root_table_points)==1d0,'root density extent')
  call require(all(root_density>=0d0).and.all(root_density<=100d0),'root density range')
  do i=2,root_table_points
    call require(root_relative_depth(i)>root_relative_depth(i-1),'root density order')
  end do
  call require(any(root_density(:root_table_points)>0d0),'zero root density')
  call require(all(ieee_is_finite([maximum_root_depth_cm,hlim3l,hlim3h,hlim4,adcrl,adcrh,hlim1,hlim2u,hlim2l])), &
    'nonfinite root parameters')
  close(74)
  call rdinit(74,0,trim(met))
  call rdinne('yyyy',n);call require(n>0.and.n<=100000,'MET capacity')
  allocate(dd(n),mm(n),yyyy(n),rain(n),times(n))
  call rdfinr('dd',1,31,dd,n,n);call rdfinr('mm',1,12,mm,n,n);call rdfint('yyyy',yyyy,n,n)
  call rdfdor('rain',0d0,1d3,rain,n,n);call require(all(ieee_is_finite(rain)),'nonfinite rain')
  close(74)
  do i=1,n
    datea=0;datea(1:3)=[yyyy(i),mm(i),dd(i)];call dtardp(datea,0.0,times(i))
    if(i>1)call require(times(i)-times(i-1)==1d0,'MET must be consecutive')
  end do
  call require(times(1)<=tstart.and.times(n)>=tend,'incomplete MET')
  first=nint(tstart-times(1))+1;last=nint(tend-times(1))+1
  open(newunit=u,file='root.nml',status='new',action='write');write(u,nml=crop);close(u)
  open(newunit=u,file='rain.csv',status='new',action='write')
  write(u,'(A)')'t1900,rain_cm_day'
  do i=first,last
    write(u,'(ES25.16E3,A,ES25.16E3)')times(i),',',rain(i)*.1d0
  end do
  close(u)
  print '(A)','SWP_NATIVE_ROOT_IMPORTED'
contains
  subroutine require(ok,message)
    logical,intent(in)::ok
    character(*),intent(in)::message
    if(.not.ok)then
      print '(A)','SWP_ROOT_REJECTED: '//message
      error stop 1
    end if
  end subroutine
  subroutine zero_switch(name,maximum)
    character(*),intent(in)::name
    integer,intent(in)::maximum
    integer::v
    if(.not.rdinqr(name))return
    call rdsinr(name,0,maximum,v);call require(v==0,'unsupported '//name)
  end subroutine
end program
