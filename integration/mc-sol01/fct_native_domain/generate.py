"""Metric-aware numerical successor; all surface physics stays production-owned."""
import runpy
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
HERE=Path(__file__).resolve().parent
g=runpy.run_path(str(HERE.parent/'fct_sinks/generate.py'));rep=g['replace']
def storage():
 s=g['g']['storage']().decode().replace('mod_research_storage_fct','mod_research_metric_storage').replace('advance_research_storage_fct','advance_research_metric_storage')
 s=rep(s,'  real(real64)::h,dt,','  real(real64),allocatable::h(:)\n  real(real64)::dl,dr,dt,')
 s=rep(s,'any(f%dz_cm/=f%dz_cm(1)).or.','')
 s=rep(s,'  if(any(f%bulk_density/=f%bulk_density(1)).or.any(f%kf/=f%kf(1)))return\n','')
 s=rep(s,'h=f%dz_cm(1)','h=f%dz_cm')
 s=rep(s,'max(1d0,h,maxval(dt*q))','max(1d0,maxval(h),maxval(abs(dt*q)))')
 s=rep(s,'if(any(f%q_face_up_cm_day>0d0))return','if(f%q_face_up_cm_day(1)>0d0)return')
 s=rep(s,'if(any(dt*q(2:)>min(f%theta,f%theta_previous)*h))return','if(any(dt*(max(q(2:),0d0)+max(-q(:n),0d0))>min(f%theta,f%theta_previous)*h))return')
 s=rep(s,'  face(2:)=q(2:)*(m%concentration_mg_cm3+.5d0*slope)', '''  do i=2,n
   if(q(i)>=0d0)then
    face(i)=q(i)*(m%concentration_mg_cm3(i-1)+.5d0*slope(i-1))
   else
    face(i)=q(i)*(m%concentration_mg_cm3(i)-.5d0*slope(i))
   end if
  end do
  face(n+1)=max(q(n+1),0d0)*m%concentration_mg_cm3(n)+min(q(n+1),0d0)*f%cseep_mg_cm3''')
 s=rep(s,'  anti=dt*q(2:n)*(half(:n-1)+.5d0*slope(:n-1)-low%concentration_mg_cm3(:n-1))', '''  do i=1,n-1
   if(q(i+1)>=0d0)then
    anti(i)=dt*q(i+1)*(half(i)+.5d0*slope(i)-low%concentration_mg_cm3(i))
   else
    anti(i)=dt*q(i+1)*(half(i+1)-.5d0*slope(i+1)-low%concentration_mg_cm3(i+1))
   end if
  end do''')
 s=rep(s,'cmax=max(maxval(m%concentration_mg_cm3),f%rain_c_mg_cm3)','cmax=max(maxval(m%concentration_mg_cm3),f%rain_c_mg_cm3,f%cseep_mg_cm3)')
 begin=s.index('   slope(i)=mc(');end=s.index('\n  end do',begin)
 s=s[:begin]+'''   dl=.5d0*(h(i-1)+h(i));dr=.5d0*(h(i)+h(i+1))
   slope(i)=h(i)*mc(2d0*(m%concentration_mg_cm3(i)-m%concentration_mg_cm3(i-1))/dl, &
    (m%concentration_mg_cm3(i+1)-m%concentration_mg_cm3(i-1))/(dl+dr), &
    2d0*(m%concentration_mg_cm3(i+1)-m%concentration_mg_cm3(i))/dr)'''+s[end:]
 for old,new in [('amount/h,','amount/h(i),'),('upper(i)=h*','upper(i)=h(i)*'),('mass(i)/h,','mass(i)/h(i),'),('f%theta(i)*h)','f%theta(i)*h(i))'),('physical=p%sorbed_density*h','physical=p%sorbed_density*h(i)')]:s=rep(s,old,new)
 return s.encode()
def composed():
 s=g['composed']().decode().replace('mod_research_sink_fct','mod_research_native_fct').replace('advance_research_sink_fct','advance_research_native_fct')
 s=rep(s,' use mod_research_composed_fct',' use mod_research_sink_fct\n use mod_research_composed_fct')
 s=s.replace('use mod_research_storage_fct','use mod_research_metric_storage').replace('advance_research_storage_fct','advance_research_metric_storage')
 s=rep(s,'::high_s,low_s','::high_s,low_s,predictor_s')
 begin=s.index('  if(all(f%root_sink_cm_day==0d0)');end=s.index('  if(.not.allocated(f%theta_previous))',begin)
 s=s[:begin]+'''  if(all(f%dz_cm==f%dz_cm(1)).and.all(f%bulk_density==f%bulk_density(1)).and. &
   all(f%kf==f%kf(1)).and.all(f%q_face_up_cm_day<=0d0).and.s%pond_mass==0d0.and. &
   all([f%pond_end_cm,f%runoff_depth_cm,f%irrigation_rate_cm_day,f%runon_rate_cm_day]==0d0))then
   call advance_research_sink_fct(m,s,f,enabled,next,next_s,r,correction_l1,applied_correction);return
  end if
'''+s[end:]
 old='  call advance_research_metric_storage(m,s,advection,.true.,high,high_s,r)'
 s=rep(s,old,'''  if(f%q_face_up_cm_day(1)>0d0.or.f%macropore_area_fraction/=0d0)return
  ! This private baseline supplies the production-owned pond-to-soil transfer.
  call advance_b111_reactive_solute_substep(m,s,f,low,low_s,r,exact_empty_pond_limit=.true.)
  if(r%status/=B111_REACTIVE_OK)return
  advection%rain_c_mg_cm3=0d0
  if(f%q_face_up_cm_day(1)<0d0)advection%rain_c_mg_cm3= &
   r%pond_to_soil_mg_cm2/(-f%q_face_up_cm_day(1)*f%dt_day)
  advection%rain_rate_cm_day=-f%q_face_up_cm_day(1)
  advection%irrigation_rate_cm_day=0d0;advection%runon_rate_cm_day=0d0
  advection%pond_end_cm=0d0;advection%runoff_depth_cm=0d0
  predictor_s=s;predictor_s%pond_mass=0d0
  call advance_research_metric_storage(m,predictor_s,advection,.true.,high,high_s,r)''')
 s=rep(s,'advance_b111_reactive_solute_substep(m,s,advection,low','advance_b111_reactive_solute_substep(m,predictor_s,advection,low')
 s=rep(s,'cmax=max(maxval(m%concentration_mg_cm3),f%rain_c_mg_cm3)','cmax=max(maxval(m%concentration_mg_cm3),advection%rain_c_mg_cm3,f%cseep_mg_cm3)')
 return s.encode()
def sources():
 parts=g['sources']();parts.pop('joint_driver.f90');parts.pop('sink_trace.f90');parts.pop('sink_joint.f90')
 parts.update({'metric_storage.f90':storage(),'native_composed.f90':composed()});return parts
