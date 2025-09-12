
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


shp_path = raw"D:\met2map\longhurst\Longhurst_world_v4_2010.shp"

s = generate_seed(
    50,
    -30,
    100,
    shp_path
)

display(s)

si = [i for i in keys(s)][1:end-1]


get_biome(
    0.0, -120.0, shp_path
)

generate_profile(
    0.0, -120.0,
    shp_path,
    reverse(si),
    max_depth = 3000,
    depth_step = 1,
    #output_path = raw"D:\met2map\genseed\genseed_trade_wind.csv"
)



# generate_all_profiles.jl
# This script automates the generation of full-depth profiles for each major biome
# using the BioGeoSeed package. It saves the output of each profile to a CSV file.


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
 
    output_filename = joinpath(OUTPUT_DIR, "$(biome)_profile.csv")
    
    try
        generate_profile(
            coords.lat, 
            coords.lon, 
            shp_path, 
            SOLUTES_TO_PROFILE,
            max_depth=10000,      # Generate profile down to 10 km
            depth_step=10,       # Set a reasonable step for a deep profile
            output_path=output_filename
        )
        println("   ...Success! Profile saved to '$output_filename'")
    catch e
        @error "   ...An error occurred while generating the profile for $biome: $e"
    end
end