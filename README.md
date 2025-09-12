# BioGeoSeed.jl
**BioGeoSeed.jl** is a Julia package designed to generate scientifically plausible, redox-aware marine biogeochemical SEEDs for metabolic modeling, particularly in environments where empirical data is sparse. By providing a latitude, longitude, and depth, users can obtain a comprehensive set of environmental parameters that simulate the distinct chemical signatures of the world's major ocean biomes.

The strength of the package is its process-based model where a realistic dissolved oxygen profile (complete with a sharp oxycline and a biome-specific Oxygen Minimum Zone) acts as the master variable that causally determines the speciation of key nitrogen, sulfur, and metal compounds.

## Usage example

Requires a shapefile of Longurst biochemical provinces. 

```Julia
using BioGeoSeed

shp_path = "/path/to/your/Longhurst_world_v4_2010.shp"

s = generate_seed(
    lat = 50,
    lon = -30,
    depth = 100,
    shp_path
)

```

Which gets you

```Julia
Dict{String, Any} with 33 entries:
  "gly_e"     => 0.470495
  "co2_e"     => 18.4216
  "hdcea_e"   => 0.125465
  "zn2_e"     => 0.0149525
  "cobalt2_e" => 0.000345058
  "glc_D_e"   => 0.627326
  "pi_e"      => 2.30039
  "arab_L_e"  => 0.104554
  ⋮           => ⋮
```


## Core features
* Global Biome Identification: Automatically classifies any oceanic coordinate into one of four primary biomes (Polar, Westerlies, Trade-Winds, Coastal) using the Longhurst biogeochemical province map.

* Realistic Physical Profiles: Generates physically consistent vertical profiles for dissolved oxygen, including the formation of well-defined Oxygen Minimum Zones.

* Redox-Controlled Chemistry: Models the vertical distribution of nitrate, nitrite, and ammonium as a direct consequence of the ambient oxygen concentration, simulating processes like denitrification and inhibited nitrification.

* Comprehensive Chemical Suite: Provides data for a wide range of compounds including macronutrients, micronutrients, dissolved organic matter pools, and key seawater chemistry parameters like pH and dissolved CO2.

* Flexible Output: Allows users to generate data for a single point (generate_seed) or create full-depth vertical profiles that can be plotted and saved to a CSV file (generate_profile).

## Planed features
A planned future enhancement is to allow users to provide their own empirical data for key variables (e.g., a measured oxygen or nitrate profile). The package would then use this data as a boundary condition to constrain the internal models and calculate the remaining dependent chemical species. 

## Module breakdown
The package is organized into a series of specialized modules, each responsible for a different aspect of the calculation. The Assembler.jl module orchestrates the calls to these components in the correct sequence.

### Provinces.jl

This module determines the geographic context for all subsequent calculations.

* Uses the Shapefile.jl package to read the polygons of the Longhurst biogeochemical provinces. For a given latitude and longitude, it performs a point-in-polygon test to find the corresponding province code (e.g., "NADR"). It then uses an internal dictionary (BIOME_MAP) to map this province code to its parent biome ("Westerlies"). The results are cached to prevent reloading the shapefile on every call.

### PhysicalModels.jl

This module calculates the master variable: the dissolved oxygen profile.

* The calculate_oxygen function models the vertical O2 profile as a combination of a logistic decay function and a negative Gaussian function. The logistic function creates the sharp oxycline, while the Gaussian function subtracts from this baseline to form the Oxygen Minimum Zone (OMZ). The depth, intensity, and width of the OMZ are parameterized on a per-biome basis.

### Macronutrients.jl

* Calculates the non-redox-sensitive macronutrients.

* Internal Logic: This module generates profiles for phosphate (pi_e) and silicate (si_e). Phosphate is modeled using a logistic function to create the nutricline, while silicate is calculated stoichiometrically from phosphate with a deep-water regeneration term added.

### BiogeochemistryModels.jl

This is the core of the redox-aware framework, modeling all species whose concentrations are controlled by the dissolved oxygen profile.

* Nitrate (no3_e): A baseline profile is calculated from phosphate stoichiometry. A negative Gaussian "deficit" is then subtracted, centered in the OMZ, to simulate nitrate consumption via denitrification. The magnitude of this deficit is inversely proportional to the minimum oxygen concentration in the OMZ.

* Nitrite (no2_e): The final concentration is the sum of two distinct Gaussian peaks: a shallow, ever-present Primary Nitrite Maximum (PNM) at the base of the euphotic zone, and a Secondary Nitrite Maximum (SNM) that only forms in the core of intense, suboxic OMZs.

* Ammonium (nh4_e): The profile is the sum of two peaks: a shallow subsurface maximum from general microbial activity, and a deep accumulation peak centered in the OMZ that simulates the inhibition of nitrification under low-oxygen conditions.

* Metals & Sulfur: Simpler threshold-based models determine the concentration of dissolved iron (fe2_e), manganese (mn2_e), and sulfide (h2s_e) based on whether the redox state is Oxic, Suboxic, Anoxic, or Sulfidic.

### Micronutrients.jl & OrganicMatter.jl

These modules calculate other important biochemical pools.

* Micronutrients.jl calculates non-redox trace metals (Zn, Cd, etc.) from phosphate ratios and B-vitamins from biome-specific surface values. OrganicMatter.jl models bulk DOC and POC pools with exponential decay functions and partitions them into constituent monomers (amino acids, sugars, lipids) based on depth-dependent rules.

### SeawaterChemistry.jl

Calculates basic chemical parameters.

* Uses simple, empirically-derived formulas to estimate seawater pH and dissolved co2_e based on the biome's characteristic sea surface temperature and atmospheric pCO2.

### Assembler.jl

This is the user-facing module that brings everything together.

* It calls the various modules in the correct order, ensuring that dependencies (like calculating oxygen first) are met. It then merges all the dictionaries, standardizes the metabolite names to the BIGG ID format (e.g., "phosphate" -> "pi_e"), adds metadata, and returns the final, consolidated output.
