# Master script para khemani

inicio <- Sys.time()

source("codigo/khemani-data01.R")   # Preparación VD, VIs y contorles. Crea lapop2018_filtrado.rds
source("codigo/khemani-data02.R")   # Revisión de variables, frecuencias y NAs en los datos
source("codigo/khemani-an01.R")     # Regresiones: tablas completas
source("codigo/khemani-an02.R")     # Regresiones: tablas resumen
source("codigo/khemani-an03.R")     # Regresiones: efectos marginales tablas y gráficos
source("codigo/khemani-an04.R")     # Tabla de estadísticas descriptivas

fin <- Sys.time()
fin - inicio

