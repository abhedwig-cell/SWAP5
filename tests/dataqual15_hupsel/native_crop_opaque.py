"""Private extension: embedded logicals and validation before branch evaluation."""
import native_crop_bool as scalar
SOURCE=scalar.SOURCE
VALID='''  logical function logical_bytes_valid(value)result(valid)
    use iso_fortran_env,only:int8
    logical,intent(in)::value
    integer(int8)::raw(storage_size(value)/8),yes(storage_size(value)/8),no(storage_size(value)/8)
    raw=transfer(value,raw);yes=transfer(.true.,yes);no=transfer(.false.,no)
    valid=all(raw==yes).or.all(raw==no)
  end function
'''

def candidate(original):
    source=scalar.candidate(original)
    marker='  subroutine weather_native_event('
    assert source.count(marker)==1;source=source.replace(marker,VALID+marker,1)
    for marker,field in (('    if(.not.clipped_schema)then','v%root_layer_reduction_clipped'),('    if(.not.reading.and..not.with_grass.and.v%grass_management_present)then','v%grass_management_present')):
        assert source.count(marker)==1
        source=source.replace(marker,'    if(.not.reading)then\n      if(.not.logical_bytes_valid('+field+'))then\n        io=1;return\n      end if\n    end if\n'+marker,1)
    # Intrinsic derived-type stream I/O writes components in declaration order,
    # without in-memory record padding. Preserve that order exactly.
    marker='''        read(u,iostat=io)v%evolution_continuation
      else
        write(u,iostat=io)v%evolution_continuation'''
    assert source.count(marker)==1
    source=source.replace(marker,'''      end if
      if(reading)then
        read(u,iostat=io)v%evolution_continuation%temperature_sum
      else
        write(u,iostat=io)v%evolution_continuation%temperature_sum
      end if
      if(io/=0)return
      call scalar_logical_io(u,reading,v%evolution_continuation%anthesis_reached,io)
      if(io/=0)return
      if(reading)then
        read(u,iostat=io)v%evolution_continuation%minimum_temperature_history_count, &
          v%evolution_continuation%minimum_temperature_history
      else
        write(u,iostat=io)v%evolution_continuation%minimum_temperature_history_count, &
          v%evolution_continuation%minimum_temperature_history''',1)
    marker='''    if(reading)then
      read(u,iostat=io)v%root_growth_carrier
    else
      write(u,iostat=io)v%root_growth_carrier
    end if'''
    assert source.count(marker)==1
    source=source.replace(marker,'''    if(reading)then
      read(u,iostat=io)v%root_growth_carrier%actual_gross_root_growth, &
        v%root_growth_carrier%potential_gross_root_growth
    else
      write(u,iostat=io)v%root_growth_carrier%actual_gross_root_growth, &
        v%root_growth_carrier%potential_gross_root_growth
    end if
    if(io/=0)return
    call scalar_logical_io(u,reading,v%root_growth_carrier%valid,io)''',1)
    assert source.count('call scalar_logical_io(')==34
    return source
