"""Private continuous onset for the upper saturated connection."""
import json
import sys
from pathlib import Path

import build_joint_pore_volume_candidate as previous
from build_joint_entry_candidate import ROOT, once, sha

MODEL = 'ANDELST_JOINT_PORE_VOLUME_UPPER_SUPPORT_V9'


def render(folder):
    shadow = previous.render(folder)
    name = 'src/solver/mod_b111_profile_groundwater_projection.f90'
    p = shadow[ROOT / name]
    s = once(p.read_text(),
             '    real(real64)::remaining,gap,amount,crossing,lower_head,level_delta',
             '    real(real64)::remaining,gap,amount,crossing,lower_head,level_delta,upper_support')
    s = once(s, '    projection%level_cm=connected%level_cm+level_delta', '''    ! If only the uppermost node is wet, use its linearly interpolated
    ! saturated support toward the next node. It vanishes continuously
    ! at h(1)=0 when the next resolved compartment remains unsaturated.
    upper_support=1.0_real64
    if(head(2)<0.0_real64)upper_support=head(1)/(head(1)-head(2))
    projection%level_cm=projection%level_cm+upper_support* &
      ((connected%level_cm-projection%level_cm)+level_delta)''')
    p.write_text(s, newline='\n')

    m = folder / 'MODEL.json'
    r = json.loads(m.read_text())
    r.update(model=MODEL, upper_support='The connected drainage weight grows with the resolved wet fraction when the uppermost node first becomes positive above an unsaturated neighbor.',
             rendered_sources_sha256={str(n.relative_to(ROOT)): sha(p.read_bytes()) for n, p in shadow.items()})
    m.write_text(json.dumps(r, indent=2) + '\n')
    return shadow


if __name__ == '__main__':
    previous.previous.previous.previous.drainage.current.contact.base.render = render
    previous.previous.previous.previous.drainage.current.contact.base.main()
    p = Path(sys.argv[sys.argv.index('--output') + 1]) / 'BUILD.json'
    r = json.loads(p.read_text())
    r['contact_model'] = MODEL
    p.write_text(json.dumps(r, indent=2) + '\n')

