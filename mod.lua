function data()
	return {
		info = {
			minorVersion = 0,
			severityAdd = "NONE",
			severityRemove = "WARNING",
			name = _("Dynamic Arrivals Board"),
			description = [[
[h1]Main Features[/h1]
- Arrivals board - place it on a platform and it will display the next arriving trains (i hope!)

[b]Please report any bugs with this mod so I can try to address them.[/b]
			]],
			tags = { "British", "uk", "train" },
			visible = true,
			authors = {
				{
					name = "badgerrhax",
					role = "CREATOR"
				}
			}
		},

		postRunFn = function(settings, params)
		end
 }
end
-- TODO - something in this mod crashes when starting a new game... something about savestate between two states not matching..