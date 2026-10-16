# SWAP-019: daily returned leaf DM counted again at harvest

Status: confirmed original implementation defect; corrected-reference admission
candidate B1.12. SWAP5 partial-return production remains outside this unit.

Immutable B0 and ordered B1.11 have identical target preimages for wofost.f90 and
wofostnut.f90. The B0 member manifest records their SHA256 values. Earlier admitted
patches do not modify either member. B1.11 grows dead-leaf stock by all leaf death,
but its N routine already returns fraction f of daily leaf DM/N to soil. It removes
returned N from retained leaf N, while returned DM remains in DWLV and is sent to
soil again at harvest. Original ordinary source execution produces327.1kg soil DM
from300kg initial biomass without assimilation, although N closes.

The physical rule is that material already transferred to soil cannot remain in
the aboveground physical stock. Actual classical WOFOST with active crop N must
add only(1-f) leaf death to DWLV. Daily pending input remains f times death, and
harvest applies its fraction to the material still retained above ground.

The two-member correction exposes the existing fraction and guards the corrected
increment by actual state, SWCROPSNM=1 and SW_WOFOST=1. This last condition refines
PR1263's broader candidate: soybean and grass management have separate unqualified
removal semantics and retain their complete original shared-update behavior.
Their original behavior is not newly scientifically admitted by preservation.
No N equation, stem/root rule, forcing, soil chemistry or SWAP5 state changes.

For the corrected route, expected soil-DM reduction is harvest_leaf_fraction*f*
cumulative_leaf_death. Soil DM plus nonreturned harvest/exported material equals
initial DM plus actual source growth. Independent leaf/stem harvest fractions
close N as well. f=0, N-OFF and potential behavior are unchanged. B1.11 remains
immutable; historical evidence stays pinned to its original exact reference.
