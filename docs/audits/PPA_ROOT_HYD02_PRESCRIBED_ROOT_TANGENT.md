# PPA-ROOT-HYD02 prescribed-root tangent coverage

**Status:** preregistered before production-source mutation.

HYDRO-MEMORY ACC02 requires a root-active real SWAP + groundwater predictor/corrector trajectory. The existing accepted-trajectory directional service currently fails closed whenever any root-sink provider is associated. That is correct for an arbitrary state-dependent root-uptake owner, but it is unnecessarily broad for the already admitted `b110_root_sink_provider_t`.

That concrete provider carries a prescribed root-extraction vector. During one trial its values do not depend on pressure head, water content or the groundwater-control coordinate. Its direct derivative with respect to the coupling control is therefore exactly zero. The physical root sink remains present in the principal Richards residual; only its *directional* contribution is zero.

This workunit may admit only that concrete provider. Every other root-sink implementation remains fail-closed.

The production change is restricted to five directional/coupling contract files. No Richards equation, HeadCalc residual, temporal indicator, solver tolerance, mass gate, retry policy, root-sink magnitude or application-accuracy value may change.

Qualification is by equivalence: a prescribed ROOT sink and the same vector carried through the already admitted GENERIC sink route must produce identical physical candidates, accepted-trajectory directions and integrated bottom-exchange derivatives. Root coverage must be transported explicitly through accepted-substep composition and publication, and the MODFLOW6 tangent endpoint may claim root coverage only from that provenance. Existing F-KT21 and F-GC31 directional behavior must be preserved.
