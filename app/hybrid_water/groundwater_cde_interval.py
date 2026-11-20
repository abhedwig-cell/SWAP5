"""Compose existing daily-step CDE intervals and complete groundwater state."""
import hashlib
from pathlib import Path


def magic(project):
    from cde_interval_output import active_selection
    selected=active_selection(project)
    if selected is None or not selected.get('groundwater_cde_interval'):
        return None
    history=selected['swhyst']
    return b'S5GIC002' if history==0 else ('S5GIH'+f'{2*history-1:03d}').encode()


def validate_source(bundle,identity):
    output=identity['original_output']
    if (output.get('groundwater_cde_interval') is not True or
            output.get('native_codec') not in ('S5GIC001','S5GIH001','S5GIH003')):
        raise ValueError('Foreign groundwater CDE interval source domain')
    actual=(Path(bundle)/'original_cde_output_state.f90').read_bytes().replace(b'\r\n',b'\n')
    expected=Path(__file__).with_name('cde_interval_output_state.f90').read_bytes().replace(b'\r\n',b'\n')
    if actual!=expected:
        raise ValueError('Foreign actual groundwater CDE interval private-state provider')
    source=(Path(bundle)/'headcalc.f90').read_bytes().replace(b'\r\n',b'\n')
    expected=('a13d2e813001ff1d366cca902c8384a4347e00627a4996fb5ed5f7a612fde4f9'
              if identity.get('implicit_conductivity') else
              'becdfa41163769b4009f5ad596e85af5c4235edf1adde7ba8385e6e09f2c4beb')
    if hashlib.sha256(source).hexdigest()!=expected:
        raise ValueError('Foreign actual groundwater CDE interval parent HeadCalc provider')
