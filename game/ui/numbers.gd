extends RefCounted

static func number(value: float) -> String:
	var text := "%.2f" % value
	while text.ends_with("0"):
		text = text.trim_suffix("0")
	return text.trim_suffix(".")
