import geopandas as gpd
import pandas as pd
import pyogrio
import os
from tqdm import tqdm
import requests
from pathlib import Path
import multiprocessing
from concurrent.futures import ThreadPoolExecutor, as_completed
import threading
from functools import partial
import time

# Set up paths and directories
output_path = Path(Path(__file__).parent.parent,'03_output')

# List of African countries (ISO 3166-1 alpha-3 codes)
countries = [
    'DZA', 'AGO', 'BEN', 'BWA', 'BFA', 'BDI', 'CMR', 'CPV', 'CAF', 'TCD', 
    'COM', 'COG', 'COD', 'DJI', 'EGY', 'GNQ', 'ERI', 'ETH', 'GAB', 'GMB', 
    'GHA', 'GIN', 'GNB', 'CIV', 'KEN', 'LSO', 'LBR', 'LBY', 'MDG', 'MWI', 
    'MLI', 'MRT', 'MUS', 'MAR', 'MOZ', 'NAM', 'NER', 'NGA', 'RWA', 'STP', 
    'SEN', 'SYC', 'SLE', 'SOM', 'ZAF', 'SSD', 'SDN', 'SWZ', 'TZA', 'TGO', 
    'TUN', 'UGA', 'ZMB', 'ZWE'
]

# Thread-safe progress bar
class ThreadSafeCounter:
    def __init__(self, total):
        self.counter = 0
        self.total = total
        self.lock = threading.Lock()
        self.tqdm = tqdm(total=total, desc="Processing countries")

    def update(self):
        with self.lock:
            self.counter += 1
            self.tqdm.update(1)

    def close(self):
        self.tqdm.close()

def download_file(url, filename):
    """Download a file with retry logic"""
    max_retries = 3
    for attempt in range(max_retries):
        try:
            with requests.get(url, stream=True) as r:
                r.raise_for_status()
                total_size = int(r.headers.get('content-length', 0))
                with open(filename, 'wb') as f:
                    for chunk in r.iter_content(chunk_size=8192):
                        f.write(chunk)
            return True
        except requests.exceptions.RequestException as e:
            if attempt == max_retries - 1:
                print(f"Failed to download {filename} after {max_retries} attempts: {str(e)}")
                return False
            time.sleep(2 ** attempt)  # Exponential backoff
    return False

def process_single_country(country_code, counter=None):
    """Process a single country's data"""
    try:
        url = f"https://geodata.ucdavis.edu/gadm/gadm4.1/gpkg/gadm41_{country_code}.gpkg"
        output_file = output_path / f"gadm41_{country_code}.gpkg"
        
        if not output_file.exists():
            if not download_file(url, output_file):
                return country_code, None
        
        gdf = gpd.read_file(output_file, layer="ADM_ADM_1")
        
        if counter:
            counter.update()
            
        return country_code, gdf
        
    except Exception as e:
        print(f"Error processing {country_code}: {str(e)}")
        return country_code, None

def parallel_process_countries(countries_list, max_workers=None):
    """Process countries in parallel using ThreadPoolExecutor"""
    if max_workers is None:
        max_workers = min(32, multiprocessing.cpu_count() * 2)  # Reasonable default
    
    # Create thread-safe counter
    counter = ThreadSafeCounter(len(countries_list))
    
    # Create partial function with counter
    process_func = partial(process_single_country, counter=counter)
    
    results = {}
    failed_countries = []
    
    with ThreadPoolExecutor(max_workers=max_workers) as executor:
        # Submit all tasks
        future_to_country = {
            executor.submit(process_func, country): country 
            for country in countries_list
        }
        
        # Process completed tasks
        for future in as_completed(future_to_country):
            country_code, result = future.result()
            if result is not None:
                results[country_code] = result
            else:
                failed_countries.append(country_code)
    
    counter.close()
    return results, failed_countries

def main():
    # Create output directory if it doesn't exist
    output_path.mkdir(parents=True, exist_ok=True)
    
    print(f"Starting parallel processing of {len(countries)} countries...")
    start_time = time.time()
    
    # Process all countries in parallel
    results, failed_countries = parallel_process_countries(countries)
    
    if failed_countries:
        print(f"\nFailed to process the following countries: {', '.join(failed_countries)}")
    
    if not results:
        raise ValueError("No country data was successfully processed")
    
    # Combine all successful results
    print("\nCombining all country data...")
    africa = gpd.GeoDataFrame(pd.concat(results.values(), ignore_index=True))
    
    # Project to EPSG:102022 (Africa Albers Equal Area Conic)
    print("Projecting to Africa Albers Equal Area Conic...")
    africa = africa.to_crs("esri:102022")
    
    # Calculate area
    print("Calculating areas...")
    africa['area_km2'] = africa.geometry.area / 1e6
    
    # Save the result
    output_file = output_path / "africa_admin_divisions.gpkg"
    print(f"\nSaving results to {output_file}")
    africa.to_file(output_file, driver="GPKG")
    
    elapsed_time = time.time() - start_time
    print(f"\nProcessing completed successfully in {elapsed_time:.2f} seconds!")
    print(f"Successfully processed {len(results)} countries")
    print(f"Failed to process {len(failed_countries)} countries")
    
    return africa, failed_countries

if __name__ == '__main__':
    main()