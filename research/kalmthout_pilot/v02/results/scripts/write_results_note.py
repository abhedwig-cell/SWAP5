from pathlib import Path
import json
import pandas as pd
import numpy as np
R=Path(__file__).resolve().parents[1];parts=[]
def text(s):parts.append(s.strip()+'\n')
def table(headers,rows):
 def f(v):
  if v is None:return 'Not simulated'
  if isinstance(v,(float,np.floating)):
   if np.isnan(v):return 'Not simulated'
   return f'{v:,.1f}'
  return str(v)
 parts.append('| '+' | '.join(headers)+' |\n| '+' | '.join(['---']*len(headers))+' |\n'+'\n'.join('| '+' | '.join(f(v) for v in row)+' |' for row in rows)+'\n')
def fig(n,name,caption):text(f'![Figure {n}](figures/{name}.png)\n\nFigure {n}. {caption}')
a=pd.read_csv(R/'tables/annual_domain.csv');s=pd.read_csv(R/'tables/common_period_domain.csv');c=pd.read_csv(R/'tables/annual_and_seasonal_classes.csv');dep=pd.read_csv(R/'tables/depth_statistics.csv');w=pd.read_csv(R/'tables/weather_comparison.csv');thermal=pd.read_csv(R/'tables/thermal_depth_metrics.csv');summary=json.loads((R/'evidence/analysis_summary.json').read_text());validation=json.loads((R/'evidence/conversion_validation.json').read_text())
text('''# Kalmthoutse Heide SWAP results and SYMPHONICA products

Thematic analysis of the first provisional regional simulation

SYMPHONICA results note | V02 | 19 October 2026

## 1 Main results and their interpretation

The completed model produces a consistent set of daily water, soil moisture and temperature results for 4,096 independent soil columns over 1 January 2024 to 1 October 2026. The strongest contrast is between the relatively wet growing season of 2024 and the drier seasons that follow. For the common 183-day interval from 1 April to 30 September, rainfall is 605.7 mm in 2024, 256.5 mm in 2025 and 324.5 mm in 2026. Requested total evaporation, calculated as transpiration plus soil evaporation plus the native interception term, is 645.0, 370.4 and 443.5 mm respectively. These are averages of the model columns over the existing pilot grid.

The lower evaporation in 2025 occurs despite a warmer and brighter growing season than in 2024. Available soil water, vegetation demand and the imposed boundaries constrain the response. The strongest modelled transpiration limitation occurs in the forest class. The ratio of actual to potential forest transpiration over April to September changes from 0.539 in 2024 to 0.141 in 2025. This is a diagnostic of the specified model configuration. It is not a measured stress index or evidence that actual forests in the area experienced precisely this reduction.

Depth matters. Mean April to September shallow soil water concentration falls from 216.3 kg m⁻³ in 2024 to 125.9 kg m⁻³ in 2025, at the actual centre depth of 10.5 cm. At 162.5 cm, corresponding means are 226.2 and 194.5 kg m⁻³. Deeper states vary more slowly and retain a different seasonal history. Soil temperatures show the expected qualitative damping and delayed seasonal maximum with depth, although their absolute values remain sensitive to the thermal boundary and initial profile.

We can calculate a GPP-equivalent flux for the 802 grass and 503 maize-proxy columns. Those cover 31.86% of the model grid. Forest, heath, urban surrogates and wetlands have no assimilation model in this configuration. Their GPP remains missing. A spatial mean calculated only over the available crop cells would describe that subset, not ecosystem GPP for the full Kalmthoutse Heide domain.

This note accompanies the earlier technical construction note. It adds interpretation of the computed results and an executable conversion to candidate SYMPHONICA outputs. It also refines the earlier generic description of GASST: the native label alone does not capture the carbon-fraction correction applied in the SWAP 4.3.1 crop source. The conversion below accounts for that correction explicitly.

The results remain a technical exercise and a first provisional version. They have not been calibrated or independently validated against field observations. The workflow is intended to connect to the standard datasets being collected and made accessible within SYMPHONICA. The products supplied here implement the requested variable meanings and units, while the final project schema, approved sources and ingestion conventions still need agreement.

## 2 What is being averaged

The domain is the 16 km by 16 km minimal pilot extent, including the surroundings of the nature reserve. It contains a 64 by 64 grid of 250 m cells in EPSG:32631. Each cell has an area of 62,500 m² and contains a separate two-metre soil column. The columns do not exchange lateral groundwater or surface water. Their spatial variation comes from input and parameter differences, not from a coupled regional aquifer solution.

All cells use the same hourly ERA5 forcing at the representative extraction location. Regional totals in this note first average over equally sized cells and then sum daily interval quantities. Class totals follow the same operation within each class. They are water depths per modelled column area. The grid is not an exclusive mask of the reserve, and the model uses a dominant terrestrial response in mixed-cover cells. Open water and impervious urban surfaces do not receive complete separate hydrological models.
''')
table(['Model route','Cells','Grid area km²','GPP available'],[[name,n,n*.0625,'Yes' if name in ('Grass','Maize proxy') else 'No'] for name,n in summary['class_counts'].items()])
fig(1,'01_domain_and_model_routes','Vegetation assignments and selected representation limitations. Soil imputation affects 640 cells; 24 have more than 50% mapped water, and 396 use an urban pervious-soil surrogate. Combinations of these flags are shown separately. These maps describe the model representation and input provenance, not observation quality at every location.')
text('''Averages across these classes are descriptive. Forest and grass differ in soils, rooting, canopy parameters and sometimes their mapped setting. The comparisons are not controlled experiments that change vegetation alone. Wetland results use only three cells with an assumed shallow groundwater boundary; these cells must not be treated as a statistically representative sample of wetlands.

## 3 Variable definitions and conversion to SYMPHONICA

### 3 1 Evaporation in millimetres per day

The requested definition is ET = 10 × (TACT + EACT + EIC). TACT, EACT and EIC are native daily interval water depths in cm. Multiplication by 10 changes cm to mm. Because every interval is exactly one UTC day, the numeric daily depth in mm equals the mean rate in mm d⁻¹ for that interval. The calculation retains the native signs and accounting definitions.

EPD, evaporation from ponded water, is deliberately separate from that requested sum. The additional variable ET_including_pond equals ET + 10 × EPD. In this particular delivery the distinction is numerically negligible: the 2024 domain mean accumulated pond evaporation is approximately 0.0000007 mm and it is zero in the other two periods. Keeping it separate is still necessary for future configurations with meaningful ponding, lakes or surface storage.

EIC includes the native canopy accounting treatment at crop-calendar transitions. ET therefore inherits the known canopy-reset limitations. The converter preserves canopy_reset_flag and the independent balance residual. It does not remove small flagged discrepancies or relabel all interception accounting as pure measured canopy evaporation.

### 3 2 Soil moisture in kilograms per cubic metre

The requested soil moisture is the mass of water per bulk volume of soil. We calculate soil_moisture = 1,000 × WC, using a constant water density of 1,000 kg m⁻³. For example, WC = 0.25 m³ m⁻³ becomes 250 kg m⁻³. A temperature-dependent water density is not applied.

This is not gravimetric moisture in kg water per kg dry soil. No bulk-density multiplication is needed for the specified kg m⁻³ quantity. It is also not water storage in kg m⁻² or a layer-integrated root-zone moisture product. The five WC values are states at five actual compartment centres. Multiplying by water density does not change their spatial or temporal support.

### 3 3 GPP as a daily mean carbon dioxide flux

GASST is the crop model's gross assimilation output before maintenance respiration is subtracted. SWAP 4.3.1 first converts gross CO2 assimilation to its internal assimilate equivalent using PGASS = DTGA × 30 × (0.4 / CFRDM) / 44. It then applies the retained management and water-stress responses to obtain actual gross assimilation. The CSV GASST field reads the integrated IGASS accumulator, which is reset at output intervals. These relationships were checked in the executed version's wofost.f90, swap_csv_output.f90 and integral.f90 source.

CFRDM is 0.45 in the grass file and 0.40 in the maize file. To recover the carbon amount represented by GASST, we multiply by that carbon fraction. Using the model's nominal molar carbon mass of 12 g mol⁻¹ gives:

GPP = GASST × CFRDM × 1,000 / 12 / 10,000 × 1,000,000 / 86,400.

The steps convert kg of assimilate equivalent per hectare and day into grams of carbon, moles of carbon, area per square metre, micromoles and seconds. One mole of assimilated carbon corresponds to one mole of CO2. For 86,400-second intervals, the factors are 0.04340278 for grass and 0.03858025 for maize. Thus 100 native units give 4.3403 µmol CO2 m⁻² s⁻¹ for grass and 3.8580 for maize.

The grass factor is 12.5% higher than a universal CH2O-based factor using 30 g mol⁻¹. Put the other way around, that universal factor would underestimate the corrected grass flux by 11.1%. For maize, CFRDM=0.40 makes the familiar CH2O conversion equivalent. Applying one generic factor without inspecting CFRDM would lose this distinction.

The conversion retains the model's management factor, including RELMF=0.7 for grass and 1.0 for maize, and the actual stress effects. It does not reconstruct hypothetical assimilation before those reductions. We call the resulting quantity a model GPP equivalent because its biological assumptions remain those of the selected WOFOST configuration. It is not net primary production, harvested carbon, net ecosystem exchange or an independently measured carbon budget.

The result is a mean over the complete 24-hour interval, including night. It is not a midday or daylight-average photosynthesis rate. A daytime flux, hourly curve or diurnal amplitude cannot be recovered by changing units in daily GASST. Positive values denote uptake. Where the prescribed vegetation route does not calculate assimilation, GPP remains NaN. Existing no-active-dynamic-crop zeros retain their availability flag.

### 3 4 Temperature and time coordinates

Soil temperature is already in degrees Celsius and is copied unchanged. We do not subtract 273.15. WC and T are day-end states, whereas ET and GPP describe daily intervals. The input coordinate time is the upper daily bound: simulation_date=2025-01-01 therefore has time at 2025-01-02 00:00 UTC. The converter preserves simulation_date, time_bounds, the actual depth coordinate, cell identifiers and flags.
''')
table(['Requested product','Calculation','Unit and support'],[['ET','10 × (TACT + EACT + EIC)','mm d⁻¹, complete UTC-day mean'],['soil_moisture','1,000 × WC','kg m⁻³ of bulk soil, day-end state'],['GPP','GASST × CFRDM × 0.0964506173','µmol CO2 m⁻² s⁻¹, complete UTC-day mean'],['soil_temperature','T unchanged','°C, day-end state'],['ET_including_pond','ET + 10 × EPD','mm d⁻¹, additional diagnostic']])
text('''The NetCDF GPP unit attribute is encoded as umol m-2 s-1, with substance=CO2 stored separately. This avoids putting an unrecognised substance token into the physical unit string. The four required products have explicit long names, units, temporal methods, coordinates and provenance. File-level metadata identifies the mapping as a provisional candidate, rather than an approved SYMPHONICA schema. The converter verifies the pinned V02 source-file hashes before applying the mapping. A new model version requires a reviewed mapping rather than silent reuse of these constants. Future rotations with changing crops would need CFRDM to follow the active crop in time; the static cell values used here are valid for the repeated V02 crop assignments.

## 4 Three contrasting periods

Only 2024 and 2025 are complete calendar years. The 2026 file ends on 1 October and contains 274 days. Its available-period sum is not an annual total. To compare all three years, we use 1 April through 30 September, a complete 183-day window in each year. This also avoids a leap-day mismatch in seasonal totals. Full annual averages and sums are retained separately.
''')
table(['Year','Available days','Annual or available P mm','April to September P mm','April to September air °C','Season radiation MJ m⁻²'],[[int(row.year),int(row.days),row.P_mm,s.loc[i,'P_mm'],w.loc[i,'April_September_air_C'],w.loc[i,'April_September_radiation_MJ_m2']] for i,row in a.iterrows()])
fig(2,'02_monthly_weather','Monthly forcing separates the wet 2024 season from the dry spring and early summer of 2025. The April to September air-temperature means are 16.03, 16.76 and 17.33 °C. Partial October 2026 is omitted from these monthly overlays. All cells share this forcing, so the figure contains no spatial weather variation.')
text('''Within this short record, 2024 is the wetter and cooler growing-season case, 2025 is the driest growing-season case, and 2026 combines the warmest growing season with intermediate seasonal rainfall. These descriptions are comparisons among these three simulations. They are not climatological classifications such as a return-period drought, an exceptionally wet year relative to a 30-year normal or evidence of a long-term trend.

The seasonal rainfall decrease from 2024 to 2025 is 57.7%, whereas shortwave radiation increases by about 12.0%. Mean growing-season air temperature rises by 0.73 °C. Annual mean air temperatures for the two full years are both about 11.88 °C. That near equality illustrates why a complete-year temperature mean can conceal substantial seasonal differences relevant to water demand and plant growth.

The simulation has no prior spin-up. Its initial uniform pressure head is an imposed state rather than an observed equilibrium. Consequently, 2024 differs from subsequent years both in forcing and in proximity to initialisation. The following calculations show the actual model response, but they do not isolate a pure weather effect. A weather-only comparison would require controlled initial states or a qualified spin-up design.

## 5 Water use and storage over the whole grid
''')
table(['Year and window','P mm','ET mm','T mm','Soil E mm','Canopy mm','Bottom outflow mm','Native storage change mm'],[[str(int(r.year))+(' to 1 Oct' if r.year==2026 else ' full'),r.P_mm,r.ET_mm,r.T_mm,r.soil_E_mm,r.canopy_term_mm,r.net_bottom_outflow_mm,r.storage_change_mm] for _,r in a.iterrows()])
text('''The storage column is the sum of native DSTOR, not an independently reconstructed end-state difference. Bottom outflow equals -10 × BOT and is positive outward. The native BALDEV sums and independent canopy flags remain in the machine-readable tables. Rounded values in this printed table will not reproduce the tiny residuals of the unrounded native ledger.

In 2024 the model evaporates 823.2 mm and releases 455.5 mm through the bottom boundary against 1,070.9 mm rainfall. Native storage declines by 207.7 mm, supplying part of those losses. Evaporation plus bottom outflow can therefore exceed contemporaneous rainfall without violating the native period accounting. It does show how strongly the first-year interpretation depends on initial water storage. Calling the 455.5 mm a measured or validated recharge estimate would be unjustified.

In 2025 rainfall is 600.7 mm, evaporation 558.5 mm and net bottom outflow 116.4 mm. A further 74.2 mm native storage decline contributes to the balance. The 2026 available period has evaporation of 546.0 mm, nearly equal to its 545.0 mm rainfall, while approximately 59.2 mm bottom outflow is supplied together with a 60.2 mm storage decline. These are independent-column budgets under the imposed lower boundaries, not a coupled regional groundwater balance.
''')
fig(3,'03_period_water_balance','Evaporation components and precipitation are plotted alongside net bottom outflow and native storage change. The left panel contains complete 2024 and 2025 plus the partial 2026 period, marked with an asterisk. The right panel uses the same April to September window in all years. Lines and bars use a common water-depth axis; the displayed quantities should not all be added as independent losses.')
table(['Common season','P mm','ET mm','ET mm d⁻¹','Bottom outflow mm','Native storage change mm','T actual over potential'],[[int(r.year),r.P_mm,r.ET_mm,f'{r.ET_mean_mm_d:.3f}',r.net_bottom_outflow_mm,r.storage_change_mm,f'{r.T_ratio:.3f}'] for _,r in s.iterrows()])
text('''In the matched season, ET decreases by 42.6% from 2024 to 2025, then increases by 19.7% in 2026. Seasonal ET exceeds seasonal rainfall in every year: by 39.3 mm in 2024, 113.9 mm in 2025 and 119.0 mm in 2026. The excess is not itself the storage decline because bottom exchange, runoff and native balance terms also enter the budget. The complete period equations are provided in the CSV tables.

No surface runoff is produced anywhere in the delivered native daily fields. Artificial drainage and irrigation are disabled. Zero runoff is an output of these columns and boundary assumptions. It does not establish that the real domain has no runoff, ditch drainage or urban stormflow. The absent impervious and open-water processes are particularly relevant to that interpretation.

## 6 Evaporation through time and across vegetation
''')
fig(4,'04_evaporation_time_series','Seven-day centred means of the domain evaporation components. Smoothing is used only for display; all totals use unsmoothed daily quantities. The moist 2024 season supports a broader period of high transpiration, while 2025 has a smaller transpiration contribution and a larger relative role for rainfall-linked canopy evaporation. The blank end of 2026 is unavailable output, not zero evaporation.')
text('''The interception contribution is substantial. In the full 2024 period, it is 285.8 mm, around 34.7% of requested ET. For the same April to September period, the canopy share increases from 35.5% in 2024 to 38.1% in 2025 as transpiration decreases. That does not mean canopies become intrinsically more efficient interceptors in a dry year. The relative share also changes because another component declines. Its magnitude depends strongly on the prescribed forest canopy and interception settings.

Individual daily values can be higher than the smoothed curves suggest. The maximum domain mean requested ET is 8.00 mm d⁻¹ on 15 June 2024, 7.10 on 3 September 2025 and 6.88 on 2 June 2026. A rainfall-driven canopy term can produce an evaporation peak on a day that is not the hottest day. These peaks are model results and have not been checked against an independent energy or flux observation.
''')
fig(5,'05_class_evaporation_and_input_difference','Fourteen-day mean ET by class and the cumulative difference between rainfall and evaporation including pond evaporation. The lower curve is an input-output difference, not a groundwater storage series or a standard drought index. It omits lower-boundary exchange from the plotted difference; those fluxes must be included in a full water balance.')
text('''The three wetland columns maintain high evaporation in 2025 and 2026. Their groundwater assumption is a ready explanation within this model: they have access to an imposed shallow-head boundary. In the 2025 common season those columns receive 492.3 mm of net upward bottom exchange, compared with 256.5 mm rainfall, and evaporate 748.8 mm. The native storage change is only about +0.1 mm. Their response therefore depends strongly on imposed boundary supply and cannot be interpreted as evidence that natural wetlands are unaffected by drought. The contrast with freely draining forest columns demonstrates the combined effect of representation choices and boundary supply, not a controlled physiological comparison.
''')
fig(6,'06_seasonal_ET_maps','Requested total evaporation over the same 183-day season, with a common scale across the top maps. Difference maps use a common centred scale. The 2025 decrease is widespread and strongest in much of the forest-dominated region. The maps show assigned-column responses; the grid has neither lateral redistribution nor spatial meteorological variation.')
fig(7,'07_class_ET_components','Class mean seasonal ET separated into transpiration, soil evaporation and the native canopy term. Forest has the largest canopy contribution; heath has a large soil-evaporation share under its prescribed canopy. Wetland values are based on only three cells with a distinct groundwater assumption. Differences therefore combine vegetation, soils and boundary conditions.')
sub=c[c.period=='April to September']
table(['Year','Class','ET mm','T mm','Soil E mm','Canopy mm','T ratio'],[[int(r.year),r['class'],r.ET_mm,r.T_mm,r.soil_E_mm,r.canopy_term_mm,f'{r.T_ratio:.3f}'] for _,r in sub.iterrows()])
text('''Forest seasonal ET falls from 726.9 mm to 384.0 mm between 2024 and 2025, whereas the heath response falls from 498.8 to 350.8 mm. In 2025 forest transpiration is only 122.2 mm, compared with 212.7 mm in its canopy term. Heath transpiration changes less, from 130.1 to 113.9 mm, while its soil evaporation declines strongly. This apparent contrast is consistent with the different imposed demands and canopy representations. It cannot establish that actual heath vegetation is more drought resistant than the local forests.

The maize proxy and grass class have similar total ET in the matched 2025 season, 368.3 and 351.7 mm, but their components differ. Maize has 177.0 mm soil evaporation and 141.7 mm transpiration, while grass has 116.3 and 181.4 mm. Thus similar total evaporation can conceal substantially different soil exposure, active canopy periods and carbon-water response.

## 7 Transpiration limitation and its meaning
''')
fig(8,'08_transpiration_ratios','Monthly sum of actual transpiration divided by monthly sum of potential transpiration within each class. Ratios near one indicate little reduction under the model definition. White means unavailable or no meaningful potential demand; partial October 2026 is omitted. Ratios are formed from sums, not by averaging unstable daily ratios when potential transpiration is close to zero.')
text('''The domain seasonal actual-to-potential transpiration ratio is 0.665 in 2024, 0.231 in 2025 and 0.280 in 2026. Because forest occupies 52.8% of the grid and has a high potential demand, it strongly influences the aggregate. A domain ratio is not an area average of class ratios and cannot be interpreted as the fraction of plants suffering stress.

The forest seasonal ratio is 0.141 in 2025 and 0.175 in 2026. Grass has ratios of 0.559 and 0.684, and maize 0.553 and 0.537. The slightly lower maize ratio in the warmer 2026 season coexists with higher integrated maize assimilation and transpiration than in 2025. Potential demand and the temporal overlap between growth, weather and stress differ, so a single ratio does not fully rank crop performance.

The current output does not split every transpiration reduction into independent drought and oxygen components. Dynamic crops retain their source drought, oxygen and rooting settings, while prescribed vegetation follows its own parameter route. We therefore describe the diagnostic as transpiration limitation. Attributing the entire reduction to one stress mechanism would require its specific output fields and a corresponding audit.

## 8 Soil moisture across depth and time
''')
fig(9,'09_soil_moisture_depth_time','Daily end-state water mass concentration at the five actual output centres. The line is the spatial mean over all model columns and the band is the spatial 10th to 90th percentile. The band describes spatial heterogeneity, not parameter uncertainty, an observational range or a confidence interval. Vertical scales are identical across the five panels.')
text('''At 10.5 cm the lowest spatial mean is 128.6 kg m⁻³ on 2 September 2024, 107.5 on 3 October 2025 and 106.5 on 16 August 2026. The 2026 minimum is the lowest observed in that available model period. It is not a complete-year minimum. The driest domain-average date is also not the driest date in every cell, so spatial maps below use one common date rather than mix cell-specific minima.

The 2025 minimum occurs after the common April to September comparison window. That illustrates why matching seasonal totals is useful but does not capture every late-season state. Interannual comparisons should retain both the common window and the complete available chronology, especially when autumn rewetting or carry-over storage matters.
''')
table(['Actual centre cm below surface','2024 season kg m⁻³','2025 season kg m⁻³','2026 season kg m⁻³'],[[abs(z),*[dep[(dep.period=='April to September')&(dep['class']=='Domain')&(dep.depth_cm==z)&(dep.year==y)].iloc[0].moisture_mean_kg_m3 for y in (2024,2025,2026)]] for z in (-10.5,-22.5,-42.5,-82.5,-162.5)])
fig(10,'10_moisture_month_depth','Monthly means at the sampled centres show stronger shallow drying and slower changes at depth. Rows are the five discrete output centres, displayed with equal categorical spacing. They are not a vertically interpolated continuous moisture field. Partial October 2026 is excluded, and the remaining months are unavailable.')
text('''Over April to September, the 2024-to-2025 moisture decrease is 90.4 kg m⁻³ at 10.5 cm but 31.7 at 162.5 cm. In 2026 shallow seasonal moisture partly recovers to 148.4 kg m⁻³, while the deep mean is 196.0, only slightly above 2025 and still below 2024. This is consistent with different response times and a history of deep storage depletion. The present simulation does not prove the persistence of an observed regional groundwater deficit.

A value at 162.5 cm is soil water content at that centre, not a water-table measurement. Free drainage does not provide a resolved regional groundwater level. Similarly, the five reported concentrations cannot be integrated exactly into two-metre storage without the full compartment values and thicknesses. Native WTOT and DSTOR are the appropriate authorities for full-profile storage in this delivery.
''')
fig(11,'11_class_depth_profiles','Class mean profiles from January to March and June to August 2025. Connected markers link the five sampled centres only. The wetland profile reflects the imposed shallow water supply, while freely draining classes show greater seasonal change. Source layers, soil assignments, vegetation and boundary types differ among classes; these profiles cannot isolate rooting effects alone.')
fig(12,'12_dry_date_spatial_moisture','Water concentration at 10.5, 82.5 and 162.5 cm on 3 October 2025, the date of the lowest domain-average shallow moisture that year. Maps share the same concentration scale. Deeper spatial patterns differ from the very dry shallow pattern. The highest wet values include columns influenced by different soil or lower-boundary assumptions.')
text('''Concentrations in kg m⁻³ make the amount of water per soil volume clear, but equal concentrations do not imply equal plant water availability. Soil retention curves determine the associated pressure head and accessible water. A fixed regional threshold in kg m⁻³ would ignore differences in residual water content, porosity, texture and rooting. Establishing such a threshold requires a specific ecological or agricultural definition and suitable validation.

## 9 Soil temperature and thermal response
''')
fig(13,'13_soil_temperature_time','Spatial means of day-end soil temperature, together with a seven-day mean of the daily mean air forcing. The air and soil curves have different temporal sampling support and should not be subtracted as a calibrated temperature bias. Soil responses are increasingly damped at depth. Numerical heat is active, while frozen-water hydrology remains disabled.')
table(['Actual centre cm below surface','2024 season °C','2025 season °C','2026 season °C'],[[abs(z),*[dep[(dep.period=='April to September')&(dep['class']=='Domain')&(dep.depth_cm==z)&(dep.year==y)].iloc[0].temperature_mean_C for y in (2024,2025,2026)]] for z in (-10.5,-22.5,-42.5,-82.5,-162.5)])
text('''The April to September mean temperature at 10.5 cm increases from 15.81 °C in 2024 to 16.56 in 2025 and 17.09 in 2026. The corresponding deep means are 14.75, 15.13 and 15.55 °C. The seasonal warming signal is therefore present at every reported depth, with a smaller magnitude deeper in the profile. This describes these input years and model assumptions; it is not a trend estimate.

The initial thermal profile is linear from 7.5125 °C at the surface to 11.8794 °C at two metres. The upper thermal boundary uses air temperature and the bottom imposes zero heat flux. These choices, the soil thermal parameter conversion and the absence of thermal spin-up limit interpretation of both first-year means and deep thermal behaviour. The annual mean profile need not be monotonic, particularly when comparing temperatures sampled at the day end rather than true daily means.
''')
fig(14,'14_temperature_depth_amplitude','Annual range and annual mean of the spatially averaged day-end soil temperatures for the two complete years. The range is maximum minus minimum of that daily series, not the full within-day amplitude or the range over every cell. Deep values respond less strongly than shallow values. The mean-profile differences are small and remain affected by initialisation and boundary assumptions.')
table(['Year','Depth cm','Range of spatial mean °C','Date of maximum'],[[int(r.year),r.depth_cm,r.temperature_range_of_spatial_mean_C,r.peak_date] for _,r in thermal[thermal.year.isin([2024,2025])].iterrows()])
text('''In 2025 the annual range of the spatial mean declines from 27.08 °C at 10.5 cm to 16.15 °C at 162.5 cm. The shallow maximum occurs on 1 July, while the deep maximum occurs on 23 August. These are calendar dates of the maxima in a season containing several warm episodes. Their 53-day difference is not an estimate of the travel time of one isolated heat pulse.

The minimum over every exported cell and depth is about -1.99 °C in 2024, -0.72 in 2025 and -0.88 in 2026. A negative soil temperature does not establish simulated ice content or frozen-soil hydraulic effects because SWFROST remains off. Sensor comparison should use the true model centre depth and the native sampling time, and should consider whether above-canopy air temperature is an adequate ground thermal boundary.

## 10 Crop assimilation and GPP coverage
''')
fig(15,'15_crop_GPP_time','Seven-day mean GPP equivalent by dynamic crop and year, expressed as a 24-hour average. Crop calendars, temperature-dependent start and growth, mowing and water limitation shape the curves. The panels use their own vertical ranges so that grass seasonality remains visible; compare numeric values using the labelled axes. The absence of maize assimilation outside its active period is distinct from missing forest or heath assimilation.')
g=c[c['class'].isin(['Grass','Maize proxy'])]
table(['Year','Window','Crop','GPP g C m⁻²','Mean GPP µmol CO2 m⁻² s⁻¹'],[[int(r.year),'Year' if r.period=='Available year' and r.year<2026 else ('To 1 Oct' if r.period=='Available year' else 'Apr to Sep'),r['class'],r.GPP_gC_m2,f'{r.GPP_mean_umol_m2_s:.3f}'] for _,r in g.iterrows()])
text('''In the matched season, grass gross carbon assimilation decreases from 1,434.7 g C m⁻² in 2024 to 846.5 in 2025, then recovers to 1,024.9 in 2026. Maize-proxy values are 2,119.3, 1,107.2 and 1,275.8 g C m⁻². Relative to 2024, the 2025 decreases are 41.0% for grass and 47.8% for maize. The 2026 values remain below 2024 despite their increase from 2025.

The full-year grass and maize means in 2024 are 4.690 and 5.838 µmol CO2 m⁻² s⁻¹. Growing-season means are higher because the annual mean includes winter and inactive periods. These are model gross fluxes before respiratory deductions. They do not describe yield, net biomass accumulation or ecosystem carbon storage. Mowing and harvest can affect subsequent assimilation, but exported GASST alone cannot reconstruct the fate of harvested or respired carbon.

The result is also sensitive to the generic crop choice. Maize was assigned to every broad agricultural cell, rather than mapped from actual annual crops. Grass includes cells that might in reality be unmanaged grass or another vegetation type. The source management reduction remains in the flux after conversion, so the result should not be interpreted as theoretical unstressed photosynthetic capacity.
''')
fig(16,'16_GPP_space_and_coverage','Matched-season GPP in 2025 and the corresponding spatial availability mask. Grey cells have no assimilation model and remain missing. The 1,305 available cells represent 81.5625 km² of the 256 km² grid. A full-domain ecosystem GPP total is not produced, since the missing 68.14% includes the dominant forest class and the heath area of interest.')
text('''A map or average must preserve this coverage. Setting missing forest GPP to zero would systematically change the meaning of regional carbon uptake. Averaging only valid cells without stating the denominator would likewise make a crop-subset statistic look like a regional ecosystem statistic. The delivered GPP field therefore retains NaN values and GASST_flag, and this note reports class means rather than a misleading full-domain mean.

## 11 Carbon and water are linked inside the model
''')
fig(17,'17_carbon_water_relations','Cell-level matched-season gross carbon assimilation against transpiration and shallow soil water concentration. Marker shape distinguishes years and colour distinguishes crop. These associations arise from a model in which assimilation explicitly depends on water-stress reduction and crop development. They are not independent evidence that either modelled flux is correct.')
text('''The within-class correlation between seasonal GPP and transpiration exceeds 0.97 in every crop-year combination. In maize it is above 0.998. This should be expected in part from the source relationship GASS = PGASS × RELTR, where actual-to-potential transpiration contributes to the growth reduction. Reporting that correlation as validation would therefore be circular.

For a descriptive carbon-water diagnostic, divide seasonal gross carbon assimilation in g C m⁻² by seasonal transpiration in mm. One mm of water equals one kg m⁻², so the result has units g C per kg transpired water. The calculation concerns gross carbon and transpiration, not harvested dry matter and not total ET. Cells with less than 1 mm transpiration are excluded from this ratio to avoid unstable division.
''')
cu=pd.read_csv(R/'tables/carbon_water_diagnostics.csv');table(['Year','Crop','Median g C per kg transpired water','Spatial P10','Spatial P90'],[[int(r.year),r['class'],f'{r.median_GPP_per_transpiration_gC_kgH2O:.3f}',f'{r.p10:.3f}',f'{r.p90:.3f}'] for _,r in cu.iterrows()])
text('''The maize diagnostic is around 8.0 g C kg⁻¹ in 2024 and 7.8 in 2025; grass is around 5.4 and 4.7. The very narrow 2024 within-class range largely reflects the common forcing, crop parameters and weak water limitation, rather than a quantified uncertainty bound. Crop-type differences include photosynthetic and management assumptions, so they are not a direct comparison of observed field water-use efficiencies.

The shallow-moisture relation is less direct. Different soils can have similar water concentration but different pressure heads or root-accessible stores. The near-horizontal 2024 clusters show that varying shallow concentration need not change assimilation when the configured crop is largely unstressed. A five-depth soil moisture series and a crop-response diagnostic provide complementary information; neither replaces the other.

## 12 Spatial spread and sensitivity to the analysis population

The model's spatial variation is conditional on the available inputs. Some differences reflect real source contrasts, while others reflect class assignments, donor profiles and explicit defaults. The spatial P10 and P90 below are percentiles of cell totals within a class in 2025. They are not confidence limits or an ensemble of alternative parameter sets.
''')
sr=pd.read_csv(R/'tables/spatial_ET_ranges.csv');sr=sr[(sr.year==2025)&(sr.variable=='ET')]
table(['Class','2025 cell ET minimum mm','Spatial P10 mm','Median mm','Spatial P90 mm','Maximum mm'],[[r['class'],r['min'],r.p10,r['median'],r.p90,r['max']] for _,r in sr.iterrows()])
text('''The heath class includes a few much higher ET columns than its median, consistent with the presence of different lower-boundary assignments among the broader heath group. The three wetland values are essentially identical at the precision shown. Repeated settings and shared forcing can produce repeated output; the number of mapped cells is not the number of independent measurements or independent parameter realisations.

A separate screening changes the population used for a mean without rerunning any physics. It first removes urban and wetland classes, then majority-water cells, then retains natural and crop columns with a dominant land fraction of at least 80% and zero mapped water fraction, and finally excludes soil-imputation flags. This tests the effect of reporting choices and class composition. It is not a correction of the full-domain result or a calibrated uncertainty analysis.
''')
rs=pd.read_csv(R/'tables/representation_sensitivity.csv');table(['Analysis population','Cells','2025 season ET mm','Shallow moisture kg m⁻³'],[[r.selection,int(r.cells),r.ET_aprsep_2025_mm,r.shallow_moisture_kg_m3] for _,r in rs.iterrows()])
text('''The resulting ET means range from 370.4 to about 378.0 mm. The most restricted subset contains 1,585 cells and gives 377.5 mm, about 1.9% above the full-grid mean. That small shift does not bound the effect of better soil properties, groundwater coupling or different vegetation parameters, none of which were changed. It only shows that this particular selection rule modestly changes this particular reported mean.

## 13 Accounting flags and conversion verification
''')
fig(18,'18_accounting_flags','Largest absolute independent daily water residual over all cells, and the number of flagged cells. The two marked transitions are the 503 maize post-harvest events on 16 October 2025 and the 1,198 annual grass and urban events on 1 January 2026. Maximum residuals are small compared with seasonal evaporation, but they remain explicit daily physical-accounting limitations.')
text('''All original 4,096 columns completed their native runs. Of these, 2,395 have unflagged completion and 1,701 retain recognised canopy-calendar accounting flags. The original native fluxes, DSTOR and BALDEV are not modified by the conversion. The maximum recognised event is approximately 0.035682 mm, and the maximum annual-event residual is about 0.0106133 mm. Their small size does not justify calling those daily balances perfectly closed.

The candidate files have been checked over all cells, days and five depth levels. ET matches the requested sum exactly in float64. Temperature matches the source exactly. Converted moisture is stored as float32; the largest extra rounding difference from the exact 1,000 multiplication is about 0.0000153 kg m⁻³. Inverting every valid GPP value to daily carbon mass reproduces native GASST × CFRDM to the declared float64 tolerance. Cell identities, daily bounds, actual depths, assimilation availability and canopy flags are preserved.

These checks qualify the stated data conversion, not the original ecological or hydrological parameter choices. No comprehensive external CF conventions checker or agreement with an official SYMPHONICA schema is claimed. The source native NetCDF files remain immutable and are identified by their existing SHA-256 hashes.

## 14 Candidate products and practical use
''')
table(['Candidate file','Daily intervals','Cells','Depths','Bytes'],[[p['file'],d,4096,5,p['bytes']] for p,d in zip(summary['conversion_products'],[366,365,274])])
text('''The products retain the same annual partitioning as the native export. Each contains ET, soil_moisture, GPP and soil_temperature, plus ET_including_pond, pond_evaporation and the independent balance residual in mm. It retains the actual and requested depths, coordinates, vegetation and crop descriptions, spatial input flags and dynamic availability flags. crop_carbon_fraction records the active CFRDM used for the conversion.

ET and GPP use float64. Soil moisture and soil temperature use float32. Primary numeric arrays use zlib level 4 compression, shuffle and Fletcher32, with chunks of 32 days by 64 cells and all five depth values together where applicable. The converter writes a .partial file and renames it after completion. File-level metadata retains source file names and hashes, the baseline Git commit, water density, molar carbon mass, conversion definitions and the provisional mapping status.

For reproducibility, the accompanying package contains the three derived annual files, the conversion contract, reusable converter, analysis and plotting scripts, complete numeric tables, figure files and verification evidence. The original simulation files are already preserved in the V02 Git delivery. The analysis does not require a native rerun. Only completed .nc files are read; abandoned or in-progress .partial files are excluded.

The following example illustrates one annual conversion. The analysis and validation scripts use the same input directory and an explicit output directory.

```sh
python3 scripts/convert_symphonica.py \\
  /path/to/Kalmthout_SW431_V02_daily_2025.nc \\
  /path/to/SYMPHONICA_Kalmthout_V02_daily_2025.nc
python3 scripts/analyse_results.py /path/to/native/daily_netcdf /path/to/results
python3 scripts/validate_conversion.py /path/to/native/daily_netcdf /path/to/results
```

To aggregate ET over a period, integrate its daily mean rate over the corresponding interval durations. Here the intervals are all one day, so summing the daily numbers gives mm. To aggregate GPP to g C m⁻², multiply each mean flux by its duration in seconds, divide by one million and multiply by 12. To average moisture or temperature, average the requested day-end samples; do not sum them as fluxes. Retain actual depth and availability metadata with any extracted series.

A spatially complete map is not equivalent to a complete landscape process model. Do not treat the urban surrogate as a sewer model, a high-water-fraction soil column as a lake or net bottom outflow as a validated aquifer recharge product. For GPP, preserve missing values outside dynamic crops and state the represented area whenever aggregating available cells.

## 15 Priorities for a more informative next version

The current results point to a focused sequence of improvements. First, improve the hydrological relationship with the surroundings. Review groundwater observations, vertical reference levels, drainage and surface-water supply before changing lower boundaries. The contrast between freely draining classes and the three shallow-head wetland columns makes this a material uncertainty in seasonal transpiration and evaporation.

Second, establish a defensible hydrological and thermal spin-up. The first year loses 207.7 mm of native water storage, so initialisation is not a negligible bookkeeping issue. A controlled comparison should determine how much of the 2024-to-2025 contrast persists when the initial states and preceding climate history are treated consistently. Such a test would separate a weather contrast from an initial-state effect more clearly than the present chronological run can.

Third, align the pipeline with the standard datasets being collected and made accessible within SYMPHONICA. The agreement should cover source versions, identifiers, grid or feature support, CRS and vertical datum, temporal intervals, actual depth support, missing values and quality flags. It should also specify whether project evaporation includes ponded-water evaporation and whether GPP means a complete-day mean, daylight mean or a different temporal product. The units alone do not establish that semantic agreement.

For vegetation, use actual crop maps and management, distinguish managed grass from natural vegetation, and review prescribed forest and heath canopy demand. The large forest interception contribution and strong dry-season transpiration limitation deserve observational checks. Obtaining ecosystem GPP requires an appropriate assimilation model for forest and heath; filling their missing values by extrapolating crop means would add an unsupported assumption.

For soils, review donor-imputed cells, local restrictive horizons, organic layers and hydraulic parameter uncertainty. Compare moisture using pressure-head and retention information as well as kg m⁻³. For temperature, check the air-to-ground upper boundary, thermal properties and sensor depth matching before interpreting small biases. Numerical heat and frost hydrology should remain separate choices.

Finally, evaluate the four products against suitable independent observations with explicit temporal and spatial matching. A high correlation between two internally coupled model outputs is not such an evaluation. Field observations, source uncertainty and out-of-sample periods are needed to move from an executable technical exercise to a model with established predictive performance.

## Appendix A Monthly water accounting

Monthly values below are means across model columns followed by interval integration. All water quantities are in mm. The final October 2026 row covers one day only and must not be compared with complete months. Storage change is the native DSTOR accounting quantity. The CSV tables retain additional components and unrounded precision.
''')
mo=pd.read_csv(R/'tables/monthly_domain.csv');table(['Period','Days','P mm','ET mm','T mm','Bottom outflow mm','Storage change mm'],[[r.period,int(r.days),r.P_mm,r.ET_mm,r.T_mm,r.net_bottom_outflow_mm,r.storage_change_mm] for _,r in mo.iterrows()])
text('''## Appendix B Evidence and source interpretation

The source simulation is pinned to Git commit 48c7897c6500309e5e83377986ca2ff3e20917e3. It is the complete locally refined V02 grid with native numerical heat and WOFOST grass and maize. The construction note describes original source datasets, parameter transfer, model execution and known limitations. This note analyses those outputs without changing the native simulations.

The machine-readable conversion_contract.json is the explicit mapping definition. GPP_source_derivation.json retains source excerpts and source hashes for the carbon-fraction conversion, gross assimilation, output accumulation and interval reset. conversion_validation.json records complete-array checks. analysis_summary.json identifies the source and derived files, represented populations and annual and matched-season summaries. Every figure is generated from retained aggregate arrays and tables by the included plotting script.

The exact SWAP 4.3.1 source is the primary authority for the CFRDM correction. General WOFOST documentation explains the relationship between daily gross CO2 assimilation and carbohydrate equivalents, but a generic 30/44 equation without this source-version detail is insufficient for the current grass file. External context is available from the SWAP theory and user guide at https://swap.wur.nl/manual/ and the WOFOST assimilation documentation and source at https://github.com/ajwdewit/pcse/blob/master/pcse/crop/assimilation.py . Those references do not independently validate the Kalmthout application.

Spatial percentile bands and class differences in this note describe one deterministic simulation under shared meteorology. They are not uncertainty ensembles. The three available periods are not a climatic reference distribution. Those distinctions should remain visible when the products enter the broader SYMPHONICA comparison and data-delivery workflow.
''')
(R/'Kalmthout_V02_results_and_SYMPHONICA.md').write_text('\n'.join(parts))
print('WORDS',sum(len(p.split()) for p in parts),'FIGURES',18)
