from pathlib import Path
import geopandas as gpd
import pandas as pd
import numpy as np
from shapely.geometry import box
import pyproj
import logging
import os
import sys
from mpi4py import MPI
from datetime import datetime

def setup_logging(rank, country_code=None):
    """Set up logging for MPI processes"""
    log_dir = Path('logs')
    log_dir.mkdir(exist_ok=True)
    
    # Create a logger
    logger = logging.getLogger()
    logger.setLevel(logging.INFO)
    
    # Create formatters
    formatter = logging.Formatter(
        '%(asctime)s - Rank %(rank)s - %(levelname)s - %(message)s',
        defaults={'rank': rank}
    )
    
    # File handler - one per rank
    timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
    if country_code:
        log_file = log_dir / f'popdens_rank{rank}_{country_code}_{timestamp}.log'
    else:
        log_file = log_dir / f'popdens_rank{rank}_{timestamp}.log'
    
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

def print_diagnostics(gdf, stage, country_code=None, rank=None):
    """Print diagnostic information about the GeoDataFrame."""
    logging.info(f"\n{'='*50}")
    logging.info(f"DIAGNOSTICS - {stage}")
    if rank is not None:
        logging.info(f"MPI Rank: {rank}")
    if country_code:
        logging.info(f"Country: {COUNTRIES.get(country_code, country_code)}")
    
    logging.info(f"CRS: {gdf.crs}")
    logging.info(f"Number of features: {len(gdf):,}")
    
    if 'population' in gdf.columns:
        total_pop = gdf['population'].sum()
        logging.info(f"Total population: {total_pop:,.0f}")
    
    if gdf.geometry is not None:
        bounds = gdf.total_bounds
        logging.info(f"Bounding Box:")
        logging.info(f"  West:  {bounds[0]:.4f}")
        logging.info(f"  South: {bounds[1]:.4f}")
        logging.info(f"  East:  {bounds[2]:.4f}")
        logging.info(f"  North: {bounds[3]:.4f}")
    
    logging.info(f"Memory usage: {gdf.memory_usage(deep=True).sum() / 1024**2:.2f} MB")
    logging.info("="*50 + "\n")

def process_country(country_code, rank, target_crs="esri:102033"):
    """Process population density for a single country."""
    logger = setup_logging(rank, country_code)
    logger.info(f"\nProcess rank {rank} starting {COUNTRIES.get(country_code, country_code)}...")
    
    try:
        # 1. Load and filter admin divisions for the country
        logger.info(f"Rank {rank}: Loading admin divisions...")
        admin_divisions = gpd.read_file(ADMIN_DIVISIONS_PATH)
        country_admin = admin_divisions[admin_divisions['GID_0'] == country_code].copy()
        print_diagnostics(country_admin, "Admin Divisions", country_code, rank)
        
        if len(country_admin) == 0:
            logger.error(f"Rank {rank}: No admin divisions found for {country_code}")
            return None
        
        # 2. Get country bounds and transform to EPSG:4326 for filtering population data
        country_bounds = tuple(country_admin.to_crs("EPSG:4326").total_bounds)
        logger.info(f"Rank {rank}: Using bounds for {country_code}: {country_bounds}")
        
        # 3. Load population data for country bounds
        logger.info(f"Rank {rank}: Loading population data...")
        country_pop = gpd.read_file(
            POPULATION_DATA_PATH,
            bbox=country_bounds
        )
        print_diagnostics(country_pop, "Population Hexagons", country_code, rank)
        
        if len(country_pop) == 0:
            logger.error(f"Rank {rank}: No population hexagons found for {country_code}")
            return None
            
        # 4. Transform both datasets to target CRS
        logger.info(f"Rank {rank}: Converting to target CRS: {target_crs}")
        country_admin = country_admin.to_crs(target_crs)
        country_pop = country_pop.to_crs(target_crs)
        
        # 5. Spatial join
        logger.info(f"Rank {rank}: Performing spatial join...")
        result = gpd.sjoin(
            country_admin,
            country_pop,
            how="left",
            predicate="intersects"
        )
        print_diagnostics(result, "After Spatial Join", country_code, rank)
        
        # 6. Calculate population density
        logger.info(f"Rank {rank}: Calculating population density...")
        # Group by admin division and sum population
        pop_by_admin = result.groupby('GID_1')['population'].sum().reset_index()
        
        # Merge back to admin divisions
        final_result = country_admin.merge(pop_by_admin, on='GID_1', how='left')
        
        # Calculate area in km² and density
        final_result['area_km2'] = final_result.geometry.area / 1_000_000
        final_result['pop_density'] = final_result['population'] / final_result['area_km2']
        
        print_diagnostics(final_result, "Final Results", country_code, rank)
        
        # 7. Export results
        output_file = RESULTS_PATH / f"{country_code}_popdens_bbox.gpkg"
        logger.info(f"Rank {rank}: Saving results to {output_file}")
        final_result.to_file(output_file, driver="GPKG")
        
        return {
            'country_code': country_code,
            'total_population': final_result['population'].sum(),
            'success': True
        }
        
    except Exception as e:
        logger.error(f"Rank {rank}: Error processing {country_code}: {str(e)}")
        return {
            'country_code': country_code,
            'error': str(e),
            'success': False
        }

def main():
    """Main execution function with MPI"""
    # Initialize MPI
    comm = MPI.COMM_WORLD
    rank = comm.Get_rank()
    size = comm.Get_size()
    
    # Set up logging for the main process
    logger = setup_logging(rank)
    
    # Get list of countries
    country_codes = list(COUNTRIES.keys())
    n_countries = len(country_codes)
    
    # Calculate workload distribution
    countries_per_rank = n_countries // size
    extra = n_countries % size
    
    # Determine this rank's countries
    start_idx = rank * countries_per_rank + min(rank, extra)
    end_idx = start_idx + countries_per_rank + (1 if rank < extra else 0)
    my_countries = country_codes[start_idx:end_idx]
    
    logger.info(f"Rank {rank}/{size-1} processing countries: {my_countries}")
    
    # Process assigned countries
    results = []
    for country_code in my_countries:
        result = process_country(country_code, rank)
        results.append(result)
    
    # Gather all results to rank 0
    all_results = comm.gather(results, root=0)
    
    # Print summary on rank 0
    if rank == 0:
        logger.info("\nProcessing Summary:")
        flat_results = [item for sublist in all_results for item in sublist]
        for result in flat_results:
            if result['success']:
                logger.info(f"{COUNTRIES[result['country_code']]}: "
                          f"{result['total_population']:,.0f}")
            else:
                logger.info(f"{COUNTRIES[result['country_code']]}: "
                          f"Failed - {result.get('error', 'Unknown error')}")

if __name__ == "__main__":
    main()