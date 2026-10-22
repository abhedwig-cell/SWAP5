"""Compare actual warm/cold seasons and independently reconstruct gross closure."""
import argparse
import json
from pathlib import Path
from assess_perf01_weather import read, differences

ap=argparse.ArgumentParser(description=__doc__)
ap.add_argument('--cold',type=Path,required=True)
ap.add_argument('--warm',type=Path,required=True)
ap.add_argument('--output',type=Path,required=True)
args=ap.parse_args()
cold,a=read(args.cold);warm,b=read(args.warm)
assert cold['weather_sha256']==warm['weather_sha256']
assert cold['head_budget_cm']==warm['head_budget_cm']==.001
assert cold['totals']['rain_mm']==warm['totals']['rain_mm']
delta=differences(b,a)
assert cold['max_gross_daily_closure_mm']<1e-8 and warm['max_gross_daily_closure_mm']<1e-8
assert delta['storage_mm']['max_daily_abs']<=.01
assert abs(delta['runoff_mm']['total_difference'])<=.05
assert abs(delta['bottom_mm']['total_difference'])<=.05
for key in ['transpiration_mm','biomass','lai']:
    assert delta[key]['max_daily_abs']<1e-10,key
result={'status':'WARM_COLD_97DAY_PHYSICAL_SCREEN_PASS','cold':cold,'warm':warm,
        'warm_minus_cold':delta,
        'day84':{'cold':a[83],'warm':b[83]},
        'speed_ratio_cold_over_warm':cold['user_seconds']/warm['user_seconds'],
        'scope':'1e-3cm illustrative97day same forcing. Screening thresholds are separate from unchanged native acceptance gates; no new production tolerance.'}
args.output.write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps({'status':result['status'],'cold_cpu':cold['user_seconds'],'warm_cpu':warm['user_seconds'],
                  'warm_closure_mm':warm['max_gross_daily_closure_mm'],
                  'max_storage_difference_mm':delta['storage_mm']['max_daily_abs'],
                  'runoff_difference_mm':delta['runoff_mm']['total_difference'],
                  'bottom_difference_mm':delta['bottom_mm']['total_difference'],
                  'day84_cold_cpu':a[83]['core_cpu_s'],'day84_warm_cpu':b[83]['core_cpu_s']}))
