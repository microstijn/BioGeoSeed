
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

generate_seed(
    50,
    -30,
    100,
    shp_path
)


