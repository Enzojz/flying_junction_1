function data()
    return {
        info = {
            minorVersion = 2,
            severityAdd = "NONE",
            severityRemove = "CRITICAL",
            name = _("Concrete Flying Junction"),
            description = _([[Typical Concrete Flying Junction in Europe.
This is the very first release of the project. Please take attention the usage in important game saves.

* Available via Passenger station menu *
* Attention: this MOD may change the bridge order for other bridge MODs, take attention with use on saved games with other bridge MODs installed.

Implemented functions:
* 1 ~ 6 tracks for upper or lower level
* Crossing angle between 10° and 89° with increment of 1°
* Track grouping of tunnels by 1, 2 or no grouping
* Left handed or right handed
* Build with slope
* Altitude Adjustment

To be implemented functions:
* Curves over flying junction
* Option of parallel track raising
* Cosmetics

Changelog:
1.2
* Fixed issue with change of original in-game bridges in saved games.
1.1
* Changed altitude options for a more accurate adjustment, and avoid brdige failure by default 

--------------- 
* Planned projects 
- Elevated station 
- Underground station with visible platforms
- Crossing station 
- Curved station 
            ]]),
            authors = {
                {
                    name = "Enzojz",
                    role = "CREATOR",
                    text = "Idee, Scripting",
                    steamProfile = "enzojz",
                    tfnetId = 27218,
                },
            },
            tags = {"Train Station", "Station", "Bridge", "Track"},
        },
    }
end
