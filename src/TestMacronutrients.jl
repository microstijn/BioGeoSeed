# TestMacronutrients.jl
# REFACTORED: This test suite now only tests for the non-redox-sensitive
# macronutrients (phosphate, silicate, ammonium).

module TestMacronutrients

using Test
using ..Macronutrients

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
            @test haskey(polar_surface, "ammonium")
            @test isapprox(polar_surface["ammonium"], 0.308, atol=0.01)

            polar_deep = get_macronutrients("Polar", 2000.0)
            @test isapprox(polar_deep["phosphate"], 2.5, atol=0.1)
            @test polar_deep["silicate"] > 100

            # --- Test Coastal Biome (at ammonium peak) ---
            coastal_peak = get_macronutrients("Coastal", 50.0)
            @test isapprox(coastal_peak["ammonium"], 2.0, atol=0.01)
        end

        @testset "Error Handling" begin
            # Test that an invalid biome name returns nothing
            invalid_result = get_macronutrients("Invalid Biome", 100)
            @test isnothing(invalid_result)
        end
    end
end

end # module TestMacronutrients

