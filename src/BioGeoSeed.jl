module BioGeoSeed

include("Provinces.jl")
include("TestProvinces.jl")
include("Macronutrients.jl")
include("TestMacronutrients.jl")
include("Micronutrients.jl")
include("TestMicronutrients.jl")
include("OrganicMatter.jl")
include("TestOrganicMatter.jl")

using .Provinces
export get_biome

using .TestProvinces
export run_provinces_tests

using .Macronutrients
export get_macronutrients

using .TestMacronutrients
export run_macronutrient_tests

using .Micronutrients
export get_micronutrients   

using .TestMicronutrients
export run_micronutrient_tests

using .OrganicMatter
export get_organic_matter 
 
using .TestOrganicMatter
export run_organic_matter_tests


end # module BioGeoSeed
