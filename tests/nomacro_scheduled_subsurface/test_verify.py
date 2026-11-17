import copy,importlib.util,json,unittest
from pathlib import Path
spec=importlib.util.spec_from_file_location('scheduled',Path(__file__).with_name('verify.py'));s=importlib.util.module_from_spec(spec);spec.loader.exec_module(s)
class Admission(unittest.TestCase):
    def test_s_actual_scheduled_subsurface_mass_native_and_chemical_refusals(self):
        load=lambda n:json.loads((s.ROOT/s.S_PROOF/(n+'.json')).read_text())
        values=[load(n) for n in ('QUALIFICATION','WINDOWS_NAMED','COMPOSITION_COMPARE','WINDOWS_ISOLATION')]
        values.append(dict(Windows=load('WINDOWS_PREFLIGHT'),**{'Ubuntu-point':load('UBUNTU_POINT_PREFLIGHT'),'Ubuntu-interval':load('UBUNTU_INTERVAL_PREFLIGHT')}))
        s.validate_s(*values);attacks=[]
        for field,value in [('runtime_source',s.R_RUNTIME),('complete_model_days',1096),('mass_guard_cm',1e-9),('maximum_water_residual_cm',float('nan')),('maximum_water_residual_cm',-1),('physical_equations_changed',True),('new_persistent_codec',True),('whole_scientific_equivalence','PASS'),('functional_completion','NOMACRO_FUNCTIONAL_COMPLETE'),('chemical_subsurface','ENABLED')]:
            bad=copy.deepcopy(values);bad[0][field]=value;attacks.append(bad)
        for edit in ('mass','negative','native','year','short','active','external','source','solute','point','opt'):
            bad=copy.deepcopy(values);report=bad[0]['platforms']['Ubuntu']['interval'];r=report['profiles']['O2']
            if edit=='mass':r['budgets']['max_water_cm']=1.00001e-10
            elif edit=='negative':r['budgets']['max_kernel_cm']=-1
            elif edit=='native':r['own'][0]['exact_native']=False
            elif edit=='year':r['own'].pop()
            elif edit=='short':r['short']['own']['exact_native']=False
            elif edit=='active':r['subsurface_exposure']['days']=[]
            elif edit=='external':r['active_own']['active_external_disk_recovery']=False
            elif edit=='source':report['source_commit']=s.R_RUNTIME
            elif edit=='solute':report['inputs']['selectors']['SWSOLU']=1
            elif edit=='point':bad[0]['platforms']['Ubuntu'].pop('point')
            else:report['profiles'].pop('O0')
            attacks.append(bad)
        bad=copy.deepcopy(values);bad[1]['salt']['full_days']=100;attacks.append(bad)
        bad=copy.deepcopy(values);next(iter(bad[2]['profiles'].values()))['all_physical_rows_exact']=False;attacks.append(bad)
        bad=copy.deepcopy(values);bad[3]['profiles']['O2']['alternating_steps']=2;attacks.append(bad)
        bad=copy.deepcopy(values);bad[4]['Ubuntu-point']['checks'].pop(0);attacks.append(bad)
        for index,bad in enumerate(attacks):
            with self.subTest(attack=index),self.assertRaises(ValueError):s.validate_s(*bad)

    def test_current_pulse_composed_mass_native_and_chemical_refusals(self):
        load=lambda n:json.loads((s.ROOT/s.S_PROOF/(n+'.json')).read_text())
        values=[load(n) for n in ('PULSE_COMPOSED_QUALIFICATION','PULSE_COMPOSED_NAMED','PULSE_COMPOSED_COMPARE','PULSE_COMPOSED_ISOLATION')]
        values.append(dict(Windows=load('PULSE_COMPOSED_PREFLIGHT'),**{'Ubuntu-point':load('PULSE_COMPOSED_UBUNTU_POINT_PREFLIGHT'),'Ubuntu-interval':load('PULSE_COMPOSED_UBUNTU_INTERVAL_PREFLIGHT')}))
        s.validate_s(*values,runtime=s.COMPOSED_RUNTIME,ubuntu=s.COMPOSED_UBUNTU);attacks=[]
        for field,value in [('runtime_source',s.R_RUNTIME),('complete_model_days',1096),('mass_guard_cm',1e-9),('maximum_water_residual_cm',float('nan')),('maximum_water_residual_cm',-1),('physical_equations_changed',True),('new_persistent_codec',True),('whole_scientific_equivalence','PASS'),('functional_completion','NOMACRO_FUNCTIONAL_COMPLETE'),('chemical_subsurface','ENABLED')]:
            bad=copy.deepcopy(values);bad[0][field]=value;attacks.append(bad)
        for edit in ('mass','negative','native','year','short','active','external','source','solute','point','opt'):
            bad=copy.deepcopy(values);report=bad[0]['platforms']['Ubuntu']['interval'];r=report['profiles']['O2']
            if edit=='mass':r['budgets']['max_water_cm']=1.00001e-10
            elif edit=='negative':r['budgets']['max_kernel_cm']=-1
            elif edit=='native':r['own'][0]['exact_native']=False
            elif edit=='year':r['own'].pop()
            elif edit=='short':r['short']['own']['exact_native']=False
            elif edit=='active':r['subsurface_exposure']['days']=[]
            elif edit=='external':r['active_own']['active_external_disk_recovery']=False
            elif edit=='source':report['source_commit']=s.R_RUNTIME
            elif edit=='solute':report['inputs']['selectors']['SWSOLU']=1
            elif edit=='point':bad[0]['platforms']['Ubuntu'].pop('point')
            else:report['profiles'].pop('O0')
            attacks.append(bad)
        bad=copy.deepcopy(values);bad[1]['salt']['full_days']=100;attacks.append(bad)
        bad=copy.deepcopy(values);next(iter(bad[2]['profiles'].values()))['all_physical_rows_exact']=False;attacks.append(bad)
        bad=copy.deepcopy(values);bad[3]['profiles']['O2']['alternating_steps']=2;attacks.append(bad)
        bad=copy.deepcopy(values);bad[4]['Ubuntu-point']['checks'].pop(0);attacks.append(bad)
        for index,bad in enumerate(attacks):
            with self.subTest(attack=index),self.assertRaises(ValueError):s.validate_s(*bad,runtime=s.COMPOSED_RUNTIME,ubuntu=s.COMPOSED_UBUNTU)

if __name__=='__main__':unittest.main()
