-- Quick script for Transport Fever 2 Bridges
-- Copyright Enzojz 2020
-- Please study it and write your own code, it's easy to understand :)
-- For more information about the format required by the game visite:
-- https://www.transportfever.net/lexicon/index.php?entry/288-raw-bridge-data/
function data()
    return {
        name = "JCT_VOID",
        
        yearFrom = 1800,
        yearTo = 1800,
        
        carriers = {"RAIL", "ROAD"},
        
        speedLimit = 100,
        
        pillarLen = 0.5,
        
        pillarMinDist = 9999,
        pillarMaxDist = 9999,
        pillarTargetDist = 9999,
        noParallelStripSubdivision = true,
        
        cost = 0.0,
        
        updateFn = function(params)
            local result = {
                railingModels = {},
                pillarModels = {}
            }
            
            for _, _ in ipairs(params.pillarHeights) do
                table.insert(result.pillarModels, {{}})
            end
            
            for _, _ in ipairs(params.railingIntervals) do
                local rs = {{}}
                table.insert(result.railingModels, rs)
            end
            
            return result
        end
    }
end
