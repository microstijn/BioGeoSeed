
using Pkg
#Pkg.develop(path=joinpath(@__DIR__, ".."))
Pkg.activate(joinpath(@__DIR__, ".."))

using Revise
using BioGeoSeed

run_biogeochemistry_models_tests();

shp_path = raw"D:\met2map\longhurst\Longhurst_world_v4_2010.shp"

s = generate_seed(
    50,
    -30,
    100,
    shp_path
)

si = [i for i in keys(s)][1:end-1]



generate_profile(
    0.0, -120.0,
    shp_path,
    reverse(si),
    max_depth = 10000,
    depth_step = 1,
    output_path = raw"D:\met2map\genseed\genseed_trade_wind.csv"
)



run_provinces_tests(
    shp_path
);

run_macronutrient_tests();
run_micronutrient_tests();
run_physical_models_tests();
run_organic_matter_tests();
run_seawater_chemistry_tests();
run_biogeochemistry_models_tests();




