# Clientelismo y políticas públicas
# khemani-data01: Preparación de datos Lapop 2018
# Felipe Botero
# 19 de julio de 2024

library(tidyverse)
library(dplyr)
library(ggplot2)
library(haven)


lapop2018 <- read_dta("datos/lapop2018.dta")

# Variable clientelismo: 
# clien4a: aprobación de práctica de dar regalos a cambio de votos
# clien1n: conoce a alguien a quien le ofrecieron regalos a cambio de votos
# clien1na: ha recibido regalos a cambio de votos

# Rename clien4a = apruebacompravoto
lapop2018 <- lapop2018 %>%
  rename(apruebacompravoto = clien4a)

# Rename clien1n = conocecompravoto
lapop2018 <- lapop2018 %>%
  rename(conocecompravoto = clien1n)

# Rename clien1na = vendiovoto
lapop2018 <- lapop2018 %>%
  rename(vendiovoto = clien1na)

# Recode conocecompravoto 1 = "Sí" 2 = "No"
lapop2018 <- lapop2018 %>%
  mutate(conocecompravoto = as.factor(conocecompravoto)) %>%
  mutate(conocecompravoto = recode(conocecompravoto, `1` = "Sí", `2` = "No"))

# Frecuencias conocecompravoto
lapop2018 %>%
  dplyr::select(conocecompravoto) %>%
  table() %>%
  prop.table() %>%
  round(2)

# Recode vendiovoto 1 = "Sí" 2 = "No"
lapop2018 <- lapop2018 %>%
  mutate(vendiovoto = as.factor(vendiovoto)) %>%
  mutate(vendiovoto = recode(vendiovoto, `1` = "Sí", `2` = "No"))

# Frecuencias vendiovoto
lapop2018 %>%
  dplyr::select(vendiovoto) %>%
  table() %>%
  prop.table() %>%
  round(2)

# verificar si hay valores perdidos en conocecompravoto y vendiovoto
lapop2018 %>%
  dplyr::select(conocecompravoto, vendiovoto) %>%
  map_df(~sum(is.na(.)))

# Ver número de observaciones de variables clientelismo por país
lapop2018 %>%
  dplyr::select(pais, conocecompravoto, vendiovoto) %>%
  group_by(pais) %>%
  summarise(
    n = n(),
    n_cli1 = sum(!is.na(conocecompravoto)),
    n_cli2 = sum(!is.na(vendiovoto))
  )

# Lista de países en las que conocecompravoto y vendiovoto tienen valores
lapop2018 %>%
  filter(!is.na(conocecompravoto) | !is.na(vendiovoto)) %>%
  dplyr::select(pais) %>%
  distinct()

# Variables sobre calidad de servicios públicos
# carreteras: sd2new2
# colegiospub: sd3new2
# salud: sd6new2

# Clonar sd2new2 = carreteras, sd3new2 = colegiospub, sd6new2 = salud
lapop2018 <- lapop2018 %>%
  rename(carreteras = sd2new2) %>%
  rename(colegiospub = sd3new2) %>%
  rename(salud = sd6new2)

# Ver número de observaciones de variables de calidad de servicios públicos por país
lapop2018 %>%
  dplyr::select(pais, carreteras, colegiospub, salud) %>%
  group_by(pais) %>%
  summarise(
    n = n(),
    n_carreteras = sum(!is.na(carreteras)),
    n_colegiospub = sum(!is.na(colegiospub)),
    n_salud = sum(!is.na(salud))
  )

# Lista de países en las que las variables de calidad de servicios públicos tienen valores
lapop2018 %>%
  filter(!is.na(carreteras) | !is.na(colegiospub) | !is.na(salud)) %>%
  dplyr::select(pais) %>%
  distinct()

# Recode carreteras, colegiospub, salud 1 & 2 to Satisfecho; 3 & 4 to Insatisfecho
lapop2018 <- lapop2018 %>%
  mutate(carreteras = as.factor(carreteras)) %>%
  mutate(colegiospub = as.factor(colegiospub)) %>%
  mutate(salud = as.factor(salud)) %>%
  mutate(carreteras = recode(carreteras, `1` = "Satisfecho", `2` = "Satisfecho", `3` = "Insatisfecho", `4` = "Insatisfecho")) %>%
  mutate(colegiospub = recode(colegiospub, `1` = "Satisfecho", `2` = "Satisfecho", `3` = "Insatisfecho", `4` = "Insatisfecho")) %>%
  mutate(salud = recode(salud, `1` = "Satisfecho", `2` = "Satisfecho", `3` = "Insatisfecho", `4` = "Insatisfecho"))


# Frecuencias de calidad de servicios públicos
lapop2018 %>%
  dplyr::select(carreteras, colegiospub, salud) %>%
  map(~table(.)) %>%
  map(~prop.table(.) %>% 
        round(2))

# Variables de control
# sexo: Q1
# edad: Q2
# rural or urban household: ur (1) Urban (2) Rural
# number of adults in household: q12c (total adultos) - q12bn (menores de 13)
# level of education: ed
# whether food insecure: fs2, fs8
# ownership of a radio: r3-r16
# ownership of a television: r1
# ownership of a cell phone: r4a
# radio as a daily information source: smedia1-smedia9: socialmedia
# About how often do you pay attention to the news, whether on TV, the radio, newspapers or the internet?: gi0n.
# voted in the last national elections: vb2
# attended a campaign meeting or rally for the last national election: cp13
# worked for a candidate or political party in the last national election
# contacted a politician or government official about some important problems

# Crear variable adultos como g12c-g12bn
lapop2018 <- lapop2018 %>%
  mutate(adultos = pmax(q12c - q12bn, 0))
prop.table(table(lapop2018$adultos))



# summary of variables de control
lapop2018 %>%
  dplyr::select(q1, q2, ur, q12c, adultos, ed, fs2, fs8, r1, r4a, gi0n, vb2, cp13) %>%
  map(~table(.)) %>%
  map(~prop.table(.) %>% 
        round(2))

# Filtrar los países especificados
# Convertir la columna 'pais' a numérico antes de filtrar
lapop2018 <- lapop2018 %>% mutate(pais = as.numeric(pais))

# Filtrar los países especificados
paises_seleccionados <- c(1, 2, 3, 4, 8, 11, 12, 21, 23)
lapop2018_filtrado <- lapop2018 %>% filter(pais %in% paises_seleccionados)

# Verificar los países únicos en el conjunto de datos filtrado
unique(lapop2018_filtrado$pais)

#List of paises
lapop2018_filtrado |> 
  dplyr::select(pais) |> 
  distinct()

# verificar datos de clientelismo en todos los países
# Frequencies of conocecompravoto by country
lapop2018_filtrado %>%
  dplyr::select(pais, conocecompravoto) %>%
  group_by(pais) %>%
  summarise(frequency = list(round(prop.table(table(conocecompravoto)), 2))) %>%
  unnest(frequency)

# colombia no tiene datos de conocecompravoto, pero sí de vendiovoto
lapop2018_filtrado %>%
  filter(pais == "Colombia") %>%
  count(vendiovoto) %>%
  mutate(prop = round(n / sum(n), 2))



# Recodificar pais para que en vez de números salgan los nombres de los países
lapop2018_filtrado <- lapop2018_filtrado %>%
  mutate(pais = recode(pais,
                       `1` = "México",
                       `2` = "Guatemala",
                       `3` = "El Salvador",
                       `4` = "Honduras",
                       `8` = "Colombia",
                       `11` = "Perú",
                       `12` = "Paraguay",
                       `21` = "República Dominicana",
                       `23` = "Jamaica"))
unique(lapop2018_filtrado$pais)

lapop2018_filtrado |> 
  dplyr::select(pais) |> 
  distinct()

# guardar datos rds
saveRDS(lapop2018_filtrado, "datos/lapop2018_filtrado.rds")
