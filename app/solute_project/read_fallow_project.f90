! Original SWP daily PM fallow prefix. No hydraulic/thermal/solute substitute.
program read_fallow_project
 use iso_fortran_env,only:real64
 use mod_pmdirect_swetr0_process
 implicit none
 integer::u,n,i,j,k,days,mode,dates(6),nir=0,nwindows,iday,swfixed,irtype(1000),dd(10000),mm(10000),yyyy(10000),nc
 real(real64)::first,last,starts(64),t,jan1,fraction,pondmx,rsro,cofred,rsigni,rds
 real(real64)::irdate(1000),irdepth(1000),irrate(1000),irconc(1000),irstart(1000),irend(1000)
 real(real64)::irrig(2048),ends(2048),source_soil(2048),source_pond(2048),source_air(2048),source_rain(2048),edge,irrigation_c
 real(real64)::rad(10000),tmn(10000),tmx(10000),hum(10000),wind(10000),rain(10000)
 real(real64)::soil(2048),pond(2048),air(2048),amount(2048),spacing,shape,wetper,dbot,entres,base,kh
 character(1024)::swp,met,dra,arg,selection
 logical::original_germination=.false.
 type(pmdirect_swetr0_weather_t)::weather
 type(pmdirect_swetr0_site_t)::site
 type(pmdirect_swetr0_canopy_t)::canopy
 type(pmdirect_swetr0_daily_result_t)::result
 type(pmdirect_swetr0_diagnostics_t)::diagnostic
 call get_command_argument(1,swp);call get_command_argument(2,met);call get_command_argument(3,dra)
 call get_command_argument(4,arg);read(arg,*)days
 call get_command_argument(5,selection)
 if(len_trim(selection)>0.and.trim(selection)/='original-germination')error stop 'unknown source lifecycle selection'
 original_germination=trim(selection)=='original-germination'
 if(days<1.or.days>2048)error stop 'prefix capacity'
 call rdinit(74,0,trim(swp));call rdstim('tstart',first);call rdstim('tend',last)
 call rdatim('cropstart',starts,64,nc)
 if(nc<1.or.(.not.original_germination.and.first+days>minval(starts(:nc))).or.first+days>last+1d0)error stop 'prefix crosses original crop emergence/calendar'
 call rdsinr('swetr',0,1,mode);if(mode/=0)error stop 'original direct PM required'
 call rdsinr('swdivide',0,1,mode);if(mode/=1)error stop 'direct PM partition required'
 call rdsinr('swrain',0,3,mode);if(mode/=0)error stop 'daily source rainfall required'
 call rdsinr('swmetdetail',0,1,mode);if(mode/=0)error stop 'daily source meteorology required'
 call rdsinr('swrunon',0,1,mode);if(mode/=0)error stop 'runon owner not composed'
 call rdsinr('swpondmx',0,1,mode);if(mode/=0)error stop 'variable pond threshold not composed'
 call rdsdor('rsroexp',.01d0,10d0,t);if(t/=1d0)error stop 'nonlinear runoff outside this source route'
 call rdsinr('swbotb',1,8,mode);if(mode/=6)error stop 'original zero-flux bottom required'
 call rdsinr('swredu',0,2,mode);if(mode/=1)error stop 'source Black required'
 call rdsinr('swmacro',0,1,mode);if(mode/=0)error stop 'no hidden macro removal'
 call rdsinr('swhea',0,2,mode);if(mode/=1)error stop 'source heat required'
 call rdsinr('swcalt',1,2,mode);if(mode/=2)error stop 'source numeric heat required'
 call rdsinr('swsolu',0,1,mode);if(mode/=1)error stop 'source solute required'
 call rdsinr('swdra',0,2,mode);if(mode/=1)error stop 'source drainage required'
 call rdsinr('swsnow',0,1,mode);if(mode/=0)error stop 'snow coupling unavailable'
 call rdsinr('swfrost',0,1,mode);if(mode/=0)error stop 'frost coupling unavailable'
 call rdsdor('lat',-90d0,90d0,site%latitude_degrees)
 call rdsdor('alt',-400d0,3000d0,site%altitude_m)
 call rdsdor('altw',.1d0,99d0,site%wind_measurement_height_m)
 call rdsdor('alth',.1d0,99d0,site%humidity_measurement_height_m)
 call rdsdor('angstroma',0d0,1d0,site%angstrom_a)
 call rdsdor('angstromb',0d0,1d0,site%angstrom_b)
 call rdsdor('fwind',.5d0,5d0,site%wind_function_factor)
 call rdsdor('rsoil',0d0,1000d0,site%soil_surface_resistance_s_m)
 call rdsdor('pondmx',0d0,1000d0,pondmx);call rdsdor('rsro',.001d0,1d0,rsro)
 call rdsdor('cofredbl',0d0,1d0,cofred);call rdsdor('rsigni',0d0,1d0,rsigni)
 call rdsdor('rds',1d0,5000d0,rds)
 call rdsinr('swirfix',0,1,swfixed)
 if(swfixed==1)then
  call rdsinr('swirgfil',0,1,mode);if(mode/=0)error stop 'external irrigation file unavailable'
  call rdatim('irdate',irdate,1000,nir)
  call rdfdor('irdepth',0d0,1000d0,irdepth,1000,nir)
  call rdfdor('irrate',.000001d0,100d0,irrate,1000,nir)
  call rdfdor('irconc',0d0,1000d0,irconc,1000,nir)
  call rdfinr('irtype',0,2,irtype,1000,nir)
  irstart(:nir)=irdate(:nir)-first;irend(:nir)=irstart(:nir)+irdepth(:nir)/irrate(:nir)/24d0
  do i=1,nir
   if(irend(i)>0d0.and.irstart(i)<days.and.irtype(i)/=1)error stop 'prefix contains unsupported irrigation type'
   if(i>1)then
    if(irstart(i)<irend(i-1))error stop 'overlapping original irrigation'
   end if
  end do
 end if
 close(74)
 call rdinit(74,0,trim(dra));call rdsinr('dramet',1,3,mode)
 if(mode/=2)error stop 'original Hooghoudt drainage required'
 call rdsinr('ipos',1,5,mode);if(mode/=2)error stop 'original IPOS2 required'
 call rdsdor('lm2',1d0,1000d0,spacing);call rdsdor('shape',0d0,1d0,shape)
 call rdsdor('wetper',0d0,1000d0,wetper);call rdsdor('zbotdr',-1000d0,0d0,dbot)
 call rdsdor('entres',0d0,1000d0,entres);call rdsdor('basegw',-1d4,0d0,base)
 call rdsdor('khtop',0d0,1000d0,kh);close(74)
 call rdinit(74,0,trim(met));call rdinne('yyyy',n)
 if(n<days.or.n>10000)error stop 'weather capacity'
 call rdfint('dd',dd,10000,n);call rdfint('mm',mm,10000,n);call rdfint('yyyy',yyyy,10000,n)
 call rdfdor('rad',0d0,1d6,rad,10000,n);call rdfdor('tmin',-50d0,60d0,tmn,10000,n)
 call rdfdor('tmax',-50d0,60d0,tmx,10000,n);call rdfdor('hum',0d0,20d0,hum,10000,n)
 call rdfdor('wind',0d0,100d0,wind,10000,n);call rdfdor('rain',0d0,1000d0,rain,10000,n);close(74)
 k=0
 do i=1,n
  dates=0;dates(1:3)=[yyyy(i),mm(i),dd(i)];call dtardp(dates,0.,t)
  if(t<first.or.t>=first+days)cycle
  if(t/=first+k)error stop 'source weather not consecutive'
  dates(2:3)=[1,1];call dtardp(dates,0.,jan1)
  weather%day_of_year=nint(t-jan1)+1
  weather%radiation_j_m2_d=1000d0*rad(i)
  weather%minimum_air_temperature_c=tmn(i);weather%maximum_air_temperature_c=tmx(i)
  weather%vapour_pressure_kpa=hum(i);weather%wind_speed_m_s=wind(i)
  weather%gross_rain_cm_d=.1d0*rain(i)
  call evaluate_pmdirect_swetr0_daily(weather,site,canopy,result,diagnostic)
  if(diagnostic%status/=PMDIRECT_SWETR0_OK)error stop 'original bare PM rejected'
  k=k+1;soil(k)=result%potential_soil_evaporation_cm_per_day;pond(k)=result%potential_pond_evaporation_cm_per_day
  air(k)=.5d0*(tmn(i)+tmx(i));amount(k)=weather%gross_rain_cm_d
 end do
 if(k/=days)error stop 'weather prefix unavailable'
 source_soil=soil;source_pond=pond;source_air=air;source_rain=amount
 nwindows=0;t=0d0;irrigation_c=0d0
 do while(t<days)
  edge=min(real(days,real64),real(floor(t)+1,real64))
  do i=1,nir
   if(irstart(i)>t)edge=min(edge,irstart(i))
   if(irend(i)>t)edge=min(edge,irend(i))
  end do
  if(edge<=t.or.nwindows==2048)error stop 'forcing event capacity/order'
  nwindows=nwindows+1;iday=floor(t)+1;ends(nwindows)=edge
  soil(nwindows)=source_soil(iday);pond(nwindows)=source_pond(iday)
  air(nwindows)=source_air(iday);amount(nwindows)=source_rain(iday);irrig(nwindows)=0d0
  do i=1,nir
   if(t>=irstart(i).and.t<irend(i))then
    irrig(nwindows)=irrate(i)*24d0*.1d0
    if(irrigation_c/=0d0.and.irrigation_c/=irconc(i))error stop 'varying original irrigation concentration'
    irrigation_c=irconc(i)
   end if
  end do
  t=edge
 end do
 days=nwindows
 open(newunit=u,file='input.nml',status='new',action='write')
 if(original_germination)then
  write(u,'(a)')'&column original_hupsel_germination=.true.,schema=2,nodes=0,fallow_only=.true.,source_bottom_mode=6,swp_water_bootstrap=.true.,'
 else
 write(u,'(a)')'&column schema=2,nodes=0,fallow_only=.true.,source_bottom_mode=6,swp_water_bootstrap=.true.,'
 end if
 write(u,'(a)')'swp_native_hydraulics=.true.,swp_heat_bootstrap=.true.,dynamic_temperature=.true.,'
 write(u,'(a)')'bottom_up_cm_day=0,temporal_tolerance=1d-4,retain_accepted_step_proposal=.true.,'// &
 'black_evaporation=.true.,native_drainage=.true.,drain_variant=2,'
 write(u,'(a,es25.16e3)')'black_cofred=',cofred
 write(u,'(a,es25.16e3)')'black_rsigni=',rsigni
 write(u,'(a,es25.16e3)')'pond_max_cm=',pondmx
 write(u,'(a,es25.16e3)')'runoff_resistance_day=',rsro
 write(u,'(a,es25.16e3)')'drain_spacing_m=',spacing
 write(u,'(a,es25.16e3)')'drain_bottom_cm=',dbot
 write(u,'(a,es25.16e3)')'drain_shape=',shape
 write(u,'(a,es25.16e3)')'drain_khtop=',kh
 write(u,'(a,es25.16e3)')'drain_entres=',entres
 write(u,'(a,es25.16e3)')'drain_base=',base
 write(u,'(a,es25.16e3)')'drain_wetper=',wetper
 ! Distribution requires one value per original node; adapter counts it via TTUTIL.
 call rdinit(74,0,trim(swp));call rdinne('ncomp',n);call rdfint('ncomp',dd,10000,n);j=sum(dd(:n));close(74)
 write(u,'(a)',advance='no')'drain_anisotropy='
 do i=1,j
  write(u,'(a)',advance='no')'1,'
 end do
 write(u,'(a)')' /'
 write(u,'(a,i0)')'&surface windows=',days
 write(u,'(a)',advance='no')'ends_day='
 do i=1,days
  write(u,'(es25.16e3,a)',advance='no')ends(i),','
 end do
 write(u,*)
 write(u,'(a,es25.16e3)')'irrigation_c=',irrigation_c
 call vector('irrigation_cm_day',irrig)
 call vector('rain_cm_day',amount);call vector('soil_evaporation_cm_day',soil)
 call vector('evaporation_cm_day',pond);call vector('air_temperature_c',air)
 write(u,'(a)')'/','&crop /','&rotation /'
 close(u)
 print '(a,i0)','ORIGINAL_PM_FALLOW_PREFIX_PREPARED=',days
contains
 subroutine vector(name,v)
  character(*),intent(in)::name
  real(real64),intent(in)::v(:)
  integer::i
  write(u,'(a)',advance='no')trim(name)//'='
  do i=1,days
   write(u,'(es25.16e3,a)',advance='no')v(i),','
  end do
  write(u,*)
 end subroutine
end program
