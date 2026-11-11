"""Read-only complete hybrid water comparison against the sealed original B0 run.

Reference print precision bounds observation; it is not a new physical tolerance.
"""
import argparse,csv,hashlib,io,json,math,tarfile
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
p=argparse.ArgumentParser(description=__doc__);p.add_argument('--full',type=Path,required=True);p.add_argument('--output',type=Path,required=True)
a=p.parse_args();sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
archive=ROOT/'integration/dataqual15/GRASS_UNION_FULL_EVIDENCE.tar.xz'
manifest=json.loads(archive.with_name('GRASS_UNION_FULL_MANIFEST.json').read_text())
assert sha(archive)==manifest['evidence_sha256']
parse=lambda text:list(csv.DictReader(line for line in text.splitlines() if line.strip() and not line.startswith('*')))
with tarfile.open(archive) as source:b0=parse(source.extractfile('dq15-original-nodal-reference/original/result_output.csv').read().decode())[1:]
rows=[json.loads(line) for line in (a.full/'daily.jsonl').read_text().splitlines()]
printed=parse((a.full/'original/result_output.csv').read_text())[1:]
assert len(rows)==len(b0)==len(printed)==1827
maxima={};comparisons=[]
for original,current,row in zip(b0,printed,rows):
 assert row['committed'] and original['DATE']==current['DATE']
 flow=row['external_flux_cm']
 physical={'WTOT':math.fsum(row['stock_end_cm']),'DSTOR':math.fsum(row['stock_end_cm'])-math.fsum(row['stock_start_cm']),'RAIN':flow[0],'EIC':flow[7],'TACT':flow[9],'EACT':flow[11],'BOT':-row['bottom_outward_cm'],'GWL':row['groundwater_cm']}
 differences={k:v-float(original[k]) for k,v in physical.items()}
 for k,v in differences.items():maxima[k]=max(maxima.get(k,0),abs(v))
 comparisons.append({'day':row['day'],'date':original['DATE'],'hybrid_minus_B0_cm':differences})
common=['TPOT','TACT','TREDDRY','TREDWET','PHRVDM','HRVDM']
printed_max={k:max(abs(float(c[k])-float(o[k])) for c,o in zip(printed,b0)) for k in common}
day=187
result={'status':'COMPLETE_DESCRIPTIVE_REFERENCE_COMPARISON_NOT_WHOLE_SCIENCE','sealed_archive_sha256':sha(archive),'current_daily_sha256':sha(a.full/'daily.jsonl'),'days':1827,'maximum_absolute_water_difference_cm':maxima,'current_five_decimal_print_minus_B0_maxima':printed_max,'day188':{'date':b0[day]['DATE'],'unrounded_hybrid_actual_uptake_cm':rows[day]['external_flux_cm'][9],'B0_actual_uptake_cm':float(b0[day]['TACT']),'original_B0':{k:b0[day][k] for k in common},'current_legacy_print':{k:printed[day][k] for k in common},'water_differences_cm':comparisons[day]['hybrid_minus_B0_cm'],'judgment':'Original coherent donor retains the original water trajectory and printed oxygen/crop result at day188. Current oxygen is only five-decimal printed, so no unrounded oxygen equivalence claim. Native sixteen/four thermal trajectories and their failed original oxygen comparison are unchanged and not requalified by this route.'},'precision_note':'Differences against 12-decimal B0 water print and five-decimal current crop/oxygen print are descriptive, not relaxed model/scientific tolerances. Water acceptance remains1e-10cm. No native1e-5C, complete energy, whole-science or accuracy-matched runtime-parity claim.','daily_water_comparison':comparisons}
a.output.write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
print(json.dumps({k:v for k,v in result.items() if k not in ('daily_water_comparison',)}))
