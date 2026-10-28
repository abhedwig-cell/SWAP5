"""OA64 binary design: each two distinct nonzero GF(2)^6 columns cover four pairs."""
import itertools,json
from pathlib import Path
D=Path(__file__).resolve().parent
base=json.loads((D.parent/'dataqual01/scenarios.json').read_text());spec={k:base[k]for k in ['schema','source_directory','input_files']}
spec.update(timeout_seconds=15,slow_seconds_per_day=10,design='64 rows;12 distinct nonzero GF(2)^6 linear columns; every factor pair has all4 level pairs16 times. One historical project, transformed physical inputs; no arbitrary population percentage.',scenarios=[])
def replace(file,key,value):return dict(kind='replace',file=file,pattern=r'^(\s*'+key+r'\s*=\s*)[^!\n]+',replacement=r'\g<1>'+str(value)+' ',count=1)
def scale(file,header,column,factor,count):return dict(kind='scale_table',file=file,header=header,column=column,factor=factor,count=count)
axes={'gwl_cm':[-80.9,-110.],'pondmx_cm':[0.,.1],'rain_factor':[1.,4.],'ksat_factor':[.7,1.3],'alpha_factor':[.8,1.2],'lai_factor':[.75,1.25],'temperature_factor':[.8,1.2],'drain_resistance_day':[250.,1000.],'macro_surface_fraction':[.03,.05],'runoff_exponent':[.5,2.],'empirical_oxygen':[False,True],'root_depth_factor':[.8,1.2]}
columns=[1,2,4,8,16,32,3,5,9,17,33,6]
assert len(columns)==len(axes)and len(set(columns))==len(columns)
for row in range(64):
 factors={name:levels[(row&column).bit_count()%2]for column,(name,levels)in zip(columns,axes.items())}
 f=factors
 ops=[replace('swap.swp','GWLI',f['gwl_cm']),replace('swap.swp','PONDMX',f['pondmx_cm']),replace('swap.swp','RSROEXP',f['runoff_exponent']),replace('swap.swp','VLMPSTSS',f['macro_surface_fraction']),replace('swap.dra','DRARES1',f['drain_resistance_day']),scale('andelst_rain.998',r'^\s*Station\s+Day',5,f['rain_factor'],2098),scale('swap.swp',r'^\s*ORES\s+OSAT',5,f['ksat_factor'],8),scale('swap.swp',r'^\s*ORES\s+OSAT',2,f['alpha_factor'],8),scale('wintcer1.crp',r'^\s*LAITB\s*=',1,f['lai_factor'],12),scale('wintcer1.crp',r'^\s*RDTB\s*=',1,f['root_depth_factor'],4)]
 for col in [5,6]:ops.append(scale('andelst_meteo.998',r'^\s*Station\s+DD',col,f['temperature_factor'],365))
 if f['empirical_oxygen']:
  ops.extend([replace('wintcer1.crp','SWOXYGEN',1),dict(kind='replace',file='wintcer1.crp',pattern=r'^(\s*SWOXYGEN\s*=.*)$',replacement=r'\g<1>\n HLIM1=0.0\n HLIM2U=-100.0\n HLIM2L=-100.0',count=1)])
 spec['scenarios'].append(dict(id=f'oa64v2-{row:02d}',mode='experimental',days=2,source_surface_demand=True,perched_jacobian=True,factors=f,transformations=ops))
# Reproducible coverage no denominator beyond the explicit selected factor pairs.
coverage={a+'|'+b:sorted({(s['factors'][a],s['factors'][b])for s in spec['scenarios']})for a,b in itertools.combinations(axes,2)}
assert len(coverage)==66 and all(len(v)==4 for v in coverage.values())
unique={json.dumps(s['factors'],sort_keys=True)for s in spec['scenarios']}
assert len(unique)==64,'rank-deficient design repeats physical configurations'
assert all(sum((s['factors'][a],s['factors'][b])==pair for s in spec['scenarios'])==16 for a,b in itertools.combinations(axes,2)for pair in coverage[a+'|'+b])
(D/'scale64-v2.json').write_text(json.dumps(spec,indent=2)+'\n');(D/'design-v2.json').write_text(json.dumps(dict(configurations=64,unique_factor_rows=len(unique),columns=columns,factors=axes,factor_pairs=66,required_level_pairs=264,covered_level_pairs=sum(map(len,coverage.values())),pairs=coverage),indent=2)+'\n')

for scenario in spec["scenarios"]:scenario["stop_at_time"]=1.0539999999964493
(D/"wet-window64-v2.json").write_text(json.dumps(spec,indent=2)+"\n")
