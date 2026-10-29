program grass_solar_geometry_driver
 use iso_fortran_env,only:real64
 use MOD_meteo,only:astro,lat
 use atmosphere_interface,only:rad
 use mod_crop_solar_geometry
 implicit none
 type(crop_solar_geometry_t)::view
 real(real64)::first,last,t,jan1,radiation(10000),original(7),actual(7),error,maximum_error
 integer::n,i,count,dd(10000),mm(10000),yyyy(10000),date(6),code
 call rdinit(74,0,'input.swp');call rdsdor('lat',-90d0,90d0,lat)
 call rdstim('tstart',first);call rdstim('tend',last);close(74)
 call rdinit(74,0,'input.met');call rdinne('yyyy',n)
 if(n>10000)error stop 'weather capacity'
 call rdfint('dd',dd,10000,n);call rdfint('mm',mm,10000,n);call rdfint('yyyy',yyyy,10000,n)
 call rdfdor('rad',0d0,1d6,radiation,10000,n);close(74)
 count=0;maximum_error=0d0
 do i=1,n
  date=0;date(1:3)=[yyyy(i),mm(i),dd(i)];call dtardp(date,0.,t)
  if(t<first.or.t>last)cycle
  date(2:3)=[1,1];call dtardp(date,0.,jan1)
  rad=1000d0*radiation(i)
  call compare(nint(t-jan1)+1)
  count=count+1
 end do
 if(count/=1827)error stop 'original weather coverage'
 do i=1,5
  lat=real(i-3,real64)*45d0;rad=1d7
  call compare(1);call compare(182);call compare(366)
 end do
 call evaluate_crop_solar_geometry(0,52d0,1d7,view,code)
 if(code==CROP_SOLAR_OK)error stop 'invalid day'
 call evaluate_crop_solar_geometry(1,91d0,1d7,view,code)
 if(code==CROP_SOLAR_OK)error stop 'invalid latitude'
 call evaluate_crop_solar_geometry(1,52d0,-1d0,view,code)
 if(code==CROP_SOLAR_OK)error stop 'invalid radiation'
 write(*,*)'ORIGINAL_GRASS_SOLAR_GEOMETRY_PASS',count,15,maximum_error
contains
 subroutine compare(day)
  integer,intent(in)::day
  call evaluate_crop_solar_geometry(day,lat,rad,view,code)
  if(code/=CROP_SOLAR_OK)error stop 'source geometry rejected'
  call astro(day,original(1),original(2),original(3),original(4),original(5),original(6),original(7))
  actual=[view%atmospheric_transmission,view%daylength_hours,view%photoperiod_hours,view%sine_offset, &
   view%sine_amplitude,view%diffuse_perpendicular,view%effective_solar_height]
  error=maxval(abs(original-actual));maximum_error=max(maximum_error,error)
  if(error/=0d0)then
   print *,day,lat,original,actual
   error stop 'source geometry differential'
  end if
 end subroutine
end program
