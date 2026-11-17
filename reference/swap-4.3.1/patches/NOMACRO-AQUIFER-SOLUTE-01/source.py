"""Exact no-macro original aquifer correction; no global B1 promotion."""
import hashlib
from pathlib import Path

ROOT=Path(__file__).resolve().parents[4]
ORIGINAL='2fc8592001cdcd2de95a252d8b9099416c94e4d2654c335908858a735f80e7a2'
SUBSURFACE='7731a8db5712fd3d2c6631ee910d79c1801b5b762673c9427a30cfdfb5f29c0b'
HELPER='260e6c62d8bfa285c36c357e3cda57b46a25b43df2dc1408125c7c1592350823'
STEP_POLICY='original-aquifer-loss-limited-forward-euler-v1'
SAFETY=0.9


def helper_source():
    raw=(ROOT/'src/process/mod_aquifer_solute_reservoir.f90').read_bytes().replace(b'\r\n',b'\n')
    if hashlib.sha256(raw).hexdigest()!=HELPER:raise ValueError('Foreign aquifer production evaluator')
    return raw


def source(original,*,mode='corrected'):
    if mode not in ('corrected','legacy-index-only'):raise ValueError('Unknown aquifer reference mode')
    if hashlib.sha256(original).hexdigest() not in (ORIGINAL,SUBSURFACE):
        raise ValueError('Foreign original/composed CDE aquifer preimage')
    helper_source()
    end=original.index(b'end submodule MOD_Solute_CDE')+len(b'end submodule MOD_Solute_CDE')
    tail=original[end:];body=original[:end].decode('cp1252').replace('\r\n','\n')
    def replace(anchor,value):
        nonlocal body
        if body.count(anchor)!=1:raise ValueError('Changed original aquifer anchor: '+repr(anchor))
        body=body.replace(anchor,value)
    anchor='      module subroutine calc_AgeTracer(task)\n         integer, intent(in) :: task\n      end subroutine calc_AgeTracer'
    replace(anchor,"""      module subroutine hybrid_aquifer_cumulative(values)
         real(8),intent(out)::values(7)
      end subroutine
      module subroutine hybrid_aquifer_checkpoint(unit,restoring)
         integer,intent(in)::unit
         logical,intent(in)::restoring
      end subroutine
"""+anchor)
    replace('   public :: solute_CDE, calc_AgeTracer','   public :: solute_CDE, calc_AgeTracer, hybrid_aquifer_cumulative, hybrid_aquifer_checkpoint')
    replace('      use MOD_swap_base, only: swcrop, swsolu, swscre, swsnow',
            '      use MOD_swap_base, only: swcrop, swsolu, swscre, swsnow, swmacro\n'
            '      use iso_fortran_env,only:int64\n'
            '      use ieee_arithmetic,only:ieee_is_finite\n'
            '      use mod_aquifer_solute_reservoir,only:aquifer_solute_result, &\n'
            '           evaluate_aquifer_solute_reservoir,evaluate_aquifer_loss_limit,AQ_OK')
    replace('!save\n   contains',"""      real(8),save::aq_capacity=0d0,aq_storage_factor=0d0
      real(8),save::aq_soil_cumulative=0d0,aq_surface_cumulative=0d0,aq_decay_cumulative=0d0
      integer(int64),save::aq_limited_steps=0_int64
!save
   contains""")
    replace('      real(8)                             :: sampro0',
            '      type(aquifer_solute_result)          :: aq_trial\n'
            '      real(8)                             :: aq_soil_rate,aq_outward_water,aq_interval_limit,aq_old_concentration\n'
            '      integer                             :: aq_status\n'
            '      real(8)                             :: sampro0')
    replace('         sampro  = samini',"""         aq_capacity=0d0;aq_storage_factor=0d0
         aq_soil_cumulative=0d0;aq_surface_cumulative=0d0;aq_decay_cumulative=0d0
         aq_limited_steps=0_int64
         if(swbr==1.and.swmacro==0)then
            if(numnod<1)error stop 'Invalid aquifer profile'
            if(kfsat>0d0)then
               if(.not.ieee_is_finite(bdens(layer(numnod))))error stop 'Nonfinite aquifer bulk density'
               if(bdens(layer(numnod))<100d0)error stop 'Aquifer sorption requires original bulk density'
            end if
            aq_storage_factor=bdenskfsatporos(numnod)
            call evaluate_aquifer_solute_reservoir(cdrain,aq_storage_factor,daquif,0d0,0d0,decsat,0d0,aq_trial,aq_status)
            if(aq_status/=AQ_OK)error stop 'Invalid original aquifer storage capacity'
            aq_capacity=aq_trial%capacity_cm
         end if
         sampro  = samini""")
    if mode=='corrected':replace('         tcumsol = 0.0d0',"""         aq_interval_limit=huge(1d0)
         if(swbr==1.and.swmacro==0)then
            aq_outward_water=max(qdrtot,0d0)-sum(min(qdra(1:nrlevs,1:numnod),0d0))
            call evaluate_aquifer_loss_limit(aq_capacity,aq_outward_water,decsat,0.9d0,aq_interval_limit,aq_status)
            if(aq_status/=AQ_OK)error stop 'Invalid original aquifer loss-rate bound'
         end if
         tcumsol = 0.0d0""")
    if mode=='corrected':replace('            tcumsol = tcumsol + dtsolu',"""            if(swbr==1.and.swmacro==0)then
               if(aq_interval_limit<min(dtsolu,dt-tcumsol))aq_limited_steps=aq_limited_steps+1_int64
               dtsolu=min(dtsolu,aq_interval_limit,dt-tcumsol)
            end if
            tcumsol = tcumsol + dtsolu
            aq_soil_rate=0d0""")
    else:replace('            tcumsol = tcumsol + dtsolu','            tcumsol = tcumsol + dtsolu\n            aq_soil_rate=0d0')
    anchor='               isqdra = isqdra + cdrtot*dz(i)*dtsolu'
    replace(anchor,anchor+'\n               if(swbr==1.and.swmacro==0)aq_soil_rate=aq_soil_rate+cdrtot*dz(i)')
    anchor="""               if (qdrtot > 0.0d0) then
                  cdrain = cdrain + dtsolu/bdenskfsatporos(i) * ( (isqdra - qdrtot*cdrain)/daquif - decsat*cdrain*bdenskfsatporos(i) )
               else
                  cdrain = cdrain + dtsolu/bdenskfsatporos(i) * ( isqdra/daquif - decsat*cdrain*bdenskfsatporos(i) )
               end if"""
    corrected="""               if(swmacro==0)then
                  call evaluate_aquifer_solute_reservoir(cdrain,aq_storage_factor,daquif,aq_soil_rate,qdrtot, &
                       decsat,dtsolu,aq_trial,aq_status)
                  if(aq_status/=AQ_OK)error stop 'Invalid conserved original aquifer candidate'
                  cdrain=aq_trial%concentration_mg_cm3
                  aq_soil_cumulative=aq_soil_cumulative+aq_trial%soil_input_mg_cm2
                  aq_surface_cumulative=aq_surface_cumulative+aq_trial%surface_out_mg_cm2
                  aq_decay_cumulative=aq_decay_cumulative+aq_trial%decayed_mg_cm2
               else
"""+anchor+'\n               end if'
    if mode=='legacy-index-only':
        corrected="""               if(swmacro==0)then
                  aq_old_concentration=cdrain
"""+anchor.replace('bdenskfsatporos(i)','bdenskfsatporos(numnod)')+"""
                  aq_soil_cumulative=aq_soil_cumulative+aq_soil_rate*dtsolu
                  aq_surface_cumulative=aq_surface_cumulative+max(qdrtot,0d0)*cdrain*dtsolu
                  aq_decay_cumulative=aq_decay_cumulative+decsat*aq_old_concentration*aq_capacity*dtsolu
               else
"""+anchor+'\n               end if'
    replace(anchor,corrected)
    if mode=='corrected':replace('               sqsur = sqsur + qdrtot*cdrain*dtsolu',"""               if(swmacro==0)then
                  sqsur=sqsur+aq_trial%surface_out_mg_cm2
               else
                  sqsur = sqsur + qdrtot*cdrain*dtsolu
               end if""")
    replace('end submodule MOD_Solute_CDE',"""module subroutine hybrid_aquifer_cumulative(values)
   real(8),intent(out)::values(7)
   values=0d0
   if(swbr/=1.or.swmacro/=0.or.aq_capacity<=0d0)return
   values=[cdrain,aq_capacity,cdrain*aq_capacity,aq_soil_cumulative,aq_surface_cumulative, &
           aq_decay_cumulative,real(aq_limited_steps,8)]
end subroutine
module subroutine hybrid_aquifer_checkpoint(unit,restoring)
   integer,intent(in)::unit
   logical,intent(in)::restoring
   real(8)::saved_concentration,saved_capacity,saved_stock,saved_cumulative(3),values(7)
   integer(int64)::saved_limits
   integer::ios
   type(aquifer_solute_result)::candidate
   if(swbr/=1.or.swmacro/=0)error stop 'Foreign aquifer native policy'
   if(restoring)then
      read(unit,iostat=ios)saved_concentration,saved_capacity,saved_stock,saved_cumulative,saved_limits
      if(ios/=0)error stop 'Incomplete original aquifer state'
      if(.not.all(ieee_is_finite([saved_concentration,saved_capacity,saved_stock,saved_cumulative]))) &
         error stop 'Nonfinite original aquifer state'
      if(saved_capacity/=aq_capacity.or.saved_stock<0d0.or.any(saved_cumulative(2:3)<0d0).or.saved_limits<0) &
         error stop 'Foreign or negative original aquifer state'
      call evaluate_aquifer_solute_reservoir(saved_concentration,aq_storage_factor,daquif,0d0,0d0,decsat,0d0,candidate,ios)
      if(ios/=AQ_OK)error stop 'Invalid original aquifer native concentration'
      if(abs(candidate%stock_before_mg_cm2-saved_stock)>1d-10)error stop 'Unbalanced original aquifer native stock'
      cdrain=saved_concentration;cseep=cdrain
      aq_soil_cumulative=saved_cumulative(1);aq_surface_cumulative=saved_cumulative(2);aq_decay_cumulative=saved_cumulative(3)
      aq_limited_steps=saved_limits
   else
      call hybrid_aquifer_cumulative(values)
      write(unit)values(1),values(2),values(3),values(4:6),aq_limited_steps
   end if
end subroutine
end submodule MOD_Solute_CDE""")
    return body.replace('\n','\r\n').encode('cp1252')+tail


def reference_csv(original):
    body=original.decode('cp1252').replace('\r\n','\n')
    anchor='   use MOD_solute,               only: imsqprec, imsqirrig, imsqbot, imsqdra, imdectot, imrottot, sampro, sbaldev, sdstor'
    if body.count(anchor)!=1:raise ValueError('Changed original aquifer observer import')
    body=body.replace(anchor,anchor+', hybrid_aquifer_cumulative')
    anchor='   real(8)           :: dstor_1, dstor_2, baldev_1, baldev_2'
    if body.count(anchor)!=1:raise ValueError('Changed original aquifer observer declaration')
    body=body.replace(anchor,anchor+'\n   real(8)::aq_values(7)')
    anchor='   dstor_1    = wasrdm1 - iwasrdm1beg'
    if body.count(anchor)!=1:raise ValueError('Changed original aquifer observer output')
    body=body.replace(anchor,"   call hybrid_aquifer_cumulative(aq_values)\n"
        "   write(*,'(a,7(1x,es25.17e3))')'AQUIFER_CUMULATIVE',aq_values\n"
        "   write(*,'(a,9(1x,es25.17e3))')'AQUIFER_SOIL',sampro,sdstor,imsqprec,imsqirrig,imsqbot,imsqdra,imdectot,imrottot,sbaldev\n"+anchor)
    return body.replace('\n','\r\n').encode('cp1252')
