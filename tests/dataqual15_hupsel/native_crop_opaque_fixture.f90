program opaque_fixture
  use iso_fortran_env,only:int32
  use mod_wofost_crop_native_codec
  use mod_wofost_crop_owner_state,only:wofost_crop_owner_state_t
  use mod_fmr_wofost_crop_transaction,only:fmr_wofost_crop_transaction_persistence_t
  implicit none
  type(wofost_crop_owner_state_t)::owner
  type(fmr_wofost_crop_transaction_persistence_t)::view
  integer::u,io,j,mode,kind
  integer(int32)::bad(4)=[2,-1,256,2147483647]
  character(32)::argument
  call get_command_argument(1,argument)
  if(trim(argument)=='valid')then
    do j=0,1
      allocate(owner%evolution_continuation)
      owner%evolution_continuation%temperature_sum=12.5d0
      owner%evolution_continuation%anthesis_reached=j==1
      owner%evolution_continuation%minimum_temperature_history_count=3
      owner%evolution_continuation%minimum_temperature_history=7.25d0
      open(newunit=u,file='owner'//achar(48+j)//'.bin',access='stream',form='unformatted',status='replace')
      call weather_native_owner(u,.false.,owner,io);close(u)
      if(io/=0)stop 1
      deallocate(owner%evolution_continuation)
      view%root_growth_carrier%valid=j==1
      view%root_growth_carrier%actual_gross_root_growth=2.5d0
      view%root_growth_carrier%potential_gross_root_growth=3.5d0
      open(newunit=u,file='view'//achar(48+j)//'.bin',access='stream',form='unformatted',status='replace')
      call weather_native_crop_view(u,.false.,view,io,source_clipped_schema=.true.,grass_schema=.true.);close(u)
      if(io/=0)stop 2
    end do
  else if(trim(argument)=='invalid')then
    do kind=1,4
      do j=1,4
        if(kind==1)then
          allocate(owner%evolution_continuation)
          owner%evolution_continuation%anthesis_reached=transfer(bad(j),.true.)
        else if(kind==2)then
          view%root_growth_carrier%valid=transfer(bad(j),.true.)
        else if(kind==3)then
          view%grass_management_present=transfer(bad(j),.true.)
        else
          view%receipt%root_layer_reduction_clipped=transfer(bad(j),.true.)
        end if
        open(newunit=u,status='scratch',access='stream',form='unformatted')
        if(kind==1)then
          call weather_native_owner(u,.false.,owner,io)
          deallocate(owner%evolution_continuation)
        else if(kind==4)then
          call weather_native_event(u,.false.,view%receipt,io,source_clipped_schema=.false.)
        else
          call weather_native_crop_view(u,.false.,view,io,source_clipped_schema=.true.,grass_schema=.false.)
        end if
        close(u)
        if(io==0)stop 3
        view%root_growth_carrier%valid=.false.
        view%grass_management_present=.false.
        view%receipt%root_layer_reduction_clipped=.false.
      end do
    end do
  else if(trim(argument)=='read-owner'.or.trim(argument)=='read-view')then
    open(newunit=u,file='input.bin',access='stream',form='unformatted',status='old')
    if(trim(argument)=='read-owner')then
      call weather_native_owner(u,.true.,owner,io)
      inquire(unit=u,pos=mode)
      if(io==0.or.mode/=33)stop 5
    else
      call weather_native_crop_view(u,.true.,view,io,source_clipped_schema=.true.,grass_schema=.true.)
      inquire(unit=u,pos=mode)
      if(io==0.or.mode/=69)stop 6
    end if
    close(u)
  else
    stop 4
  end if
end program
