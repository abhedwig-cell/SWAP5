#!/usr/bin/env python3
"""Export complete native cell ledgers to CSV, GeoJSON and a simple GeoPackage."""
import argparse
import csv
import datetime as dt
import json
from pathlib import Path
import sqlite3
import struct

from pyproj import CRS
from shapely.geometry import shape

TERMS=('RAIN','IRRIG','SSDI','BOT','RUNON','RUNOFF','EACT','EPD','TACT','EIC','DRN','TPOT')


def write_csv(path,rows):
    with path.open('w',newline='') as handle:
        fields=list(dict.fromkeys(k for row in rows for k in row))
        w=csv.DictWriter(handle,fieldnames=fields);w.writeheader();w.writerows(rows)


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('root',type=Path);p.add_argument('output',type=Path)
    p.add_argument('--require-complete',action='store_true')
    args=p.parse_args();args.output.mkdir(parents=True,exist_ok=True)
    version=json.loads((args.root/'model_version.json').read_text())['version'] if (args.root/'model_version.json').exists() else 'WORLDCOVER_REFERENCE'
    grid=json.loads((args.root/'grid_250m.geojson').read_text());annual=[];summary=[]
    for feature in grid['features']:
        props=feature['properties'];identity=props['cell_id'];case=args.root/'cells'/identity
        path=case/'run_receipt.json';r=json.loads(path.read_text()) if path.exists() else {}
        record=dict(cell_id=identity,parent_500m=props['parent_500m'],worldcover_class=props['dominant_land_class'],
                    model_vegetation_class=props.get('model_vegetation_class',props['dominant_land_class']),
                    vegetation_source=props.get('vegetation_source','WorldCover broad class'),
                    water_fraction=props['water_fraction'],boundary=props['boundary'],status=r.get('status','NOT_RUN'))
        props.update(record)
        if r.get('status') not in ('SUCCESS','COMPLETED_WITH_YEAR_BOUNDARY_ACCOUNTING_FLAG'):
            assert not args.require_complete, (identity,r.get('status','NOT_RUN'))
            summary.append(record);continue
        contract=json.loads((case/'cell_manifest.json').read_text())
        assert r['input_sha256']==contract['input_sha256']
        with (case/'result_output.csv').open() as handle:
            rows=list(csv.DictReader(line for line in handle if not line.startswith('*')))
        assert len(rows)==1006
        required={'RAIN','IRRIG','SSDI','BOT','RUNOFF','EACT','EPD','WTOT','PD_VOL'}
        if contract['vegetation']['nhi_index'] is not None:required.update(('TACT','EIC','TPOT','IC_VOL'))
        assert required<=rows[0].keys(), (identity,'missing active output')
        def v(row,key):return float(row.get(key,0.))
        def storage(row):return sum(v(row,k) for k in ('WTOT','PD_VOL','IC_VOL'))
        for year in (2024,2025,2026):
            indices=[i for i,row in enumerate(rows) if i and row['DATE'].startswith(str(year))]
            assert len(indices)=={2024:366,2025:365,2026:274}[year]
            a=dict(cell_id=identity,year=year,days=len(indices),native_status=r['status'])
            a.update({key+'_mm':10*sum(v(rows[i],key) for i in indices) for key in TERMS})
            a['storage_change_mm']=10*(storage(rows[indices[-1]])-storage(rows[indices[0]-1]))
            a['printed_closure_mm']=sum(a[k+'_mm'] for k in TERMS[:5])-sum(a[k+'_mm'] for k in TERMS[5:11])-a['storage_change_mm']
            a['transpiration_shortfall_mm']=a['TPOT_mm']-a['TACT_mm'];annual.append(a)
        record.update({key+'_mm':10*sum(v(row,key) for row in rows[1:]) for key in TERMS})
        record.update(storage_change_mm=r['water_balance']['storage_change_mm'],
                      printed_closure_mm=r['water_balance']['period_printed_closure_mm'],
                      max_daily_native_baldev_mm=r['water_balance']['max_native_daily_baldev_mm'],
                      net_bottom_outflow_mm=-record['BOT_mm'],
                      transpiration_shortfall_mm=record['TPOT_mm']-record['TACT_mm'])
        summary.append(record)
        props.update(record)
    assert len(summary)==4096
    write_csv(args.output/'cell_period_balances.csv',summary)
    if annual:write_csv(args.output/'cell_annual_balances.csv',annual)
    (args.output/'baseline250_results.geojson').write_text(json.dumps(grid))
    gpkg=args.output/'baseline250_results.gpkg'
    if gpkg.exists():gpkg.unlink()
    with sqlite3.connect(gpkg) as db:
        db.executescript('''PRAGMA application_id=1196444487; PRAGMA user_version=10300;
CREATE TABLE gpkg_spatial_ref_sys(srs_name TEXT NOT NULL,srs_id INTEGER NOT NULL PRIMARY KEY,organization TEXT NOT NULL,organization_coordsys_id INTEGER NOT NULL,definition TEXT NOT NULL,description TEXT);
CREATE TABLE gpkg_contents(table_name TEXT NOT NULL PRIMARY KEY,data_type TEXT NOT NULL,identifier TEXT UNIQUE,description TEXT DEFAULT '',last_change DATETIME NOT NULL,min_x DOUBLE,min_y DOUBLE,max_x DOUBLE,max_y DOUBLE,srs_id INTEGER);
CREATE TABLE gpkg_geometry_columns(table_name TEXT NOT NULL,column_name TEXT NOT NULL,geometry_type_name TEXT NOT NULL,srs_id INTEGER NOT NULL,z TINYINT NOT NULL,m TINYINT NOT NULL,PRIMARY KEY(table_name,column_name));
CREATE TABLE cells(fid INTEGER PRIMARY KEY,geom BLOB NOT NULL,cell_id TEXT UNIQUE,landcover INTEGER,vegetation INTEGER,veg_source TEXT,status TEXT,bottom_out_mm REAL,transpiration_mm REAL,soil_evap_mm REAL,interception_term_mm REAL,runoff_mm REAL,storage_change_mm REAL,water_fraction REAL,flags TEXT);
''')
        db.executemany('INSERT INTO gpkg_spatial_ref_sys VALUES(?,?,?,?,?,?)',[
            ('Undefined Cartesian',-1,'NONE',-1,'undefined',''),('Undefined geographic',0,'NONE',0,'undefined',''),
            ('WGS84 UTM31N',32631,'EPSG',32631,CRS.from_epsg(32631).to_wkt(version='WKT1_GDAL'),'')])
        db.execute('INSERT INTO gpkg_geometry_columns VALUES(?,?,?,?,?,?)',('cells','geom','POLYGON',32631,0,0))
        db.execute('INSERT INTO gpkg_contents VALUES(?,?,?,?,?,?,?,?,?,?)',('cells','features','SWAP431 initial250m '+version,
            'Independent one-dimensional initial soil-column responses; water and impervious fractions remain explicit limitations.',
            '2026-10-18T00:00:00.000Z',592980.,5683020.,608980.,5699020.,32631))
        for f in grid['features']:
            r=f['properties'];geom=b'GP'+bytes([0,1])+struct.pack('<i',32631)+shape(f['geometry']).wkb
            db.execute('INSERT INTO cells(geom,cell_id,landcover,vegetation,veg_source,status,bottom_out_mm,transpiration_mm,soil_evap_mm,interception_term_mm,runoff_mm,storage_change_mm,water_fraction,flags) VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?,?)',
                (geom,r['cell_id'],r['dominant_land_class'],r.get('model_vegetation_class',r['dominant_land_class']),r.get('vegetation_source','WorldCover broad class'),r.get('status','NOT_RUN'),r.get('net_bottom_outflow_mm'),
                 r.get('TACT_mm'),r.get('EACT_mm'),r.get('EIC_mm'),r.get('RUNOFF_mm'),r.get('storage_change_mm'),r['water_fraction'],r['flags']))
        assert db.execute('PRAGMA integrity_check').fetchone()[0]=='ok'
        assert db.execute('SELECT count(*) FROM cells').fetchone()[0]==4096
    completed=[r for r in summary if 'RAIN_mm' in r]
    totals=dict(model_version=version,total_cells=4096,completed_cells=len(completed),full_period_days=1005,
                annual_records=len(annual),full_grid_complete=len(completed)==4096,
                native_year_boundary_flagged=sum(r['status']=='COMPLETED_WITH_YEAR_BOUNDARY_ACCOUNTING_FLAG' for r in summary),
                eic_contract='Native EIC includes annual canopy capacity loss, not pure interception evaporation.',
                spatial_contract='Column responses for dominant terrestrial cover;304 water-mixed cells and396 built-up soil surrogates are not complete water/urban models.',
                signed_bottom_flux='BOT positive into soil column; net_bottom_outflow=-BOT; not a validated groundwater recharge map.')
    (args.output/'result_export_receipt.json').write_text(json.dumps(totals,indent=2)+'\n');print(json.dumps(totals,indent=2))


if __name__=='__main__':main()
