-- Same signature placement logic as fuzzel/fuzzel.ini's prompt: a small
-- corner mark, not a header taking its own line.
Status:children_add(function()
	return ui.Line { ui.Span(" //kuro. "):fg("#5c5c5c") }
end, 5000, Status.RIGHT)
