#!/usr/bin/env python3
"""Plot exact gridded initial model outputs and a separate local improvement map."""
import argparse
import csv
import json
from pathlib import Path

import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
from matplotlib.colors import ListedColormap,BoundaryNorm,TwoSlopeNorm


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('root',type=Path);p.add_argument('exports',type=Path)
    p.add_argument('refinement',type=Path);p.add_argument('output',type=Path)
    args=p.parse_args();args.output.parent.mkdir(parents=True,exist_ok=True)
    register=list(csv.DictReader((args.root/'cell_register.csv').open()))
    outputs={r['cell_id']:r for r in csv.DictReader((args.exports/'cell_period_balances.csv').open())}
    annual={r['cell_id']:r for r in csv.DictReader((args.exports/'cell_annual_balances.csv').open()) if r['year']=='2025'}
    local={r['cell_id']:r for r in csv.DictReader((args.refinement/'heath_refinement_register.csv').open())}
    version=json.loads((args.root/'model_version.json').read_text())['version'] if (args.root/'model_version.json').exists() else 'WORLDCOVER_REFERENCE'
    codes=[10,20,30,40,50,90] if any(r['dominant_land_class']=='20' for r in register) else [10,30,40,50,90]
    names={code:i for i,code in enumerate(codes)}
    layers=[np.full((64,64),np.nan) for _ in range(6)]
    complete=0
    for r in register:
        i,j=int(r['row'])-1,int(r['col'])-1;identity=r['cell_id'];out=outputs[identity]
        layers[0][i,j]=names[int(r['dominant_land_class'])]
        layers[1][i,j]=int('SOILGAP_NEAREST_GRID_IMPUTATION' in r['flags'])
        if out.get('net_bottom_outflow_mm'):
            layers[2][i,j]=float(out['net_bottom_outflow_mm']);layers[3][i,j]=float(out['TACT_mm']);complete+=1
        if identity in annual and float(annual[identity]['TPOT_mm'])>0:
            layers[4][i,j]=100*float(annual[identity]['TACT_mm'])/float(annual[identity]['TPOT_mm'])
        a=local[identity]
        layers[5][i,j]=2 if float(a['wet_heath_fraction_lower'])>=.5 else 1 if a['proposed_vegetation_refinement']=='NHI_HEATH_ANALOGUE' else 0
    extent=(min(float(r['xmin']) for r in register)/1000,max(float(r['xmax']) for r in register)/1000,
            min(float(r['ymin']) for r in register)/1000,max(float(r['ymax']) for r in register)/1000)
    plt.rcParams.update({'font.family':'DejaVu Sans','font.size':9,'axes.titlesize':11,'axes.labelsize':9})
    fig,axes=plt.subplots(2,3,figsize=(14,10.6),layout='constrained')
    titles=['a. Gemeenschappelijke landbedekkingsbasis','b. Bodemkaart: imputatie van ontbrekende lagen',
            'c. Netto afvoer via de onderrand','d. Actuele transpiratie',
            'e. Transpiratie in 2025, actueel / potentieel','f. Lokale verbeterlaag: gekarteerde heide']
    if 20 in codes:titles[0]='a. Modelvegetatie, met expliciete heidetoekenning'
    for ax,title in zip(axes.ravel(),titles):
        ax.set_title(title,loc='left',pad=9);ax.set_xlabel('UTM31N oost, km');ax.set_ylabel('UTM31N noord, km')
        ax.tick_params(labelsize=8)
    colors={10:'#36724b',20:'#b49acb',30:'#a7c764',40:'#e4c558',50:'#aaaaaa',90:'#69afbb'}
    palettes=[ListedColormap([colors[c] for c in codes]),
              ListedColormap(['#dbe7e9','#cb7541']),plt.get_cmap('RdBu'),plt.get_cmap('viridis'),
              plt.get_cmap('YlGn'),ListedColormap(['#eeeeeb','#b49acb','#648fbc'])]
    norms=[BoundaryNorm(np.arange(-.5,len(codes)),len(codes)),BoundaryNorm([-.5,.5,1.5],2),
           TwoSlopeNorm(vmin=min(-1,float(np.nanmin(layers[2]))),vcenter=0,vmax=max(1,float(np.nanmax(layers[2])))),
           None,None,BoundaryNorm([-.5,.5,1.5,2.5],3)]
    for k,(ax,data,cmap,norm) in enumerate(zip(axes.ravel(),layers,palettes,norms)):
        image=ax.imshow(data,origin='lower',extent=extent,interpolation='nearest',cmap=cmap,norm=norm,
                        **({'vmin':0,'vmax':100} if k==4 else {}))
        cb=fig.colorbar(image,ax=ax,orientation='horizontal',fraction=.045,pad=.09)
        cb.ax.tick_params(labelsize=8)
        if k==0:cb.set_ticks(range(len(codes)),labels=[{10:'Bos',20:'Heide',30:'Gras',40:'Landbouw',50:'Stedelijk',90:'Moeras'}[c] for c in codes])
        elif k==1:cb.set_ticks([0,1],labels=['Directe kaartwaarde','Nabijgelegen kaartwaarde'])
        elif k in (2,3):cb.set_label('mm over 1 januari 2024 t/m 1 oktober 2026')
        elif k==4:cb.set_label('% van native potentiële transpiratie')
        elif k==5:cb.set_ticks([0,1,2],labels=['Geen voorstel','Heide','Vochtige heide'])
    label={'WORLDCOVER_REFERENCE':'WorldCover-referentie','EUROPEAN_COMMON_HEATH':'Europese basis met CORINE-heide','EUROPEAN_PLUS_LOCAL_HEATH':'Europese basis met lokale heideverbetering'}[version]
    fig.suptitle(f'Kalmthoutse Heide | SWAP 4.3.1 op 250 meter | {label}\n{complete} van 4096 kolommen doorgerekend',fontsize=15)
    foot='De lokale heidekaart rechts onder is een verbeterlijst; de Europese basis gebruikt CORINE.' if version=='EUROPEAN_COMMON_HEATH' else 'De lokale heidekaart rechts onder is als positieve vegetatieverbetering toegepast.' if version=='EUROPEAN_PLUS_LOCAL_HEATH' else 'De lokale heidekaart rechts onder is een verbeterlijst en is niet in de referentie verwerkt.'
    fig.supxlabel('Europese bodem- en landbedekkingsbasis, ERA5 en expliciete priors. Mengcellen en stedelijke fracties zijn vereenvoudigd.\n'+foot,fontsize=9)
    fig.savefig(args.output,dpi=160,facecolor='white');plt.close(fig)
    print(json.dumps(dict(output=str(args.output),completed_columns=complete,full_grid_complete=complete==4096)))


if __name__=='__main__':main()
