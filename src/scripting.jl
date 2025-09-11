
using Pkg
#Pkg.develop(path=joinpath(@__DIR__, ".."))
Pkg.activate(joinpath(@__DIR__, ".."))

using Revise
using BioGeoSeed


# IMPORTANT: Replace this with the actual path to your .shp file
shp_path = raw"D:\met2map\longhurst\Longhurst_world_v4_2010.shp"

run_provinces_tests(
    shp_path
);

run_macronutrient_tests();

c = get_macronutrients(
    "Polar",
    10
)

get_micronutrients(
    "Polar",
    c
)

get_organic_matter(
    "Polar",
    10
)

run_organic_matter_tests();

get_seawater_chemistry(
    "Polar"
)

run_seawater_chemistry_tests();


generate_seed(
    50,
    -30,
    100,
    shp_path
)