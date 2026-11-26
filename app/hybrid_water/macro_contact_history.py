"""Field contact43 and accepted RATE reference48; no event-clock change."""
from donor_sources import replace

def render_rate(source):
    source=source.replace('\r\n','\n')
    source=replace(source,'      t1900 = t1900','      call macro_contact_invalidate()\n      t1900 = t1900')
    source=replace(source,'      if (ITask == 1) return','      call macro_contact_seal(ITask)\n      if (ITask == 1) return')
    a=source.index('      subroutine ABSORPTION');b=source.index('      subroutine RAPIDDRAIN',a)
    body=source[a:b]
    body=replace(body,'      use variables,     only: thetas, theta, thetar, dt, h, k','      use variables,     only: thetas, theta, thetar, dt, h, k,t1900\n      use MOD_swap_mp,only:GwlFlCpZo')
    decl='''      real(8)::contact,wet_top,wet_span,overlap,wet_rate
      real(8),save::ref_delta(madm,macp)=0d0,ref_heads(macp),ref_t,ref_dt
      logical,save::ref_mask(madm,macp)=.false.,ref_ready=.false.
      integer,save::ref_generation=0,ref_stamp=-1
      integer::ref_task
      real(8)::ref_get_delta(madm,macp)
      logical::ref_get_mask(madm,macp)
'''
    body=replace(body,'      implicit none','      implicit none\n'+decl)
    needle='      icBt = min0(ICpBtDm(id),ICpTpSatZon-1)'
    # Retain the original explanatory comment on this exact line.
    i=body.index(needle);e=body.index('\n',i)
    body=body[:e]+'''\n      if(swmbf==1)icBt=min0(ICpBtDm(id),ICpTpSatZon)'''+body[e:]
    needle='      do ic = icTp, icBt'
    body=body.replace(needle,needle+'''\n         if(swmbf==1.and.ic==ICpTpSatZon)then
            if(h(ic)>=0d0)cycle
         end if''')
    needle='            Lay       = Layer(ic)'
    body=replace(body,needle,'''            contact=1d0
            if(swmbf==1.and.ic==ICpTpSatZon)then
               wet_top=min(z(ic)+.5d0*dz(ic),ZWaLevDm(id))
               wet_span=max(0d0,wet_top-(z(ic)-.5d0*dz(ic)))
               if(wet_span<=0d0)cycle
               overlap=max(0d0,wet_top-max(z(ic)-.5d0*dz(ic),GwlFlCpZo))
               contact=min(1d0,max(0d0,overlap/wet_span))
               if(contact<=0d0)cycle
            end if
'''+needle)
    needle='            if (AbsSorp > SorpFac*AbsDarc) then'
    body=replace(body,needle,'''            if(swmbf==1.and.ic==ICpTpSatZon)then
               AbsSorp=contact*AbsSorp;AbsDarc=contact*AbsDarc
            end if
'''+needle)
    needle='               FlEndSrpEvt(id,ic) = .FALSE.'
    body=replace(body,needle,needle+'''
               if(swmbf==1.and.swabs==1.and.ic==ICpTpSatZon)then
                  wet_rate=1d0
                  if(ic==ICpTpWaSrDm(id))wet_rate=FrMpWalWet(id,ic)
                  ref_delta(id,ic)=AwlCorFac(ic)*PpDmCp(id,ic)*(4d0/DiPoCp(ic))*wet_rate*contact &
                     *SorpDmCp(id,ic)*(sqrt(TimAbsCumDmCp(id,ic)+dt)-sqrt(TimAbsCumDmCp(id,ic)))
                  ref_mask(id,ic)=.true.
               end if''')
    entry='''      return
      entry macro_contact_invalidate()
      ref_ready=.false.;ref_mask=.false.;ref_delta=0d0;ref_generation=ref_generation+1
      return
      entry macro_contact_seal(ref_task)
      ref_ready=swmbf==1.and.swabs==1.and.ref_task==1
      ref_t=t1900;ref_dt=dt;ref_stamp=ref_generation
      ref_heads(1:numnod)=h(1:numnod)
      return
      entry macro_contact_take(ref_get_delta,ref_get_mask)
      if(.not.ref_ready.or.ref_t/=t1900.or.ref_dt/=dt.or.ref_stamp/=ref_generation) &
         error stop 'Contact reference stale or consumed'
      if(any(ref_heads(1:numnod)/=h(1:numnod)))error stop 'Contact reference head mismatch'
      ref_get_delta=ref_delta;ref_get_mask=ref_mask;ref_ready=.false.
      return
'''
    i=body.rfind('      return\n      end');assert i>=0
    body=body[:i]+entry+body[i+len('      return\n'):]
    return source[:a]+body+source[b:]

def render_macro(source):
    source=source.replace('\r\n','\n')
    source=replace(source,'      ICpTpSatZon = NodGwlFlCpZo\n      call MACROSTATE ()','      ICpTpSatZon = NodGwlFlCpZo\n      call MACROSTATE (.true.)')
    a=source.index('SUBROUTINE MACROSTATE ()');b=source.index('end subroutine MacroState',a)
    body=source[a:b]
    body=replace(body,'SUBROUTINE MACROSTATE ()','SUBROUTINE MACROSTATE (initializing)')
    body=replace(body,'      use variables,     only: dt','      use variables,     only: dt,h,t1900')
    body=replace(body,'      real(8) Time, VlHlp, MPWatbal','''      real(8) Time, VlHlp, MPWatbal
      logical,intent(in),optional::initializing
      logical::is_initial
      real(8)::accepted_delta(madm,macp)
      logical::accepted_mask(madm,macp)
      integer,save::contact_log=0''')
    body=replace(body,'      WaSrMp            = 0.d0', '''      is_initial=.false.
      if(present(initializing))is_initial=initializing
      if(.not.is_initial.and.swmbf==1.and.swabs==1)call macro_contact_take(accepted_delta,accepted_mask)
      WaSrMp            = 0.d0''')
    needle='           ICpBtUnsMtxDm = min0(ICpBtDm(id),ICpTpSatZon-1)'
    body=replace(body,needle,needle+'''
            if(.not.is_initial.and.swmbf==1.and.ICpTpSatZon<=NumNod)then
               if(h(ICpTpSatZon)<0d0)ICpBtUnsMtxDm=min0(ICpBtDm(id),ICpTpSatZon)
            end if''')
    start=body.index('                  ThtSrpRefDmCp(id,ic) = ThtSrpRefDmCp(id,ic) +AwlCorFac(ic)')
    end=body.index('                  TimAbsCumDmCp(id,ic) =',start)
    old=body[start:end]
    new='''                  if(swmbf==1.and.ic==ICpTpSatZon)then
                     if(.not.accepted_mask(id,ic))error stop 'Missing accepted contact reference'
                     ThtSrpRefDmCp(id,ic)=ThtSrpRefDmCp(id,ic)+accepted_delta(id,ic)
                     if(contact_log==0)open(newunit=contact_log,file='macro_contact_history.txt',status='replace')
                     write(contact_log,*)t1900,dt,id,ic,Time,accepted_delta(id,ic),ThtSrpRefDmCp(id,ic)
                  else
'''+old+'''                  end if
'''
    body=body[:start]+new+body[end:];source=source[:a]+body+source[b:]
    # Both attempt save and restore invalidate ephemeral accepted-RATE evidence.
    a=source.index('SUBROUTINE MACROSTATEVAR');b=source.index('end subroutine MacroStateVar',a)
    body=source[a:b];body=replace(body,'      select case (task)','      call macro_contact_invalidate()\n      select case (task)')
    return source[:a]+body+source[b:]
