from pathlib import Path
import datetime as dt,json,csv
import numpy as np
import pandas as pd
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import matplotlib.dates as mdates
from matplotlib.colors import ListedColormap,BoundaryNorm,TwoSlopeNorm
from matplotlib.patches import Patch

ROOT=Path(__file__).resolve().parents[1];F=ROOT/'figures';F.mkdir(exist_ok=True)
META=np.load(ROOT/'evidence/spatial_metadata.npz',allow_pickle=True);YEARS=(2024,2025,2026);A={y:np.load(ROOT/f'evidence/aggregates_{y}.npz') for y in YEARS};D={y:pd.to_datetime(A[y]['date']) for y in YEARS}
CODES=(10,20,30,40,50,90);NAMES=('Forest','Heath','Grass','Maize proxy','Urban surrogate','Wetland');COLORS=('#276444','#a34c9a','#78a445','#d4a331','#7a7a7a','#359ca3');CC=dict(zip(CODES,COLORS));CN=dict(zip(CODES,NAMES))
plt.rcParams.update({'font.family':'DejaVu Sans','font.size':9,'axes.titlesize':10,'axes.labelsize':9,'legend.fontsize':8,'axes.spines.top':False,'axes.spines.right':False,'figure.facecolor':'white','savefig.facecolor':'white','axes.grid':True,'grid.alpha':.18})
summary=json.loads((ROOT/'evidence/analysis_summary.json').read_text());annual=pd.read_csv(ROOT/'tables/annual_domain.csv');classes=pd.read_csv(ROOT/'tables/annual_and_seasonal_classes.csv');weather=np.load(ROOT/'evidence/weather_daily.npz');air={};pos=0
for y in YEARS:n=len(D[y]);air[y]=weather['air_C'][pos:pos+n];pos+=n
extent=[592980/1000,608980/1000,5683020/1000,5699020/1000]
Z=-META['depth_cm'];ZLABEL=[f'{z:g} cm' for z in Z];leg=[Patch(color=c,label=f'{n} ({int((META["class"]==k).sum()):,})') for k,n,c in zip(CODES,NAMES,COLORS)]
def save(fig,name):fig.savefig(F/(name+'.png'),dpi=230,bbox_inches='tight');plt.close(fig)
def mapax(ax,v,**kw):
 im=ax.imshow(np.asarray(v).reshape(64,64),origin='lower',extent=extent,interpolation='nearest',**kw);ax.set_xlabel('Easting (km UTM 31N)');ax.set_ylabel('Northing (km)');ax.grid(False);return im
def roll(x,n=7):return pd.Series(x).rolling(n,center=True,min_periods=n).mean().to_numpy()
def timeaxis(ax):ax.xaxis.set_major_locator(mdates.MonthLocator(interval=3));ax.xaxis.set_major_formatter(mdates.DateFormatter('%b\n%Y'))
def monthaxis(ax):ax.set_xlim(1,366);ax.set_xticks([15,75,135,196,258,319],['Jan','Mar','May','Jul','Sep','Nov'])
# 01 Model routes and input limitations.
fig,axs=plt.subplots(1,2,figsize=(9,4.0),layout='constrained');mapped=np.searchsorted(CODES,META['class']);mapax(axs[0],mapped,cmap=ListedColormap(COLORS),vmin=-.5,vmax=5.5);axs[0].set_title('Vegetation and crop route');axs[0].legend(handles=leg,loc='lower left',fontsize=6.8,framealpha=.95)
flags=META['flags'].astype(str);quality=np.array([('IMPUT' in f) for f in flags],int)+2*(META['water_fraction']>.5)+4*(META['class']==50)
im=mapax(axs[1],quality,cmap=ListedColormap(['#edf0e8','#dd8d34','#4b93b9','#9367a8','#777777','#3f3f3f','#151515','#000000']),vmin=-.5,vmax=7.5);axs[1].set_title('Selected representation limitations');ql=['None of these flags','Soil imputation','Water fraction > 50%','Soil plus water > 50%','Urban surrogate','Urban plus soil imputation','Urban plus water > 50%','All three'];qc=['#edf0e8','#dd8d34','#4b93b9','#9367a8','#777777','#3f3f3f','#151515','#000000'];axs[1].legend(handles=[Patch(color=qc[i],label=ql[i]) for i in np.unique(quality)],loc='lower left',fontsize=6.5)
save(fig,'01_domain_and_model_routes')
# 02 Weather by month with partial October clearly excluded from overlays.
fig,axs=plt.subplots(2,1,figsize=(8,5.1),layout='constrained',sharex=True)
for y,c in zip(YEARS,('#4078a5','#c7633d','#46996c')):
 m=A[y]['month'];months=range(1,13) if y<2026 else range(1,10);axs[0].plot(list(months),[A[y]['P'][m==k].sum() for k in months],'-o',label=str(y),color=c);axs[1].plot(list(months),[air[y][m==k].mean() for k in months],'-o',label=str(y),color=c)
axs[0].set_ylabel('Rainfall (mm per month)');axs[0].legend(ncol=3);axs[1].set_ylabel('Mean air temperature (°C)');axs[1].set_xticks(range(1,13),['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec']);axs[0].set_title('Shared ERA5 forcing; October 2026 has only one day and is omitted here');save(fig,'02_monthly_weather')
# 03 Period water accounting.
fig,axs=plt.subplots(1,2,figsize=(9,4),layout='constrained')
for ax,table,title in [(axs[0],annual,'Available calendar periods'),(axs[1],pd.read_csv(ROOT/'tables/common_period_domain.csv'),'Same April to September window')]:
 x=np.arange(3);base=np.zeros(3)
 for key,c,label in [('T_mm','#3a9470','Transpiration'),('soil_E_mm','#d49b58','Soil evaporation'),('canopy_term_mm','#668db4','Canopy term')]:ax.bar(x-.18,table[key],.32,bottom=base,color=c,label=label);base+=table[key].to_numpy()
 ax.bar(x+.18,table['P_mm'],.32,color='#a7cce2',label='Rainfall');ax.plot(x,table['net_bottom_outflow_mm'],'s-',color='#8756a1',label='Net bottom outflow');ax.plot(x,table['storage_change_mm'],'v--',color='#444444',label='Storage change');ax.axhline(0,color='#444',lw=.7);ax.set_xticks(x,['2024','2025','2026*' if ax==axs[0] else '2026']);ax.set_ylabel('Water depth (mm)');ax.set_title(title)
axs[0].legend(fontsize=7,loc='upper right');save(fig,'03_period_water_balance')
# 04 Temporal ET components.
fig,axs=plt.subplots(3,1,figsize=(8,6),layout='constrained',sharey=True)
for ax,y in zip(axs,YEARS):
 ax.stackplot(D[y],roll(A[y]['Tact']),roll(A[y]['Esoil']),roll(A[y]['Eic']),colors=['#3a9470','#d49b58','#668db4'],labels=['Transpiration','Soil evaporation','Canopy term'],alpha=.9);ax.set_title(str(y));ax.set_ylabel('ET components (mm d⁻¹)');ax.set_ylim(0,6);ax.xaxis.set_major_locator(mdates.MonthLocator(interval=2));ax.xaxis.set_major_formatter(mdates.DateFormatter('%b'));ax.set_xlim(dt.date(y,1,1),dt.date(y,12,31))
axs[0].legend(loc='upper right',ncol=3,fontsize=7);save(fig,'04_evaporation_time_series')
# 05 ET by class smoothed, full time.
fig,axs=plt.subplots(2,1,figsize=(8,5.2),layout='constrained',sharex=True)
for code in CODES:
 dates=np.concatenate([D[y].to_numpy() for y in YEARS]);values=np.concatenate([A[y][f'ET_class{code}'] for y in YEARS]);axs[0].plot(dates,roll(values,14),color=CC[code],label=CN[code],lw=1.2)
axs[0].set_ylabel('14 day mean ET (mm d⁻¹)');axs[0].legend(ncol=3,fontsize=7)
p=np.concatenate([A[y]['P'] for y in YEARS]);et=np.concatenate([A[y]['ET']+A[y]['EPD'] for y in YEARS]);axs[1].plot(dates,np.cumsum(p-et),color='#3f6d9e');axs[1].axhline(0,color='#555',lw=.7);axs[1].set_ylabel('Cumulative P minus all evaporation\n(mm since 1 January 2024)');timeaxis(axs[1]);save(fig,'05_class_evaporation_and_input_difference')
# 06 ET maps matched seasons.
fig,axs=plt.subplots(2,3,figsize=(10,6.7),layout='constrained');v=[A[y]['ET_aprsep_cell'] for y in YEARS];lo=min(x.min() for x in v);hi=max(x.max() for x in v)
for ax,y,a in zip(axs[0],YEARS,v):im=mapax(ax,a,cmap='YlGnBu',vmin=lo,vmax=hi);ax.set_title(f'April to September {y}')
fig.colorbar(im,ax=list(axs[0]),shrink=.8,label='Requested ET (mm over 183 days)')
for ax,a,title in [(axs[1,0],v[1]-v[0],'2025 minus 2024'),(axs[1,1],v[2]-v[1],'2026 minus 2025')]:im=mapax(ax,a,cmap='RdBu',vmin=-500,vmax=500);ax.set_title(title)
fig.colorbar(im,ax=list(axs[1,:2]),shrink=.8,label='ET change (mm)');axs[1,2].axis('off');axs[1,2].text(.05,.8,'Equal seasonal windows\n\nEach pixel is a terrestrial soil column.\nWater and urban fractions are not\ncomplete landscape water balances.\n\nShared meteorology; spatial variation\ncomes from soils, vegetation and\nboundary assumptions.',va='top',fontsize=10);save(fig,'06_seasonal_ET_maps')
# 07 Component dependence on class for common period.
fig,axs=plt.subplots(1,3,figsize=(10,4.2),layout='constrained',sharey=True)
for ax,y in zip(axs,YEARS):
 table=classes[(classes.year==y)&(classes.period=='April to September')].set_index('class').loc[list(NAMES)];bottom=np.zeros(6)
 for key,c,label in [('T_mm','#3a9470','Transpiration'),('soil_E_mm','#d49b58','Soil evaporation'),('canopy_term_mm','#668db4','Canopy term')]:ax.bar(np.arange(6),table[key],bottom=bottom,color=c,label=label);bottom+=table[key].to_numpy()
 ax.set_xticks(np.arange(6),['Forest','Heath','Grass','Maize','Urban','Wetland'],rotation=60,ha='right');ax.set_title(str(y));ax.set_ylabel('April to September ET (mm)')
axs[0].legend(fontsize=6.5);save(fig,'07_class_ET_components')
# 08 Stress ratios: sum TACT / sum TPOT per month.
fig,axs=plt.subplots(3,1,figsize=(8,6.3),layout='constrained',sharex=True)
for ax,y in zip(axs,YEARS):
 months=np.unique(A[y]['month']);months=months[months<=9] if y==2026 else months;r=np.full((6,12),np.nan)
 for i,c in enumerate(CODES):
  for m in months:
   tm=A[y]['month']==m;den=A[y][f'TPOT_class{c}'][tm].sum();r[i,m-1]=A[y][f'TACT_class{c}'][tm].sum()/den if den>1e-6 else np.nan
 im=ax.imshow(r,aspect='auto',vmin=0,vmax=1,cmap='YlGnBu');ax.set_yticks(range(6),NAMES);ax.set_title(str(y));ax.grid(False)
axs[-1].set_xticks(range(12),['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec']);fig.colorbar(im,ax=list(axs),label='Sum actual / sum potential transpiration',shrink=.8);save(fig,'08_transpiration_ratios')
# 09 Five-depth water mass concentration.
fig,axs=plt.subplots(5,1,figsize=(8,7.5),layout='constrained',sharex=True)
for i,ax in enumerate(axs):
 x=np.concatenate([D[y].to_numpy() for y in YEARS]);mean=np.concatenate([A[y]['WC_mean'][:,i] for y in YEARS]);p10=np.concatenate([A[y]['WC_p10'][:,i] for y in YEARS]);p90=np.concatenate([A[y]['WC_p90'][:,i] for y in YEARS]);ax.fill_between(x,p10,p90,color='#b9d2df',label='Spatial P10 to P90');ax.plot(x,mean,color='#225f88',lw=1,label='Spatial mean');ax.set_ylim(0,650);ax.set_ylabel(f'{ZLABEL[i]}\n(kg m⁻³)');ax.axvline(dt.date(2025,1,1),color='#aaa',lw=.5);ax.axvline(dt.date(2026,1,1),color='#aaa',lw=.5)
axs[0].legend(loc='upper right',ncol=2,fontsize=7);timeaxis(axs[-1]);save(fig,'09_soil_moisture_depth_time')
# 10 Monthly depth patterns, categorical sampled centres.
fig,axs=plt.subplots(1,3,figsize=(10,3.6),layout='constrained',sharey=True)
for ax,y in zip(axs,YEARS):
 mat=np.full((5,12),np.nan);mat[:,:A[y]['WC_monthly'].shape[0]]=A[y]['WC_monthly'].T
 if y==2026:mat[:,9]=np.nan
 im=ax.imshow(mat,aspect='auto',cmap='YlGnBu',vmin=50,vmax=500);ax.set_title(str(y));ax.set_xticks([0,3,6,9],['Jan','Apr','Jul','Oct']);ax.set_yticks(range(5),ZLABEL);ax.grid(False)
fig.colorbar(im,ax=list(axs),label='Monthly mean water mass (kg m⁻³)',shrink=.9);save(fig,'10_moisture_month_depth')
# 11 Class dependence of depth profiles in winter and summer 2025.
fig,axs=plt.subplots(1,2,figsize=(8,4.8),layout='constrained',sharey=True)
for ax,lab,title in zip(axs,('JFM','JJA'),('January to March 2025','June to August 2025')):
 for i,c in enumerate(CODES):ax.plot(A[2025]['WC_'+lab+'_class'][i],Z,'o-',color=CC[c],label=CN[c],lw=1,ms=3)
 ax.set_title(title);ax.set_xlabel('Water mass per soil volume (kg m⁻³)');ax.set_ylim(175,0);ax.set_xlim(0,600)
axs[0].set_ylabel('Actual centre depth below surface (cm)');axs[1].legend(loc='lower right',fontsize=7);save(fig,'11_class_depth_profiles')
# 12 Soil states on common date of lowest domain shallow moisture in 2025.
fig,axs=plt.subplots(1,3,figsize=(10,3.5),layout='constrained')
for ax,i in zip(axs,(0,3,4)):
 im=mapax(ax,A[2025]['WC_drydate_cell'][:,i],cmap='YlGnBu',vmin=0,vmax=600);ax.set_title(ZLABEL[i])
fig.colorbar(im,ax=list(axs),label='Water mass per soil volume (kg m⁻³)',shrink=.9);fig.suptitle('2025 lowest domain shallow-moisture date: '+str(A[2025]['drydate']),fontsize=11);save(fig,'12_dry_date_spatial_moisture')
# 13 Heat time series with meteorological input distinguished.
fig,axs=plt.subplots(3,1,figsize=(8,6.5),layout='constrained',sharey=True)
for ax,y in zip(axs,YEARS):
 ax.plot(D[y],roll(air[y]),color='#888',lw=.7,alpha=.7,label='Air, daily mean')
 for i,c in enumerate(plt.cm.plasma(np.linspace(.1,.85,5))):ax.plot(D[y],A[y]['Tsoil_mean'][:,i],color=c,label=ZLABEL[i],lw=1)
 ax.set_title(str(y));ax.set_ylabel('Temperature (°C)');ax.set_xlim(dt.date(y,1,1),dt.date(y,12,31));ax.xaxis.set_major_locator(mdates.MonthLocator(interval=2));ax.xaxis.set_major_formatter(mdates.DateFormatter('%b'))
axs[0].legend(ncol=3,fontsize=7,loc='upper right');save(fig,'13_soil_temperature_time')
# 14 Monthly temperature depth pattern and annual amplitude.
fig,axs=plt.subplots(1,2,figsize=(8,4.5),layout='constrained')
for y,c in zip((2024,2025),('#4078a5','#c7633d')):
 means=A[y]['Tsoil_mean'];axs[0].plot(np.ptp(means,axis=0),Z,'o-',label=str(y),color=c);axs[1].plot(means.mean(axis=0),Z,'o-',label=str(y),color=c)
axs[0].set_xlabel('Annual max minus min of spatial mean (°C)');axs[1].set_xlabel('Annual mean soil temperature (°C)');axs[0].set_ylabel('Actual centre depth (cm)');axs[0].invert_yaxis();axs[1].invert_yaxis();axs[0].legend();axs[1].legend();save(fig,'14_temperature_depth_amplitude')
# 15 GPP 24h averages by crop and year.
fig,axs=plt.subplots(2,1,figsize=(8,5.8),layout='constrained',sharex=True)
for ax,c in zip(axs,(30,40)):
 for y,col in zip(YEARS,('#4078a5','#c7633d','#46996c')):ax.plot(A[y]['doy'],roll(A[y][f'GPP_class{c}']),color=col,label=str(y),lw=1.2)
 ax.set_title(CN[c]);ax.set_ylabel('GPP (µmol CO₂ m⁻² s⁻¹)\n24 hour mean');monthaxis(ax);ax.set_ylim(bottom=0)
axs[0].legend(ncol=3);save(fig,'15_crop_GPP_time')
# 16 Coverage, seasonal GPP and transpiration.
fig,axs=plt.subplots(1,2,figsize=(9,4),layout='constrained');data=np.ma.masked_invalid(A[2025]['carbon_aprsep_cell']);cmap=plt.cm.viridis.copy();cmap.set_bad('#dddddd');im=mapax(axs[0],data,cmap=cmap);fig.colorbar(im,ax=axs[0],shrink=.8,label='April to September GPP (g C m⁻²)');axs[0].set_title('2025 model GPP; grey means not simulated')
coverage=np.isfinite(META['cf']).astype(int);from matplotlib.colors import to_rgb
coverage_rgb=np.array([to_rgb('#dddddd'),to_rgb('#44865c')])[coverage].reshape(64,64,3)
axs[1].imshow(coverage_rgb,origin='lower',extent=extent,interpolation='nearest');axs[1].set_xlabel('Easting (km UTM 31N)');axs[1].set_ylabel('Northing (km)');axs[1].grid(False);axs[1].set_title('GPP coverage: 1,305 of 4,096 cells');axs[1].legend(handles=[Patch(color='#44865c',label='Dynamic grass or maize'),Patch(color='#ddd',label='No assimilation model')],loc='lower left',fontsize=7);save(fig,'16_GPP_space_and_coverage')
# 17 Coupling, colour by crop, markers per year.
fig,axs=plt.subplots(1,2,figsize=(9,4),layout='constrained')
for year,marker in zip(YEARS,('o','^','s')):
 a=A[year]
 for c in (30,40):
  mask=META['class']==c;x=a['TACT_aprsep_cell'][mask]*10;y=a['carbon_aprsep_cell'][mask];axs[0].scatter(x,y,s=7,alpha=.25,color=CC[c],marker=marker,label=f'{CN[c]} {year}');axs[1].scatter(a['WC_aprsep_cell'][mask,0],y,s=7,alpha=.25,color=CC[c],marker=marker)
axs[0].set_xlabel('April to September transpiration (mm)');axs[0].set_ylabel('April to September GPP (g C m⁻²)');axs[1].set_xlabel('April to September shallow moisture (kg m⁻³)');axs[1].set_ylabel('April to September GPP (g C m⁻²)');axs[0].legend(fontsize=6.8);save(fig,'17_carbon_water_relations')
# 18 Accounting events with scale visible.
fig,axs=plt.subplots(2,1,figsize=(8,4.5),layout='constrained',sharex=True);dates=np.concatenate([D[y].to_numpy() for y in YEARS]);res=np.concatenate([A[y]['max_residual_mm'] for y in YEARS]);flags=np.concatenate([A[y]['canopy_flag_count'] for y in YEARS]);axs[0].plot(dates,res,color='#a94f40');axs[0].set_ylabel('Max absolute daily\nindependent residual (mm)');axs[1].vlines(dates[flags>0],0,flags[flags>0].astype(float),color='#777',lw=2);axs[1].scatter(dates[flags>0],flags[flags>0],color='#777',s=14);axs[1].set_ylabel('Flagged cells');timeaxis(axs[1]);save(fig,'18_accounting_flags')
# Additional numeric evidence for the text, with no inferred climatological ranks.
weather_rows=[];extremes=[];thermal=[];coupling=[]
for year in YEARS:
 a=A[year];apr=(a['month']>=4)&(a['month']<=9);weather_rows.append({'year':year,'available_days':len(D[year]),'air_mean_C':float(air[year].mean()),'April_September_air_C':float(air[year][apr].mean()),'April_September_radiation_MJ_m2':float(weather['radiation_MJ_m2'][sum(len(D[y]) for y in YEARS if y<year):sum(len(D[y]) for y in YEARS if y<=year)][apr].sum())})
 extremes.append({'year':year,'lowest_shallow_date':str(a['drydate']),'lowest_shallow_domain_kg_m3':float(a['WC_mean'][:,0].min()),'highest_shallow_domain_kg_m3':float(a['WC_mean'][:,0].max()),'lowest_deep_domain_kg_m3':float(a['WC_mean'][:,-1].min()),'ET_max_domain_mm_d':float(a['ET'].max()),'ET_max_date':str(a['date'][a['ET'].argmax()])})
 for i,z in enumerate(Z):
  means=a['Tsoil_mean'][:,i];thermal.append({'year':year,'days':len(means),'depth_cm':z,'temperature_mean_C':float(means.mean()),'temperature_range_of_spatial_mean_C':float(np.ptp(means)),'temperature_mean_min_C':float(means.min()),'temperature_mean_max_C':float(means.max()),'peak_date':str(a['date'][means.argmax()]),'WC_domain_temporal_range_kg_m3':float(np.ptp(a['WC_mean'][:,i]))})
 for c in (30,40):
  sel=META['class']==c;x=a['TACT_aprsep_cell'][sel]*10;y=a['carbon_aprsep_cell'][sel];valid=x>1;coupling.append({'year':year,'class':CN[c],'r_GPP_transpiration':float(np.corrcoef(x,y)[0,1]),'median_GPP_per_transpiration_gC_kgH2O':float(np.median(y[valid]/x[valid])),'p10':float(np.quantile(y[valid]/x[valid],.1)),'p90':float(np.quantile(y[valid]/x[valid],.9))})
for name,rows in [('weather_comparison',weather_rows),('extremes',extremes),('thermal_depth_metrics',thermal),('carbon_water_diagnostics',coupling)]:pd.DataFrame(rows).to_csv(ROOT/'tables'/f'{name}.csv',index=False)
print('FIGURES',len(list(F.glob('*.png'))))
