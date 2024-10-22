from pathlib import Path
import geopandas as gpd
import pandas as pd
from tqdm import tqdm
import multiprocessing
import numpy as np
import os
from functools import partial

# Set up paths and directories
work_dir = Path(Path(__file__).parent.parent.parent.parent)
output_path = Path(Path(__file__).parent.parent, '03_output')
data_path = Path(work_dir, 'datos')

# Define specific data paths
ADMIN_DIVISIONS_PATH = work_dir / 'codigo' / '01_build' / '03_output'/ 'south_america_admin_divisions.gpkg'
POPULATION_DATA_PATH = data_path / 'spatial' / 'kontur_population_world.gpkg'
RESULTS_PATH = output_path / 'population_density_results.gpkg'

# Hypatia-optimized settings
BATCH_SIZE = 500000  # Increased for 32GB RAM
CHUNK_SIZE = 5000    # Increased for 32 cores

def init_worker():
    """
    Initialize worker process by setting a process-specific random seed.
    """
    np.random.seed(os.getpid())

def process_chunk(df_chunk, admin_divisions, desc="Processing"):
    """
    Process a chunk of the population dataset against admin divisions.
    """
    try:
        return gpd.overlay(df_chunk, admin_divisions, how='intersection')
    except Exception as e:
        print(f"Error processing chunk: {str(e)}")
        return None

def parallel_intersection(df1, df2, chunk_size=CHUNK_SIZE):
    """
    Perform parallel spatial intersection with proper error handling and progress tracking.
    """
    num_cores = max(1, multiprocessing.cpu_count() - 1)
    num_chunks = max(num_cores, len(df1) // chunk_size)
    df_split = np.array_split(df1, num_chunks)
    
    process_func = partial(process_chunk, admin_divisions=df2)
    
    results = []
    try:
        with multiprocessing.Pool(num_cores, initializer=init_worker) as pool:
            for result in tqdm(
                pool.imap_unordered(process_func, df_split),
                total=len(df_split),
                desc="Performing spatial intersection"
            ):
                if result is not None:
                    results.append(result)
    except Exception as e:
        print(f"Error in parallel processing: {str(e)}")
        raise
    
    if not results:
        raise ValueError("No valid results obtained from parallel processing")
    
    return pd.concat(results, ignore_index=True)

def process_population_in_batches(pop_path, admin_divisions, batch_size=BATCH_SIZE):
    """
    Process the population data in batches to handle large datasets.
    
    Args:
        pop_path (Path): Path to population data
        admin_divisions (GeoDataFrame): Administrative divisions
        batch_size (int): Number of rows to process in each batch
    
    Returns:
        GeoDataFrame: Combined results of all batches
    """
    total_rows = sum(1 for _ in gpd.read_file(pop_path, rows=1))
    print(f"Total population hexagons to process: {total_rows:,}")
    
    all_results = []
    
    for batch_start in tqdm(range(0, total_rows, batch_size), desc="Processing batches"):
        # Load a batch of population data
        world_pop_batch = gpd.read_file(
            pop_path,
            rows=batch_size,
            skiprows=range(1, batch_start + 1) if batch_start > 0 else None
        )
        
        if world_pop_batch.crs != admin_divisions.crs:
            world_pop_batch = world_pop_batch.to_crs(admin_divisions.crs)
        
        # Find intersecting hexagons for this batch
        intersecting = gpd.sjoin(
            world_pop_batch,
            admin_divisions,
            predicate='intersects',
            how='inner'
        )
        
        if len(intersecting) > 0:
            # Process intersecting hexagons
            batch_result = parallel_intersection(
                world_pop_batch.loc[intersecting.index],
                admin_divisions
            )
            all_results.append(batch_result)
            
            # Optional: Save intermediate results
            if len(all_results) % 5 == 0:  # Save every 5 batches
                intermediate = pd.concat(all_results, ignore_index=True)
                intermediate.to_file(
                    output_path / f'intermediate_results_batch_{len(all_results)}.gpkg',
                    driver="GPKG"
                )
    
    return pd.concat(all_results, ignore_index=True) if all_results else None

def main():
    """Main execution function"""
    try:
        print("Loading data...")
        output_path.mkdir(parents=True, exist_ok=True)
        
        print(f"Loading admin divisions from: {ADMIN_DIVISIONS_PATH}")
        admin_divisions = gpd.read_file(ADMIN_DIVISIONS_PATH)
        
        print("Processing population data in batches...")
        intersected = process_population_in_batches(POPULATION_DATA_PATH, admin_divisions)
        
        if intersected is None:
            raise ValueError("No intersecting population data found")
        
        print("Calculating population density...")
        # Calculate areas and adjustments
        intersected['intersected_area'] = intersected.geometry.area
        intersected['area_fraction'] = intersected['intersected_area'] / intersected.geometry.area
        intersected['adjusted_population'] = intersected['population'] * intersected['area_fraction']
        
        # Aggregate results
        population_by_admin = (
            intersected.groupby('GID_1')['adjusted_population']
            .sum()
            .reset_index()
        )
        
        # Merge and calculate final density
        result = admin_divisions.merge(
            population_by_admin,
            on='GID_1',
            how='left'
        )
        result['population_density'] = result['adjusted_population'] / result['area_km2']
        
        print("\nResults summary:")
        print(result[['NAME_1', 'adjusted_population', 'area_km2', 'population_density']])
        
        print(f"\nSaving results to: {RESULTS_PATH}")
        result.to_file(RESULTS_PATH, driver="GPKG")
        
        print("\nProcessing completed successfully!")
        return result
        
    except Exception as e:
        print(f"Error in main execution: {str(e)}")
        raise

if __name__ == '__main__':
    main()