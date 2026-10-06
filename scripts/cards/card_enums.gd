class_name CardEnums
extends RefCounted
## Approved card taxonomy, docs/PRODUCT_BASELINE.md section 6.
## Do not add types or rarities without an explicit user decision.
## Data files reference values by key name, e.g. "CREATURE", "LEGENDARY".

## Card types. Legendary is a rarity, not a type.
enum Type { CREATURE, SPELL, ARTIFACT, CURSE }

enum Rarity { COMMON, RARE, EPIC, LEGENDARY }
