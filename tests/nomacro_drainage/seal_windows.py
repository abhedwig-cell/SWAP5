"""Neutral current drainage evidence seal; no scientific admission authority."""
import argparse,json,sys
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[1]/'nomacro_scheduled_subsurface'))
from weather_surface_seal import archive

def main():
 p=argparse.ArgumentParser()
 for k in ('evidence-root','work-root','output'):p.add_argument('--'+k,type=Path,required=True)
 a=p.parse_args();records={};ev,work,out=a.evidence_root,a.work_root,a.output
 for opt in ('O0','O2'):
  directories=[];builds=[]
  for case in ('water','automatic','fixed','prescribed'):
   version='v1' if case in ('water','automatic') else 'v2'
   root=ev/f'extended-drainage-{case}-{opt}-1096-conserved-atmosphere-full-{version}'
   result=json.loads((root/'RESULT.json').read_text());assert result['status']=='ACTUAL_EXTENDED_ORIGINAL_SOIL_SURFACE_COMBINED_NATIVE_PERIOD_PASS'
   directories.append((case,root));builds.append((case+'-build',Path(result['build_root'])))
   if case in ('water','automatic'):
    controls=ev/f'extended-drainage-{case}-{opt}-controls-conserved-atmosphere-v1'
    assert json.loads((controls/'RESULT.json').read_text())['status']=='ACTUAL_EXTENDED_NATIVE_PUBLIC_TRANSACTION_CONTROLS_PASS'
    directories.append((case+'-controls',controls))
  root=ev/f'extended-drainage-table-{opt}-37-conserved-atmosphere-short-v1';result=json.loads((root/'RESULT.json').read_text());assert result['status']=='ACTUAL_EXTENDED_ORIGINAL_SOIL_SURFACE_COMBINED_NATIVE_PERIOD_PASS'
  directories.append(('table',root));builds.append(('table-build',Path(result['build_root'])))
  for case in ('pulsed','hourly'):
   root=ev/f'extended-drainage-nonselected-{case}-{opt}-preservation-v1';assert (root/'PRESERVATION.json').is_file()
   directories.append(('nonselected-'+case,root));builds.append(('nonselected-'+case+'-build',work/f'extended-drainage-{opt}-v1/nonselected-preservation-v1/{case}'))
  root=ev/f'extended-drainage-nonselected-named-{opt}-v1';assert json.loads((root/'RESULT.json').read_text())['status']=='ACTUAL_NAMED_SHARED_TRANSPORT_PHYSICAL_COMPLETE_NATIVE_SEAM_PASS'
  directories.append(('named-seam',root));builds.append(('named-build',work/f'extended-drainage-{opt}-v1/nonselected-named-v1'))
  name='EXTENDED_DRAINAGE_WINDOWS_'+opt+'_RAW_ARCHIVE';records[name]=archive(out,name,directories,[],builds)
 name='EXTENDED_DRAINAGE_WINDOWS_SOURCE_RAW_ARCHIVE'
 records[name]=archive(out,name,[('source',ev/'extended-drainage-final-source-d057fcc08')],[('provider/PREPARED.json',Path('C:/Users/Veldh012/swap5-coverage-evidence/J_windows_provider/PREPARED.json'))])
 print(json.dumps({k:dict(bytes=v['bytes'],members=len(v['members']),sha256=v['sha256']) for k,v in records.items()},indent=2))

if __name__=='__main__':main()
