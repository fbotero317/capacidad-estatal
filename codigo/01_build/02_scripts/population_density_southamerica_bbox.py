from pathlib import Path
import geopandas as gpd
import pandas as pd
import numpy as np
from shapely.geometry import box
import pyproj
from tqdm import tqdm
import logging

# Set up logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(levelname)s - %(message)s'
)

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
    
    if gdf.geometry is not None:
        bounds = gdf.total_bounds
        logging.info(f"Bounding Box:")
        logging.info(f"  West:  {bounds[0]:.4f}")
        logging.info(f"  South: {bounds[1]:.4f}")
        logging.info(f"  East:  {bounds[2]:.4f}")
        logging.info(f"  North: {bounds[3]:.4f}")
    
    logging.info(f"Memory usage: {gdf.memory_usage(deep=True).sum() / 1024**2:.2f} MB")
    logging.info("="*50 + "\n")

def process_country(country_code, target_crs="esri:102033"):
    """
    Process population density for a single country.
    
    Args:
        country_code (str): Three-letter country code
        target_crs (str): Target CRS for processing (default: South America Albers Equal Area)
    """
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
        country_bounds = country_admin.to_crs("EPSG:4326").total_bounds
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
        
        # 5. Spatial join
        logging.info("Performing spatial join...")
        result = gpd.sjoin(
            country_admin,
            country_pop,
            how="left",
            predicate="intersects"
        )
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
        
        return final_result
        
    except Exception as e:
        logging.error(f"Error processing {country_code}: {str(e)}")
        return None

def main():
    """Main execution function"""
    logging.info("Starting population density calculation for South American countries")
    
    results = {}
    for country_code in tqdm(COUNTRIES.keys()):
        result = process_country(country_code)
        if result is not None:
            results[country_code] = result
    
    # Print summary of all countries
    logging.info("\nProcessing Summary:")
    for country_code, result in results.items():
        total_pop = result['population'].sum() if result is not None else 0
        logging.info(f"{COUNTRIES[country_code]}: {total_pop:,.0f}")

if __name__ == "__main__":
    main()