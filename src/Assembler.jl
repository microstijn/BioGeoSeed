# Assembler.jl
# This module has been significantly updated to incorporate the new
# redox-aware framework and the final validation step for currency metabolites.
module Assembler

# Import functions from all sibling modules.
using ..Provinces, ..Macronutrients, ..Micronutrients, ..OrganicMatter, ..SeawaterChemistry, ..PhysicalModels, ..BiogeochemistryModels
using Logging
using LoggingExtras
using UnicodePlots
using DelimitedFiles

export generate_seed, generate_profile

#= --- Master Metabolite Dictionary --- =#
const MASTER_METABOLITE_MAP = Dict(
    # Macronutrients (non-redox)
    "phosphate" => "pi_e", "silicate" => "si_e", "ammonium" => "nh4_e",
    # Redox-sensitive species
    "nitrate" => "no3_e", "nitrite" => "no2_e", "sulfate" => "so4_e", "sulfide" => "h2s_e",
    "iron" => "fe2_e", "manganese" => "mn2_e",
    # Micronutrients (non-redox)
    "Zn" => "zn2_e", "Cd" => "cd2_e", "Ni" => "ni2_e", "Cu" => "cu2_e", "Co" => "cobalt2_e",
    "B1" => "thm_e", "B12" => "cbl1_e",
    # Dissolved Organic Pools
    "DON" => "don_e", "DOP" => "dop_e",
    # Physical/Chemical
    "dissolved_co2" => "co2_e", "oxygen" => "o2_e"
)

#= --- Public Interface --- =#

"""
    generate_seed(...)

Generates a redox-aware marine biogeochemical seed for a given oceanic location.

This function determines the appropriate biome using the Longhurst biogeochemical province map and calculates a comprehensive suite of chemical concentrations. The model causally links the dissolved oxygen profile to the speciation of key redox-sensitive compounds. Users can call this function with either positional or keyword arguments.

# Arguments
- `lat::Real`: Latitude in decimal degrees (e.g., `50.0`).
- `lon::Real`: Longitude in decimal degrees (e.g., `-30.0`).
- `depth::Real`: Depth in meters as a positive value (e.g., `100.0`).
- `shapefile_path::String`: The file path to the Longhurst provinces shapefile.

# Keywords
- `user_data::Dict`: An optional dictionary to provide measured data, which will override the internal models. The key should be the compound name (e.g., `"oxygen"`).

# Examples

```julia
    shp_path = "/path/to/your/Longhurst_world_v4_2010.shp"
    
    # --- Positional Usage ---
    # The simplest way to call the function.
    seed1 = generate_seed(50, -30, 100, shp_path)
    
    # --- Keyword Usage with User Data ---
    # Useful for clarity and for providing measured data to constrain the model.
    user_measurements = Dict("oxygen" => 25.0) # Measured O2 is 25.0 μmol/kg
    
    seed2 = generate_seed(
        lat = 50,
        lon = -30,
        depth = 800,
        shapefile_path = shp_path,
        user_data = user_measurements
    )
```
"""
function generate_seed(; lat::Real, lon::Real, depth::Real, shapefile_path::String, user_data::Dict = Dict())
    @info "Generating Redox-Aware Environmental Seed"
    @info "Location: Lat=$lat, Lon=$lon, Depth=$depth m"

    # Step 1: Context
    biome, prov_code = get_biome(lat, lon, shapefile_path)
    if isnothing(biome); @warn "Location is on land."; return nothing; end
    @info "Identified Province: $prov_code (Biome: $biome)"

    # Step 2: Calculations
    # Check for user-provided oxygen data.

    local o2_conc
    if haskey(user_data, "oxygen")
        o2_conc = user_data["oxygen"]
        @info "Using user-provided oxygen: $o2_conc μmol/kg"
    else
        # If no user data, run the internal model.
        o2_conc = calculate_oxygen(biome, depth)
    end

    macronutrients = get_macronutrients(biome, depth)
    redox_species = get_redox_sensitive_species(biome, o2_conc, macronutrients["phosphate"], depth)
    micronutrients = get_micronutrients(biome, macronutrients)
    organic_matter = get_organic_matter(biome, depth)
    seawater_chem = get_seawater_chemistry(biome)

    if any(isnothing, [o2_conc, macronutrients, redox_species, micronutrients, organic_matter, seawater_chem])
        @error "A critical calculation step failed."; return nothing;
    end
    
    # Step 3: Assemble and Standardize
    raw_seed_data = merge(macronutrients, micronutrients, organic_matter, seawater_chem, redox_species, Dict("oxygen"=>o2_conc))
    standardized_seed = Dict{String, Any}()

    for (key, concentration) in raw_seed_data
        final_key = get(MASTER_METABOLITE_MAP, key, key)
        if haskey(MASTER_METABOLITE_MAP, key) || endswith(key, "_e") || endswith(key, "_L_e") || endswith(key, "_D_e")
            standardized_seed[final_key] = concentration
        end
    end

    ph_value = raw_seed_data["pH"]
    standardized_seed["h_e"] = 10.0^(-ph_value)

    # Step 4: Add metadata
    standardized_seed["metadata"] = Dict(
        "latitude" => lat, "longitude" => lon, "depth_m" => depth,
        "province_code" => prov_code, "biome" => biome, "pH" => ph_value,
        # REMOVED: This key-value pair also caused an error.
        # "redox_state" => raw_seed_data["redox_state"],
        "DOC_total_umolC_kg" => raw_seed_data["DOC_total"],
        "POC_total_umolC_kg" => raw_seed_data["POC_total"],
        "units" => "Concentrations in umol/kg (or equivalent)"
    )
    
    # Step 5: Final Validation
    currency_metabolites = Set(["atp_e","adp_e","amp_e","nad_e","nadh_e","nadp_e","nadph_e","coa_e","ppi_e","h_e","h2o_e"])
    for met in currency_metabolites; delete!(standardized_seed, met); end
    @info "Final validation complete. Currency metabolites removed."
    
    @info "Seed generation complete."
    return standardized_seed
end

function generate_seed(lat::Real, lon::Real, depth::Real, shapefile_path::String; user_data::Dict = Dict())
    return generate_seed(lat=lat, lon=lon, depth=depth, shapefile_path=shapefile_path, user_data=user_data)
end

"""
    generate_profile(...)

    Generates profile data, displays a plot, and optionally saves the data.
"""
function generate_profile(lat::Real, lon::Real, shapefile_path::String, solutes::Vector{String};
                          max_depth=1000, depth_step=50, output_path::Union{String, Nothing}=nothing)
    
    @info "Generating Depth Profile Data"
    @info "Location: Lat=$lat, Lon=$lon | Solutes: $(join(solutes, ", "))"

    depths = Float64[]
    concentrations = Dict(s => Float64[] for s in solutes)
    
    current_logger = global_logger()
    global_logger(MinLevelLogger(current_logger, Warn))

    for depth in 0:depth_step:max_depth
        seed = generate_seed(lat, lon, depth, shapefile_path)
        if isnothing(seed); break; end
        push!(depths, depth) # Use positive depth for data file
        for solute in solutes
            conc = get(seed, solute, get(seed["metadata"], solute, 0.0))
            push!(concentrations[solute], conc)
        end
    end

    global_logger(current_logger)
    if isempty(depths); @error "No data generated for profile."; return; end

    # Display the plot to the console
    plot = lineplot(concentrations[solutes[1]], -depths, title="Depth Profile at ($lat, $lon)",
                    xlabel="Concentration", ylabel="Depth (m)", name=solutes[1], width=80, height=25)
    for i in 2:length(solutes)
        lineplot!(plot, concentrations[solutes[i]], -depths, name=solutes[i])
    end
    println(plot)

    # Save the numerical data to a CSV file if an output path is provided
    if !isnothing(output_path)
        try
            # Combine all data into a matrix
            data_matrix = hcat(depths, [concentrations[s] for s in solutes]...)
            # Create a header row
            header = hcat("Depth_m", reshape(solutes, 1, :))
            
            open(output_path, "w") do f
                writedlm(f, header, ',')
                writedlm(f, data_matrix, ',')
            end
            @info "Profile data saved to: $output_path"
        catch e
            @error "Failed to save profile data to '$output_path'. Error: $e"
        end
    end
    
    @info "Profile generation complete."
end

end # module Assembler