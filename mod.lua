local construction = require "bh_dynamic_arrivals_board/bh_construction_hooks"

function data()
	return {
		info = {
			minorVersion = 8,
			severityAdd = "WARNING",
			severityRemove = "WARNING",
			name = _("Dynamic Arrivals Board"),
			description = [[
[h1]Main Features[/h1]
- [b]Single Terminal Arrivals Display[/b] - place it on a platform and it will automatically display the next arriving trains to that platform. Use the terminal param to force a platform if it sees the wrong one.
- [b]Station Departures Display[/b] - place within 50m of a station and it will display up to the next 8 trains and their destinations / platform / times

[h1]Extra Configuration[/h1]
I wanted to try avoiding the need for a GUI but sometimes it is the simplest way. Here's what it provides so far.
- Appears when placing a sign close to multiple stations, or when you click on an existing sign
- Allows you to see which stations the sign is displaying, and to change them
- Allows you to re-scan for nearby stations without having to replace it
- Allows you to delete the sign without having to pause

[h1]Planned Features[/h1]
- Single Terminal for one vehicle with list of "calling at" stations
- Station Arrivals Display (showing origins instead of destinations)

[h1]Known issues[/h1]
- Line destination calculations may be wrong for some lines - it depends how they are defined. If you have lines that it gets wrong, please provide the list of stops and expected destinations. It may or may not be possible to automatically calculate - e.g. I don't think it'll ever work for "circular" lines without manual configuration

[h1]Limitations[/h1]
- The ETA calculations are based on previous arrival times and segment travel times - if the vehicle has not travelled the line at least once, this data will be inaccurate but will improve over time.

[h1]Extensibility[/h1]
This is designed to work as a base mod for other modders to create their own displays too. There's a construction registration API where you can tell it about your
display construction and it will manage its display updates when placed in game. See the comments in mod.lua and how the included constructions use the data the engine provides.

[b]Please report any bugs with this mod so I can try to address them.[/b]
			]],
			tags = { "Track Asset", "Misc", "Script Mod" },
			visible = true,
			authors = {
				{
					name = "badgerrhax",
					role = "CREATOR"
				}
			}
		},

		runFn = function()
			-- To add support for your own mod constructions, in your mod's runFn,
			-- require "bh_dynamic_arrivals_board/bh_construction_hooks" and call construction.registerConstruction
			-- with the path to your construction file. The engine will then send data to it.
			construction.registerConstruction("asset/bh_dynamic_arrivals_board/bh_digital_display.con", {
				 -- when true, attaches to a single terminal. if there is a "terminal_override" param on the construction it will use the number provided by that as the terminal,
				 -- expecting 0 to be "auto detect". 0 or absence of this parameter will auto detect the closest terminal to where the construction was placed.
				 -- when true, receives info about arrivals as parameters named "arrival_<index>_dest" and "arrival_<index>_time"
				 -- when false, attaches to the nearest station and receives data for ALL terminals in the station. there will be an additional parameter "arrival_<index>_terminal" containing the terminal id.
				 -- it is up to you to decide how your construction will handle a variable number of terminals in terms of model instances and positioning.
				singleTerminal = true,

				 -- send the current game time (in seconds) in a parameter "game_time" and formatted as HH:MM:SS in "time_string"
				clock = true,

				 -- max number of construction params that will be populated with arrival data. there may be less. "num_arrivals" param contains count if you want it.
				 -- if 0 there will be no arrival data provided at all (this thing becomes only a clock, basically)
				maxArrivals = 2,

				-- false = time from now until arrival, true = world time of arrival
				absoluteArrivalTime = false,

				-- parameter name prefix (can help avoid conflicts with other mod params)
				labelParamPrefix = "bh_digital_display_",
			})

			construction.registerConstruction("asset/bh_dynamic_arrivals_board/bh_digital_station_summary_display.con", {
			 singleTerminal = false,
			 clock = true,
			 maxArrivals = 8,
			 absoluteArrivalTime = true,
			 labelParamPrefix = "bh_summary_display_",
		 })
		end,
 }
end
