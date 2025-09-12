# TestBiogeochemistryModels.jl
# REFACTORED: This test suite has been updated to validate the new, more
# sophisticated dual-Gaussian model for the Secondary Nitrite Maximum (SNM).

module TestBiogeochemistryModels

using Test
# Use `..` to correctly access sibling modules within the BioGeoSeed package.
using ..BiogeochemistryModels 
using ..PhysicalModels 

export run_biogeochemistry_models_tests

"""
    run_biogeochemistry_models_tests()

    Runs the complete test suite for the BiogeochemistryModels module, with a
    specific focus on validating the new Secondary Nitrite Maximum (SNM) logic.
"""
function run_biogeochemistry_models_tests()
    @testset "Biogeochemistry Models Tests" begin

        # Use a biome with a strong OMZ for a clear test of the SNM.
        test_biome = "Trade-Winds" 
        test_phosphate = 2.0 # umol/kg - representative deep-water value
        
        # Get the specific parameters for this biome to determine the critical test depths.
        # This makes the test robust and directly linked to the model's parameters.
        omz_params = PhysicalModels.OXYGEN_PARAMS[test_biome]
        snm_params = BiogeochemistryModels.NITRITE_PARAMS[test_biome]

        # Define the critical depths for testing: the OMZ core and the SNM peak.
        depth_omz = omz_params.z_omz 
        depth_snm = depth_omz + snm_params.z_snm_offset 

        # We need realistic oxygen values at these depths for a valid test.
        o2_at_omz = PhysicalModels.calculate_oxygen(test_biome, depth_omz)
        o2_at_snm = PhysicalModels.calculate_oxygen(test_biome, depth_snm)

        @testset "Secondary Nitrite Maximum (SNM) Logic" begin
            # Test conditions AT THE OMZ CORE depth
            species_at_omz = get_redox_sensitive_species(test_biome, o2_at_omz, test_phosphate, depth_omz)
            @test species_at_omz isa Dict
            # At the OMZ core, nitrate should be at or near its minimum concentration.
            @test species_at_omz["nitrate"] < 1.0 
            
            # Test conditions AT THE SNM PEAK depth
            species_at_snm = get_redox_sensitive_species(test_biome, o2_at_snm, test_phosphate, depth_snm)
            @test species_at_snm isa Dict
            # At the SNM depth, nitrite should be at or near its maximum concentration.
            @test species_at_snm["nitrite"] > 1.0 
            
            # CRITICAL TEST 1: Confirm that the nitrite peak is spatially offset from the OMZ.
            # The nitrite concentration must be higher at the SNM depth than at the OMZ depth.
            @test species_at_snm["nitrite"] > species_at_omz["nitrite"]
            
            # CRITICAL TEST 2: Confirm the nitrate minimum is at the OMZ core.
            # The nitrate concentration must be lower at the OMZ depth than at the SNM depth.
            @test species_at_omz["nitrate"] < species_at_snm["nitrate"]
        end

        @testset "General Redox State Calculations" begin
            # Test Sulfidic Conditions to ensure other logic remains intact
            sulfidic_species = get_redox_sensitive_species(test_biome, 0.05, test_phosphate, 500.0)
            @test sulfidic_species["redox_state"] == "Sulfidic"
            @test sulfidic_species["sulfide"] > 2000.0
        end

        @testset "Error Handling" begin
            # Test that an invalid biome name returns nothing
            invalid_result = get_redox_sensitive_species("Invalid Biome", 100.0, test_phosphate, 100.0)
            @test isnothing(invalid_result)
        end
    end
end

end # module TestBiogeochemistryModels

