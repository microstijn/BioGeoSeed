# TestMacronutrients.jl
# REFACTORED: This test suite now only tests for the non-redox-sensitive
# macronutrients (phosphate and silicate). Ammonium is no longer tested here.
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
            
            # Test for phosphate and silicate only
            @test polar_surface["phosphate"] > 0.4 # High surface nutrients
            @test haskey(polar_surface, "silicate")
            
            # Ensure ammonium key is not present
            @test !haskey(polar_surface, "ammonium")

            polar_deep = get_macronutrients("Polar", 2000.0)
            @test isapprox(polar_deep["phosphate"], 2.5, atol=0.1)
            @test polar_deep["silicate"] > 100
        end

        # --- NEW TEST SET ---
        @testset "User Data Overrides" begin
            user_val = 5.0 # An unusually high phosphate value
            result = get_macronutrients("Polar", 10.0, user_phosphate=user_val)
            
            # Test 1: The returned phosphate should be exactly the user-provided value.
            @test result["phosphate"] == user_val
            
            # Test 2: The silicate calculation should be based on the user's phosphate.
            # We get the ratio from the BIOME_PARAMS to confirm.
            polar_params = Macronutrients.BIOME_PARAMS["Polar"]
            expected_silicate = polar_params.RSi_P * user_val
            @test result["silicate"] ≈ expected_silicate atol=0.1
        end

        @testset "Error Handling" begin
            # Test that an invalid biome name returns nothing
            invalid_result = get_macronutrients("Invalid Biome", 100)
            @test isnothing(invalid_result)
        end
    end
end

end # module TestMacronutrients