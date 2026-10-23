! Project orchestration adapter; original TTUTIL grammar, no physical state.
program read_swp_project
 use iso_fortran_env,only:real64
 use ieee_arithmetic,only:ieee_is_finite
 use mod_crop_rotation_calendar,only:crop_calendar_t,initialize_crop_calendar,CROP_CAL_OK
 implicit none
 integer,parameter::MAX_CROPS=64,MAX_SUB=256
 integer::ncrop,n,m,i,j,k,u,code,mode,swcrop,first_year,last_year,dates(6),layers(MAX_SUB),counts(MAX_SUB)
 integer::types(MAX_CROPS),nyears,first,last,total,rain_mode,soil_factor_mode,nrainfiles,nrain,rn,lo,hi
 integer,allocatable::dd(:),mm(:),yyyy(:)
 real(real64),allocatable::tmn(:),tmx(:),rain(:),etref(:),times(:),output(:,:)
 real(real64)::soil_factor=1d0,rtim,dayrain,previous,legacy_time
 integer::reduction_mode=0
 real(real64)::cofred=0d0
 integer::drain_mode=0,nsub
 character(1024)::drfil,pathdrain=''
 real(real64),allocatable::rain_times(:),rain_amounts(:),event_times(:),event_rates(:)
 integer,allocatable::rain_dd(:),rain_mm(:),rain_yyyy(:)
 real(real64)::tstart,tend,starts(MAX_CROPS),ends(MAX_CROPS),rds,pondmx,rsro,exponent,bottom,amplitude,daymax,fraction
 character(1024)::swp,action,metfil,pathatm,pathcrop,crops(MAX_CROPS),filename,crp,metnames(8),rainnames(8),rainfil
 character(16)::start_text,end_text,a,b,index_text,ext
 logical::rdinqr
 type(crop_calendar_t)::calendar
 call get_command_argument(1,swp);call get_command_argument(2,action)
 call require(trim(action)=='scan'.or.trim(action)=='prepare','scan or prepare required')
 call rdinit(74,0,trim(swp))
 call rdstim('tstart',tstart);call rdstim('tend',tend)
 call require(all(ieee_is_finite([tstart,tend])),'finite calendar')
 call require(tstart==aint(tstart).and.tend==aint(tend).and.tend>=tstart.and.tend-tstart<2048d0,'whole calendar/capacity')
 call rdsinr('swcrop',0,2,swcrop);call require(swcrop==1,'project currently requires simple crop periods')
 call rdsinr('swetr',0,1,mode);call require(mode==1,'SWETR0/PM requires a separate physical demand composition')
 call rdsinr('swrain',0,3,rain_mode);call require(rain_mode==0.or.rain_mode==3,'only daily or detailed rain selected')
 soil_factor_mode=0
 if(rdinqr('swcfbs'))call rdsinr('swcfbs',0,1,soil_factor_mode)
 if(soil_factor_mode==1)call rdsdor('cfbs',0d0,1.5d0,soil_factor)
 call zero('swmetdetail',1);call zero('swdivide',1)
 if(rdinqr('swredu'))call rdsinr('swredu',0,2,reduction_mode)
 call require(reduction_mode==0.or.reduction_mode==2,'only SWREDU0 or Boesten SWREDU2 selected')
 if(reduction_mode==2)then
  call rdsdor('cofredbo',0d0,1d0,cofred);call require(cofred>0d0,'positive Boesten COFREDBO required')
 end if
 if(rdinqr('swdra'))call rdsinr('swdra',0,2,drain_mode)
 call require(drain_mode<=1,'extended surface water drainage not selected')
 if(drain_mode==1)then
  call rdscha('drfil',drfil);call lowerc(drfil);call safe(drfil)
  if(rdinqr('pathdrain'))call rdscha('pathdrain',pathdrain)
  call safe(pathdrain)
 end if
 call zero('swirfix',1);call zero('swirrf',3);call zero('swrunon',1)
 call zero('swmacro',1);call zero('swsnow',1);call zero('swhea',2);call zero('swfrost',1)
 call zero('swtill',1);call zero('swcropsnm',1);call zero('swpondmx',1)
 call rdsinr('swbotb',1,9,mode);call require(mode==2,'only prescribed SWBOTB2 selected; SWBOTB1 is excluded')
 call rdsinr('sw2',1,2,mode);call require(mode==1,'constant prescribed bottom flux required')
 call rdsdor('sinave',-10d0,10d0,bottom);call rdsdor('sinamp',-10d0,10d0,amplitude)
 call rdsdor('sinmax',0d0,366d0,daymax);! Nonzero amplitude is bound to the existing Reference substep control.
 call rdsdor('pondmx',0d0,1000d0,pondmx);call rdsdor('rsro',.001d0,1d0,rsro)
 call rdsdor('rsroexp',.01d0,10d0,exponent);call require(exponent==1d0,'nonlinear runoff exponent not selected')
 call rdsdor('rds',1d0,5000d0,rds)
 call rdscha('metfil',metfil);call lowerc(metfil);call safe(metfil)
 pathatm='';pathcrop=''
 if(rdinqr('pathatm'))call rdscha('pathatm',pathatm)
 if(rdinqr('pathcrop'))call rdscha('pathcrop',pathcrop)
 call safe(pathatm);call safe(pathcrop)
 call rdatim('cropstart',starts,MAX_CROPS,ncrop);call require(ncrop>=1,'crop periods required')
 call rdinne('cropend',n);call require(n==ncrop,'CROPEND count');call rdftim('cropend',ends,MAX_CROPS,n)
 call rdinne('cropfil',n);call require(n==ncrop,'CROPFIL count');call rdfcha('cropfil',crops,MAX_CROPS,n)
 call rdinne('croptype',n);call require(n==ncrop,'CROPTYPE count');call rdfinr('croptype',1,2,types,MAX_CROPS,n)
 call require(all(types(:ncrop)==1),'only simple crops selected')
 call require(all(starts(:ncrop)==aint(starts(:ncrop))).and.all(ends(:ncrop)==aint(ends(:ncrop))),'whole crop dates')
 call require(tstart<=starts(1),'mid-crop simulation startup not selected')
 call initialize_crop_calendar(starts(:ncrop),ends(:ncrop),calendar,code);call require(code==CROP_CAL_OK,'ordered nonoverlapping crop calendar')
 do i=1,ncrop
  call lowerc(crops(i));call safe(crops(i));call require(len_trim(crops(i))>0,'empty crop reference')
 end do
 call rdinne('isoillay',n);call require(n>0.and.n<=MAX_SUB,'grid capacity')
 call rdfinr('isoillay',1,256,layers,MAX_SUB,n);call rdinne('ncomp',m);call require(m==n,'grid counts')
 call rdfinr('ncomp',1,256,counts,MAX_SUB,n);call require(sum(counts(:n))<=256,'node capacity')
 nsub=n
 call dtdpar(tstart+.1d0,dates,fraction);first_year=dates(1)
 call dtdpar(tend+.1d0,dates,fraction);last_year=dates(1)
 call dtdpst('year-month-day',tstart,start_text);call dtdpst('year-month-day',tend,end_text)
 metnames='';nyears=1
 if(index(trim(metfil),'.met')>0)then
  metnames(1)=metfil
 else
  nyears=last_year-first_year+1;call require(nyears<=size(metnames),'year capacity')
  do i=1,nyears
   write(ext,'(I3.3)')mod(first_year+i-1,1000);metnames(i)=trim(metfil)//'.'//trim(ext)
  end do
 end if
 rainnames='';nrainfiles=0
 if(rain_mode==3)then
  call rdscha('rainfil',rainfil);call lowerc(rainfil);call safe(rainfil)
  if(index(trim(rainfil),'.rain')>0)then
   nrainfiles=1;rainnames(1)=rainfil
  else
   nrainfiles=last_year-first_year+1;call require(nrainfiles<=size(rainnames),'rain year capacity')
   do i=1,nrainfiles
    write(ext,'(I3.3)')mod(first_year+i-1,1000);rainnames(i)=trim(rainfil)//'.'//trim(ext)
   end do
  end if
 end if
 close(74)
 if(trim(action)=='scan')then
  open(newunit=u,file='project.csv',status='new',action='write')
  write(u,'(A)')'kind,index,value'
  write(u,'(A)')'pathatm,0,'//trim(pathatm)
  write(u,'(A)')'pathcrop,0,'//trim(pathcrop)
  if(drain_mode==1)then
   write(u,'(A)')'pathdrain,0,'//trim(pathdrain)
   write(u,'(A)')'drain,1,'//trim(drfil)//'.dra'
  end if
  do i=1,nyears
   write(u,'(A,I0,A)')'met,',i,','//trim(metnames(i))
  end do
  do i=1,nrainfiles
   write(u,'(A,I0,A)')'rain,',i,','//trim(rainnames(i))
  end do
  if(rain_mode==3)write(u,'(A)')'detailed_rain,0,1'
  if(reduction_mode==2)write(u,'(A,ES25.16E3)')'boesten_cofred,0,',cofred
  do i=1,ncrop
   write(u,'(A,I0,A)')'crop,',i,','//trim(crops(i))//'.crp'
  end do
  write(u,'(A,ES25.16E3)')'bottom,0,',bottom
  if(amplitude/=0d0)then
   write(u,'(A,ES25.16E3)')'bottom_amplitude,0,',amplitude
   write(u,'(A,ES25.16E3)')'bottom_daymax,0,',daymax
   write(u,'(A,ES25.16E3)')'legacy_origin,0,',tstart
   do i=first_year,last_year+1
    dates=0;dates(1:3)=[i,1,1];call dtardp(dates,0.,fraction)
    write(u,'(A,I0,A,ES25.16E3)')'year_start,',i-first_year+1,',',fraction
   end do
  end if
  write(u,'(A,ES25.16E3)')'pondmax,0,',pondmx
  write(u,'(A,ES25.16E3)')'rsro,0,',rsro
  close(u)
  print '(A)','SWP_NATIVE_PROJECT_SCANNED';stop
 end if
 if(drain_mode==1)call prepare_drainage()
 ! Normalize only original daily ETref fields; preserve full source bytes outside
 ! this view in the project launcher. Read/validate all files before publication.
 allocate(output(8,100000));output=0d0;total=0
 do k=1,nyears
  write(index_text,'(I0)')k;filename='weather-'//trim(index_text)//'.met'
  call rdinit(74,0,trim(filename));call rdinne('yyyy',m);call require(m>0.and.total+m<=100000,'weather capacity')
  allocate(dd(m),mm(m),yyyy(m),tmn(m),tmx(m),rain(m),etref(m),times(m))
  call rdfinr('dd',1,31,dd,m,m);call rdfinr('mm',1,12,mm,m,m);call rdfint('yyyy',yyyy,m,m)
  call rdfdor('tmin',-1d5,1d5,tmn,m,m);call rdfdor('tmax',-1d5,1d5,tmx,m,m)
  rain=0d0
  if(rain_mode==0)call rdfdor('rain',0d0,1000d0,rain,m,m)
  call rdfdor('etref',0d0,100d0,etref,m,m);close(74)
  call require(all(ieee_is_finite(tmn)).and.all(ieee_is_finite(tmx)).and.all(ieee_is_finite(rain)).and. &
    all(ieee_is_finite(etref)),'nonfinite daily weather')
  do i=1,m
   dates=0;dates(1:3)=[yyyy(i),mm(i),dd(i)];call dtardp(dates,0.,times(i))
   if(i>1)call require(times(i)==times(i-1)+1d0,'weather dates consecutive and unique')
   if(i==1.and.total>0)call require(times(i)==output(1,total)+1d0,'consecutive year files')
   output(1:7,total+i)=[times(i),real(dd(i),real64),real(mm(i),real64),real(yyyy(i),real64),tmn(i),tmx(i),rain(i)]
  end do
  output(8,total+1:total+m)=etref;total=total+m
  deallocate(dd,mm,yyyy,tmn,tmx,rain,etref,times)
 end do
 call require(output(1,1)<=tstart.and.output(1,total)>=tend,'complete weather calendar')
 do k=1,ncrop
  write(index_text,'(I0)')k;crp='crop-'//trim(index_text)//'.crp'
  call rdinit(74,0,trim(crp));call zero('swirrf',3);close(74)
 end do
 if(rain_mode==3)call detailed_rain_input()
 open(newunit=u,file='weather.met',status='new',action='write')
 write(u,'(A)')'DD MM YYYY TMIN TMAX RAIN ETREF'
 do i=1,total
  write(u,'(3(I0,1X),4(ES25.16E3,1X))')nint(output(2:4,i)),output(5:8,i)
 end do
 close(u)
 do k=1,ncrop
  write(index_text,'(I0)')k;filename='period-'//trim(index_text)//'.swp'
  open(newunit=u,file=trim(filename),status='new',action='write')
  write(u,'(A)')'TSTART='//trim(start_text);write(u,'(A)')'TEND='//trim(end_text)
  write(u,'(A)')"METFIL='weather.met'"
  write(u,'(A)')'SWCROP=1','SWETR=1','SWRAIN=0','SWEVAP=1','SWREDU=0','SWHEA=0','SWSNOW=0','SWMACRO=0'
  write(u,'(A,I0)')'SWCFBS=',soil_factor_mode
  if(soil_factor_mode==1)write(u,'(A,ES25.16E3)')'CFBS=',soil_factor
  write(u,'(A,ES25.16E3)')'RDS=',rds
  ! Preparation emits potential demand only. SWREDU2 is executed against each
  ! candidate hydraulic state by the existing Boesten physical owner, not here.
  ! Native preparation needs only these explicit flags; physical original SWP
  ! remains separate. Pond factor is read from that original in this same adapter.
  fraction=1.25d0
  call rdinit(74,0,trim(swp))
  if(rdinqr('cfevappond'))call rdsdor('cfevappond',0d0,3d0,fraction)
  close(74)
  write(u,'(A,ES25.16E3)')'CFEVAPPOND=',fraction
  write(u,'(A)')'ISOILLAY NCOMP'
  do j=1,n
   write(u,'(2(I0,1X))')layers(j),counts(j)
  end do
  write(u,'(A)')'CROPSTART CROPEND CROPFIL CROPTYPE'
  call dtdpst('year-month-day',starts(k),a);call dtdpst('year-month-day',ends(k),b)
  write(u,'(A)')trim(a)//' '//trim(b)//" 'crop-"//trim(index_text)//"' 1"
  close(u)
 end do
 print '(A)','SWP_NATIVE_PROJECT_PREPARED'
contains
 subroutine prepare_drainage()
  integer::sw,nn,na,ii,jj,v
  real(real64)::res,infres,spacing,base,anis(MAX_SUB),dates(1024),heads(1024)
  call rdinit(74,0,'drain-1.dra')
  call rdsinr('dramet',1,3,v);call require(v==3,'only DRAMET3 selected')
  call rdsinr('swdivd',0,1,v);call require(v==1,'native drainage requires explicit DIVDRA')
  call rdsinr('swdivdinf',0,1,v);call require(v==0,'alternative infiltration distribution not selected')
  call rdsinr('swdislay',0,2,v);call require(v==0,'adjusted discharge layers not selected')
  call rdsinr('nrlevs',1,5,v);call require(v==1,'native drainage requires one level')
  call rdsinr('swintfl',0,1,v);call require(v==0,'interflow not selected')
  call rdsinr('swallo1',1,3,v);call require(v==3,'native drainage requires drainage-only SWALLO1=3')
  call rdsinr('swdtyp1',1,2,sw);call require(sw==1,'native drainage requires drain tube')
  call rdsdor('drares1',10d0,1d5,res);call rdsdor('infres1',0d0,1d5,infres)
  call rdsdor('l1',1d0,1d5,spacing);call rdsdor('zbotdr1',-10000d0,0d0,base)
  call rdador('cofani',.0001d0,1000d0,anis,MAX_SUB,na)
  call require(maxval(layers(:nsub))<=na,'COFANI soil-layer coverage')
  call rdatim('datowl1',dates,1024,nn);call require(nn>=1,'channel table required')
  call rdinne('level1',v);call require(v==nn,'channel date/head count')
  call rdfdor('level1',-10000d0,200d0,heads,1024,v)
  call require(all(ieee_is_finite(dates(:nn))).and.all(ieee_is_finite(heads(:nn))),'finite channel table')
  call require(all(dates(2:nn)>dates(:nn-1)),'strict channel calendar')
  call require(dates(1)<=tstart.and.dates(nn)>=tend+1d0,'complete channel calendar')
  close(74)
  open(newunit=u,file='drainage.nml',status='new',action='write')
  write(u,'(A)')' native_drainage=.true.'
  write(u,'(A,ES25.16E3)')' drain_resistance=',res
  write(u,'(A,ES25.16E3)')' drain_infiltration_resistance=',infres
  write(u,'(A,ES25.16E3)')' drain_spacing_m=',spacing
  write(u,'(A,ES25.16E3)')' drain_bottom_cm=',base
  write(u,'(A,ES25.16E3)')' drain_legacy_origin=',tstart
  write(u,'(A,I0)')' drain_table_count=',nn
  write(u,'(A)',advance='no')' drain_table_times='
  do ii=1,nn
   write(u,'(ES25.16E3,A)',advance='no')dates(ii),','
  end do
  write(u,'(A)')''
  write(u,'(A)',advance='no')' drain_table_heads='
  do ii=1,nn
   write(u,'(ES25.16E3,A)',advance='no')heads(ii),','
  end do
  write(u,'(A)')''
  write(u,'(A)',advance='no')' drain_anisotropy='
  do ii=1,nsub
   do jj=1,counts(ii)
    write(u,'(ES25.16E3,A)',advance='no')anis(layers(ii)),','
   end do
  end do
  write(u,'(A)')'';close(u)
 end subroutine
 subroutine detailed_rain_input()
  ! Original TTUTIL fields and MOD_meteo:LoadRainData interval convention.
  ! Full original rain bytes remain bound by the launcher, including unused tail.
  allocate(event_times(100001),event_rates(100001));rn=0
  previous=-huge(1d0)
  do k=1,nrainfiles
   write(index_text,'(I0)')k;filename='rain-'//trim(index_text)//'.rain'
   call rdinit(74,0,trim(filename));call rdinne('year',m)
   call require(m>0.and.rn+m<=100000,'detailed rain capacity')
   allocate(rain_dd(m),rain_mm(m),rain_yyyy(m),rain_times(m),rain_amounts(m))
   call rdfinr('day',1,31,rain_dd,m,m);call rdfinr('month',1,12,rain_mm,m,m)
   call rdfinr('year',1,3000,rain_yyyy,m,m)
   call rdfdor('time',0d0,1d0,rain_times,m,m);call rdfdor('amount',0d0,10000d0,rain_amounts,m,m);close(74)
   call require(all(ieee_is_finite(rain_times)).and.all(ieee_is_finite(rain_amounts)),'nonfinite detailed rain')
   do i=1,m
    dates=0;dates(1:3)=[rain_yyyy(i),rain_mm(i),rain_dd(i)];call dtardp(dates,0.,legacy_time)
    legacy_time=legacy_time+rain_times(i)
    if(previous/=-huge(1d0))call require(legacy_time-previous>=1d-8,'detailed rain timestamps must ascend')
    if(legacy_time>=tstart)then
     if(previous==-huge(1d0))then
      if(legacy_time-tstart>1d-8)then
       rn=rn+1;event_times(rn)=legacy_time;event_rates(rn)=rain_amounts(i)*.1d0/(legacy_time-tstart)
      end if
     else
      rn=rn+1;event_times(rn)=legacy_time;event_rates(rn)=rain_amounts(i)*.1d0/(legacy_time-previous)
     end if
    end if
    previous=legacy_time
   end do
   deallocate(rain_dd,rain_mm,rain_yyyy,rain_times,rain_amounts)
  end do
  ! The historical reader closes the last event with a zero-flux sentinel.
  ! Only the first interval ending at/after simulation end is consumed here.
  nrain=rn
  do i=1,rn
   if(event_times(i)>=tend+1d0)then
    nrain=i;exit
   end if
  end do
  if(nrain==0)then
   nrain=1;event_times(1)=tend+2d0;event_rates(1)=0d0
  else if(event_times(nrain)<tend+1d0)then
   nrain=nrain+1;event_times(nrain)=tend+2d0;event_rates(nrain)=0d0
  end if
  call require(all(ieee_is_finite(event_rates(:nrain))).and.all(event_rates(:nrain)>=0d0).and. &
   all(event_rates(:nrain)<=5d5),'detailed rate outside existing surface forcing domain')
  open(newunit=u,file='rain_events.csv',status='new',action='write')
  write(u,'(A)')'end_day,rate_cm_day'
  do i=1,nrain
   if(event_times(i)<=tstart)cycle
   write(u,'(ES25.16E3,A,ES25.16E3)')event_times(i)-tstart,',',event_rates(i)
  end do
  close(u)
  ! Literal original day integration; day records prepare ET/root views only.
  output(7,:)=0d0;rn=1
  do j=1,total
   if(output(1,j)<tstart.or.output(1,j)>tend)cycle
   dayrain=0d0
   do while(event_times(rn)<output(1,j)+1d0)
    if(rn==1)then
     rtim=event_times(rn)-tstart
    else
     rtim=event_times(rn)-max(output(1,j),event_times(rn-1))
    end if
    dayrain=dayrain+rtim*event_rates(rn);rn=rn+1
   end do
   if(rn==1)then
    rtim=min(1d0,min(event_times(rn),output(1,j)+1d0)-tstart)
   else
    rtim=min(1d0,min(event_times(rn),output(1,j)+1d0)-event_times(rn-1))
   end if
   dayrain=dayrain+rtim*event_rates(rn);output(7,j)=dayrain*10d0
  end do
 end subroutine
 subroutine require(ok,message)
  logical,intent(in)::ok
  character(*),intent(in)::message
  if(.not.ok)then
   print '(A)','SWP_PROJECT_REJECTED: '//message;error stop 1
  end if
 end subroutine
 subroutine zero(name,maximum)
  character(*),intent(in)::name
  integer,intent(in)::maximum
  integer::v
  if(.not.rdinqr(name))return
  call rdsinr(name,0,maximum,v);call require(v==0,'unsupported active '//name)
 end subroutine
 subroutine safe(name)
  character(*),intent(in)::name
  call require(index(name,',')==0.and.index(name,achar(10))==0.and.index(name,achar(13))==0,'unsupported path characters')
 end subroutine
end program
