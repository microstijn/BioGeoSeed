
using Pkg
#Pkg.develop(path=joinpath(@__DIR__, ".."))
Pkg.activate(joinpath(@__DIR__, ".."))

using Revise
using BioGeoSeed


shp_path = raw"D:\met2map\longhurst\Longhurst_world_v4_2010.shp"

run_provinces_tests(
    shp_path
);

run_macronutrient_tests();
run_micronutrient_tests();
run_physical_models_tests();
run_organic_matter_tests();
run_seawater_chemistry_tests();
run_biogeochemistry_models_tests();
run_assembler_tests(shp_path);


shp_path = raw"D:\met2map\longhurst\Longhurst_world_v4_2010.shp"

s = generate_seed(
    50,
    -30,
    100,
    shp_path
)

# Create a dictionary with your measured data
site_measurements = Dict(
    "oxygen" => 15.0,        # Low oxygen value from the OMZ
    "phosphate" => 2.1,      # Measured phosphate
    "temperature" => 0     # Measured in-situ temperature
)

# Call the function with the new keyword argument
s = generate_seed(
    lat = 50,
    lon = -30,
    depth = 400, # A depth where an OMZ is likely
    shapefile_path = shp_path,
    user_data = site_measurements # Pass your data here
)

si = [i for i in keys(s)][1:end-1]

get_biome(
    0.0, -120.0, shp_path
)


SOLUTES_TO_PROFILE = [
    "o2_e",
    # Carbon Cycle
    "co2_e", 
    # Nitrogen Cycle
    "no3_e", "no2_e", "nh4_e",
    # Phosphorus Cycle
    "pi_e",
    # Sulfur Cycle
    "so4_e", "h2s_e"
]

generate_profile(
    50, -30,
    shp_path,
    SOLUTES_TO_PROFILE,
    max_depth = 1000,
    depth_step = 1,
    #output_path = raw"D:\met2map\genseed\genseed_trade_wind.csv"
    #plot_output_path =  raw"D:\met2map\genseed\westerlies_plot.txt"
)
SOLUTES_TO_PROFILE = [
    "o2_e",
    # Carbon Cycle
    "co2_e", 
    # Nitrogen Cycle
    "no3_e", "no2_e", "nh4_e", "don_e",
    # Phosphorus Cycle
    "pi_e", "dop_e",
    # Sulfur Cycle
    "so4_e", "h2s_e"
]

SOLUTES_TO_PROFILE = [
    "o2_e",
    # Carbon Cycle
    "co2_e", 
    # Nitrogen Cycle
    "no3_e", "no2_e", "nh4_e",
    # Phosphorus Cycle
    "pi_e",
    # Sulfur Cycle
    "so4_e", "h2s_e"
]
heatmap_solutes = SOLUTES_TO_PROFILE

generate_heatmap_profile(
    38.0, -126.0,   # Coastal Biome location
    shp_path,
    heatmap_solutes,
    max_depth=1500,
    n_steps=100      # Number of rows in the heatmap
);



# generate_all_profiles.jl
# This script automates the generation of full-depth profiles for each major biome
# using the BioGeoSeed package. It saves the output of each profile to a CSV file.
using StatsBase

SOLUTES_TO_PROFILE = [
    "o2_e",
    # Carbon Cycle
    "co2_e", 
    # Nitrogen Cycle
    "no3_e", "no2_e", "nh4_e", "don_e",
    # Phosphorus Cycle
    "pi_e", "dop_e",
    # Sulfur Cycle
    "so4_e", "h2s_e"
]

BIOME_LOCATIONS = Dict(
    "Polar" => (lat=-70.0, lon=-90.0),      # Austral Polar Province
    "Westerlies" => (lat=50.0, lon=-30.0),      # North Atlantic Drift
    "Trade-Winds" => (lat=0.0, lon=-120.0),     # Pacific Equatorial Divergence
    "Coastal" => (lat=38.0, lon=-126.0)     # California Current
)

OUTPUT_DIR = raw"D:\met2map\genseed"


# Loop through each biome, generate its profile, and save it.
for (biome, coords) in BIOME_LOCATIONS
    
    biome, prov = get_biome(
        coords.lat, 
        coords.lon,
        shp_path
    )

    output_filename = joinpath(OUTPUT_DIR, "$(biome)_profile.csv")
    
    try
        generate_profile(
            coords.lat, 
            coords.lon, 
            shp_path, 
            SOLUTES_TO_PROFILE,
            max_depth=5000,      # Generate profile down to 10 km
            depth_step=20,       # Set a reasonable step for a deep profile
            output_path=output_filename
        )
        println("   ...Success! Profile saved to '$output_filename'")
    catch e
        @error "   ...An error occurred while generating the profile for $biome: $e"
    end
end