local func = require "jct/func"

local oldPostRunFn = function()
    local tracks = api.res.trackTypeRep.getAll()
    local trackModuleList = {}
    local trackIconList = {}
    local trackNames = {}
    for __, trackName in pairs(tracks) do
        local track = api.res.trackTypeRep.get(api.res.trackTypeRep.find(trackName))
        local trackName = trackName:match("(.+).lua")
        local baseFileName = ("jct/tracks/%s"):format(trackName)
        for __, catenary in pairs({false, true}) do
            local mod = api.type.ModuleDesc.new()
            mod.fileName = ("%s%s.module"):format(baseFileName, catenary and "_catenary" or "")
            
            mod.availability.yearFrom = track.yearFrom
            mod.availability.yearTo = track.yearTo
            mod.cost.price = 0
            
            mod.description.name = track.name .. (catenary and _("MENU_WITH_CAT") or "")
            mod.description.description = track.desc .. (catenary and _("MENU_WITH_CAT") or "")
            mod.description.icon = track.icon
            
            mod.type = "jct_track"
            mod.order.value = 0
            mod.metadata = {
                isTrack = true,
                width = track.trackDistance,
                realWidth = track.trackDistance,
                type = "jct_track"
            }
            
            mod.category.categories = catenary and {_("TRACK_CAT")} or {_("TRACK")}
            
            mod.updateScript.fileName = "construction/jct/track_module.updateFn"
            mod.updateScript.params = {
                trackType = trackName .. ".lua",
                catenary = catenary,
                trackWidth = track.trackDistance
            }
            
            mod.getModelsScript.fileName = "construction/jct/track_module.getModelsFn"
            mod.getModelsScript.params = {}
            
            api.res.moduleRep.add(mod.fileName, mod, true)
        end
        table.insert(trackModuleList, baseFileName)
        table.insert(trackIconList, track.icon)
        table.insert(trackNames, track.name)
    end
    
    local streetModuleList = {}
    local streetIconList = {}
    local streetNames = {}
    local streets = api.res.streetTypeRep.getAll()
    for __, streetName in pairs(streets) do
        local street = api.res.streetTypeRep.get(api.res.streetTypeRep.find(streetName))
        if (#street.categories > 0 and not streetName:match("street_depot/") and not streetName:match("street_station/")) then
            local nBackward = #func.filter(street.laneConfigs, function(l) return (l.forward == false) end)
            local isOneWay = nBackward == 0
            local baseFileName = ("jct/streets/%s"):format(streetName:match("(.+).lua"))
            for i = 1, (isOneWay and 2 or 1) do
                local isRev = i == 2
                local mod = api.type.ModuleDesc.new()
                mod.fileName = ("%s%s.module"):format(baseFileName, isRev and "_rev" or "")
                
                mod.availability.yearFrom = street.yearFrom
                mod.availability.yearTo = street.yearTo
                mod.cost.price = 0
                
                mod.description.name = street.name
                mod.description.description = street.desc
                mod.description.icon = street.icon
                
                mod.type = "jct_track"
                mod.order.value = 0
                mod.metadata = {
                    isTrack = true,
                    width = street.streetWidth + street.sidewalkWidth * 2,
                    realWidth = street.streetWidth + street.sidewalkWidth * 2,
                    type = "jct_track"
                }
                
                mod.category.categories = {isRev and _("ONE_WAY_REV") or isOneWay and _("ONE_WAY") or _("STREET")}
                
                mod.updateScript.fileName = "construction/jct/track_module.updateFn"
                mod.updateScript.params = {
                    isStreet = true,
                    isRev = isRev,
                    trackType = streetName,
                    catenary = false,
                    trackWidth = street.streetWidth + street.sidewalkWidth * 2
                }
                mod.getModelsScript.fileName = "construction/jct/track_module.getModelsFn"
                mod.getModelsScript.params = {}
                
                api.res.moduleRep.add(mod.fileName, mod, true)
            end
            table.insert(streetModuleList, baseFileName)
            table.insert(streetIconList, street.icon)
            table.insert(streetNames, street.name)
        end
    end
    
    for i, wall in ipairs({"concrete_wall", "brick_wall", "brick_2_wall", false}) do
        local mod = api.type.ModuleDesc.new()
        mod.fileName = ("jct/jct_%s.module"):format(wall or "wall")
        
        mod.availability.yearFrom = 0
        mod.availability.yearTo = 0
        mod.cost.price = 0
        
        mod.description.name = _(("MENU_%s_NAME"):format(string.upper(wall or "wall")))
        mod.description.description = _(("MENU_%s_DESC"):format(string.upper(wall or "wall")))
        mod.description.icon = _(("ui/jct/%s.tga"):format(wall or "wall"))
        
        mod.type = "jct_wall"
        mod.order.value = i
        mod.metadata = {
            isTrack = false,
            width = 1,
            realWidth = 0.5,
            type = "jct_wall"
        }
        
        mod.category.categories = {_("STRUCTURE")}
        
        mod.updateScript.fileName = "construction/jct/wall_module.updateFn"
        mod.updateScript.params = {
            wallType = wall,
            width = 0.5
        }
        mod.getModelsScript.fileName = "construction/jct/wall_module.getModelsFn"
        mod.getModelsScript.params = {}
        
        api.res.moduleRep.add(mod.fileName, mod, true)
    end
    
    local con = api.res.constructionRep.get(api.res.constructionRep.find("jct/jct.con"))
    
    for c = 1, #con.constructionTemplates do
        local data = api.type.DynamicConstructionTemplate.new()
        for i = 1, #con.constructionTemplates[c].data.params do
            local p = con.constructionTemplates[c].data.params[i]
            local param = api.type.ScriptParam.new()
            param.key = p.key
            param.name = p.name
            if (p.key == "trackType") then
                param.values = trackNames
            elseif (p.key == "streetType") then
                param.values = streetNames
            else
                param.values = p.values
            end
            param.defaultIndex = p.defaultIndex or 0
            param.uiType = p.uiType
            data.params[i] = param
        end
        con.constructionTemplates[c].data = data
    end
    con.createTemplateScript.fileName = "construction/jct/create_template.fn"
    con.createTemplateScript.params = {trackModuleList = trackModuleList, streetModuleList = streetModuleList}
end

function data()
    return {
        info = {
            minorVersion = 0,
            severityAdd = "NONE",
            severityRemove = "NONE",
            name = _("MOD_NAME"),
            description = _("MOD_DESC"),
            authors = {
                {
                    name = "Enzojz",
                    role = "CREATOR",
                    text = "Idea, Scripting, Modeling, Texturing",
                    steamProfile = "enzojz",
                    tfnetId = 27218,
                }
            },
            tags = {"Track", "Street Construction", "Station", "Train Station", "Track Asset"},
        },
        postRunFn = function(settings, params)
            oldPostRunFn()
            
            
            local tracks = api.res.trackTypeRep.getAll()
            local trackModuleList = {}
            local trackIconList = {}
            local trackNames = {}
            for i, trackName in pairs(tracks) do
                local track = api.res.trackTypeRep.get(api.res.trackTypeRep.find(trackName))
                local trackName = trackName:match("(.+).lua")
                local baseFileName = ("jct2/tracks/%s"):format(trackName)
                local mod = api.type.ModuleDesc.new()
                mod.fileName = ("%s.module"):format(baseFileName)
                
                mod.availability.yearFrom = track.yearFrom
                mod.availability.yearTo = track.yearTo
                mod.cost.price = 0
                
                mod.description.name = track.name
                mod.description.description = track.desc
                mod.description.icon = track.icon
                
                mod.type = "jct_track"
                mod.order.value = i + 1
                mod.metadata = {
                    typeName = "jct_track",
                    isTrack = true,
                    width = track.trackDistance,
                    height = track.railBase + track.railHeight,
                    typeId = 1,
                    scriptName = "construction/jct2/track",
                    preProcessAdd = "preProcessAdd",
                    preProcessRemove = "preProcessRemove",
                    slotSetup = "slotSetup",
                    preClassify = "preClassify",
                    postClassify = "postClassify",
                    gridization = "gridization"
                }
                
                mod.category.categories = {_("TRACK")}
                
                mod.updateScript.fileName = "construction/jct2/track.updateFn"
                mod.updateScript.params = {
                    trackType = trackName .. ".lua",
                    trackWidth = track.trackDistance
                }
                
                mod.getModelsScript.fileName = "construction/jct2/track.getModelsFn"
                mod.getModelsScript.params = {}
                
                api.res.moduleRep.add(mod.fileName, mod, true)
                table.insert(trackModuleList, baseFileName)
                table.insert(trackIconList, track.icon)
                table.insert(trackNames, track.name)
            end
        end
    }
end
