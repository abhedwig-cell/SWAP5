"""Explicit execution policies for the unchanged original CDE physical block."""
from donor_sources import replace

LEGACY_SOLUTE_STEP_POLICY = 'admitted-cde-substeps-v1'
TRANSACTIONAL_SOLUTE_STEP_POLICY = 'transactional-cde-substeps-v1'
SOLUTE_STEP_POLICIES = (LEGACY_SOLUTE_STEP_POLICY, TRANSACTIONAL_SOLUTE_STEP_POLICY)


def render_transactional_cde(source):
    start=source.index('      module subroutine solute_CDE(task)')
    end=source.index('      end subroutine solute_CDE',start)
    body=source[start:end]
    values=['csurf','cpond','isqtop','dectot','imdectot','rottot','imrottot',
            'sqdra','imsqdra','sqbot','imsqbot','isqdra','sqsur','cdrain','rounderr']
    declarations='''      logical :: cde_trial_negative
      integer :: cde_trial_attempt
      real(8),allocatable :: trial_cmsy(:),trial_cml(:),trial_imqsol(:)
      real(8) :: trial_values(15)
'''
    body=replace(body,'      logical                             :: differ',
                      declarations+'      logical                             :: differ')
    body=replace(body,'         tcumsol = 0.0d0','''         if(.not.allocated(trial_cmsy))then
           allocate(trial_cmsy(numnod),trial_cml(numnod),trial_imqsol(numnod+1))
         end if
         if(size(trial_cmsy)/=numnod)error stop 'Chemical trial grid changed'
         tcumsol = 0.0d0''')
    # A chemical retry/remaining interval may be shorter than water DTMIN.
    body=replace(body,'            dtsolu  = max(dtsolu,dtmin)',
                      '            ! The independent chemical interval is not enlarged to water DTMIN.')
    begin='''            cde_trial_attempt=0
            cde_trial_loop: do
              cde_trial_attempt=cde_trial_attempt+1
              trial_cmsy=cmsy(1:numnod);trial_cml=cml(1:numnod)
              trial_imqsol=imqsol(1:numnod+1)
              trial_values=['''+', &\n                '.join(','.join(values[i:i+4]) for i in range(0,len(values),4))+''']
              cde_trial_negative=.false.
'''
    body=replace(body,'            tcumsol = tcumsol + dtsolu',begin)
    body=replace(body,'               if (cmsy(i) < vsmall) then',
        '''               if(cmsy(i)<0d0)then
                 cde_trial_negative=.true.
                 write(*,'(a,1x,i0,3(1x,es25.17e3))') 'HYBRID_CDE_RETRY',i,t1900,dtsolu,cmsy(i)*dz(i)
                 exit
               end if
               if (cmsy(i) < vsmall) then''')
    restore='\n'.join('                '+name+'=trial_values('+str(i+1)+')' for i,name in enumerate(values))
    finish='''            if(cde_trial_negative)then
                cmsy(1:numnod)=trial_cmsy;cml(1:numnod)=trial_cml
                imqsol(1:numnod+1)=trial_imqsol
'''+restore+'''
                dtsolu=0.5d0*dtsolu
                if(cde_trial_attempt>=80.or.dtsolu<=0d0.or.tcumsol+dtsolu==tcumsol) &
                  error stop 'Chemical trial cannot preserve nonnegative inventory'
                cycle cde_trial_loop
            end if
            exit cde_trial_loop
            end do cde_trial_loop
            tcumsol=tcumsol+dtsolu

'''
    body=replace(body,'! ---       solute balance in aquifer for breakthrough curve',finish+'! ---       solute balance in aquifer for breakthrough curve')
    return source[:start]+body+source[end:]
