# 1. Environment Setup
import geopandas as gpd
import pandas as pd
import numpy as np
from shapely.geometry import shape
import pyproj
import pyarrow as pa
import pyarrow.parquet as pq
from tqdm import tqdm
import multiprocessing

# 2. Data Import
# Load the spatial datasets
pop_hex = gpd.read_file("datos/population/colombia/kontur_population_CO_20231101.gpkg")
col_dpto = gpd.read_file("datos/spatial/MGN2023_DPTO_POLITICO/MGN_ADM_DPTO_POLITICO.shp")
roads_colombia = gpd.read_file("datos/spatial/colombia_roads.gpkg")

# 3. Coordinate Transformation
# Ensure all datasets use the same CRS (coordinate reference system)
if pop_hex.crs != col_dpto.crs:
    pop_hex = pop_hex.to_crs(col_dpto.crs)

if roads_colombia.crs != col_dpto.crs:
    roads_colombia = roads_colombia.to_crs(col_dpto.crs)

# 4. Spatial Intersections
# Helper function for spatial intersection using parallel processing
def parallel_intersection(df1, df2):
    # Split the data for parallel processing
    num_cores = multiprocessing.cpu_count()
    df_split = np.array_split(df1, num_cores)
    
    with multiprocessing.Pool(num_cores) as pool:
        # Use tqdm to track progress
        result = list(tqdm(pool.imap(lambda x: gpd.overlay(x, df2, how='intersection'), df_split), total=len(df_split)))
    
    # Concatenate the results back together
    return pd.concat(result, ignore_index=True)

# Roads with Departments
try:
    # If the file already exists, load it
    roads_dpto_intersect = gpd.read_parquet("datos/spatial/roads_dpto_intersect.rds")
except FileNotFoundError:
    # Perform the spatial intersection
    roads_dpto_intersect = parallel_intersection(roads_colombia, col_dpto)
    # Save to a file
    roads_dpto_intersect.to_parquet("datos/spatial/roads_dpto_intersect.rds", index=False)

# Population with Departments
try:
    # If the file already exists, load it
    pop_dpto_intersect = gpd.read_parquet("datos/spatial/pop_dpto_intersect.rds")
except FileNotFoundError:
    # Perform the spatial intersection
    pop_dpto_intersect = parallel_intersection(pop_hex, col_dpto)
    # Save to a file
    pop_dpto_intersect.to_parquet("datos/spatial/pop_dpto_intersect.rds", index=False)

# 5. Road Density Calculation
# Road Length Calculation
roads_dpto_intersect['length_km'] = roads_dpto_intersect.geometry.length / 1000  # Convert to kilometers

# Department Area Calculation
col_dpto['area_km2'] = col_dpto.geometry.area / 1e6  # Convert to square kilometers

# Aggregate Road Lengths
road_length_by_dpto = roads_dpto_intersect.groupby('dpto_ccdgo')['length_km'].sum().reset_index()
road_length_by_dpto.columns = ['dpto_ccdgo', 'total_road_length_km']

# Compute Road Density
col_dpto = col_dpto.merge(road_length_by_dpto, on='dpto_ccdgo', how='left')
col_dpto['road_density'] = col_dpto['total_road_length_km'] / col_dpto['area_km2']

# 6. Population Density Calculation
# Aggregate Population by Department
pop_by_dpto = pop_dpto_intersect.groupby('dpto_ccdgo')['population'].sum().reset_index()
pop_by_dpto.columns = ['dpto_ccdgo', 'total_population']

# Compute Population Density
col_dpto = col_dpto.merge(pop_by_dpto, on='dpto_ccdgo', how='left')
col_dpto['pop_density'] = col_dpto['total_population'] / col_dpto['area_km2']

# 7. Data Export
# Select and reorder the columns for final output
final_df = col_dpto[['dpto_ccdgo', 'area_km2', 'total_road_length_km', 'road_density', 'pop_density']].copy()

# Export the final DataFrame to a Parquet file
final_df.to_parquet('colombia-departments_road_pop.parquet', index=False)

