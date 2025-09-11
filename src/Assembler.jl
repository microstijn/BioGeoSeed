# Assembler.jl
# This module provides the main, high-level function to generate a complete
# biogeochemical seed by assembling the outputs of all other predictive modules.

module Assembler

# We need to import the functions from the other modules to use them.
# The `using ..` syntax is used to access sibling modules within the same package.
using ..Provinces
using ..Macronutrients
using ..Micronutrients
using ..OrganicMatter

export generate_seed

"""
    generate_seed(lat::Real, lon::Real, depth::Real, shapefile_path::String) -> Union{Dict{String, Any}, Nothing}

    The main user-facing function of the BioGeoSeed package. It generates a
    complete, location-specific environmental seed for metabolic modeling.

    This function orchestrates the calls to all underlying predictive modules
    and assembles their outputs into a single, comprehensive dictionary.

    # Arguments
    - `lat`: Latitude (-90 to 90).
    - `lon`: Longitude (-180 to 180).
    - `depth`: Depth in meters (non-negative).
    - `shapefile_path`: The full path to the Longhurst provinces shapefile.

    # Returns
    - A `Dict` containing the complete environmental seed. Keys include nutrient
      names and component fractions, and values are their predicted concentrations.
      Also includes metadata about the location.
    - Returns `nothing` if the location is on land or if any step fails.
"""
function generate_seed(lat::Real, lon::Real, depth::Real, shapefile_path::String)
    println("--- Generating Environmental Seed ---")
    println("Location: Lat=$lat, Lon=$lon, Depth=$depth m")

    # Step 1: Determine the biogeochemical context
    biome, prov_code = get_biome(lat, lon, shapefile_path)

    if isnothing(biome)
        println("Location is on land or outside a defined province. No seed generated.")
        return nothing
    end
    println("Identified Province: $prov_code (Biome: $biome)")

    # Step 2: Calculate the concentration of each chemical group
    macronutrients = get_macronutrients(biome, depth)
    micronutrients = get_micronutrients(biome, macronutrients)
    organic_matter = get_organic_matter(biome, depth)

    if isnothing(macronutrients) || isnothing(micronutrients) || isnothing(organic_matter)
        println(stderr, "A critical calculation step failed. Could not generate complete seed.")
        return nothing
    end
    println("Successfully calculated all chemical components.")

    # Step 3: Assemble all results into a single seed dictionary
    # Start with metadata about the location and context.
    seed = Dict{String, Any}(
        "metadata" => Dict(
            "latitude" => lat,
            "longitude" => lon,
            "depth" => depth,
            "province_code" => prov_code,
            "biome" => biome
        )
    )
    
    # Merge the dictionaries from each module.
    merge!(seed, macronutrients)
    merge!(seed, micronutrients)
    merge!(seed, organic_matter)
    
    println("--- Seed generation complete. ---")
    return seed
end

end # module Assembler
