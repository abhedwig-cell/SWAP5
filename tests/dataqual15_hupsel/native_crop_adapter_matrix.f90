program matrix
 use mod_wofost_crop_native_codec
 use mod_fmr_wofost_crop_transaction,only:fmr_wofost_crop_transaction_persistence_t
 implicit none
 type(fmr_wofost_crop_transaction_persistence_t)::v
 integer::u,io,j,mode
 character(32)::name
 allocate(v%owner%evolution_continuation)
 v%owner%evolution_continuation%temperature_sum=2.5d0
 v%owner%evolution_continuation%minimum_temperature_history_count=2
 v%owner%evolution_continuation%minimum_temperature_history=8.25d0
 v%root_growth_carrier%actual_gross_root_growth=1.25d0
 v%root_growth_carrier%potential_gross_root_growth=2.25d0
 do j=0,1
  v%owner%evolution_continuation%anthesis_reached=j==1
  v%root_growth_carrier%valid=j==1
  do mode=0,3
   write(name,'("schema-",i0,"-",i0,".bin")')mode,j
   open(newunit=u,file=trim(name),access='stream',form='unformatted',status='replace')
   select case(mode)
   case(0)
    call weather_native_crop_view(u,.false.,v,io)
   case(1)
    call weather_native_crop_view(u,.false.,v,io,source_clipped_schema=.true.)
   case(2)
    call weather_native_crop_view(u,.false.,v,io,grass_schema=.true.)
   case(3)
    call weather_native_crop_view(u,.false.,v,io,source_clipped_schema=.true.,grass_schema=.true.)
   end select
   close(u)
   if(io/=0)stop 1
  end do
 end do
end program
