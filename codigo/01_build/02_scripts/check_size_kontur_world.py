import geopandas as gpd
from pathlib import Path
import fiona

# Set up paths and directories
work_dir = Path(Path(__file__).parent.parent.parent.parent)
output_path = Path(Path(__file__).parent.parent, '03_output')
data_path = Path(work_dir, 'datos')

# Define specific data paths
ADMIN_DIVISIONS_PATH = work_dir / 'codigo' / '01_build' / '03_output'/ 'south_america_admin_divisions.gpkg'
POPULATION_DATA_PATH = data_path / 'spatial' / 'kontur_population_CO_20231101.gpkg'
RESULTS_PATH = output_path / 'population_density_results.gpkg'


# First, let's just count the rows using fiona
path = POPULATION_DATA_PATH

with fiona.open(path) as src:
    total_rows = len(src)
    print(f"Total number of rows: {total_rows:,}")
    
    # Let's also look at the schema to understand the data structure
    print("\nSchema:")
    print(src.schema)
    
    # And get the file size in GB
    file_size_gb = Path(path).stat().st_size / (1024**3)
    print(f"\nFile size: {file_size_gb:.2f} GB")
