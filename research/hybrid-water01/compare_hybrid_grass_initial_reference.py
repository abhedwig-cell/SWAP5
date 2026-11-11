"""Descriptive original-water comparison, using unrounded authoritative receipts."""
import argparse
import csv
import hashlib
import io
import json
import math
from pathlib import Path
import tarfile

ROOT=Path(__file__).resolve().parents[2]
p=argparse.ArgumentParser(description=__doc__);p.add_argument('--daily',type=Path,required=True);p.add_argument('--output',type=Path,required=True)
a=p.parse_args();sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
archive=ROOT/'integration/dataqual15/GRASS_UNION_FULL_EVIDENCE.tar.xz'
manifest=json.loads(archive.with_name('GRASS_UNION_FULL_MANIFEST.json').read_text())
assert sha(archive)==manifest['evidence_sha256']
with tarfile.open(archive) as source:
    text=source.extractfile('dq15-original-nodal-reference/original/result_output.csv').read().decode()
b0=list(csv.DictReader(line for line in io.StringIO(text) if line.strip() and not line.startswith('*')))[1:5]
rows=[json.loads(line) for line in a.daily.read_text().splitlines()]
assert [r['day'] for r in rows]==[1,2,3,4]
assert all(r['committed'] and len(r['pressure_head_cm'])==113 for r in rows)
comparison=[]
for original,row in zip(b0,rows):
    flow=row['external_flux_cm']
    physical={'WTOT':math.fsum(row['stock_end_cm']),
              'DSTOR':math.fsum(row['stock_end_cm'])-math.fsum(row['stock_start_cm']),
              'RAIN':flow[0],'EIC':flow[7],'TACT':flow[9],'EACT':flow[11],
              'BOT':-row['bottom_outward_cm'],'GWL':row['groundwater_cm']}
    comparison.append({'day':row['day'],'date':original['DATE'],
                       'prototype_minus_B0_cm':{k:v-float(original[k]) for k,v in physical.items()}})
result={'status':'DESCRIPTIVE_INITIAL_WATER_COMPARISON_NOT_WHOLE_SCIENCE',
        'sealed_archive_sha256':sha(archive),'prototype_daily_sha256':sha(a.daily),
        'days':comparison,'maximum_absolute_difference_cm':max(abs(x) for row in comparison for x in row['prototype_minus_B0_cm'].values()),
        'output_precision_note':'Use unrounded authoritative stock/flux receipts. LegacyCSV five-decimal text is not a new physical tolerance; reference printed precision limits this comparison.',
        'scope':'Eight water quantities, first4days only. No full project, crop/heat/native1e-5C, day188/day584 or whole-science acceptance.'}
a.output.write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8',newline='\n')
print(json.dumps({'status':result['status'],'maximum_absolute_difference_cm':result['maximum_absolute_difference_cm']}))
