"""Private scalar native-logical codec candidate; no production admission."""
import re

SOURCE='src/adapter/mod_wofost_crop_native_codec.f90'
FIELDS=set('present_value valid root_layer_reduction_clipped deepest_root_oxygen_factor_available rootzone_drought_uptake_factor_available crop_emerged potential_shadow_present potential_shadow%active root_growth_carrier_present root_depth_present root_profile_present receipt_present lifecycle_present lifecycle%valid lifecycle%prepared lifecycle%sown lifecycle%germinated lifecycle%emerged lifecycle%harvested lifecycle%task2_initialized grass_management_present'.split())
HELPER='''  ! Preserve native stream bytes, but never evaluate a malformed logical.
  subroutine scalar_logical_io(u,reading,value,io)
    use iso_fortran_env,only:int8
    integer,intent(in)::u
    logical,intent(in)::reading
    logical,intent(inout)::value
    integer,intent(out)::io
    integer(int8)::raw(storage_size(value)/8),yes(storage_size(value)/8),no(storage_size(value)/8)
    io=0
    yes=transfer(.true.,yes);no=transfer(.false.,no)
    if(reading)then
      read(u,iostat=io)raw
      if(io/=0)return
    else
      raw=transfer(value,raw)
    end if
    if(.not.all(raw==yes).and..not.all(raw==no))then
      io=1;return
    end if
    if(reading)then
      value=all(raw==yes)
    else
      write(u,iostat=io)raw
    end if
  end subroutine
'''

def candidate(source):
    pattern=r'(?m)^( +)if\(reading\)then\n\1  read\(u,iostat=io\)([^\n]+)\n\1else\n\1  write\(u,iostat=io\)\2\n\1end if'
    changed=[]
    def replace(match):
        field=match[2];key=field.removeprefix('v%')
        if key not in FIELDS:return match[0]
        changed.append(key)
        return match[1]+'call scalar_logical_io(u,reading,'+field+',io)'
    result=re.sub(pattern,replace,source)
    assert set(changed)==FIELDS,(set(changed)^FIELDS)
    assert len(changed)==32,len(changed)
    assert result.count('\ncontains\n')==1
    return result.replace('\ncontains\n','\ncontains\n'+HELPER,1)
