"""Preserve one physical clock from immutable epoch and accepted local elapsed time."""
import hashlib
import math

# Complete unchanged original/qualified TimeControl bodies. Clock/step bodies
# occur literally in the admitted original CDE clock Ubuntu source archives.
PARENT_SHA={
    'interval':'88b3d17865169672767b2d53460a625e191a6f6527067261e41bd99fd98e7c84',
    'clock':'d8001b7c6fb223e369fe99ed9966dcaa0678ef8e1dce19b5e3903112af2fd1a5',
    'step':'6152a865e86248a038712891e672e22b7d2fe2ebdd54d8d36aa3dc7346408189',
}
POLICY='immutable-epoch-integer-day-accepted-local-elapsed-clock-v1'
OLD='      t1900 = t1900 + dt'
NEW='      t1900 = hybrid_groundwater_clock_epoch + dble(daycum-1) + tcum'
ANCHOR='   real(8), parameter   :: dtCrit = 1.0d-8'


def kind(selected):
    return 'step' if selected.get('cde_clock_output') and selected['flprintdt'] else 'clock' if selected.get('cde_clock_output') else 'interval'


def declaration(epoch):
    if not math.isfinite(epoch):raise ValueError('Nonfinite original Snow groundwater clock epoch')
    return '   real(8), parameter :: hybrid_groundwater_clock_epoch = '+format(epoch,'.17e').replace('e','d')+'\n'


def render(source,selected,epoch):
    source=source.replace('\r\n','\n')
    if hashlib.sha256(source.encode('cp1252')).hexdigest()!=PARENT_SHA[kind(selected)]:
        raise ValueError('Changed complete parent Snow groundwater TimeControl source')
    if source.count(OLD)!=1 or source.count(ANCHOR)!=1:
        raise ValueError('Changed original Snow groundwater clock update')
    return source.replace(OLD,NEW,1).replace(ANCHOR,declaration(epoch)+ANCHOR,1)


def validate(source,selected,epoch):
    source=source.replace('\r\n','\n');addition=declaration(epoch)
    if source.count(addition)!=1 or source.count(NEW)!=1:
        raise ValueError('Foreign actual Snow groundwater TimeControl clock provider')
    parent=source.replace(addition,'',1).replace(NEW,OLD,1)
    if hashlib.sha256(parent.encode('cp1252')).hexdigest()!=PARENT_SHA[kind(selected)]:
        raise ValueError('Foreign complete parent Snow groundwater TimeControl provider')
