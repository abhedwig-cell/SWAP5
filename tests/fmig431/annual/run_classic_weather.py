#!/usr/bin/env python3
"""Existing real Richards/file-weather crop scenarios selected for classic IDSL0."""
import argparse,hashlib,json,os,subprocess,time
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
a=argparse.ArgumentParser();a.add_argument('--output',required=True);args=a.parse_args()
out=Path(args.output).resolve();out.mkdir(parents=True,exist_ok=False)
auth=out/'B111.b64';auth.write_bytes(subprocess.check_output(['git','show','988b46c3246e835b6f9bcd97b3f2714c56de30d2:integration/audits/evidence/SWAP431_B111_AUTHORITY.tar.gz.b64'],cwd=ROOT))
driver=(ROOT/'tests/fmig431/test_crop_file_weather_production.f90').read_text()
assert driver.count('scalar%development_daylength_mode = 1')==1
driver=driver.replace('scalar%development_daylength_mode = 1','scalar%development_daylength_mode = 0',1)
anchor='         owner%biomass%storage_biomass,owner%biomass%exponential_leaf_area_index, &'
assert driver.count(anchor)==1
driver=driver.replace(anchor,anchor+'''\n         owner%biomass%cumulative_dead_root_biomass,owner%biomass%cumulative_dead_stem_biomass, &
         owner%biomass%cumulative_dead_leaf_biomass, &''',1)
anchor='wo%biomass%root_biomass,wo%biomass%stem_biomass,wo%biomass%leaf_area_sum()]'
assert driver.count(anchor)==1
driver=driver.replace(anchor,'''wo%biomass%root_biomass,wo%biomass%stem_biomass,wo%biomass%leaf_area_sum(), &
             wo%biomass%cumulative_dead_root_biomass,wo%biomass%cumulative_dead_stem_biomass, &
             wo%biomass%cumulative_dead_leaf_biomass]''',1)
driver=driver.replace("      call ta%copy_committed_for_crop(1,ss,st);call require(st==FMR_APP_BOOT_OK,'rooted final accepted soil')", """      call require(wo%biomass%cumulative_dead_root_biomass>0.0_real64.and. &
           wo%biomass%cumulative_dead_stem_biomass>0.0_real64,'classic real-growth mortality active')
      call ta%copy_committed_for_crop(1,ss,st);call require(st==FMR_APP_BOOT_OK,'rooted final accepted soil')""",1)
(out/'driver.f90').write_text(driver)
s=(ROOT/'tests/fmig431/run_crop_file_weather_production.sh').read_text()
s=s.replace('ROOT="$(cd "$(dirname "$0")/../.." && pwd)"','ROOT="${ANNUAL_ROOT:?}"',1)
s=s.replace('BUILD="$(mktemp -d)"','BUILD="${ANNUAL_BUILD:?}"',1).replace('trap \'rm -rf "$BUILD"\' EXIT',"trap ':' EXIT",1)
s=s.replace("Path('integration/audits/evidence/SWAP431_B111_AUTHORITY.tar.gz.b64')",repr(str(auth)),1)
# Keep Path semantics when substituting the source archive locator.
s=s.replace(repr(str(auth))+'.read_bytes()', 'Path('+repr(str(auth))+').read_bytes()',1)
s=s.replace('"$ROOT/tests/fmig431/test_crop_file_weather_production.f90"','"$BUILD/driver.f90"',1)
(out/'run.sh').write_text(s);env=os.environ.copy();env.update(ANNUAL_ROOT=str(ROOT),ANNUAL_BUILD=str(out))
t=time.monotonic();r=subprocess.run(['bash',str(out/'run.sh')],cwd=ROOT,env=env,capture_output=True,text=True)
(out/'stdout').write_text(r.stdout);(out/'stderr').write_text(r.stderr)
result={'exit':r.returncode,'seconds':time.monotonic()-t,'scope':'All existing real Richards/weather neutral/dry/hydraulic continuous/restart assertions retained, IDSL0 selected. Complete-owner comparison and terminal bit vector include cumulative death; root/stem mortality must be positive. O0/O2, real accepted root uptake and joint opaque restart. No source table, solver, threshold or provider replacement.'}
(out/'result.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result));raise SystemExit(r.returncode)
