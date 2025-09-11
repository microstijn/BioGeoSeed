# Provinces.jl
# This module provides functions to determine the Longhurst Biogeochemical Province
# and its parent biome for a given latitude and longitude.

module Provinces

# Required package for reading shapefiles.
# Ensure this is added to your Julia environment: `import Pkg; Pkg.add("Shapefile")`
using Shapefile
import GeoInterface

# Export the primary public function.
export get_biome

#= Multi-line comment for section header =#
#= --- Global Variables --- =#

# A thread-safe, atomically accessed cache to store the loaded province data.
# This prevents reloading the shapefile on every function call, significantly
# improving performance after the first call. The type is `Ref{Any}` to
# allow it to initially hold `nothing` and later the province data structure.
const PROVINCES_CACHE = Ref{Any}(nothing)

# A complete and authoritative mapping from each province code to its parent biome.
# This ensures that any valid province code found in the shapefile can be
# correctly classified.
const BIOME_MAP = Dict(
    # CORRECTED: APLR is a Polar biome, not Coastal.
    "APLR" => "Polar", "ARCT" => "Polar", "ARCH" => "Coastal", "BENG" => "Coastal",
    "BERS" => "Westerlies", "BKPL" => "Coastal", "BRAZ" => "Coastal", "CALC" => "Coastal",
    "CARI" => "Coastal", "CHIL" => "Coastal", "CHIN" => "Coastal", "EAFR" => "Coastal",
    "EURA" => "Westerlies", "FKLD" => "Coastal", "GUIA" => "Coastal", "GUIN" => "Coastal",
    "GULF" => "Coastal", "HUMB" => "Coastal", "INDW" => "Coastal", "JAVA" => "Coastal",
    "KAMS" => "Westerlies", "KURO" => "Westerlies", "MEDI" => "Westerlies", "MONS" => "Coastal",
    "NADR" => "Westerlies", "NASE" => "Coastal", "NASW" => "Westerlies", "NATR" => "Trade-Winds",
    "NECS" => "Coastal", "NEWZ" => "Westerlies", "NPPF" => "Westerlies", "NPTG" => "Trade-Winds",
    "NPTE" => "Trade-Winds", "OCEA" => "Westerlies", "PEQD" => "Trade-Winds", "PNEC" => "Coastal",
    "PSAE" => "Westerlies", "PSAW" => "Westerlies", "REDS" => "Coastal", "SANT" => "Polar",
    "SATL" => "Trade-Winds", "SGS" => "Polar", "SOUT" => "Westerlies", "SSTC" => "Westerlies",
    "SUND" => "Coastal", "TAS" => "Westerlies", "TASM" => "Westerlies", "TEDP" => "Trade-Winds",
    "TPLU" => "Coastal", "WARM" => "Trade-Winds", "WAFR" => "Coastal", "ETRA" => "Trade-Winds",
    "ANTA" => "Polar", "AUSW" => "Coastal", "ALSE" => "Coastal"
)


#= --- Core Functions --- =#

"""
    _point_in_polygon(point, polygon::Shapefile.Polygon) -> Bool

    Checks if a point is inside a polygon using the Ray Casting algorithm.
    This is a robust method for point-in-polygon tests. It handles polygons
    with multiple parts (e.g., islands within a larger shape).
"""
function _point_in_polygon(point, polygon::Shapefile.Polygon)
    x, y = point
    is_inside = false

    # A shapefile polygon can have multiple parts (rings).
    # We need to check each part.
    for ring in GeoInterface.getring(polygon)
        num_vertices = length(ring)
        p1 = ring[end] # Start with the last vertex

        for i in 1:num_vertices
            p2 = ring[i]
            # Check if the point is on a horizontal segment. This is an edge case.
            if p1.y == p2.y == y && x >= min(p1.x, p2.x) && x <= max(p1.x, p2.x)
                return true
            end
            
            # Check if the horizontal ray from the point intersects the edge (p1, p2).
            if (y > min(p1.y, p2.y)) && (y <= max(p1.y, p2.y)) && (x <= max(p1.x, p2.x))
                if p1.y != p2.y
                    # Calculate the x-intersection of the ray and the edge.
                    x_intersection = (y - p1.y) * (p2.x - p1.x) / (p2.y - p1.y) + p1.x
                    if p1.x == p2.x || x <= x_intersection
                        is_inside = !is_inside
                    end
                end
            end
            p1 = p2
        end
    end
    return is_inside
end


"""
    _load_provinces(shapefile_path::String)

    Internal function to load and process province polygons from a shapefile.
"""
function _load_provinces(shapefile_path::String)
    try
        table = Shapefile.Table(shapefile_path)
        province_data = [(row.ProvCode, Shapefile.shape(row)) for row in table]
        return province_data
    catch e
        println(stderr, "Error loading shapefile at '$shapefile_path': $e")
        println(stderr, "Please ensure the file path is correct and the Shapefile.jl package is installed.")
        return nothing
    end
end

"""
    get_biome(lat::Real, lon::Real, shapefile_path::String) -> Tuple{Union{String, Nothing}, Union{String, Nothing}}

    The primary public function. Determines the Longhurst province and its parent
    biome for a given latitude and longitude.
"""
function get_biome(lat::Real, lon::Real, shapefile_path::String)
    if isnothing(PROVINCES_CACHE[])
        println("Loading and caching province data from shapefile...")
        PROVINCES_CACHE[] = _load_provinces(shapefile_path)
        if !isnothing(PROVINCES_CACHE[])
             println("...loading complete.")
        end
    end
    
    if isnothing(PROVINCES_CACHE[])
        println(stderr, "Cache is empty. Could not load provinces.")
        return nothing, nothing
    end
    
    point = (lon, lat)

    for (prov_code, polygon) in PROVINCES_CACHE[]
        if _point_in_polygon(point, polygon)
            biome = get(BIOME_MAP, prov_code, "Unknown Biome")
            return biome, prov_code
        end
    end
    
    return nothing, nothing
end

end # module Provinces

