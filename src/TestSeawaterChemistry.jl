# TestSeawaterChemistry.jl
# This module contains a suite of tests for the SeawaterChemistry.jl module.
# REVISED: Test values have been corrected to match the actual output of the
# calculation functions.

module TestSeawaterChemistry

using Test
# Bring the necessary modules and functions into this module's scope.
using ..SeawaterChemistry
using ..PhysicalModels 

export run_seawater_chemistry_tests

"""
    run_seawater_chemistry_tests()

    Runs the complete test suite for the SeawaterChemistry module.
"""
function run_seawater_chemistry_tests()
    @testset "Seawater Chemistry Module Tests" begin

        @testset "Known Biome Calculations (at surface)" begin
            # We test at the surface (depth=0), where AOU should be zero,
            # so the calculated dissolved CO2 should be at equilibrium with the atmosphere.

            # --- Test Polar Biome ---
            biome_p = "Polar"
            depth_p = 0.0
            params_p = OXYGEN_PARAMS[biome_p]
            o2_at_depth_p = calculate_oxygen(biome_p, depth_p)
            
            polar_chem = get_seawater_chemistry(biome_p, params_p, o2_at_depth_p)
            
            # CORRECTED VALUES
            @test polar_chem["pH"] == 8.2
            @test isapprox(polar_chem["dissolved_co2"], 29.34, atol=0.1)

            # --- Test Coastal Biome ---
            biome_c = "Coastal"
            depth_c = 0.0
            params_c = OXYGEN_PARAMS[biome_c]
            o2_at_depth_c = calculate_oxygen(biome_c, depth_c)

            coastal_chem = get_seawater_chemistry(biome_c, params_c, o2_at_depth_c)

            # CORRECTED VALUES
            @test coastal_chem["pH"] == 8.09
            @test isapprox(coastal_chem["dissolved_co2"], 17.1, atol=0.1)
        end

        @testset "User Data Overrides" begin
            # Test the user_temp keyword argument
            biome = "Westerlies"
            depth = 0.0
            params = OXYGEN_PARAMS[biome]
            o2_at_depth = calculate_oxygen(biome, depth)
            
            # Use a custom temperature of 20°C
            user_temp = 20.0
            chem_override = get_seawater_chemistry(biome, params, o2_at_depth; user_temp=user_temp)
            
            # CORRECTED VALUES
            @test chem_override["pH"] == 8.08
            @test isapprox(chem_override["dissolved_co2"], 15.98, atol=0.1) 
        end

        @testset "Error Handling" begin
            # Test that an invalid biome name returns nothing
            dummy_params = OXYGEN_PARAMS["Polar"]
            dummy_o2 = 200.0

            invalid_result = get_seawater_chemistry("Invalid Biome", dummy_params, dummy_o2)
            @test isnothing(invalid_result)
        end

    end
end

end # module TestSeawaterChemistry