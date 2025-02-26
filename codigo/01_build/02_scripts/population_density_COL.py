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
ADMIN_DIVISIONS_PATH = work_dir / 'codigo' / '01_build' / '03_output'/ 'gadm41_COL.gpkg'
POPULATION_DATA_PATH = data_path / 'spatial' / 'kontur_population_CO_20231101.gpkg'
RESULTS_PATH = output_path / 'population_density_results_colombia.gpkg'

# Hypatia-optimized settings
BATCH_SIZE = 5000  # Increased for 32GB RAM
CHUNK_SIZE = 1500  # Increased for 32 cores

def print_diagnostic(phase, gdf, group_col='GID_1', pop_col='population'):
    """
    Print diagnostic information about the GeoDataFrame at various stages.
    
    Args:
        phase (str): Name of the processing phase
        gdf (GeoDataFrame): Data to analyze
        group_col (str): Column to group by (e.g., 'GID_1' for admin divisions)
        pop_col (str): Column containing population data
    """
    print(f"\n=== Diagnostic Report: {phase} ===")
    print(f"Total rows: {len(gdf):,}")
    print(f"Memory usage: {gdf.memory_usage(deep=True).sum() / 1024**2:.2f} MB")
    print(f"Columns: {gdf.columns.tolist()}")
    
    if pop_col in gdf.columns:
        print(f"\nPopulation statistics:")
        print(f"Total population: {gdf[pop_col].sum():,.0f}")
        print(f"Non-zero population rows: {(gdf[pop_col] > 0).sum():,}")
        print(f"Zero population rows: {(gdf[pop_col] == 0).sum():,}")
        print(f"NaN population rows: {gdf[pop_col].isna().sum():,}")
    
    if group_col in gdf.columns:
        print(f"\nUnique {group_col} values: {gdf[group_col].nunique()}")
        
    print("\nSample of data:")
    print(gdf.head(2))
    print("=" * 50)

def validate_intersection_result(result, admin_gdf, phase=""):
    """
    Validate intersection results and print diagnostics.
    """
    print(f"\n>>> Validation Report for {phase}")
    
    # Check for empty result
    if result is None or len(result) == 0:
        print("WARNING: Empty intersection result!")
        return False
        
    # Check for missing admin areas
    missing_admins = set(admin_gdf['GID_1']) - set(result['GID_1'])
    if missing_admins:
        print(f"WARNING: {len(missing_admins)} admin areas have no intersection:")
        print(f"Missing GID_1s: {sorted(list(missing_admins))[:5]}...")
        
        # Get names of missing admin areas
        missing_names = admin_gdf[admin_gdf['GID_1'].isin(missing_admins)][['GID_1', 'NAME_1']]
        print("\nMissing areas:")
        print(missing_names.head())
    
    return True

def process_chunk(chunk_data):
    """
    Process a chunk of data with diagnostic information.
    """
    df_chunk, admin_divisions = chunk_data
    try:
        result = gpd.overlay(df_chunk, admin_divisions, how='intersection')
        if result is not None and len(result) > 0:
            print(f"Chunk 
                  processed successfully: {len(result)} intersections found")
            return result
        else:
            print(f"Warning: Empty result for chunk of size {len(df_chunk)}")
            return None
    except Exception as e:
        print(f"Error processing chunk: {str(e)}")
        return None

def chunk_geodataframe(gdf, num_chunks):
    """
    Split a GeoDataFrame into roughly equal chunks for parallel processing.
    
    Args:
        gdf (GeoDataFrame): Input GeoDataFrame to split
        num_chunks (int): Number of chunks to split the data into
    
    Returns:
        list: List of GeoDataFrame chunks
    """
    # Calculate chunk size
    chunk_size = len(gdf) // num_chunks
    remainder = len(gdf) % num_chunks
    
    chunks = []
    start_idx = 0
    
    for i in range(num_chunks):
        # Add one extra row to some chunks if there's a remainder
        current_chunk_size = chunk_size + (1 if i < remainder else 0)
        end_idx = start_idx + current_chunk_size
        
        # Extract chunk using iloc
        chunk = gdf.iloc[start_idx:end_idx].copy()
        chunks.append(chunk)
        
        start_idx = end_idx
    
    return chunks


def parallel_intersection(df1, df2, chunk_size=5000):
    """
    Parallel intersection with enhanced diagnostics.
    """
    print(f"\nStarting parallel intersection:")
    print(f"Input data size: {len(df1):,} rows")
    print(f"Number of admin areas: {len(df2):,}")
    
    num_cores = max(1, multiprocessing.cpu_count() - 2)
    num_chunks = max(num_cores * 2, len(df1) // chunk_size)
    
    # Prepare chunks with admin divisions
    df_split = chunk_geodataframe(df1, num_chunks) 
    chunk_data = [(chunk, df2) for chunk in df_split]

    results = []
    try:
        with multiprocessing.Pool(num_cores) as pool:
            for result in tqdm(
                pool.imap_unordered(process_chunk, chunk_data),
                total=len(chunk_data),
                desc="Processing chunks"
            ):
                if result is not None:
                    results.append(result)
                    if len(results) % 10 == 0:  # Print progress every 10 chunks
                        print(f"Processed {len(results)} chunks successfully")
    
    except Exception as e:
        print(f"Error in parallel processing: {str(e)}")
        raise
    
    if not results:
        raise ValueError("No valid results obtained from parallel processing")
    
    combined_result = pd.concat(results, ignore_index=True)
    print(f"\nParallel processing completed:")
    print(f"Total intersections found: {len(combined_result):,}")
    return combined_result

def process_population_in_batches(pop_path, admin_divisions, batch_size=500000):
    """
    Process population data in batches with comprehensive diagnostics.
    """
    # Initial diagnostic of admin divisions
    print_diagnostic("Admin Divisions Input", admin_divisions)
    
    total_rows = sum(1 for _ in gpd.read_file(pop_path, rows=1))
    print(f"\nTotal population hexagons to process: {total_rows:,}")
    
    all_results = []
    total_population = 0
    
    for batch_start in tqdm(range(0, total_rows, batch_size), desc="Processing batches"):
        print(f"\n{'='*80}")
        print(f"Processing batch starting at row {batch_start:,}")
        
        # Load batch
        world_pop_batch = gpd.read_file(
            pop_path,
            rows=batch_size,
            skiprows=range(1, batch_start + 1) if batch_start > 0 else None
        )
        
        print_diagnostic("Batch Input", world_pop_batch)
        
        # CRS alignment
        if world_pop_batch.crs != admin_divisions.crs:
            world_pop_batch = world_pop_batch.to_crs(admin_divisions.crs)
        
        # Find intersecting hexagons
        intersecting = gpd.sjoin(
            world_pop_batch,
            admin_divisions,
            predicate='intersects',
            how='inner'
        )
        
        print_diagnostic("After Spatial Join", intersecting)
        
        if len(intersecting) > 0:
            batch_result = parallel_intersection(
                world_pop_batch.loc[intersecting.index],
                admin_divisions
            )
            
            if batch_result is not None:
                print_diagnostic("Batch Result", batch_result)
                all_results.append(batch_result)
                
                # Update total population
                total_population += batch_result['population'].sum()
                print(f"Cumulative total population: {total_population:,.0f}")
                
                # Save intermediate results
                if len(all_results) % 5 == 0:
                    intermediate = pd.concat(all_results, ignore_index=True)
                    intermediate_path = output_path / f'intermediate_results_batch_{len(all_results)}.gpkg'
                    print(f"Saving intermediate results to {intermediate_path}")
                    intermediate.to_file(intermediate_path, driver="GPKG")
        else:
            print(f"WARNING: No intersecting hexagons found in batch starting at {batch_start}")
    
    if not all_results:
        print("ERROR: No results generated from any batch!")
        return None
    
    final_result = pd.concat(all_results, ignore_index=True)
    print("\nFinal Processing Summary:")
    print_diagnostic("Final Combined Results", final_result)
    return final_result

def main():
    """Main execution function with enhanced error checking and diagnostics"""
    try:
        print("Loading data...")
        output_path.mkdir(parents=True, exist_ok=True)
        
        # Load and validate admin divisions
        print(f"Loading admin divisions from: {ADMIN_DIVISIONS_PATH}")
        admin_divisions = gpd.read_file(ADMIN_DIVISIONS_PATH, layer='ADM_ADM_1')
        print_diagnostic("Initial Admin Divisions", admin_divisions)
        
        # Process population data
        intersected = process_population_in_batches(POPULATION_DATA_PATH, admin_divisions)
        
        if intersected is None:
            raise ValueError("No intersecting population data found")
        
        # Calculate population density
        print("\nCalculating population density...")
        intersected['intersected_area'] = intersected.geometry.area
        intersected['area_fraction'] = intersected['intersected_area'] / intersected.geometry.area
        intersected['adjusted_population'] = intersected['population'] * intersected['area_fraction']
        
        # Aggregate by admin area
        population_by_admin = (
            intersected.groupby('GID_1')['adjusted_population']
            .sum()
            .reset_index()
        )
        
        print("\nPopulation by admin area:")
        print(population_by_admin.sort_values('adjusted_population', ascending=False).head(10))
        
        # Final merge and density calculation
        result = admin_divisions.merge(
            population_by_admin,
            on='GID_1',
            how='left'
        )
        #result['population_density'] = result['adjusted_population'] / result['area_km2']
        
        # Final diagnostics
        print("\nFinal Results Summary:")
        zero_pop = result[result['adjusted_population'] == 0]
        if len(zero_pop) > 0:
            print(f"\nWARNING: {len(zero_pop)} areas have zero population:")
            print(zero_pop[['GID_1', 'NAME_1', 'area_km2']])
        
        nan_pop = result[result['adjusted_population'].isna()]
        if len(nan_pop) > 0:
            print(f"\nWARNING: {len(nan_pop)} areas have NaN population:")
            print(nan_pop[['GID_1', 'NAME_1', 'area_km2']])
        
        # Save results
        print(f"\nSaving results to: {RESULTS_PATH}")
        result.to_file(RESULTS_PATH, driver="GPKG")
        
        return result
        
    except Exception as e:
        print(f"Error in main execution: {str(e)}")
        raise

if __name__ == '__main__':
    main()
