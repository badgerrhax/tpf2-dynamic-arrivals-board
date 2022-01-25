local construction = require "bh_dynamic_arrivals_board/bh_construction_hooks"

function data()
	return {
		info = {
			minorVersion = 0,
			severityAdd = "NONE",
			severityRemove = "WARNING",
			name = _("Dynamic Arrivals Board"),
			description = [[
[h1]Main Features[/h1]
- Arrivals board - place it on a platform and it will display the next arriving trains

[h1]Extensibility[/h1]
This is designed to work as a base mod for other modders to create their own displays too. There's a construction registration API where you can tell it about your
display construction and it will manage its display updates when placed in game. See documentation / comments in mod.lua and how bh_digital_display.con gets registered.

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

		runFn = function()
			construction.registerConstruction("asset/bh_dynamic_arrivals_board/bh_digital_display.con", {
				 -- when true, attaches to a single terminal. if there is a "terminal_override" param on the construction it will use the number provided by that as the terminal,
				 -- expecting 0 to be "auto detect". 0 or absence of this parameter will auto detect the closest terminal to where the construction was placed.
				 -- when true, receives info about arrivals as parameters named "arrival_<index>_dest" and "arrival_<index>_eta"
				 -- when false, attaches to the nearest station and receives data for ALL terminals in the station. parameters will be named "terminal_<id>_arrival_<index>_dest" etc.
				 -- it is up to you to decide how your construction will handle a variable number of terminals in terms of model instances and positioning.
				singleTerminal = true,

				 -- send the current game time in a parameter
				clock = true,

				 -- max number of construction params that will be populated with arrival data. there may be less. "num_arrivals" param contains count if you want it
				maxArrivals = 2,

				-- false = time from now until arrival, true = world time of arrival
				absoluteArrivalTime = false,

				-- parameter name prefix (can help avoid conflicts with other mod params)
				labelParamPrefix = "bh_digital_display_"
			})
		end,

		postRunFn = function(settings, params)
		end
 }
end
-- TODO - something in this mod crashes when starting a new game... something about savestate between two states not matching..