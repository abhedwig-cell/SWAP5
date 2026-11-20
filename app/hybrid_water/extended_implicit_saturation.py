"""Remove the proved default Mualem near-saturation conductivity jump.

Only the selected implicit extended composition may call this renderer.
Scientific admission requires the separate reference-defect component evidence.
"""

def source(text):
 begin=text.index('      real(8) function hconduc');end=text.index('      end function hconduc',begin)
 body=text[begin:end];old='                  else if (relsat > (1.0d0-1.0d-6)) then'
 assert body.count(old)==1
 body=body.replace(old,'                  else if (relsat >= 1.0d0) then',1)
 text=text[:begin]+body+text[end:]
 begin=text.index('      real(8) function dhconduc');end=text.index('      end function dhconduc',begin)
 body=text[begin:end];old='h_enpr(node)>h_crit.and.relsat>1d0-1d-6'
 assert body.count(old)==1
 body=body.replace(old,'h_enpr(node)>h_crit.and.relsat>=1d0',1)
 return text[:begin]+body+text[end:]


def enabled(project):
    from extended_drainage import selection
    selected=selection(project)
    return bool(selected and selected.get('swkimpl'))
