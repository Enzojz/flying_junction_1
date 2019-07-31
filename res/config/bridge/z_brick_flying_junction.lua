local path = "bridge/rail/brick_flying_junction/"
function data()
    return {
        name = _("Brick Flying Junction"),
        
        yearFrom = 1840,
        yearTo = 0,
        
        carriers = {"RAIL"},
        
        pillarBase = {path .. "infra_junc_pillar_btm_side.mdl", path .. "infra_junc_pillar_btm_rep.mdl"},
        pillarRepeat = {path .. "infra_junc_pillar_btm_side.mdl", path .. "infra_junc_pillar_btm_rep.mdl"},
        pillarTop = {path .. "infra_junc_pillar_top_side.mdl", path .. "infra_junc_pillar_top_rep.mdl"},
        
        railingBegin = {path .. "infra_junc_railing_rep_side.mdl", path .. "infra_junc_railing_rep_rep.mdl"},
        railingRepeat = {path .. "infra_junc_railing_rep_side.mdl", path .. "infra_junc_railing_rep_rep.mdl"},
        railingEnd = {path .. "infra_junc_railing_rep_side.mdl", path .. "infra_junc_railing_rep_rep.mdl"},
        
        cost = 540.0,
    }
end
