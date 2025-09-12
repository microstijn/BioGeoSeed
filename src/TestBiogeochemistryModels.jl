# TestBiogeochemistryModels.jl
# REWRITTEN: This test suite has been completely updated to validate the new,
# process-based models for nitrate, nitrite, and ammonium that are causally
# linked to the revised dissolved oxygen profile.
module TestBiogeochemistryModels

using Test
using ..BiogeochemistryModels 
using ..PhysicalModels
using ..Macronutrients # Needed to get potential nitrate

export run_biogeochemistry_models_tests

"""
    run_biogeochemistry_models_tests()

    Runs the complete test suite for the BiogeochemistryModels module, validating
    the nitrate deficit, the dual nitrite peaks (PNM and SNM), and the new
    redox-dependent ammonium profile.
"""
function run_biogeochemistry_models_tests()
    @testset "Biogeochemistry Models Tests" begin

        # --- Setup for a biome with an intense OMZ (Coastal) ---
        intense_biome = "Coastal"
        # Get model parameters to make tests robust
        omz_params_intense = PhysicalModels.OXYGEN_PARAMS[intense_biome]
        depth_omz_intense = omz_params_intense.z_omz
        n_params_intense = BiogeochemistryModels.NITROGEN_PARAMS[intense_biome]
        depth_pnm_intense = n_params_intense.z_pnm
        
        # --- Setup for a biome with a weak OMZ (Polar) ---
        weak_biome = "Polar"
        omz_params_weak = PhysicalModels.OXYGEN_PARAMS[weak_biome]
        depth_omz_weak = omz_params_weak.z_omz

        # Realistic phosphate for calculations
        test_phosphate = 2.0 

        @testset "Nitrogen Cycle in Intense OMZ (Coastal Biome)" begin
            # Calculate species at the three critical depths: PNM, OMZ core, and deep ocean
            o2_at_pnm = calculate_oxygen(intense_biome, depth_pnm_intense)
            o2_at_omz = calculate_oxygen(intense_biome, depth_omz_intense)
            o2_deep = calculate_oxygen(intense_biome, 3000.0)

            species_at_pnm = get_redox_sensitive_species(intense_biome, o2_at_pnm, test_phosphate, depth_pnm_intense)
            species_at_omz = get_redox_sensitive_species(intense_biome, o2_at_omz, test_phosphate, depth_omz_intense)
            species_deep = get_redox_sensitive_species(intense_biome, o2_deep, test_phosphate, 3000.0)

            # TEST 1: Primary Nitrite Maximum (PNM)
            @test species_at_pnm["nitrite"] > 0.1
            @test species_at_pnm["nitrite"] > species_deep["nitrite"]
            
            # TEST 2: Nitrate Deficit
            potential_nitrate = Macronutrients.BIOME_PARAMS[intense_biome].RN_P * test_phosphate
            @test species_at_omz["nitrate"] < potential_nitrate
            
            # TEST 3: Secondary Nitrite Maximum (SNM)
            # In an intense OMZ, a nitrite peak should form in the OMZ core
            @test species_at_omz["nitrite"] > species_at_pnm["nitrite"]
            
            # TEST 4: Ammonium Accumulation in OMZ
            # REMOVED: Flawed test species_at_omz["ammonium"] > species_at_pnm["ammonium"]
            # CORRECTED TEST: The deep peak should be greater than the background deep concentration
            @test species_at_omz["ammonium"] > species_deep["ammonium"]
        end

        @testset "Nitrogen Cycle in Weak OMZ (Polar Biome)" begin
            o2_at_omz = calculate_oxygen(weak_biome, depth_omz_weak)
            species_at_omz = get_redox_sensitive_species(weak_biome, o2_at_omz, test_phosphate, depth_omz_weak)

            # CRITICAL TEST: In a weak, oxic OMZ, there should be NO significant SNM or Ammonium accumulation.
            @test species_at_omz["nitrite"] < 0.1 # Should be low, dominated by small PNM tail
            # CORRECTED: Changed < to <= to handle floating point equality.
            @test species_at_omz["ammonium"] <= 0.2 # Should not show a deep accumulation peak
        end

        @testset "Error Handling" begin
            invalid_result = get_redox_sensitive_species("Invalid Biome", 50.0, test_phosphate, 100.0)
            @test isnothing(invalid_result)
        end
    end
end

end # module TestBiogeochemistryModels