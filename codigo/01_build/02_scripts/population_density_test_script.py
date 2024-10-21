import geopandas as gpd
import pandas as pd
from tqdm import tqdm
import multiprocessing
import numpy as np

# Set up paths and directories
work_dir = Path(Path(__file__).parent.parent.parent.parent)
output_path = Path(Path(__file__).parent.parent,'03_output')
data_path = Path(work_dir,'datos')


def parallel_sjoin(left_gdf, right_gdf, how='inner', op='intersects'):
    num_cores = multiprocessing.cpu_count()
    left_split = np.array_split(left_gdf, num_cores)
    
    with multiprocessing.Pool(num_cores) as pool:
        results = list(tqdm(pool.imap(lambda x: gpd.sjoin(x, right_gdf, how=how, op=op), left_split), 
                            total=len(left_split), 
                            desc="Performing spatial join"))
    
    return pd.concat(results, ignore_index=True)

# Load a small subset of the data
print("Loading data...")
world_pop = gpd.read_file(f"{data_path}/spatial/kontur_population_world.gpkg", rows=1000)  # Load only 1000 rows
admin_divisions = gpd.read_file(f"{work_dir}/codigo/01_build/03_output/south_america_admin_divisions.gpkg", rows=10)  # Load only 10 rows

# Ensure both datasets are in the same CRS
print("Aligning coordinate reference systems...")
if world_pop.crs != admin_divisions.crs:
    world_pop = world_pop.to_crs(admin_divisions.crs)

# Perform the spatial join
print("Performing spatial join...")
joined_data = parallel_sjoin(world_pop, admin_divisions)

# Calculate population density
print("Calculating population density...")
population_by_admin = joined_data.groupby('GID_1')['population'].sum().reset_index()
result = admin_divisions.merge(population_by_admin, on='GID_1', how='left')
result['population_density'] = result['population'] / result['area_km2']

# Display results
print("\nResults:")
print(result[['NAME_1', 'population', 'area_km2', 'population_density']])

print("\nTest completed successfully!")