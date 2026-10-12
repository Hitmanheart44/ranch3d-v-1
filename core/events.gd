extends Node
## Signal bus (autoload "Events"). Features announce things here instead of reaching into each other.
## Emit from the owner of the change (usually Game); listen from anywhere (UI, ranch, audio...).

signal week_advanced(week: int)
signal money_changed(money: int)
signal monster_added(m: MonsterData)
signal monster_removed(m: MonsterData)
signal active_changed(m: MonsterData)
signal game_loaded
