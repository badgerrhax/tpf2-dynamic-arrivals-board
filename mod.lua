local construction = require "bh_dynamic_arrivals_board/bh_construction_hooks"

function data()
	return {
		info = {
			minorVersion = 0,
			severityAdd = "CRITICAL",
			severityRemove = "CRITICAL",
			name = _("Dynamic Arrivals Board [BETA]"),
			description = [[
[h1]EARLY BETA VERSION - EXPECT BUGS AND INCOMPATIBILITIES[/h1]
I've marked this mod CRITICAL severity for adding / removing from save games - only because it is still in development
and based on feedback / bug reports, I may have to make significant changes. That said, my testing indicates no critical issues
with removing it - it just replaces the boards with the default cube and I don't think this mod does anything particularly critical.

[b]DURING BETA, PLEASE BACK UP YOUR SAVE GAMES BEFORE SAVING THIS MOD IN THEM[/b]
Pretty good general advice when experimenting with new mods, really :)

I'm making this available for people to help with testing - at this stage I'm quite confident that the functionality is OK,
but I'm looking for indications on how well it performs on various computers and map sizes, station sizes, etc.

I am also looking for mods that might stop this working - e.g. the Timetables mod which is already under investigation.

The way this works is potentially quite expensive so all feedback is welcome.

When I am happy with the quality and performance I will remove all these beta warnings.

[h1]Main Features[/h1]
- Single Terminal Arrivals Display - place it on a platform and it will automatically display the next arriving trains to that platform
- Station Departures Display - place is anywhere near a station and it will display up to the next 8 trains and their destinations / platform / departure times

[h1]Known issues[/h1]
- The terminal detection is quite limited, it currently uses the vehicle override nodes on the terminals (i.e. where the train stops) and will have improved accuracy before leaving the beta phase
- Line destination calculations may be wrong for some lines - it depends how they are defined. If you have lines that it gets wrong, please provide the list of stops and expected destinations. It may or may not be possible to automatically calculate - e.g. I don't think it'll ever work for "circular" lines without manual configuration
- The ETA calculations are based on previous arrival times and segment travel times - if the vehicle has not travelled the line at least once, this data will be incomplete.
- [b]You must pause the game before editing / deleting the assets[/b] - the asset is regularly "replaced" so by the time you've clicked bulldoze, the thing you tried to bulldoze isn't there anymore.

[h1]Extensibility[/h1]
This is designed to work as a base mod for other modders to create their own displays too. There's a construction registration API where you can tell it about your
display construction and it will manage its display updates when placed in game. See the comments in mod.lua and how the included constructions use the data the engine provides.

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
				labelParamPrefix = "bh_digital_display_"
			})

			construction.registerConstruction("asset/bh_dynamic_arrivals_board/bh_digital_station_summary_display.con", {
			 singleTerminal = false,
			 clock = true,
			 maxArrivals = 8,
			 absoluteArrivalTime = true,
			 labelParamPrefix = "bh_summary_display_"
		 })
		end,
 }
end
-- TODO - something in this mod crashes when starting a new game... something about savestate between two states not matching..