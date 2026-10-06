class_name Faction
extends RefCounted
## Approved factions, docs/PRODUCT_BASELINE.md sections 3 and 5.
## Do not add, rename or remove factions without an explicit user decision.
##
## NEUTRAL marks neutral cards only; every hero belongs to one of the four factions.
## Data files reference factions by key name, e.g. "ASHRAVAEL".

enum Id {
	ASHRAVAEL, ## Ашравайль — hero Kezharyn.
	NERQATHEN, ## Неркатен — hero Vhorazel.
	DUMORYSS, ## Думорисс — hero Syrraveth.
	KHEVARUUN, ## Кеваруун — hero Tazhyrion.
	NEUTRAL, ## Neutral cards.
}
