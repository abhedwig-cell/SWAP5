"""Read-only exact source bridge for the composed groundwater CDE trial guard."""
import hashlib
from pathlib import Path

PARENT_HEAD='a13d2e813001ff1d366cca902c8384a4347e00627a4996fb5ed5f7a612fde4f9'
EXPLICIT_PARENT_HEAD='becdfa41163769b4009f5ad596e85af5c4235edf1adde7ba8385e6e09f2c4beb'
ADDITIONS=(
    b'   use MOD_integral,only:hybrid_groundwater_cde_clock_trial\n',
    b'   real(8)::hybrid_cde_clock_trial_guard,hybrid_cde_clock_candidate_bottom\n',
    b'\n         if(abs(hybrid_groundwater_cde_clock_trial(groundwater_bottom,groundwater_delta))>1d-10)flnonconv=.true.')


def validate(bundle,identity):
    output=identity['original_output']
    if (output.get('groundwater_cde_clock') is not True or output.get('cde_clock_output') is not True or
            output.get('native_codec') not in ('S5GCC001','S5GCH001','S5GCH003')):
        raise ValueError('Foreign groundwater CDE clock source domain')
    actual=(Path(bundle)/'original_cde_output_state.f90').read_bytes().replace(b'\r\n',b'\n')
    expected=Path(__file__).with_name('cde_interval_output_state.f90').read_bytes().replace(b'\r\n',b'\n')
    if actual!=expected:
        raise ValueError('Foreign actual groundwater CDE clock private-state provider')
    source=(Path(bundle)/'headcalc.f90').read_bytes().replace(b'\r\n',b'\n')
    for addition in ADDITIONS:
        if source.count(addition)!=1:
            raise ValueError('Foreign actual groundwater CDE clock HeadCalc provider')
        source=source.replace(addition,b'',1)
    expected=PARENT_HEAD if identity.get('implicit_conductivity') else EXPLICIT_PARENT_HEAD
    if hashlib.sha256(source).hexdigest()!=expected:
        raise ValueError('Foreign actual groundwater CDE clock parent HeadCalc provider')
