"""Extract the unchanged literal uptake block; no translated production formula."""
import hashlib
from pathlib import Path

def prepare(root,build,management):
 source=management.decode()
 start=source.index('! Mineralisation, but Nminer is negative in case of immobilisation')
 end=source.index('      Call Wofost_SoilBalanceCheck',start)
 body=source[start:end]
 declarations='''subroutine literal_crop_exchange(Ndemand,dvs,lai,rd,tcsf_in,LaiCritNupt,supply)
 use iso_fortran_env,only:real64
 use wofost_soil_declarations
 use MOD_texture_orgmat,only:bdens
 implicit none
 real(real64),intent(in)::Ndemand,dvs,lai,rd,tcsf_in,LaiCritNupt
 real(real64),intent(out)::supply
 real(real64)::ProdRate0,ProducPot,ProducAct,TCSF,FactNuptJuvenil,Nsupply
 real(real64)::cNH4_t_Ndemand_rate_limited,cNH4_av_Ndemand_rate_limited,cNH4_t_Nsupply_rate_limited,cNH4_av_Nsupply_rate_limited
 real(real64)::cNO3_t_Ndemand_rate_limited,cNO3_av_Ndemand_rate_limited,cNO3_t_Nsupply_rate_limited,cNO3_av_Nsupply_rate_limited
 real(real64)::Nsupply_Ndemand_rate_limited,Nsupply_Nsupply_rate_limited
 logical::FlNuptJuvenil,fl_cropcalendar
 TCSF_N=tcsf_in;fl_cropcalendar=.true.
'''
 (build/'literal_crop_exchange.f90').write_text(declarations+body+'\n supply=Nsupply\nend subroutine\n')
 s=(root/'tests/nut-reactive/reactive_oracle.inc').read_text()
 s=s.replace('subroutine literal_day(', 'subroutine literal_crop_day(').replace('after,nit,denit,carbon', 'after,nit,denit,carbon,demand,dvs,lai,rd,tcsf_in,crit,supply',1)
 s=s.replace('   real(real64)::nh4c', '   real(real64),intent(in)::demand,dvs,lai,rd,tcsf_in,crit\n   real(real64),intent(out)::supply\n   real(real64)::nh4c')
 a=s.index('   call Wofost_SoilWaterN(');b=s.index('   after%fom_kg_m3',a)
 s=s[:a]+'''   cnh4_t0=nh4c;cno3_t0=no3c;SorpCoef=p%mineral%sorption
   cnh4N_seep=p%mineral%c_bottom(1);cno3N_seep=p%mineral%c_bottom(2)
   cnh4N_top=p%mineral%c_top(1);cno3N_top=p%mineral%c_top(2);cnh4N_lat=p%mineral%c_lateral(1);cno3N_lat=p%mineral%c_lateral(2)
   Wflux_out=qout;Wflux_inBot=qbot;Wflux_inLat=qlat;Wflux_inTop=top_water;Wflux_transp=root
   call literal_crop_exchange(demand*1d-4,dvs,lai,rd,tcsf_in,crit,supply)
   nh4end=cNH4_t;no3end=cNO3_t;nh4avg=cNH4_av;no3avg=cNO3_av
   prod=.5d0*(w0+w1)*RateConNitrif*nh4avg
'''+s[b:]
 (build/'crop_oracle.inc').write_text(s)
 return dict(management_sha256=hashlib.sha256(management).hexdigest(),block_sha256=hashlib.sha256(body.encode()).hexdigest(),extraction_start=start,extraction_end=end)
