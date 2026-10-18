import argparse
import ctypes as c, json
from pathlib import Path
import rasterio
libpath=next((Path(rasterio.__file__).parent.parent/'rasterio.libs').glob('*gdal*'))
g=c.CDLL(str(libpath));g.GDALAllRegister()
g.GDALOpenEx.argtypes=[c.c_char_p,c.c_uint,c.c_void_p,c.c_void_p,c.c_void_p];g.GDALOpenEx.restype=c.c_void_p
g.GDALDatasetGetLayer.argtypes=[c.c_void_p,c.c_int];g.GDALDatasetGetLayer.restype=c.c_void_p
g.OGR_L_GetFeatureCount.argtypes=[c.c_void_p,c.c_int];g.OGR_L_GetFeatureCount.restype=c.c_longlong
g.OGR_L_GetSpatialRef.argtypes=[c.c_void_p];g.OGR_L_GetSpatialRef.restype=c.c_void_p
g.OSRGetAuthorityCode.argtypes=[c.c_void_p,c.c_char_p];g.OSRGetAuthorityCode.restype=c.c_char_p
g.OGR_L_GetNextFeature.argtypes=[c.c_void_p];g.OGR_L_GetNextFeature.restype=c.c_void_p
g.OGR_F_GetGeometryRef.argtypes=[c.c_void_p];g.OGR_F_GetGeometryRef.restype=c.c_void_p
g.OGR_G_IsValid.argtypes=[c.c_void_p];g.OGR_G_IsValid.restype=c.c_int
g.OGR_G_Area.argtypes=[c.c_void_p];g.OGR_G_Area.restype=c.c_double
g.OGR_F_Destroy.argtypes=[c.c_void_p];g.GDALClose.argtypes=[c.c_void_p]
p=argparse.ArgumentParser();p.add_argument("root",type=Path);root=p.parse_args().root
results={}
for version in ['european','local']:
    p=root/('exports_'+version)/'baseline250_results.gpkg'
    ds=g.GDALOpenEx(str(p).encode(),4,None,None,None);assert ds,p
    layer=g.GDALDatasetGetLayer(ds,0);n=g.OGR_L_GetFeatureCount(layer,1);assert n==4096
    sr=g.OGR_L_GetSpatialRef(layer);assert g.OSRGetAuthorityCode(sr,None)==b'32631'
    checked=0
    while f:=g.OGR_L_GetNextFeature(layer):
        geom=g.OGR_F_GetGeometryRef(f);assert g.OGR_G_IsValid(geom)
        assert abs(g.OGR_G_Area(geom)-62500)<1e-6
        checked+=1;g.OGR_F_Destroy(f)
    assert checked==4096;g.GDALClose(ds)
    results[version]={'driver':'independent GDAL/OGR reader','features':n,'valid_polygon_areas_m2':62500,'epsg':32631,'status':'PASS'}
(root/'gis_validation.json').write_text(json.dumps(results,indent=2)+'\n');print(json.dumps(results))
