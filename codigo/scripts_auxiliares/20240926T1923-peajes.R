


peajes <- import("/Users/upar/Downloads/Peajes_data.csv")
peajes <- peajes %>% filter(!is.na(latitud))
peajes <- peajes %>% filter(!is.na(longitud))
peajes_sf<- st_as_sf(peajes, coords = c('latitud', 'longitud'), crs = 4686)


if(!file.exists("/Users/upar/Downloads/Peajes_data.csv")){
  print("Si existe")
} else{print("No esiste")
    }

