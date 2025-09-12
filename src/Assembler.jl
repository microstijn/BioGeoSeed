# Assembler.jl
# REFACTORED: This module has been significantly updated to incorporate the new
# redox-aware framework and the final validation step for currency metabolites.

module Assembler

# Import functions from all sibling modules.
using ..Provinces, ..Macronutrients, ..Micronutrients, ..OrganicMatter, ..SeawaterChemistry, ..PhysicalModels, ..BiogeochemistryModels
using Logging
using UnicodePlots

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
function generate_seed(lat::Real, lon::Real, depth::Real, shapefile_path::String)
    @info "--- Generating Redox-Aware Environmental Seed ---"
    @info "Location: Lat=$lat, Lon=$lon, Depth=$depth m"

    # Step 1: Context
    biome, prov_code = get_biome(lat, lon, shapefile_path)
    if isnothing(biome); @warn "Location is on land."; return nothing; end
    @info "Identified Province: $prov_code (Biome: $biome)"

    # Step 2: Calculations
    o2_conc = calculate_oxygen(biome, depth)
    macronutrients = get_macronutrients(biome, depth)
    # CORRECTED: Pass the `depth` argument to the redox model
    redox_species = get_redox_sensitive_species(biome, o2_conc, macronutrients["phosphate"], depth)
    micronutrients = get_micronutrients(biome, macronutrients)
    organic_matter = get_organic_matter(biome, depth)
    seawater_chem = get_seawater_chemistry(biome)

    if any(isnothing, [o2_conc, macronutrients, redox_species, micronutrients, organic_matter, seawater_chem])
        @error "A critical calculation step failed."; return nothing;
    end
    @info "Redox state determined: $(redox_species["redox_state"])"

    # Step 3: Assemble and Standardize
    raw_seed_data = merge(macronutrients, micronutrients, organic_matter, seawater_chem, redox_species, Dict("oxygen"=>o2_conc))
    standardized_seed = Dict{String, Any}()

    for (key, concentration) in raw_seed_data
        if haskey(MASTER_METABOLITE_MAP, key)
            standardized_seed[MASTER_METABOLITE_MAP[key]] = concentration
        end
    end

    # Add protons from pH
    ph_value = raw_seed_data["pH"]
    standardized_seed["h_e"] = 10.0^(-ph_value)

    # Step 4: Add metadata
    standardized_seed["metadata"] = Dict(
        "latitude" => lat, "longitude" => lon, "depth_m" => depth,
        "province_code" => prov_code, "biome" => biome, "pH" => ph_value,
        "redox_state" => raw_seed_data["redox_state"],
        "DOC_total_umolC_kg" => raw_seed_data["DOC_total"],
        "POC_total_umolC_kg" => raw_seed_data["POC_total"],
        "units" => "Concentrations in umol/kg (or equivalent)"
    )
    
    # Step 5: Final Validation - Remove Currency Metabolites
    currency_metabolites = Set([
        "atp_e", "adp_e", "amp_e", "nad_e", "nadh_e", "nadp_e", "nadph_e",
        "coa_e", "ppi_e", "h_e", "h2o_e", "fad_e", "fadh2_e"
    ])
    
    for met in currency_metabolites
        delete!(standardized_seed, met)
    end
    @info "Final validation complete. Currency metabolites removed."
    
    @info "--- Seed generation complete. ---"
    return standardized_seed
end

function generate_profile(lat::Real, lon::Real, shapefile_path::String, solutes::Vector{String}; 
                          max_depth=1000, depth_step=50)
    
    @info "Generating Depth Profile"
    @info "Location: Lat=$lat, Lon=$lon | Solutes: $(join(solutes, ", "))"

    depths = Float64[]
    concentrations = Dict(s => Float64[] for s in solutes)
    
    current_logger = global_logger()
    global_logger(MinLevelLogger(current_logger, Warn))

    for depth in 0:depth_step:max_depth
        seed = generate_seed(lat, lon, depth, shapefile_path)
        if isnothing(seed); break; end
        push!(depths, -depth)
        for solute in solutes
            conc = get(seed, solute, get(seed["metadata"], solute, 0.0))
            push!(concentrations[solute], conc)
        end
    end

    global_logger(current_logger)
    if isempty(depths); @error "No data generated for profile."; return; end

    plot = lineplot(concentrations[solutes[1]], depths, title="Depth Profile at ($lat, $lon)",
                    xlabel="Concentration", ylabel="Depth (m)", name=solutes[1], width=80, height=25)
    for i in 2:length(solutes)
        lineplot!(plot, concentrations[solutes[i]], depths, name=solutes[i])
    end
    println(plot)
    @info "--- Profile generation complete. ---"
end

end # module Assembler

