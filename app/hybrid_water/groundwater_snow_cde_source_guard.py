"""Read-only complete source identity for explicit Snow groundwater output."""
import hashlib
from pathlib import Path

def validate_source(bundle,identity):
    output=identity['original_output']
    if (output.get('groundwater_snow_cde_output') is not True or output.get('swsnow')!=1 or
            identity.get('implicit_conductivity') is not None or
            output.get('native_codec') not in ('S5GSC000','S5GSC001','S5GSC003','S5GSI000','S5GSI001','S5GSI003')):
        raise ValueError('Foreign explicit Snow groundwater CDE source domain')
    folder=Path(__file__).parent;bundle=Path(bundle)
    for actual,template in (('original_cde_output_state.f90','cde_interval_output_state.f90'),
                            ('thermal_output_snow_calendar_state.f90','cde_interval_snow_state.f90'),
                            ('original_output_thermal_domain.f90','original_output_thermal_domain.f90'),
                            ('groundwater_history_native_state.f90','groundwater_history_native_state.f90')):
        if (bundle/actual).read_bytes().replace(b'\r\n',b'\n')!=(folder/template).read_bytes().replace(b'\r\n',b'\n'):
            raise ValueError('Foreign actual Snow groundwater CDE native/private-state provider: '+actual)
    from groundwater_snow_clock import validate as validate_clock
    from groundwater_snow_retry import validate as validate_retry,inverse,head,time,HEAD_TEMPLATE,TIME_TEMPLATE
    validate_retry(bundle)
    validate_clock(inverse((bundle/'timecontrol.f90').read_text(encoding='cp1252'),time,TIME_TEMPLATE),output,output['original_output_epoch'])
    source=(bundle/'headcalc.f90').read_bytes().replace(b'\r\n',b'\n')
    source=inverse(source.decode('cp1252'),head,HEAD_TEMPLATE).encode('cp1252')
    if output.get('cde_clock_output'):
        from groundwater_cde_clock_source_guard import ADDITIONS
        for addition in ADDITIONS:
            if source.count(addition)!=1:raise ValueError('Foreign actual Snow groundwater CDE HeadCalc provider')
            source=source.replace(addition,b'',1)
    if hashlib.sha256(source).hexdigest()!='becdfa41163769b4009f5ad596e85af5c4235edf1adde7ba8385e6e09f2c4beb':
        raise ValueError('Foreign actual explicit Snow groundwater parent HeadCalc provider')
