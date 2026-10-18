#!/usr/bin/env python3
"""Package source subsets, all cell decks, and completed native postimages."""
import argparse
import hashlib
import json
from pathlib import Path
import tarfile


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('root',type=Path);p.add_argument('previous_root',type=Path);p.add_argument('archive',type=Path)
    args=p.parse_args();args.archive.parent.mkdir(parents=True,exist_ok=True)
    files=[]
    for folder in ['model','heath_variant','model_european','model_local','local_refinement',
                   'exports_european','exports_local','sources/soilgrids','sources/corine','sources/bwk','native/source','native/ttutil']:
        files += [(f,str(f.relative_to(args.root))) for f in sorted((args.root/folder).rglob('*')) if f.is_file() or f.is_symlink()]
    files += [(f,str(f.relative_to(args.root))) for f in sorted((args.root/'sources/worldcover').glob('*')) if f.is_file()]
    files += [(f,f.name) for f in sorted(args.root.glob('*.json')) if f.is_file()]
    for name in ['native/gnu/swap_gnu','native/build_identity.json','reference_check/comparison.json','toolchain/receipt.json']:
        files.append((args.root/name,name))
    for name in ['SWAP.ZIP','TTUTIL.ZIP']:
        files.append((args.root/'distribution/SWAP_4.3.1/tools/SWAP/source'/name,'native/source_archives/'+name))
    for name in ['results/wet_heath_scenarios/forcing/hourly.met','results/wet_heath_scenarios/forcing/kalmthout.rain',
                 'results/wet_heath_scenarios/wetheath_a1_r50_ic05_bot6/swap.swp',
                 'export/weather.csv','results/weather_aligned.csv','results/era5_endpoint_20261002.json',
                 'results/nhi_ecosystem_priors/selected/Basisdata/msw_templates/fact_svat.inp',
                 'results/nhi_ecosystem_priors/nhi_source_manifest.json']:
        files.append((args.previous_root/name,'previous_root/'+name))
    selected=args.previous_root/'results/nhi_ecosystem_priors/selected'
    files += [(f,'previous_root/'+str(f.relative_to(args.previous_root))) for f in sorted(selected.rglob('*')) if f.is_file()]
    project=Path(__file__).resolve().parent.parent
    files.append((project/'domain.json','domain.json'))
    files.append((project/'align_existing_forcing.py','scripts/align_existing_forcing.py'))
    for name in ['collect_european_baseline.py','collect_worldcover_baseline.py','prepare_baseline250.py',
                 'run_baseline250.py','run_local_soil_scenarios.py','run_wet_heath_scenarios.py','build_gnu.py','requirements.txt',
                 'collect_corine_context.py','inventory_heath_refinement.py','prepare_heath_variant.py',
                 'assemble_heath_version.py','export_baseline250.py','plot_baseline250.py','finalize_baseline250.py','validate_baseline_gis.py','package_baseline250.py']:
        files.append((project/'swap431'/name,'scripts/'+name))
    files.append((project/'BASELINE250_20261018.md','BASELINE250_20261018.md'))
    files += [(f,'logs/'+f.name) for f in sorted(args.root.parent.glob('baseline250*.log')) if 'package' not in f.name]
    files=list({name:(f,name) for f,name in files}.values())
    def normalized(info):
        info.uid=info.gid=0;info.uname=info.gname='';info.mtime=0
        return info
    with tarfile.open(args.archive,'w:xz',preset=3) as tar:
        for f,name in files:tar.add(f,arcname=name,recursive=False,filter=normalized)
    receipt=dict(archive=args.archive.name,bytes=args.archive.stat().st_size,
                 sha256=hashlib.sha256(args.archive.read_bytes()).hexdigest(),entries=len(files),
                 execution_summary=json.loads((args.root/'model/execution_summary.json').read_text()),
                 input_audit=json.loads((args.root/'model/input_audit.json').read_text()),
                 restore='Extract into a fresh RUNROOT. Included scripts can prepare from sources and previous_root; native executable and original source closure are included. Relative per-cell forcing links are preserved.',
                 omitted_originals='Full WorldCover tile and NHI toolkit omitted; actual source identities and regional bytes retained.')
    args.archive.with_suffix('.manifest.json').write_text(json.dumps(receipt,indent=2)+'\n')
    print(json.dumps(receipt,indent=2))


if __name__=='__main__':main()
