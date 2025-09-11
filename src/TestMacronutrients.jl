# TestMacronutrients.jl
# This module contains a suite of tests for the Macronutrients.jl module.

module TestMacronutrients

using Test

# Bring the already-loaded Macronutrients module into this module's scope.
include("Macronutrients.jl")
using .Macronutrients

export run_macronutrient_tests

"""
    run_macronutrient_tests()

    Runs the complete test suite for the Macronutrients module.
"""
function run_macronutrient_tests()
    @testset "Macronutrients Module Tests" begin

        @testset "Known Biome Calculations" begin
            # --- Test Polar Biome ---
            polar_surface = get_macronutrients("Polar", 10.0)
            @test polar_surface isa Dict
            @test polar_surface["phosphate"] > 0.4
            @test polar_surface["nitrate"] > 5.0
            # NEW: Test for ammonium
            @test haskey(polar_surface, "ammonium")
            @test isapprox(polar_surface["ammonium"], 0.308, atol=0.01)

            polar_deep = get_macronutrients("Polar", 2000.0)
            @test isapprox(polar_deep["phosphate"], 2.5, atol=0.1)
            @test polar_deep["silicate"] > 100

            # --- Test Trade-Winds Biome (Oligotrophic Gyre) ---
            tw_surface = get_macronutrients("Trade-Winds", 10.0)
            @test isapprox(tw_surface["phosphate"], 0.087, atol = 0.01)
            @test isapprox(tw_surface["nitrate"], 1.99, atol = 0.1)
            @test isapprox(tw_surface["silicate"], 0.26, atol = 0.1)
            
            # --- Test Coastal Biome (at ammonium peak) ---
            coastal_peak = get_macronutrients("Coastal", 50.0) # 50m is the z_NH4_max
            @test coastal_peak isa Dict
            # NEW: Test that ammonium is at its maximum value at the specified peak depth
            @test isapprox(coastal_peak["ammonium"], 2.0, atol=0.01)
        end

        @testset "Edge Case Handling" begin
            # Test depth 0
            westerlies_zero = get_macronutrients("Westerlies", 0)
            @test westerlies_zero["phosphate"] > 0.09

            # Test negative depth (should be treated as 0)
            westerlies_neg = get_macronutrients("Westerlies", -50)
            @test westerlies_neg["phosphate"] == westerlies_zero["phosphate"]
        end

        @testset "Error Handling" begin
            # Test that an invalid biome name returns nothing
            invalid_result = get_macronutrients("Invalid Biome", 100)
            @test isnothing(invalid_result)
        end
    end
end

end # module TestMacronutrients

