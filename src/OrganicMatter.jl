# OrganicMatter.jl
# This module calculates the concentration and biochemical composition of dissolved
# and particulate organic matter (DOC, POC, DON, DOP) based on the biome and depth.

module OrganicMatter

export get_organic_matter

#= --- Data Structures and Parameters --- =#

struct OrganicPoolParameters
    C_surf::Float64
    C_deep::Float64
    z_decay::Float64
end

const ORGANIC_PARAMS = Dict(
    "Polar" => (DOC=OrganicPoolParameters(60.0, 40.0, 100.0), POC=OrganicPoolParameters(5.0, 0.1, 150.0)),
    "Westerlies" => (DOC=OrganicPoolParameters(65.0, 40.0, 120.0), POC=OrganicPoolParameters(6.0, 0.1, 180.0)),
    "Trade-Winds" => (DOC=OrganicPoolParameters(50.0, 40.0, 200.0), POC=OrganicPoolParameters(2.0, 0.1, 250.0)),
    "Coastal" => (DOC=OrganicPoolParameters(80.0, 45.0, 80.0), POC=OrganicPoolParameters(15.0, 0.2, 100.0))
)

const BIOCHEMICAL_COMPOSITION = Dict(
    "Euphotic" => Dict(
        "Westerlies_Coastal" => (POM=Dict("protein"=>45,"carbohydrate"=>30,"lipid"=>12), DOM=Dict("protein"=>15,"carbohydrate"=>35,"lipid"=>8)),
        "Trade-Winds" => (POM=Dict("protein"=>30,"carbohydrate"=>40,"lipid"=>17), DOM=Dict("protein"=>10,"carbohydrate"=>25,"lipid"=>7))
    ),
    "Mesopelagic" => Dict("All" => (POM=Dict("protein"=>20,"carbohydrate"=>15,"lipid"=>7), DOM=Dict("protein"=>5,"carbohydrate"=>15,"lipid"=>3))),
    "Deep" => Dict("All" => (POM=Dict("protein"=>8,"carbohydrate"=>8,"lipid"=>3), DOM=Dict("protein"=>2,"carbohydrate"=>4,"lipid"=>1)))
)

const AMINO_ACID_COMPOSITION = Dict("gly_e"=>30,"ala_L_e"=>25,"leu_L_e"=>20,"ser_L_e"=>15,"thr_L_e"=>10)
const MONOSACCHARIDE_COMPOSITION = Dict("glc_D_e"=>60,"fru_e"=>20,"xyl_D_e"=>10,"arab_L_e"=>10)
const LIPID_COMPOSITION = Dict("hdca_e"=>50,"hdcea_e"=>30,"ocdca_e"=>20)

const DOM_STOICHIOMETRY = Dict(
    "Euphotic" => (CN=14.0, CP=150.0),
    "Mesopelagic" => (CN=25.0, CP=500.0),
    "Deep" => (CN=40.0, CP=1500.0)
)


#= --- Core Calculation Functions --- =#

function _calculate_bulk_pool(params::OrganicPoolParameters, depth::Real)
    z = max(0.0, depth)
    return params.C_deep + (params.C_surf - params.C_deep) * exp(-z / params.z_decay)
end

function _partition_into_monomers(total_conc::Float64, composition::Dict)
    monomer_concs = Dict{String, Float64}()
    for (bigg_id, percentage) in composition
        monomer_concs[bigg_id] = total_conc * (percentage / 100.0)
    end
    return monomer_concs
end

function _partition_pool(biome::String, depth::Real, total_conc::Float64, pool_type::String)
    composition_pool_key = pool_type == "DOC" ? "DOM" : "POM"
    depth_zone = if depth <= 150 "Euphotic" elseif depth <= 1000 "Mesopelagic" else "Deep" end

    ruleset = if depth_zone == "Euphotic"
        biome == "Trade-Winds" ? BIOCHEMICAL_COMPOSITION[depth_zone]["Trade-Winds"] : BIOCHEMICAL_COMPOSITION[depth_zone]["Westerlies_Coastal"]
    else
        BIOCHEMICAL_COMPOSITION[depth_zone]["All"]
    end
    
    # CORRECTED: Access the NamedTuple using dot notation based on the string key.
    composition_rules = if composition_pool_key == "DOM"
        ruleset.DOM
    else # Must be "POM"
        ruleset.POM
    end

    protein_conc = total_conc * (composition_rules["protein"] / 100.0)
    carb_conc = total_conc * (composition_rules["carbohydrate"] / 100.0)
    lipid_conc = total_conc * (composition_rules["lipid"] / 100.0)
    
    protein_monomers = _partition_into_monomers(protein_conc, AMINO_ACID_COMPOSITION)
    carb_monomers = _partition_into_monomers(carb_conc, MONOSACCHARIDE_COMPOSITION)
    lipid_monomers = _partition_into_monomers(lipid_conc, LIPID_COMPOSITION)
    
    return merge(protein_monomers, carb_monomers, lipid_monomers)
end

function _calculate_don_dop(doc_conc::Float64, depth::Real)
    depth_zone = if depth <= 150 "Euphotic" elseif depth <= 1000 "Mesopelagic" else "Deep" end
    ratios = DOM_STOICHIOMETRY[depth_zone]
    
    don_conc = doc_conc / ratios.CN
    dop_conc = doc_conc / ratios.CP

    return Dict("DON" => don_conc, "DOP" => dop_conc)
end


#= --- Public Interface --- =#

function get_organic_matter(biome::String, depth::Real)
    if !haskey(ORGANIC_PARAMS, biome)
        println(stderr, "Invalid biome name provided for organic matter: $biome")
        return nothing
    end

    total_doc = _calculate_bulk_pool(ORGANIC_PARAMS[biome].DOC, depth)
    total_poc = _calculate_bulk_pool(ORGANIC_PARAMS[biome].POC, depth)

    doc_components = _partition_pool(biome, depth, total_doc, "DOC")
    poc_components = _partition_pool(biome, depth, total_poc, "POC")
    don_dop = _calculate_don_dop(total_doc, depth)

    results = merge(doc_components, poc_components, don_dop)
    results["DOC_total"] = total_doc
    results["POC_total"] = total_poc

    return results
end

end # module OrganicMatter

