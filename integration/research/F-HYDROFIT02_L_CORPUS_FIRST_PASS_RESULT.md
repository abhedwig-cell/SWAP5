# F-HYDROFIT02 P-LCORP01 first-pass result

Run: `36416128598`.

The official BRO `bro-ids` endpoint for accountable party `27378529` returned 345,758 BHR-P IDs.

The preregistered first 100 lexical IDs were inspected with zero fetch failures.

Among those:

- 11 objects had survey purpose `bodemfysischOnderzoek`;
- 0 intervals contained both the required joint water-content/conductivity observation array and a stored conductivity-shape curve.

Therefore the first lexical block is not useful for source-lambda characterization.

This is not evidence that qualifying intervals are rare in the full corpus. Lexical BRO-ID order is not a sampling frame for hydrophysical content.

## Decision

Do not enumerate or download the 345,758 objects.

Use the official characteristics-search endpoint to preselect `deliveryAccountableParty=27378529` and `characteristicModelled=JA` over a deterministic bounded spatial grid. Fetch only returned candidate objects and retain only `bodemfysischOnderzoek` objects with the required arrays.

A new spatial-selection preregistration is required before using that sample to characterize lambda.
