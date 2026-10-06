# Resolved forcing and remaining physical owners

Baseline: `78acf56f931763d2e1d4924b3dea0742f231d2e8`.
This review changes master-ledger dispositions and migration contracts. It does
not introduce production physics or widen an owning admission.

## Rain input representation

`SWRAIN=2` supplies a daily amount and WET duration. In `MOD_meteo.f90`, the
reader converts this into an explicit midnight-start constant-rate interval,
followed by zero rain. `SWRAIN=3` supplies end-stamped amounts; LoadRainData
converts each amount from mm into a cm/day interval rate and reconstructs daily
amounts by integration. Neither selector adds a constitutive law or persistent
physical state. The rain cursor is an executable input-delivery mechanism.

Their intended forcing capability is **SUPERSEDED** by the already admitted
immutable rate/span input in PPA-WU03 and the admitted interval-forcing entry
SW431-MET-FORCING. The mapping is explicit:

| Source data | Typed representation |
| --- | --- |
| Daily depth P cm and WET duration d days | [midnight, midnight+d] at P/d cm/day, then zero until next event |
| End-stamped amount A mm over [a,b] | Explicit span [a,b] at 0.1*A/(b-a) cm/day |
| A hydraulic substep inside a source interval | The same immutable rate, with the substep entirely inside its declared forcing span |
| Daily amount needed by another process | Integral of the explicit rates over that day, supplied at that process's typed input boundary |

The first-record/start-date policy remains an input interpretation: use the
same source interval endpoints, including the source's first-record convention,
before supplying typed spans. This is not an automatic `.rain` reader or a
calendar parser. A caller must split requests at forcing boundaries; the
adapter rejects a request extending beyond its span. No legacy cursor is
required in the physical restart state.

`probe_swap431_rain_mapping.py` compiles the literal B1.11 LoadRainData
conversion/integration block alongside the actual production adapter and its
full module dependency closure. It checks five explicit rainfall intervals,
ten contained subintervals, five out-of-span rejections, daily amount identity,
and a WET pulse plus dry remainder at O0/O2. This is a representation witness,
not an all-date parser equivalence test or a new runtime admission. Existing
PPA-WU03 qualification/admission supplies the runtime authority.

Snow, daily interception and PMdetail equations are distinct entries and keep
their own admitted envelopes and remaining compositions. The representation
decision does not admit those combinations. `SWRAIN=1` remains open because its
seasonal RAINTB intensity law *derives* a rainfall-duration distribution from
daily totals. That application-physics resolver differs from merely encoding
a duration or interval already supplied by the input.

## Macropore initialization

The current immutable geometry carries static compartment volumes, domain
fractions, potential domain bottoms and characteristic diameters. It validates
and consumes them; `initialize_fmr_macropore_standard_config` does not construct
the original depth parameterization.

B1.11 `macropore.f90` 251-499 splits cells at depth-curve boundaries, integrates
Mb and Ic curves, maps the temporary pieces back to original cells, divides Ic
volume among subdomains and derives domain endpoints and polygon diameters.
SWPOWM changes the exponent below SPoint from PowM to 1/PowM. These rules affect
physical pore volumes and exchange geometry, not just file parsing.

Decision: **MIGRATE** the typed static-geometry resolver in MC-MACRO01, first
SWPOWM0, then the alternative lower-curve exponent. Reuse the admitted immutable
geometry and its existing dynamic shrinkage/covering operators. Do not duplicate
macropore water storage or add initialization scratch to restart. The two ledger
entries are now confirmed missing resolvers, not generic replacement reviews.

## Source crop policies

`probe_swap431_nfix_replacement.py` compiles the literal B1.11 N-demand block
and current WOFOST81 provider. Six cases per optimization include three distinct
witnesses: at the source DVS cutoff, source fixation is zero while WOFOST81 is
10.2; storage demand changes 10.2 to 10.904 only in WOFOST81; new leaf growth
changes 10.2 to 10.32 only in WOFOST81, in kg N/ha/day for the chosen inputs.
The moisture threshold agrees. This does not show that either model is wrong.

Decision: **MIGRATE** a separately selected B1.11 demand policy in MC-NUT01,
with vegetative deficits, DVSNLT and RELTR gates, using one N owner and one
fixation receipt. Existing WOFOST81 semantics and admission remain unchanged.
The whole soil/crop N chain still needs its registered owners and qualification.

Actual-crop RELMF multiplication already exists. `SWPOTRELMF=2` additionally
scales the source's companion *potential* assimilation trajectory. The current
classic crop owner and prepare-assimilation result contain actual crop state
and actual_pgass, not a selector-controlled dual trajectory. Decision:
**MIGRATE** that potential-path policy in MC-CROP01 after the annual-crop
ownership contract is resolved. Do not describe actual RELMF as absent.

## Surface-water topology and donor limitation

The old SW431-SW-MULTILEVEL wording was wrong. B1.11 does not create an independent
surface-water storage owner for every drain level. In `surfacewater.f90`
drainflux_extended, levels up to NRPRI use prescribed primary WLP; remaining
levels use common secondary WLS and contribute to QDRD. With SWSEC2, the
falling-dry branch compares their net exchange with secondary storage plus
supply, then scales every secondary-level exchange by the same ratio. SWSEC1
returns before that finite-storage limiter.

The production multilevel aggregator sums resolved level exchanges but has no
primary/secondary ownership partition or shared-store donor limiter. The
restricted fixed-weir primitive owns one storage and accepts a nonnegative
configured drainage carrier. Its admission does not supply the missing native
level-group feedback or signed finite-storage depletion.

Decisions in MC-SW01:

- SW431-SW-PRIMARY: **MIGRATE** typed NRPRI group routing with distinct primary
  and secondary head carriers. Primary water remains externally prescribed;
  do not invent a primary storage equation.
- SW431-SW-MULTILEVEL: **MIGRATE** the common-secondary-store limiter and
  consistent per-level receipts. Depends on signed secondary depletion and
  accepted drainage/storage feedback. It is distinct from spatial DIVDRA.

Both replace vague envelope reviews with identified missing bindings/operators.
They do not reopen the admitted EXTENDED single-level equations, scalar
multilevel aggregation or external Ribasim profile.
