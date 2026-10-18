#!/usr/bin/env python3
"""Package incremental physical/source evidence, excluding full external toolkits."""
import argparse
import csv
import hashlib
import json
from pathlib import Path
import tarfile


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('root',type=Path)
    parser.add_argument('archive',type=Path)
    parser.add_argument('manifest',type=Path)
    args = parser.parse_args()
    root = args.root.resolve()
    data = root/'results'
    model = data/'wet_heath_scenarios'
    batch = json.loads((model/'batch_results.json').read_text())['runs']
    assert len(batch)==16 and all(r['native_success'] and r['reused'] for r in batch)
    assert all(r['water_balance']['physical_daily_states_checked']==1005 for r in batch)
    lai = json.loads((data/'modis_lai/lai_manifest.json').read_text())
    assert lai['items_collected']==lai['items_found']==109 and not lai['errors']
    terrain = json.loads((data/'terrain_points/terrain_manifest.json').read_text())
    assert terrain['status_counts']=={'OK':1217,'NO_DATA':0,'ERROR':0}
    nhi = data/'nhi_ecosystem_priors'
    source = json.loads((nhi/'nhi_source_manifest.json').read_text())
    files = [p for p in (data/'modis_lai').iterdir() if p.suffix in ['.json','.npz','.csv','.log']]
    files += [p for p in (data/'terrain_points').iterdir() if p.suffix in ['.json','.csv']]
    files += [nhi/'nhi_source_manifest.json'] + [nhi/r['path'] for r in source['selected_files']]
    files += [data/'symphonica_heath_replay.log',data/'symphonica_pipeline_status.json',data/'terrain_collection.log']
    files += [p for p in (model/'forcing').iterdir() if p.suffix in ['.met','.rain']]
    files += [model/'batch_results.json',model/'ensemble.log',model/'physical_audit.json']
    for r in batch:
        case = model/r['case']
        for name in r['output_sha256']:
            assert hashlib.sha256((case/name).read_bytes()).hexdigest()==r['output_sha256'][name]
        files += [p for p in case.iterdir() if p.suffix in ['.swp','.crp','.json','.csv','.log']]
    files += [p for p in (model/'failed_swrain3').iterdir() if p.is_file()]
    # Only public request metadata; no signing tokens or full third-party PDFs.
    files += [data/'source_probes'/p for p in ['dhmv_capabilities.xml','dhmv_describe.xml','dhmv_request.json',
                                              'dhmv_wms_capabilities.xml','dhmv_point_request.json','dhmv_point_sample.json']]
    args.archive.parent.mkdir(parents=True,exist_ok=True)
    entries = []
    with tarfile.open(args.archive,'w:xz') as archive:
        for path in sorted(set(files)):
            raw = path.read_bytes()
            name = str(path.relative_to(root))
            entries.append({'path':name,'bytes':len(raw),'sha256':hashlib.sha256(raw).hexdigest()})
            archive.add(path,arcname=name,recursive=False)
    summary = {'model':'SWAP4.3.1','new_complete_ecotope_scenarios':16,'revalidated_existing_soil_scenarios':42,
               'run_period':['2024-01-01','2026-10-01'],'hourly_records':24120,'precipitation_mm':2216.6,
               'native_wall_seconds_total':sum(r['wall_seconds'] for r in batch),
               'native_wall_seconds_range':[min(r['wall_seconds'] for r in batch),max(r['wall_seconds'] for r in batch)],
               'max_native_daily_balance_mm':10*max(r['water_balance']['max_daily_native_baldev'] for r in batch),
               'max_absolute_period_printed_closure_mm':10*max(abs(r['water_balance']['period_closure']) for r in batch),
               'physical_daily_states_checked':16080,'lai_items':109,'lai_cell_records':109*1024,
               'lai_quality_counts':lai['counts'],'terrain_points':1217,'terrain_cells':1024,
               'filter_terrain_head_comparisons':terrain['filter_head_comparisons'],
               'current_heath_cells_qualified':0,'canonical_admitted':False,
               'status':'EXECUTED_PROVISIONAL_ECOTOPE_SCENARIOS_WITH_EXPLICIT_PRIORS; NOT_VALIDATED_CELL_PREDICTIONS',
               'archive_bytes':args.archive.stat().st_size,'archive_sha256':hashlib.sha256(args.archive.read_bytes()).hexdigest()}
    manifest = {'summary':summary,'files':entries,
                'base_archive_sha256':['785b262bc94e723c4a53144fb4b5e4796a48835d501c8e0e01059ae726e7e748',
                                      '592611a32c0c0a771b56d33dff244119da54d3153244b6787ec37b160d43f776',
                                      '00ae585a99032af3197c0dde263113444de57b1986ea8d27565244bbe9f8f430']}
    args.manifest.parent.mkdir(parents=True,exist_ok=True)
    args.manifest.write_text(json.dumps(manifest,indent=2)+'\n')
    args.manifest.with_name('hourly_heath_summary.json').write_text(json.dumps(summary,indent=2)+'\n')
    with args.manifest.with_name('wet_heath_water_balances.csv').open('w') as handle:
        fields = ['case','root_cm','capacity_mm_per_lai','bottom_mode','wall_seconds','rain_mm','soil_evap_mm',
                  'transpiration_mm','native_interception_mm','pond_evap_mm','runoff_mm','bottom_in_mm',
                  'storage_change_mm','period_closure_mm']
        writer = csv.DictWriter(handle,fields)
        writer.writeheader()
        for r in batch:
            contract = json.loads((model/r['case']/'case_manifest.json').read_text())
            b = r['water_balance']
            t = b['totals']
            writer.writerow(dict(zip(fields,[r['case'],contract['root_depth_cm'],10*contract['canopy_capacity_cm_per_lai'],
                 contract['bottom_mode'],r['wall_seconds'],10*t['RAIN'],10*t['EACT'],10*t['TACT'],10*t['EIC'],
                 10*t['EPD'],10*t['RUNOFF'],10*t['BOT'],10*b['storage_change'],10*b['period_closure']])))
    print(json.dumps(summary))


if __name__=='__main__':
    main()
