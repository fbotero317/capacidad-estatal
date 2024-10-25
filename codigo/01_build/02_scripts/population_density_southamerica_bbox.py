from pathlib import Path
import geopandas as gpd
import pandas as pd
import numpy as np
from shapely.geometry import box
import pyproj
from tqdm import tqdm
import logging
import os
import sys
import multiprocessing
from functools import partial

# Set up logging
def setup_logging():
    """Set up logging to both file and console"""
    log_dir = Path('logs')
    log_dir.mkdir(exist_ok=True)
    
    # Create a logger
    logger = logging.getLogger()
    logger.setLevel(logging.INFO)
    
    # Create formatters
    formatter = logging.Formatter(
        '%(asctime)s - %(levelname)s - %(message)s'
    )
    
    # File handler
    log_file = log_dir / f'popdens_{os.getpid()}.log'
    file_handler = logging.FileHandler(log_file)
    file_handler.setFormatter(formatter)
    logger.addHandler(file_handler)
    
    # Console handler
    console_handler = logging.StreamHandler(sys.stdout)
    console_handler.setFormatter(formatter)
    logger.addHandler(console_handler)
    
    return logger

# Set up paths and directories
work_dir = Path(Path(__file__).parent.parent.parent.parent)
output_path = Path(Path(__file__).parent.parent, '03_output')
data_path = Path(work_dir, 'datos')

# Define specific data paths
ADMIN_DIVISIONS_PATH = work_dir / 'codigo' / '01_build' / '03_output' / 'south_america_admin_divisions.gpkg'
POPULATION_DATA_PATH = data_path / 'spatial' / 'kontur_population_20231101.gpkg'
RESULTS_PATH = output_path / 'country_results'

# Create results directory if it doesn't exist
RESULTS_PATH.mkdir(parents=True, exist_ok=True)

# South American countries with their ISO codes
COUNTRIES = {
    'ARG': 'Argentina',
    'BOL': 'Bolivia',
    'BRA': 'Brazil',
    'CHL': 'Chile',
    'COL': 'Colombia',
    'ECU': 'Ecuador',
    'GUF': 'French Guiana',
    'GUY': 'Guyana',
    'PRY': 'Paraguay',
    'PER': 'Peru',
    'SUR': 'Suriname',
    'URY': 'Uruguay',
    'VEN': 'Venezuela'
}

def print_diagnostics(gdf, stage, country_code=None):
    """Print diagnostic information about the GeoDataFrame."""
    logging.info(f"\n{'='*50}")
    logging.info(f"DIAGNOSTICS - {stage}")
    if country_code:
        logging.info(f"Country: {COUNTRIES.get(country_code, country_code)}")
    
    logging.info(f"CRS: {gdf.crs}")
    logging.info(f"Number of features: {len(gdf):,}")
    
    if 'population' in gdf.columns:
        total_pop = gdf['population'].sum()
        logging.info(f"Total population: {total_pop:,.0f}")
        
        # Additional population diagnostics
        non_zero = (gdf['population'] > 0).sum()
        zero_pop = (gdf['population'] == 0).sum()
        nan_pop = gdf['population'].isna().sum()
        logging.info(f"Population features > 0: {non_zero:,}")
        logging.info(f"Population features = 0: {zero_pop:,}")
        logging.info(f"Population features NaN: {nan_pop:,}")
    
    if gdf.geometry is not None:
        bounds = gdf.total_bounds
        logging.info(f"Bounding Box:")
        logging.info(f"  West:  {bounds[0]:.4f}")
        logging.info(f"  South: {bounds[1]:.4f}")
        logging.info(f"  East:  {bounds[2]:.4f}")
        logging.info(f"  North: {bounds[3]:.4f}")
    
    logging.info(f"Memory usage: {gdf.memory_usage(deep=True).sum() / 1024**2:.2f} MB")
    logging.info("="*50 + "\n")

def parallel_spatial_join(args):
    """Execute spatial join for a chunk of data"""
    pop_chunk, admin_gdf = args
    try:
        result = gpd.sjoin(
            admin_gdf,
            pop_chunk,
            how="left",
            predicate="intersects"
        )
        return result
    except Exception as e:
        logging.error(f"Error in parallel spatial join: {str(e)}")
        return None

def process_country(country_code, target_crs="esri:102033"):
    """Process population density for a single country."""
    logging.info(f"\nProcessing {COUNTRIES.get(country_code, country_code)}...")
    
    try:
        # 1. Load and filter admin divisions for the country
        logging.info("Loading admin divisions...")
        admin_divisions = gpd.read_file(ADMIN_DIVISIONS_PATH)
        country_admin = admin_divisions[admin_divisions['GID_0'] == country_code].copy()
        print_diagnostics(country_admin, "Admin Divisions", country_code)
        
        if len(country_admin) == 0:
            logging.error(f"No admin divisions found for {country_code}")
            return None
        
        # 2. Get country bounds and transform to EPSG:4326 for filtering population data
        country_bounds = tuple(country_admin.to_crs("EPSG:4326").total_bounds)
        logging.info(f"Using bounds for {country_code}: {country_bounds}")
        
        # 3. Load population data for country bounds
        logging.info("Loading population data...")
        country_pop = gpd.read_file(
            POPULATION_DATA_PATH,
            bbox=country_bounds
        )
        print_diagnostics(country_pop, "Population Hexagons", country_code)
        
        if len(country_pop) == 0:
            logging.error(f"No population hexagons found for {country_code}")
            return None
            
        # 4. Transform both datasets to target CRS
        logging.info(f"Converting to target CRS: {target_crs}")
        country_admin = country_admin.to_crs(target_crs)
        country_pop = country_pop.to_crs(target_crs)
        
        # 5. Parallel Spatial join
        logging.info("Performing parallel spatial join...")
        
        # Split population data into chunks
        num_cores = multiprocessing.cpu_count() - 1  # Leave one core free
        chunk_size = max(1, len(country_pop) // num_cores)
        pop_chunks = [country_pop.iloc[i:i + chunk_size] for i in range(0, len(country_pop), chunk_size)]
        
        # Prepare arguments for parallel processing
        args = [(chunk, country_admin) for chunk in pop_chunks]
        
        # Execute parallel spatial join
        with multiprocessing.Pool(num_cores) as pool:
            results = list(tqdm(
                pool.imap(parallel_spatial_join, args),
                total=len(args),
                desc="Processing chunks"
            ))
        
        # Combine results
        result = pd.concat([r for r in results if r is not None], ignore_index=True)
        print_diagnostics(result, "After Spatial Join", country_code)
        
        # 6. Calculate population density
        logging.info("Calculating population density...")
        # Group by admin division and sum population
        pop_by_admin = result.groupby('GID_1')['population'].sum().reset_index()
        
        # Merge back to admin divisions
        final_result = country_admin.merge(pop_by_admin, on='GID_1', how='left')
        
        # Calculate area in km² and density
        final_result['area_km2'] = final_result.geometry.area / 1_000_000
        final_result['pop_density'] = final_result['population'] / final_result['area_km2']
        
        print_diagnostics(final_result, "Final Results", country_code)
        
        # 7. Export results
        output_file = RESULTS_PATH / f"{country_code}_popdens_bbox.gpkg"
        logging.info(f"Saving results to {output_file}")
        final_result.to_file(output_file, driver="GPKG")
        
        return {
            'country_code': country_code,
            'total_population': final_result['population'].sum(),
            'success': True
        }
        
    except Exception as e:
        logging.error(f"Error processing {country_code}: {str(e)}")
        return {
            'country_code': country_code,
            'error': str(e),
            'success': False
        }

def main():
    """Main execution function"""
    logger = setup_logging()
    logger.info("Starting population density calculation for South American countries")
    
    results = []
    for country_code in tqdm(COUNTRIES.keys(), desc="Processing countries"):
        result = process_country(country_code)
        results.append(result)
    
    # Print summary
    logger.info("\nProcessing Summary:")
    for result in results:
        if result and result['success']:
            logger.info(f"{COUNTRIES[result['country_code']]}: "
                      f"{result['total_population']:,.0f}")
        else:
            logger.info(f"{COUNTRIES[result['country_code']]}: Failed - "
                      f"{result.get('error', 'Unknown error')}")

if __name__ == "__main__":
    main()