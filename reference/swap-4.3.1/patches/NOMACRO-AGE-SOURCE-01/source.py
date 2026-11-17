"""Original age host adapter to the real admitted soil/surface age providers.

No generic application activation. CDE body stays literal. Age surface/clock
differences are explicit policy; raw original runs remain separate diagnostics.
"""
import hashlib
from pathlib import Path

ROOT=Path(__file__).resolve().parents[4]
ORIGINAL='2fc8592001cdcd2de95a252d8b9099416c94e4d2654c335908858a735f80e7a2'
POLICY='original-water-midpoint-age-provider-and-explicit-surface-v1'
PROVIDERS=('mod_solute_compartment_state','mod_b111_age_tracer_substep','mod_b111_surface_age_budget')
OUTPUT_PROVIDERS=('mod_age_effluent_observer',)
EFFLUENT_POLICY='water-weighted-positive-export-age-over-output-interval-v1'


def source(original,*,native=False,effluent=False):
    if hashlib.sha256(original).hexdigest()!=ORIGINAL:raise ValueError('Foreign original age source')
    text=original.decode('cp1252').replace('\r\n','\n')
    anchor='    end interface'
    interface="""      module subroutine hybrid_age_observe(values)
         real(8),intent(out)::values(11)
      end subroutine
"""
    if native:interface+="""      module subroutine hybrid_age_checkpoint(unit,restoring)
         integer,intent(in)::unit
         logical,intent(in)::restoring
      end subroutine
"""
    if effluent:interface+="""      module subroutine hybrid_age_effluent_observe(values)
         real(8),intent(out)::values(24)
      end subroutine
"""
    text=text.replace(anchor,interface+anchor,1)
    text=text.replace('   public :: solute_CDE, calc_AgeTracer','   public :: solute_CDE, calc_AgeTracer, hybrid_age_observe',1)
    if native:text=text.replace('calc_AgeTracer, hybrid_age_observe','calc_AgeTracer, hybrid_age_observe, hybrid_age_checkpoint',1)
    if effluent:text=text.replace('   public :: swdc','   public :: hybrid_age_effluent_observe\n   public :: swdc',1)
    prefix,body=text.split('submodule (MOD_Solute) MOD_calc_AgeTracer',1)
    def replace(old,new):
        nonlocal body
        if body.count(old)!=1:raise ValueError('Changed original age anchor: '+old[:90])
        body=body.replace(old,new,1)
    replace('      use MOD_swap_base, only: swsolu',"""      use MOD_swap_base, only: swsolu
      use MOD_grid, only: dz
      use mod_solute_compartment_state,only:solute_compartment_state_t
      use mod_b111_age_tracer_substep,only:b111_age_tracer_substep_forcing_t, &
         b111_age_tracer_substep_receipt_t,advance_b111_age_tracer_substep,B111_AGE_SUBSTEP_OK
      use mod_b111_surface_age_budget,only:surface_age_request_t,surface_age_receipt_t, &
         advance_surface_age_budget,SURFACE_AGE_OK""")
    # Move the actual persistent age owner out of procedure-local storage so the
    # explicit observation/native interface can access it without global mocks.
    replace('   contains\n      module subroutine calc_AgeTracer(task)',"""      real(8),allocatable,save::Agemsy(:)
      real(8),save::Ageirr=0d0,Agedrain=0d0,Agepre=0d0,Agepond=0d0,Agepondm1=0d0
      real(8),save::icAgeTopupw=0d0,icAgeTopdwn=0d0
      real(8),save::age_pond_stock=0d0,age_cumulative(8)=0d0
   contains
      module subroutine calc_AgeTracer(task)""")
    for name in ('Ageirr,Agedrain,Agepre','Agepond','Agepondm1','icAgeTopupw','icAgeTopdwn'):
        import re
        pattern=r'(?m)^      real\(8\)[ \t]*:: '+name+r'[ \t]*(?:![^\n]*)?\n'
        body,n=re.subn(pattern,'',body);assert n==1,(name,n)
    import re
    body,n=re.subn(r'(?m)^      real\(8\), dimension\(:\), allocatable, save :: Agemsy[^\n]*\n','',body);assert n==1
    replace('      save  Ageirr,Agedrain,Agepre,Agepond,Agepondm1','')
    replace('      save  icAgetopupw,icAgetopdwn',"""      type(solute_compartment_state_t)::age_before,age_candidate
      type(b111_age_tracer_substep_forcing_t)::age_forcing
      type(b111_age_tracer_substep_receipt_t)::age_receipt
      type(surface_age_request_t)::age_surface
      type(surface_age_receipt_t)::age_surface_receipt
      real(8)::age_water_midpoint(numnod)
      logical::age_first_microstep""")
    replace('      use variables,     only: dt','      use variables,     only: dt,runon,epd,reva')
    replace('         Agepond   = cpre\n         Agepondm1 = Agepond',"""         Agepond   = cpre
         Agepondm1 = Agepond
         age_pond_stock=Agepond*pondm1
         age_cumulative=0d0""")
    replace('         tcumsol = 0.0d0',"""         age_surface=surface_age_request_t()
         age_surface%dt_day=dt
         age_surface%pond_start_cm=pondm1
         age_surface%pond_end_cm=pond
         age_surface%pond_age_stock_cm_day=age_pond_stock
         age_surface%rain_depth_cm=nraidt*dt
         age_surface%irrigation_depth_cm=nird*dt
         age_surface%runon_depth_cm=runon*dt
         age_surface%rain_age_day=Agepre
         age_surface%irrigation_age_day=Ageirr
         age_surface%soil_return_depth_cm=max(qtop,0d0)*dt
         age_surface%soil_return_age_day=0d0 ! explicit original retained-age evaporation policy
         age_surface%infiltration_depth_cm=max(-qtop,0d0)*dt
         age_surface%runoff_depth_cm=runots
         age_surface%evaporation_depth_cm=(epd+reva)*dt
         call advance_surface_age_budget(age_surface,age_surface_receipt)
         if(age_surface_receipt%status/=SURFACE_AGE_OK)then
            write(*,*)'AGE_SURFACE_REFUSED',pondm1,pond,nraidt*dt,nird*dt,runon*dt,qtop*dt,runots,epd*dt,reva*dt
            error stop 'Original host surface age budget rejected'
         end if
         age_pond_stock=age_surface_receipt%pond_end_stock_cm_day
         Agepond=age_surface_receipt%mixed_age_day
         age_cumulative(2)=age_cumulative(2)+age_surface_receipt%age_production_cm_day
         age_cumulative(3)=age_cumulative(3)+age_surface_receipt%external_age_input_cm_day
         age_cumulative(7)=age_cumulative(7)+age_surface_receipt%runoff_age_export_cm_day
         icAgesur=icAgesur+age_surface_receipt%runoff_age_export_cm_day
         icAgetopdwn=icAgetopdwn-age_surface_receipt%infiltration_age_export_cm_day
         age_water_midpoint=.5d0*(theta(1:numnod)+thetm1(1:numnod))
         age_first_microstep=.true.
         tcumsol = 0.0d0""")
    replace('            dtsolu  = min(dtsolu,(dt-tcumsol))\n            dtsolu  = max(dtsolu,dtmin)',
            '            dtsolu  = max(dtsolu,dtmin)\n            dtsolu  = min(dtsolu,(dt-tcumsol))')
    start=body.index('! ---       solute flux at soil surface')
    end=body.index('!           age of effluent terms',start)
    body=body[:start]+"""! ---       Real production age provider; no copied age equation.
            age_before%age_amount=Agemsy*dz(1:numnod)
            age_before%sorbed_matrix_mass=0d0*Agemsy
            age_forcing=b111_age_tracer_substep_forcing_t()
            age_forcing%dt_day=dtsolu
            age_forcing%theta=theta(1:numnod)
            age_forcing%theta_previous=theta(1:numnod)
            if(age_first_microstep)age_forcing%theta_previous=thetm1(1:numnod)
            age_forcing%production_theta_mean=age_water_midpoint
            age_forcing%dz_cm=dz(1:numnod)
            age_forcing%q_face_up_cm_day=q(1:numnod+1)
            age_forcing%root_sink_cm_day=qrot(1:numnod)
            age_forcing%qdra_cm_day=qdra(1:nrlevs,1:numnod)
            age_forcing%drain_age_day=Agedrain
            age_forcing%accepted_surface_age_available=.true.
            age_forcing%accepted_surface_age_input_cm_day= &
               age_surface_receipt%infiltration_age_export_cm_day*(dtsolu/dt)
            age_forcing%evaporative_top_retains_age=q(1)>=0d0
            age_forcing%face_left_weight=inpola(2:numnod)
            age_forcing%face_right_weight=inpolb(1:numnod-1)
            age_forcing%face_distance_cm=disnod(2:numnod)
            age_forcing%theta_sat_left=thetsl(layer(1:numnod-1))
            age_forcing%dispersivity_cm=ldis(layer(1:numnod-1))
            age_forcing%molecular_diffusion_cm2_day=ddif
            call advance_b111_age_tracer_substep(age_before,age_forcing,age_candidate,age_receipt)
            if(age_receipt%status/=B111_AGE_SUBSTEP_OK)error stop 'Original host soil age provider rejected'
            Agemsy=age_candidate%age_amount/dz(1:numnod)
            Ageml(1:numnod)=Agemsy/theta(1:numnod)
            age_first_microstep=.false.
            age_cumulative(1)=age_cumulative(1)+age_receipt%production_amount_cm_day
            age_cumulative(4)=age_cumulative(4)+age_receipt%drain_export_cm_day-age_receipt%drain_input_cm_day
            age_cumulative(5)=age_cumulative(5)+age_receipt%bottom_input_cm_day-age_receipt%bottom_export_cm_day
            age_cumulative(6)=age_cumulative(6)+age_receipt%root_export_cm_day
            age_cumulative(8)=age_cumulative(8)+age_receipt%pond_to_soil_cm_day
            rottot=rottot+age_receipt%root_export_cm_day
            sqdra=sqdra+age_receipt%drain_export_cm_day-age_receipt%drain_input_cm_day

"""+body[end:]
    # Bound observation traversal before accessing arrays, including the final
    # profile node. No effect on transport or the selected groundwater geometry.
    replace('         do while(gwl-100.0d0 < zzbot .AND. i <= numnod)',
            '         do while(i <= numnod)\n            if(gwl-100d0>=zzbot)exit')
    replace('         zzbot = zbotcp(i)\n         zztop = ztopcp(i)',
            '         zzbot=gwl-100d0;zztop=gwl\n         if(i<=numnod)then\n            zzbot=zbotcp(i);zztop=ztopcp(i)\n         end if')
    replace('            i = i + 1\n            zztop = ztopcp(i)',
            '            i = i + 1\n            if(i>numnod)exit\n            zztop = ztopcp(i)')
    replace('end submodule MOD_calc_AgeTracer',"""module subroutine hybrid_age_observe(values)
   real(8),intent(out)::values(11)
   values=0d0
   if(.not.allocated(Agemsy))return
   values(1)=sum(Agemsy*dz(1:size(Agemsy)))
   values(2)=age_pond_stock
   values(3)=values(1)+values(2)
   values(4:11)=age_cumulative
end subroutine
end submodule MOD_calc_AgeTracer""")
    if effluent:body=effluent_source(body,native)
    if native:
        replace('   contains\n      module subroutine calc_AgeTracer(task)',"""      integer,save::age_output_day_offset=0
      real(8),save::age_output_period_offset=0d0
      logical,save::age_initial_reset_pending=.false.,age_saved_cumulative_reset=.false.,age_saved_interval_reset=.false.
   contains
      module subroutine calc_AgeTracer(task)""")
        replace('      logical::age_first_microstep',
                '      logical::age_first_microstep,age_reset_now,age_interval_reset_now')
        replace('only: flzerocumu, q,','only: flzerocumu, flzerointr, q,')
        replace('         age_cumulative=0d0',"""         age_cumulative=0d0
         age_output_day_offset=0;age_output_period_offset=0d0
         age_initial_reset_pending=.false.""")
        replace('         if (flzerocumu) then',"""         age_reset_now=flzerocumu;age_interval_reset_now=flzerointr
         if(age_initial_reset_pending)then
            age_reset_now=age_saved_cumulative_reset
            age_interval_reset_now=age_saved_interval_reset
            age_initial_reset_pending=.false.
         end if
         if(age_interval_reset_now)age_output_period_offset=0d0
         if (age_reset_now) then""")
        # Age output continuation is private: do not change water/global output
        # initialization flags or counters while restoring an age observer.
        body=body.replace('date,comma,daynr,comma,daycum','date,comma,daynr,comma,(daycum+age_output_day_offset)')
        body=body.replace('/outper','/(outper+age_output_period_offset)')
        native_body=NATIVE
        if effluent:
            replace('         if(age_interval_reset_now)age_output_period_offset=0d0',
                    '         if(age_interval_reset_now)then\n            age_output_period_offset=0d0\n            age_export_water=0d0;age_export_amount=0d0\n         end if')
            native_body=native_body.replace('sqdra,saved_total','sqdra,age_export_water,age_export_amount,saved_total')
            native_body=native_body.replace('sqdra,observed(1:3)','sqdra,age_export_water,age_export_amount,observed(1:3)')
            native_body=native_body.replace('real(8)::saved_output_period','real(8)::saved_output_period,effluent_observed(24)')
            native_body=native_body.replace('      call hybrid_age_observe(observed)',
                "      if(.not.all(ieee_is_finite(age_export_water)).or..not.all(ieee_is_finite(age_export_amount))) &\n"
                "         error stop 'Nonfinite original age effluent native state'\n"
                "      if(any(age_export_water<0d0).or.any(age_export_amount<0d0))error stop 'Negative original age effluent native state'\n"
                "      call hybrid_age_effluent_observe(effluent_observed)\n      call hybrid_age_observe(observed)")
        replace('end submodule MOD_calc_AgeTracer',native_body+'\nend submodule MOD_calc_AgeTracer')
    return (prefix+'submodule (MOD_Solute) MOD_calc_AgeTracer'+body).replace('\n','\r\n').encode('cp1252')


def csv_source(original):
    # Reuse exact original observation anchors; this is an output-only hook.
    import importlib.util
    spec=importlib.util.spec_from_file_location('aq_observer',ROOT/'reference/swap-4.3.1/patches/NOMACRO-AQUIFER-SOLUTE-01/source.py')
    aq=importlib.util.module_from_spec(spec);spec.loader.exec_module(aq)
    rendered=aq.reference_csv(original,prefix='AGE_CUMULATIVE',include_soil=False).decode('cp1252')
    rendered=rendered.replace('hybrid_aquifer_cumulative','hybrid_age_observe').replace('aq_values(7)','aq_values(11)')
    rendered=rendered.replace("(a,7(1x,es25.17e3))","(a,11(1x,es25.17e3))")
    return rendered.encode('cp1252')


def effluent_source(body,native):
    def replace(old,new):
        nonlocal body
        if body.count(old)!=1:raise ValueError('Changed age effluent anchor: '+old[:90])
        body=body.replace(old,new,1)
    replace('         advance_surface_age_budget,SURFACE_AGE_OK',"""         advance_surface_age_budget,SURFACE_AGE_OK
      use mod_age_effluent_observer,only:age_effluent_result_t,evaluate_age_effluent,age_effluent_mean,AGE_EFFLUENT_OK""")
    replace('      real(8),save::age_pond_stock=0d0,age_cumulative(8)=0d0',
            '      real(8),save::age_pond_stock=0d0,age_cumulative(8)=0d0\n      real(8),save::age_export_water(8)=0d0,age_export_amount(8)=0d0')
    replace('      logical::age_first_microstep',"""      type(age_effluent_result_t)::age_export
      real(8)::age_export_concentration(numnod),age_export_tolerance
      integer::age_export_status
      logical::age_first_microstep""")
    replace('         age_cumulative=0d0','         age_cumulative=0d0\n         age_export_water=0d0;age_export_amount=0d0')
    if not native:
        replace('only: flzerocumu, q,','only: flzerocumu, flzerointr, q,')
        replace('         if (flzerocumu) then',
                '         if(flzerointr)then\n            age_export_water=0d0;age_export_amount=0d0\n         end if\n         if (flzerocumu) then')
    replace('         icAgesur=icAgesur+age_surface_receipt%runoff_age_export_cm_day',"""         age_export_water(3)=age_export_water(3)+runots
         age_export_amount(3)=age_export_amount(3)+age_surface_receipt%runoff_age_export_cm_day
         icAgesur=icAgesur+age_surface_receipt%runoff_age_export_cm_day""")
    replace('            Agemsy=age_candidate%age_amount/dz(1:numnod)',"""            age_export_concentration=age_before%age_amount/(age_forcing%theta_previous*age_forcing%dz_cm)
            call evaluate_age_effluent(dtsolu,age_export_concentration,age_forcing%root_sink_cm_day, &
               age_forcing%qdra_cm_day,age_forcing%q_face_up_cm_day(numnod+1),age_export,age_export_status)
            if(age_export_status/=AGE_EFFLUENT_OK)error stop 'Original age effluent evaluator rejected'
            age_export_tolerance=8192d0*epsilon(1d0)*max(1d0,age_receipt%age_before_cm_day,age_receipt%age_after_cm_day)
            if(abs(age_export%age_amount_cm_day(1)-age_receipt%bottom_export_cm_day)>age_export_tolerance.or. &
               abs(age_export%age_amount_cm_day(2)-age_receipt%root_export_cm_day)>age_export_tolerance.or. &
               abs(sum(age_export%age_amount_cm_day(3:))-age_receipt%drain_export_cm_day)>age_export_tolerance) &
               error stop 'Original age effluent differs from actual transport receipt'
            age_export_water(1:2)=age_export_water(1:2)+age_export%water_cm(1:2)
            age_export_amount(1:2)=age_export_amount(1:2)+age_export%age_amount_cm_day(1:2)
            age_export_water(4:3+nrlevs)=age_export_water(4:3+nrlevs)+age_export%water_cm(3:)
            age_export_amount(4:3+nrlevs)=age_export_amount(4:3+nrlevs)+age_export%age_amount_cm_day(3:)
            Agemsy=age_candidate%age_amount/dz(1:numnod)""")
    replace('integer, save                            :: agep,agee,ageq',
            'integer, save                            :: agep,agee,ageq,agew')
    replace("      comma = ','","      real(8)::effluent_view(24)\n      comma = ','")
    replace("         filtext = 'Drain water effluent (mm/day)'","         filtext = 'Positive drainage water export over age output interval (cm)'")
    replace("         filtext = 'Groundwater age effluent (all age-values in days)'",
            "         filtext = 'Mean positive-export ages (days; -9999 means no export)'")
    replace("         write (agee,'(3a)')", """         filnam=trim(pathwork)//trim(outfil)//'.ageEffluentWater.csv'
         agew=getun(iun_min,iun_max)
         call fopens(agew,filnam,'new','del')
         filtext='Positive water exports over matching age output interval (cm)'
         call writehead(agew,1,filnam,filtext,project)
         write(agew,'(a)')' Date,daynr,daycum,WaterBottom_cm,WaterRoot_cm,WaterRunoff_cm,WaterDrainSys1_cm,WaterDrainSys2_cm,WaterDrainSys3_cm,WaterDrainSys4_cm,WaterDrainSys5_cm'
         write (agee,'(3a)')""")
    replace("""         write(agee,16) date,comma,daynr,comma,daycum,comma,AgeGwl1m,comma,&
                        icAgeBot/outper,comma,icAgeRot/outper,comma,       &
                        icAgeSur/outper,(comma,icAgeDra(level)/outper,level=1,nrlevs)""", """         call hybrid_age_effluent_observe(effluent_view)
         write(agee,16)date,comma,daynr,comma,daycum,comma,AgeGwl1m,(comma,effluent_view(16+level),level=1,8)
         write(agew,16)date,comma,daynr,comma,daycum,(comma,effluent_view(level),level=1,8)
         write(*,'(a,24(1x,es25.17e3))')'HYBRID_AGE_EFFLUENT',effluent_view""")
    replace('         write(ageq,16) date,comma,daynr,comma,daycum,(comma,iqdrainout(level),level=1,nrlevs)',
            '         write(ageq,16)date,comma,daynr,comma,daycum,(comma,effluent_view(3+level),level=1,5)')
    replace('         close (ageq)','         close (ageq)\n         close (agew)')
    replace('end submodule MOD_calc_AgeTracer',"""module subroutine hybrid_age_effluent_observe(values)
   real(8),intent(out)::values(24)
   real(8)::mean
   integer::i,status
   values=0d0;values(17:24)=-9999d0
   values(1:8)=age_export_water;values(9:16)=age_export_amount
   do i=1,8
      mean=0d0
      call age_effluent_mean(age_export_amount(i),age_export_water(i),mean,status)
      if(status/=AGE_EFFLUENT_OK)error stop 'Invalid original age effluent stock/volume'
      if(age_export_water(i)>0d0)values(16+i)=mean
   end do
end subroutine
end submodule MOD_calc_AgeTracer""")
    return body


NATIVE="""module subroutine hybrid_age_checkpoint(unit,restoring)
   use ieee_arithmetic,only:ieee_is_finite
   use MOD_grid,only:numnod
   use variables,only:theta,pond,daycum,outper,flzerocumu,flzerointr
   integer,intent(in)::unit
   logical,intent(in)::restoring
   real(8)::saved_parameters(3),saved_total(3),observed(11),scale,tolerance
   real(8)::saved_output_period
   integer::ios,saved_output_day
   if(swsolu/=2.or..not.allocated(Agemsy))error stop 'Foreign original age native owner'
   if(restoring)then
      read(unit,iostat=ios)Agemsy,ageml(1:numnod),cml(1:numnod),age_pond_stock, &
         Agepond,Agepondm1,saved_parameters,age_cumulative,icAgeTopupw,icAgeTopdwn, &
         icAgeBot,icAgeRot,icAgeSur,icAgeDra,AgeGwl1m,rottot,sqdra,saved_total, &
         saved_output_day,saved_output_period,age_saved_cumulative_reset,age_saved_interval_reset
      if(ios/=0)error stop 'Incomplete original age native state'
      if(.not.all(ieee_is_finite(Agemsy)).or..not.all(ieee_is_finite(ageml(1:numnod))).or. &
         .not.all(ieee_is_finite(cml(1:numnod))).or..not.all(ieee_is_finite(age_cumulative)).or. &
         .not.all(ieee_is_finite(icAgeDra)).or..not.all(ieee_is_finite(saved_total)).or. &
         .not.all(ieee_is_finite([age_pond_stock,Agepond,Agepondm1,saved_parameters, &
         icAgeTopupw,icAgeTopdwn,icAgeBot,icAgeRot,icAgeSur,AgeGwl1m,rottot,sqdra]))) &
         error stop 'Nonfinite original age native state'
      if(any(Agemsy<0d0).or.any(ageml(1:numnod)<0d0).or.any(cml(1:numnod)<0d0).or. &
         min(age_pond_stock,Agepond,Agepondm1)<0d0.or.any(Agemsy>1d12/dz(1:numnod)).or. &
         any(age_cumulative([1,2,3,6,7,8])<0d0))error stop 'Invalid original age native domain'
      if(any(abs(saved_parameters-[Ageirr,Agedrain,Agepre])>0d0)) &
         error stop 'Foreign original age native forcing'
      if(saved_output_day<0.or..not.ieee_is_finite(saved_output_period))error stop 'Invalid original age output clock'
      if(saved_output_period<0d0)error stop 'Negative original age output period'
      age_output_day_offset=saved_output_day-daycum
      age_output_period_offset=0d0
      if(.not.age_saved_interval_reset)age_output_period_offset=saved_output_period
      age_initial_reset_pending=.true.
      call hybrid_age_observe(observed)
      scale=max(1d0,maxval(abs(saved_total)),maxval(abs(observed(1:3))))
      tolerance=8192d0*epsilon(1d0)*scale
      if(any(abs(saved_total-observed(1:3))>tolerance).or. &
         any(abs(ageml(1:numnod)*theta(1:numnod)-Agemsy)*dz(1:numnod)>tolerance).or. &
         abs(pond*Agepondm1-age_pond_stock)>tolerance)error stop 'Unbalanced original age native stock'
   else
      call hybrid_age_observe(observed)
      write(unit)Agemsy,ageml(1:numnod),cml(1:numnod),age_pond_stock, &
         Agepond,Agepondm1,[Ageirr,Agedrain,Agepre],age_cumulative,icAgeTopupw,icAgeTopdwn, &
         icAgeBot,icAgeRot,icAgeSur,icAgeDra,AgeGwl1m,rottot,sqdra,observed(1:3), &
         daycum+age_output_day_offset,outper+age_output_period_offset,flzerocumu,flzerointr
   end if
end subroutine hybrid_age_checkpoint"""
