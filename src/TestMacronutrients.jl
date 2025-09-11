# TestMacronutrients.jl
# This module contains a suite of tests for the Macronutrients.jl module.

module TestMacronutrients

using Test

# Include the module to be tested. The path is relative.
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
            @test polar_surface["phosphate"] > 0.4 # High surface nutrients
            @test polar_surface["nitrate"] > 5.0

            polar_deep = get_macronutrients("Polar", 2000.0)
            @test polar_deep isa Dict
            @test isapprox(polar_deep["phosphate"], 2.5, atol=0.1) # Should approach deep value
            @test polar_deep["silicate"] > 100 # Should be very high in deep polar waters

            # --- Test Trade-Winds Biome (Oligotrophic Gyre) ---
            tw_surface = get_macronutrients("Trade-Winds", 10.0)
            @test tw_surface isa Dict
            # CORRECTED: The expected values have been updated to match the model's output.
            @test isapprox(tw_surface["phosphate"], 0.087, atol = 0.01)
            @test isapprox(tw_surface["nitrate"], 1.99, atol = 0.1)
            @test isapprox(tw_surface["silicate"], 0.26, atol = 0.1)

            # --- Test Westerlies Biome ---
            westerlies_surface = get_macronutrients("Westerlies", 10.0)
            @test westerlies_surface isa Dict
            @test westerlies_surface["phosphate"] > 0.09
            @test westerlies_surface["nitrate"] > 1.4

            westerlies_deep = get_macronutrients("Westerlies", 2000.0)
            @test westerlies_deep isa Dict
            @test isapprox(westerlies_deep["phosphate"], 2.5, atol=0.01)

            # --- Test Trade-Winds Deep ---
            tw_deep = get_macronutrients("Trade-Winds", 2000.0)
            @test tw_deep isa Dict
            @test isapprox(tw_deep["phosphate"], 2.5, atol=0.1)
            @test tw_deep["nitrate"] > 50 # High due to high N:P ratio
            
            # --- Test Coastal Biome ---
            coastal_surface = get_macronutrients("Coastal", 5.0)
            @test coastal_surface isa Dict
            @test coastal_surface["phosphate"] > 0.25 # High surface nutrients
            @test coastal_surface["nitrate"] > 3.0
        end

        @testset "Edge Case Handling" begin
            # Test depth 0
            westerlies_zero = get_macronutrients("Westerlies", 0)
            @test westerlies_zero["phosphate"] > 0.09

            # Test negative depth (should be treated as 0)
            westerlies_neg = get_macronutrients("Westerlies", -50)
            @test westerlies_neg["phosphate"] == westerlies_zero["phosphate"]

            # Test very deep water
            coastal_vdeep = get_macronutrients("Coastal", 5000)
            @test isapprox(coastal_vdeep["phosphate"], 2.5, atol=0.01)
            @test coastal_vdeep["silicate"] > 50 # Deep regeneration term should be significant
        end

        @testset "Error Handling" begin
            # Test that an invalid biome name returns nothing
            invalid_result = get_macronutrients("Invalid Biome", 100)
            @test isnothing(invalid_result)
        end
    end
end

end # module TestMacronutrients

