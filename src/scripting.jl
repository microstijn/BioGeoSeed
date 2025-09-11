
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

?run_tests