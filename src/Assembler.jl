# Assembler.jl
# This module provides the main, high-level function to generate a complete
# biogeochemical seed by assembling and standardizing the outputs of all
# other predictive modules.

module Assembler

# Import functions from sibling modules within the package.
using ..Provinces
using ..Macronutrients
using ..Micronutrients
using ..OrganicMatter
using Logging # Use Julia's built-in logging framework

export generate_seed

#= --- Master Metabolite Dictionary --- =#

# This dictionary maps internal names to standardized BiGG IDs.
# Note: Organic matter components are now handled directly by OrganicMatter.jl
# and are returned with their correct BiGG IDs, so they are no longer in this map.
const MASTER_METABOLITE_MAP = Dict(
    # Macronutrients
    "phosphate" => "pi_e",
    "nitrate" => "no3_e",
    "silicate" => "si_e",
    "ammonium" => "nh4_e",

    # Micronutrients (Metals)
    "Fe" => "fe2_e",
    "Zn" => "zn2_e",
    "Cd" => "cd2_e",
    "Ni" => "ni2_e",
    "Cu" => "cu2_e",
    "Co" => "cobalt2_e",
    "Mn" => "mn2_e",

    # Micronutrients (Vitamins)
    "B1" => "thm_e",
    "B12" => "cbl1_e",
)


#= --- Public Interface --- =#

"""
    generate_seed(lat::Real, lon::Real, depth::Real, shapefile_path::String) -> Union{Dict{String, Any}, Nothing}

    The main user-facing function. Generates a complete, standardized environmental seed.
"""
function generate_seed(lat::Real, lon::Real, depth::Real, shapefile_path::String)
    @info "--- Generating Environmental Seed ---"
    @info "Location: Lat=$lat, Lon=$lon, Depth=$depth m"

    # Step 1: Determine the biogeochemical context
    biome, prov_code = get_biome(lat, lon, shapefile_path)

    if isnothing(biome)
        @warn "Location is on land or outside a defined province. No seed generated."
        return nothing
    end
    @info "Identified Province: $prov_code (Biome: $biome)"

    # Step 2: Calculate all chemical component concentrations
    macronutrients = get_macronutrients(biome, depth)
    micronutrients = get_micronutrients(biome, macronutrients)
    organic_matter = get_organic_matter(biome, depth)

    if any(isnothing, [macronutrients, micronutrients, organic_matter])
        @error "A critical calculation step failed. Could not generate complete seed."
        return nothing
    end
    @info "Successfully calculated all raw chemical component concentrations."

    # Step 3: Assemble and standardize the final seed
    # Merge all dictionaries. Note that organic_matter now contains BiGG IDs directly.
    raw_seed_data = merge(macronutrients, micronutrients, organic_matter)
    standardized_seed = Dict{String, Any}()

    for (key, concentration) in raw_seed_data
        # If the key is in our map, translate it to the BiGG ID.
        # Otherwise, assume the key is already a BiGG ID (from OrganicMatter.jl)
        # or metadata (like DOC_total) and use it directly.
        final_key = get(MASTER_METABOLITE_MAP, key, key)
        standardized_seed[final_key] = concentration
    end

    # Step 4: Add required metadata to the final seed
    # Note: Bulk DOC/POC are now moved to metadata
    standardized_seed["metadata"] = Dict(
        "latitude" => lat,
        "longitude" => lon,
        "depth_m" => depth,
        "province_code" => prov_code,
        "biome" => biome,
        "DOC_total_umolC_kg" => pop!(standardized_seed, "DOC_total"),
        "POC_total_umolC_kg" => pop!(standardized_seed, "POC_total"),
        "units" => "Concentrations in umol/kg, except Fe in nmol/kg"
    )
    
    @info "Seed generation complete. Output is standardized to BiGG IDs."
    return standardized_seed
end

end # module Assembler

