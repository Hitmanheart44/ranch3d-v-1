class_name GameCalendar
extends RefCounted
## Date labels. The year is 48 weeks: 12 months of 4 weeks. (Schedule holds the event calendar; this is just presentation.)

const MONTHS := ["Early Spring", "Spring", "Late Spring", "Early Summer", "Summer", "Late Summer", "Early Autumn", "Autumn",
	"Late Autumn", "Early Winter", "Winter", "Late Winter"]


static func label() -> String:
	return label_of(Game.week)


static func label_of(abs_week: int) -> String:
	var w := abs_week - 1
	return "Year %d  ·  %s  ·  Week %d" % [w / 48 + 1, MONTHS[(w / 4) % 12], w % 4 + 1]
