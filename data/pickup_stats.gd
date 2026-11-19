class_name PickupStats
extends Resource

enum PickupType {
	MEDKIT,
	AMMO
}

@export var pickup_type: PickupType = PickupType.MEDKIT
@export var amount: int = 2
