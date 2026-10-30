# Original Hupsel dry-front temporal defect

Experimental numerical policy, not production admission.

The original day566 continuation with literal PONDMX=.2, RSRO=.5, RSROEXP=1 proceeds but requires tens of thousands of full/half assessments. Read-only paired-contact observations identify the maximum defect at dry node3: at endpoint566.1582734681, full/half pressure heads are -834.85492276095/-834.85407959829cm and water contents .17005040329826/.17005045510732; top heads are -98.38333/-98.38342cm, with zero ponding. This is a dry retention tail, not evidence of the near-saturation conductivity shortcut diagnosed independently in Grassgrowth. No continuous-conductivity flag is selected.

The existing mixed pressure/storage/Darcy temporal metric now uses the standard absolute/relative pressure defect on the new explicit Black+Rutter+accepted-water-trace composition only: abs(hfull-hhalf)/max(1cm,abs(hfull),abs(hhalf)). The absolute one-cm pressure scale is inherited from the Grassgrowth experimental dry-pressure policy b9e6565. All absolute water storage, ponding, groundwater/drainage exchange, interior/bottom/surface Darcy and canopy-history certificates remain active with their existing tolerances. Newton controls, physical flux laws, crop inputs and SWKIMPL remain unchanged. Other compositions keep their prior metric.

This source requires actual original whole-project O0/O2 execution, exact native restart and donor comparison before qualification. A full project run is distinct from scientific equivalence.
