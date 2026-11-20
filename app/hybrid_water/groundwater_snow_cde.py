"""Existing Snow soil output projection with the actual groundwater reaction."""
import hashlib
from pathlib import Path


def magic(selected,clock):
    if not selected.get('groundwater_snow_cde_output') or selected['swsnow']!=1:
        raise ValueError('Foreign Snow groundwater output composition')
    history=selected['swhyst']
    return ('S5GS'+('C' if clock else 'I')+f'{0 if history==0 else 2*history-1:03d}').encode()


def metadata(selected):
    sha=lambda p:hashlib.sha256(p.read_bytes().replace(b'\r\n',b'\n')).hexdigest()
    result=dict(groundwater_snow_composition_sha256=sha(Path(__file__)),
                groundwater_snow_policy='existing-explicit-snow-groundwater-cde-composition-v1',
                groundwater_snow_new_physical_state=False)
    if selected.get('cde_clock_output'):
        result['groundwater_trial_provider_sha256']=sha(Path(__file__).with_name(
            'thermal_output_step.py' if selected['flprintdt'] else 'thermal_output_clock.py'))
        result['groundwater_snow_soil_trial_provider_sha256']=sha(Path(__file__).with_name('thermal_output_clock.py'))
    return result


def trial_source(original,watstor,selected):
    from thermal_output_step import soil_trial_source as step_trial
    from thermal_output_clock import soil_trial_source as clock_trial
    source=(step_trial if selected['flprintdt'] else clock_trial)(original,watstor)
    changes={
        'hybrid_snow_soil_trial_residual(candidate_bottom_cm_d)':
            'hybrid_groundwater_cde_clock_trial(candidate_bottom_cm_d,candidate_matrix_delta_cm)',
        'use variables,only:swbotb,nprintday':'use variables,only:swbotb,nprintday,thetm1',
        'real(8),intent(in)::candidate_bottom_cm_d':'real(8),intent(in)::candidate_bottom_cm_d,candidate_matrix_delta_cm',
        'swdra/=1.or.':'(swdra<0.or.swdra>1).or.',
        '(swbotb/=5.and.swbotb/=8)':'swbotb/=1',
        'projected_soil=sum(theta(1:numnod)*dz(1:numnod))':
            'projected_soil=sum(thetm1(1:numnod)*dz(1:numnod))+candidate_matrix_delta_cm',
    }
    for before,after in changes.items():
        if source.count(before)!=1:raise ValueError('Changed original Snow groundwater trial anchor: '+before)
        source=source.replace(before,after,1)
    anchor="if(.not.ieee_is_finite(candidate_bottom_cm_d))error stop 'Nonfinite original Snow trial boundary'"
    if source.count(anchor)!=1:raise ValueError('Changed original Snow groundwater trial validation')
    return source.replace(anchor,anchor+"\nif(.not.ieee_is_finite(candidate_matrix_delta_cm))error stop 'Nonfinite original Snow groundwater trial storage'",1)

