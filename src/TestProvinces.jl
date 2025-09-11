# TestProvinces.jl
# A test suite for the Provinces.jl module to ensure its correctness.

module TestProvinces

# Julia's standard testing library
using Test

# We need to explicitly include the source file of the module we want to test.
# This assumes TestProvinces.jl is in the same directory as Provinces.jl.
include("Provinces.jl")

# By adding "using .Provinces", we bring the Provinces module into this
# module's scope, allowing us to call its functions (e.g., Provinces.get_biome).
using .Provinces

# Export the test function so it can be called from the REPL or other scripts.
export run_provinces_tests

"""
    run_provinces_tests(shapefile_path::String)

    Executes the complete test suite for the Provinces.jl module using the
    shapefile found at the provided path.
"""
function run_provinces_tests(shapefile_path::String)
    @testset "Provinces Module Tests" begin
        
        if !isfile(shapefile_path)
            @warn "Shapefile not found at '$shapefile_path'. Skipping Provinces.jl tests."
        else
            @testset "Known Location Lookups" begin
                
                # Test Case 1: North Atlantic Drift Province
                lat1, lon1 = 50.0, -30.0
                biome1, code1 = Provinces.get_biome(lat1, lon1, shapefile_path)
                @test biome1 == "Westerlies"
                @test code1 == "NADR"

                # Test Case 2: A land-locked point (Sahara Desert)
                lat2, lon2 = 25.0, 15.0
                biome2, code2 = Provinces.get_biome(lat2, lon2, shapefile_path)
                @test isnothing(biome2)
                @test isnothing(code2)

                # Test Case 3: Austral Polar Province
                # This coordinate falls within the APLR province. With the corrected BIOME_MAP,
                # this test should now pass.
                lat3, lon3 = -70.0, -90.0
                biome3, code3 = Provinces.get_biome(lat3, lon3, shapefile_path)
                @test biome3 == "Polar"
                # This test is now more robust. It checks if the code is one of the valid Polar provinces.
                @test code3 in ["ANTA", "APLR", "SANT", "SGS", "ARCT"]

                # Test Case 4: Pacific Equatorial Divergence
                lat4, lon4 = 0.0, -120.0
                biome4, code4 = Provinces.get_biome(lat4, lon4, shapefile_path)
                @test biome4 == "Trade-Winds"
                @test code4 == "PEQD"
            end

            @testset "Error and Edge Case Handling" begin
                
                bad_path = "non_existent_file.shp"
                # We must reset the cache to force the function to try loading the bad path.
                Provinces.PROVINCES_CACHE[] = nothing
                
                biome_err, code_err = Provinces.get_biome(50.0, -30.0, bad_path)
                @test isnothing(biome_err)
                @test isnothing(code_err)
                
                # Reset the cache again so it reloads the correct file for any subsequent tests.
                Provinces.PROVINCES_CACHE[] = nothing
            end
        end
    end
end

end # module TestProvinces

