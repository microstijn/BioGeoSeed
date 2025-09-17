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
using StatsBase

export generate_seed, generate_profile, generate_heatmap_profile

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
    
    # The simplest way to call the function.
    generate_seed(50, -30, 100, shp_path)
    
    # Keyword Usage with user data
    user_measurements = Dict("oxygen" => 25.0) # Measured O2 is 25.0 μmol/kg
    
    generate_seed(
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

    # Handle OXYGEN (calculated first as it's a master variable)
    local o2_conc
    if haskey(user_data, "oxygen")
        o2_conc = user_data["oxygen"]
        @info "Using user-provided oxygen: $(o2_conc) μmol/kg"
    else
        o2_conc = calculate_oxygen(biome, depth)
    end
    
    # Handle PHOSPHATE
    user_phosphate = get(user_data, "phosphate", nothing)
    if !isnothing(user_phosphate)
        @info "Using user-provided phosphate: $(user_phosphate) μmol/kg"
    end
    macronutrients = get_macronutrients(biome, depth, user_phosphate=user_phosphate)

    # Handle TEMPERATURE and pass all required info to the chemistry model
    user_temp = get(user_data, "temperature", nothing)
     if !isnothing(user_temp)
        @info "Using user-provided temperature: $(user_temp) °C"
    end
    # The call now includes the oxygen parameters and the calculated oxygen concentration
    seawater_chem = get_seawater_chemistry(biome, PhysicalModels.OXYGEN_PARAMS[biome], o2_conc, user_temp=user_temp)

    # These calls now use the potentially user-modified data
    redox_species = get_redox_sensitive_species(biome, o2_conc, macronutrients["phosphate"], depth)
    micronutrients = get_micronutrients(biome, macronutrients)
    organic_matter = get_organic_matter(biome, depth)

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

# This is the convenience wrapper. It accepts positional arguments and immediately
# calls the main keyword version. It contains NO calculation logic.
function generate_seed(lat::Real, lon::Real, depth::Real, shapefile_path::String; user_data::Dict = Dict())
    return generate_seed(lat=lat, lon=lon, depth=depth, shapefile_path=shapefile_path, user_data=user_data)
end


"""
    generate_profile(...)

    Generates profile data, displays a plot, and optionally saves the data.
"""
function generate_profile(lat::Real, lon::Real, shapefile_path::String, solutes::Vector{String};
                          max_depth=1000, depth_step=50, output_path::Union{String, Nothing}=nothing,
                          plot_output_path::Union{String, Nothing}=nothing)
    
    @info "Generating Depth Profile Data"
    @info "Location: Lat=$lat, Lon=$lon | Solutes: $(join(solutes, ", "))"

    depths = Float64[]
    concentrations = Dict(s => Float64[] for s in solutes)
    
    # Suppress logger during the loop
    current_logger = global_logger()
    global_logger(MinLevelLogger(current_logger, Warn))
    try
        for depth in 0:depth_step:max_depth
            seed = generate_seed(lat, lon, depth, shapefile_path)
            if isnothing(seed); break; end
            push!(depths, depth)
            for solute in solutes
                conc = get(seed, solute, get(seed["metadata"], solute, 0.0))
                push!(concentrations[solute], conc)
            end
        end
    finally
        global_logger(current_logger)
    end
    
    if isempty(depths); @error "No data generated for profile."; return; end

    # Normalize the data for the second plot
    normalized_concentrations = Dict{String, Vector{Float64}}()
    for solute in solutes
        data_vector = concentrations[solute]
        data_matrix_view = reshape(data_vector, :, 1)
        scaler = StatsBase.fit(StatsBase.UnitRangeTransform, data_matrix_view, dims=1)
        normalized_matrix = StatsBase.transform(scaler, data_matrix_view)
        normalized_concentrations[solute] = vec(normalized_matrix)
    end

    # Define a consistent color palette
    plot_colors = [:cyan, :magenta, :green, :yellow, :red, :blue, :white]

    # Plot 1: Absolute Concentrations
    plot1 = lineplot(concentrations[solutes[1]], -depths, title="Absolute Concentrations",
                     xlabel="Concentration (μmol/kg)", ylabel="Depth (m)", name=solutes[1], width=50, height=70,
                     color=plot_colors[1], canvas=BlockCanvas , blend= false, compact = true)
    
    # Plot 2: Normalized Profiles (0-1 Scale)
    plot2 = lineplot(normalized_concentrations[solutes[1]], -depths, title="Normalized Profiles (0-1 Scale)",
                     xlabel="Normalized Value", name=solutes[1], width=50, height=70,
                     color=plot_colors[1], canvas=BlockCanvas , blend= false, compact = true)

    for i in 2:length(solutes)
        color_index = (i - 1) % length(plot_colors) + 1
        current_color = plot_colors[color_index]
        lineplot!(plot1, concentrations[solutes[i]], -depths, name=solutes[i], color=current_color)
        lineplot!(plot2, normalized_concentrations[solutes[i]], -depths, name=solutes[i], color=current_color)
    end

    # Create an IOBuffer and an IOContext that has color enabled
    buf1 = IOBuffer()
    io1 = IOContext(buf1, :color => true)
    show(io1, plot1) # Render plot1 into the buffer with color
    s1_str = String(take!(buf1))

    buf2 = IOBuffer()
    io2 = IOContext(buf2, :color => true)
    show(io2, plot2) # Render plot2 into the buffer with color
    s2_str = String(take!(buf2))

    # Manually combine the colored plot strings side-by-side
    combined_plot_string = ""
    s1_lines = split(s1_str, '\n')
    s2_lines = split(s2_str, '\n')
    header = "\n" * "─"^120 * "\n"
    println(header)
    combined_plot_string *= header
    
    for i in 1:max(length(s1_lines), length(s2_lines))
        padding = " "^(round(Int, plot1.graphics.width) + 1)
        line1 = get(s1_lines, i, padding)
        line2 = get(s2_lines, i, "")
        full_line = rpad(line1, 65) * line2 * "\n"
        print(full_line)
        combined_plot_string *= full_line
    end
    println("─"^120 * "\n")
    

    if !isnothing(plot_output_path)
        try
            open(plot_output_path, "w") do f
                write(f, "Profile Plots at (Lat=$lat, Lon=$lon) for solutes: $(join(solutes, ", "))\n")
                write(f, combined_plot_string)
            end
            @info "Unicode plot saved to: $plot_output_path"
        catch e
            @error "Failed to save plot to '$plot_output_path'. Error: $e"
        end
    end

    # save if flag set
    if !isnothing(output_path)
        try
            data_matrix = hcat(depths, [concentrations[s] for s in solutes]...)
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

"""
    generate_heatmap_profile(...)

    Generates profile data and displays it as a Unicode heatmap in the console.
    Each compound is independently normalized to show its relative profile shape.
"""
function generate_heatmap_profile(lat::Real, lon::Real, shapefile_path::String, solutes::Vector{String};
                                  max_depth=1000, n_steps=20)
    
    @info "Generating Heatmap Profile Data"
    @info "Location: Lat=$lat, Lon=$lon | Solutes: $(join(solutes, ", "))"

    depths = Float64[]
    concentrations = Dict(s => Float64[] for s in solutes)
    depth_step = max_depth / n_steps
    
    current_logger = global_logger()
    global_logger(MinLevelLogger(current_logger, Warn))
    
    try
        # --- 1. Generate Profile Data ---
        for depth in 0:depth_step:max_depth
            seed = generate_seed(lat=lat, lon=lon, depth=depth, shapefile_path=shapefile_path)
            if isnothing(seed); break; end
            push!(depths, round(depth))
            for solute in solutes
                conc = get(seed, solute, 0.0)
                push!(concentrations[solute], conc)
            end
        end
    finally
        global_logger(current_logger)
    end

    if isempty(depths); @error "No data generated for heatmap."; return; end

    # --- 2. Create a Data Matrix ---
    data_matrix = hcat([concentrations[s] for s in solutes]...)

    # --- 3. Normalize the Matrix ---
    scaler = StatsBase.fit(StatsBase.UnitRangeTransform, data_matrix, dims=1)
    normalized_matrix = StatsBase.transform(scaler, data_matrix)

    # --- 4. Plot the Heatmap ---
    println("\n" * "─"^120)
    println("Heatmap Profile at (Lat=$lat, Lon=$lon) from 0 to $(max_depth)m")
    println("Colors represent normalized concentration (Min to Max) for each compound.")
    
    println("\nCompound Key:")
    for (i, solute) in enumerate(solutes)
        println("  $i: $solute")
    end
    println()
    
    plot = heatmap(normalized_matrix, 
                   xlabel="Compounds (see key above)", 
                   ylabel="Depth (rows)",
                   # MODIFIED: Explicitly set a wider plot width
                   width=10,
                   colormap=:viridis)
    
    println(plot)
    println("─"^120 * "\n")
    
    @info "Heatmap generation complete."
end

end