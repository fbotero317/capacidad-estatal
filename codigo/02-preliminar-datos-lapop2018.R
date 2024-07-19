# Calidad de servicios públicos y compra de votos

library(tidyverse)
library(ggplot2)
library(haven)

# Cargamos la base de datos
lapop <- read_dta("lapop2018-comparado.dta")

# Variables de interés
# age: q1
# gender: q2
# rural or urban household: ur
# number of adults in household: q12c (total) - q12bn (menores de 13)
# level of education:
# whether food insecure: fs2, fs8
# 
# ownership of:
# r3: Refrigerator
# r4: Landline/residential telephone (not cellular)
# r4A: Cellular telephone/mobile. (Accept smartphone)
# r5: Vehicle/car. How many? [If the interviewee does not say how many, mark “one.”]
# r6: Washing machine
# r7: Microwave oven
# r8: Motorcycle
# r12: Drinking water line/pipe to the house
# r14: Indoor bathroom/toilet/WC
# r15: Computer (Accept tablet, iPad)
# r18: Internet from your home (included phone or tablet)
# r1: Television
# r16: Flat panel TV
# 
# information sources:
# gi0n: About how often do you pay attention to the news, whether on TV, the radio,
# newspapers or the internet?
# smedia1: Do you have a Facebook account?
# smedia2: How often do you see content on Facebook?
# smedia3: How often do you see political information on Facebook?
# smedia4: Do you have a Twitter account?
# smedia5: How often do you see content on Twitter?
# smedia6: How often do you see political information on Twitter?
# smedia7: Do you have a WhatsApp account?
# smedia8: How often do you use WhatsApp?
# smedia9: How often do you see political information on WhatsApp? 
# 
# 
# voted in the last presidential elections: vb2
# attended a campaign meeting or rally for the last national election: 
# interest in politics: pol1
# worked for a candidate or political party in the last national election:
# contacted a politician or government official about some important problems:


# Tabla de estadísticas descriptivas: q1, q2, ur, ed, r4, 41, vb2, pol1, 
# smedia1, smedia2, smedia3, smedia4, smedia5, smedia6, smedia7, smedia8, smedia9
# fs2, fs8
# clien1n, clien1na, clien4b
# sd2new2, sd3new2, sd6new2

lapop %>%
  select(q1, q2, ur, ed, r4, r4, r5, r6, r7, r8, r12, r14, r15, r18, r1, r16, gi0n, smedia1, smedia2, smedia3, smedia4, smedia5, smedia6, smedia7, smedia8, smedia9, fs2, fs8, clien1n, clien1na, clien4b, sd2new2, sd3new2, sd6new2) %>%
  summary()
