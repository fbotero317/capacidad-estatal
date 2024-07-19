# Lapop 2018 comparado

library(tidyverse)
library(ggplot2)

# importar datos de stata
library(haven)
lapop <- read_dta("lapop2018-comparado.dta")

# ver paises
lapop %>%
  select(pais) %>%
  distinct()

# Variable clientelismo: 
# clien1n: aprobación de práctica de dar regalos a cambio de votos
# clien1na: conoce a alguien a quien le ofrecieron regalos a cambio de votos
# clien4b: ha recibido regalos a cambio de votos

# Ver número de observaciones de variables clientelismo por país
lapop2018 %>%
  select(pais, clien1n, clien1na) %>%
  group_by(pais) %>%
  summarise(
    n = n(),
    n_cli1 = sum(!is.na(clien1n)),
    n_cli2 = sum(!is.na(clien1na))
  )

# Lista de países en las que clien1n y clien1na tienen valores
lapop2018 %>%
  filter(!is.na(clien1n) | !is.na(clien1na)) %>%
  select(pais) %>%
  distinct()

# Lista de países en las que clien4b (vote buying) tiene valores
lapop2018 %>%
  filter(!is.na(clien4b)) %>%
  select(pais) %>%
  distinct()

# Variables sobre calidad de servicios públicos
# highways: sd2new2
# public schools: sd3new2
# health: sd6new2

# Ver número de observaciones de variables de calidad de servicios públicos por país
lapop %>%
  select(pais, sd2new2, sd3new2, sd6new2) %>%
  group_by(pais) %>%
  summarise(
    n = n(),
    n_highways = sum(!is.na(sd2new2)),
    n_schools = sum(!is.na(sd3new2)),
    n_health = sum(!is.na(sd6new2))
  )

# lista de paises en los que sd2new2, sd3new2 y sd6new2 tienen valores
lapop %>%
  filter(!is.na(sd2new2) | !is.na(sd3new2) | !is.na(sd6new2)) %>%
  select(pais) %>%
  distinct()

# correlación entre prevalencia de clientelismo y calidad de servicios públicos
lapop %>%
  select(clien1n, clien1na, clien4b, sd2new2, sd3new2, sd6new2) %>%
  cor(use = "pairwise.complete.obs")

# Gráfico de dispersión entre clientelismo y calidad de carreteras
lapop %>%
  ggplot(aes(x = clien1n, y = sd2new2)) +
  geom_jitter() +
  geom_smooth(method = "lm") +
  labs(
    x = "Aprobación de clientelismo",
    y = "Calidad de carreteras"
  )

# Gráfico de dispersión entre clientelismo y calidad de servicio salud
lapop %>%
  ggplot(aes(x = clien1n, y = sd6new2)) +
  geom_jitter() +
  geom_smooth(method = "lm") +
  labs(
    x = "Aprobación de clientelismo",
    y = "Calidad de servicios de salud"
  )

# Gráfico de dispersión entre clientelismo y calidad de servicio educativo
lapop %>%
  ggplot(aes(x = clien1n, y = sd3new2)) +
  geom_jitter() +
  geom_smooth(method = "lm") +
  labs(
    x = "Aprobación de clientelismo",
    y = "Calidad de servicios educativos"
  )

# Gráfico de dispersión entre clien1na y calidad de carreteras
lapop %>%
  ggplot(aes(x = clien1na, y = sd2new2)) +
  geom_jitter() +
  geom_smooth(method = "lm") +
  labs(
    x = "Conoce a alguien que ha recibido regalos a cambio de votos",
    y = "Calidad de carreteras"
  )

# Gráfico de dispersión entre clien1na y calidad de servicio de salud
lapop %>%
  ggplot(aes(x = clien1na, y = sd6new2)) +
  geom_jitter() +
  geom_smooth(method = "lm") +
  labs(
    x = "Conoce a alguien que ha recibido regalos a cambio de votos",
    y = "Calidad de servicios de salud"
  )

# Gráfico de dispersión entre clien1na y calidad de servicio educativo
lapop %>%
  ggplot(aes(x = clien1na, y = sd3new2)) +
  geom_jitter() +
  geom_smooth(method = "lm") +
  labs(
    x = "Conoce a alguien que ha recibido regalos a cambio de votos",
    y = "Calidad de servicios educativos"
  )

# Recodificar clien1na 1=Sí, 2=No
lapop <- lapop %>%
  mutate(clien1na = as.factor(clien1na)) %>%
  mutate(clien1na = recode(clien1na, `1` = "Sí", `2` = "No"))

# Gráfico de dispersión entre clien1na y calidad de carreteras, con regresión lineal, drop NA
lapop %>%
  filter(!is.na(clien1na) & !is.na(sd2new2)) %>%
  ggplot(aes(x = clien1na, y = sd2new2)) +
  geom_jitter() +
  geom_smooth(method = "lm") +
  labs(
    x = "Conoce a alguien que ha recibido regalos a cambio de votos",
    y = "Calidad de carreteras"
  )

# recodificar clien1na 1=Sí, 2=No
lapop <- lapop %>%
  mutate(clien1na = as.factor(clien1na)) %>%
  mutate(clien1na = recode(clien1na, `1` = "Sí", `2` = "No"))

lapop %>%
  filter(!is.na(clien1na) & !is.na(sd3new2)) %>%
  ggplot(aes(x = clien1na, y = sd3new2)) +
  geom_jitter() +
  geom_smooth(method = "lm") +
  labs(
    x = "Conoce a alguien que ha recibido regalos a cambio de votos",
    y = "Calidad de servicios de salud"
  )
