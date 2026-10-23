! Project orchestration adapter; original TTUTIL grammar, no physical state.
program read_swp_project
 use iso_fortran_env,only:real64
 use ieee_arithmetic,only:ieee_is_finite
 use mod_crop_rotation_calendar,only:crop_calendar_t,initialize_crop_calendar,CROP_CAL_OK
 implicit none
 integer,parameter::MAX_CROPS=64,MAX_SUB=256
 integer::ncrop,n,m,i,j,k,u,code,mode,swcrop,first_year,last_year,dates(6),layers(MAX_SUB),counts(MAX_SUB)
 integer::types(MAX_CROPS),nyears,first,last,total
 integer,allocatable::dd(:),mm(:),yyyy(:)
 real(real64),allocatable::tmn(:),tmx(:),rain(:),etref(:),times(:),output(:,:)
 real(real64)::tstart,tend,starts(MAX_CROPS),ends(MAX_CROPS),rds,pondmx,rsro,exponent,bottom,amplitude,daymax,fraction
 character(1024)::swp,action,metfil,pathatm,pathcrop,crops(MAX_CROPS),filename,crp,metnames(8)
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
 call rdsinr('swrain',0,3,mode);call require(mode==0,'uniform daily rain required')
 call zero('swmetdetail',1);call zero('swdivide',1);call zero('swcfbs',1);call zero('swredu',2)
 call zero('swdra',3);call zero('swirfix',1);call zero('swirrf',3);call zero('swrunon',1)
 call zero('swmacro',1);call zero('swsnow',1);call zero('swhea',2);call zero('swfrost',1)
 call zero('swtill',1);call zero('swcropsnm',1);call zero('swpondmx',1)
 call rdsinr('swbotb',1,9,mode);call require(mode==2,'only prescribed SWBOTB2 selected; SWBOTB1 is excluded')
 call rdsinr('sw2',1,2,mode);call require(mode==1,'constant prescribed bottom flux required')
 call rdsdor('sinave',-10d0,10d0,bottom);call rdsdor('sinamp',-10d0,10d0,amplitude)
 call rdsdor('sinmax',0d0,366d0,daymax);call require(amplitude==0d0,'seasonal bottom boundary not selected')
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
 close(74)
 if(trim(action)=='scan')then
  open(newunit=u,file='project.csv',status='new',action='write')
  write(u,'(A)')'kind,index,value'
  write(u,'(A)')'pathatm,0,'//trim(pathatm)
  write(u,'(A)')'pathcrop,0,'//trim(pathcrop)
  do i=1,nyears
   write(u,'(A,I0,A)')'met,',i,','//trim(metnames(i))
  end do
  do i=1,ncrop
   write(u,'(A,I0,A)')'crop,',i,','//trim(crops(i))//'.crp'
  end do
  write(u,'(A,ES25.16E3)')'bottom,0,',bottom
  write(u,'(A,ES25.16E3)')'pondmax,0,',pondmx
  write(u,'(A,ES25.16E3)')'rsro,0,',rsro
  close(u)
  print '(A)','SWP_NATIVE_PROJECT_SCANNED';stop
 end if
 ! Normalize only original daily ETref fields; preserve full source bytes outside
 ! this view in the project launcher. Read/validate all files before publication.
 allocate(output(8,100000));output=0d0;total=0
 do k=1,nyears
  write(index_text,'(I0)')k;filename='weather-'//trim(index_text)//'.met'
  call rdinit(74,0,trim(filename));call rdinne('yyyy',m);call require(m>0.and.total+m<=100000,'weather capacity')
  allocate(dd(m),mm(m),yyyy(m),tmn(m),tmx(m),rain(m),etref(m),times(m))
  call rdfinr('dd',1,31,dd,m,m);call rdfinr('mm',1,12,mm,m,m);call rdfint('yyyy',yyyy,m,m)
  call rdfdor('tmin',-1d5,1d5,tmn,m,m);call rdfdor('tmax',-1d5,1d5,tmx,m,m)
  call rdfdor('rain',0d0,1000d0,rain,m,m);call rdfdor('etref',0d0,100d0,etref,m,m);close(74)
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
  write(u,'(A)')'SWCROP=1','SWETR=1','SWRAIN=0','SWEVAP=1','SWCFBS=0','SWREDU=0','SWHEA=0','SWSNOW=0','SWMACRO=0'
  write(u,'(A,ES25.16E3)')'RDS=',rds
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
