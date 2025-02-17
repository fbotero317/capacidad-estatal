# -------------------------------------------------- #
#             Vote buying measurments
#             Author: Alejandro Castillo-Ardila
#             Febrary 14th of 2025 
# -------------------------------------------------- #

# Load pacman
if (!require("pacman")) install.packages("pacman")

pacman::p_load(tidyverse, rio, janitor, skimr, ggplot2, haven,
               sandwich, lmtest)


# -------------------------------------------------- #
# Load CEDE data  ---------------------------------####
# -------------------------------------------------- #

panel_bg <- read_dta("paper-2/Data/PANEL_BUEN_GOBIERNO(2024).dta")
panel_cv <- read_dta("paper-2/Data/PANEL_CONFLICTO_Y_VIOLENCIA(2024).dta")
panel_cg <- read_dta("paper-2/Data/PANEL_CARACTERISTICAS_GENERALES(2024).dta")

panel <- panel_bg %>%
  left_join(panel_cv, by = c("codmpio", "ano")) %>%
  left_join(panel_cg, by = c("codmpio", "ano"))

remove(panel_bg, panel_cv, panel_cg)

# --------------------------------------------------- #
# Clean relevant variables of CEDE data             ####
# --------------------------------------------------- #

panelSGR <- panel %>%  #Dataframe with relevant variables
  select(codmpio, ano, y_total, y_corr, y_transf, y_transf_nal, y_transf_otra,
         g_total, g_corr, g_func, y_cap_regalias, y_cap_transf, y_cap_cofinan,
         y_cap_otros, MDM_igpr, MDM, MDM_tasa_recaudo, indesarrollo_mun,
         SGP_propgeneral_li, SRAanh_regalias_productor, SGR_total,SGR_adirectas,
         SGR_adirectas_hidrocarburos, SRAanh_regalias_productor) %>%
  filter(ano %in% c(1995:2018)) #Filter years 1995-2018 

# --------------------------------------------------- #
# Load Elections Data (2019) and before from CEDE  ####
# --------------------------------------------------- #
elecciones2019 <- read_dta("paper-2/Data/2019_alcaldia.dta")
elecciones2015 <- read_dta("paper-2/Data/2015_alcaldia.dta")
elecciones2011 <- read_dta("paper-2/Data/2011_alcaldia.dta")
elecciones2007 <- read_dta("paper-2/Data/2007_alcaldia.dta")
elecciones2003 <- read_dta("paper-2/Data/2003_alcaldia.dta")
elecciones2000 <- read_dta("paper-2/Data/2000_alcaldia.dta")

#Merge all sets, which have the same variables. First drop circunscripción from all datasets
elecciones2019 <- elecciones2019 %>% select(-circunscripcion)
elecciones2015 <- elecciones2015 %>% select(-circunscripcion)
elecciones2011 <- elecciones2011 %>% select(-circunscripcion)
elecciones2007 <- elecciones2007 %>% select(-circunscripcion)
elecciones2003 <- elecciones2003 %>% select(-circunscripcion)
elecciones2000 <- elecciones2000 %>% select(-circunscripcion)
elecciones <- bind_rows(elecciones2019,
                        elecciones2015,
                        elecciones2011,
                        elecciones2007,
                        elecciones2003,
                        elecciones2000)
remove(elecciones2019, elecciones2015, elecciones2011, elecciones2007,
       elecciones2003, elecciones2000)


# --------------------------------------------------- #
# Load Data of Garbiras-Díaz and Montenegro (2024) ####
# --------------------------------------------------- #

GDyM_Data <- read_dta("paper-2/Data/main_data_municipal_level.dta")

#Create new assigment variables

GDyM_Data <- GDyM_Data %>%
  mutate(assigment1 = case_when(
    is.na(`_assignment`) ~ 0,  # Convert NA to 0
    `_assignment` %in% 1:10 ~ 1,  # Assign 1 to all values from 1 to 10
    TRUE ~ 0  # Assign 0 to any other unexpected values
  ))



# --------------------------------------------------- #
# Create Measures of Electoral Competitiveness ####
# --------------------------------------------------- #

# Winner Strenght
eleccionesWS <- elecciones %>%
  filter(!nombres %in% c("TARJETAS NO MARCADAS", 
                         "VOTOS NULOS", 
                         "VOTOS EN BLANCO")) %>%
  group_by(ano, codmpio) %>%
  filter(sum(elegido == 1) == 1) %>% # Filtrar grupos con un ganador
  mutate(votosG = votos[elegido == 1],
         total_votos = sum(votos, na.rm = TRUE)) %>%
  filter(elegido == 1) %>%
  mutate(WS = votosG / total_votos) %>% 
  filter(elegido == 1) %>% # Winner Strength (WF)
  mutate(anoEle = ano) 

# Histogram of Winner Strength (WF) with facet-wrap by year

HistWS <- eleccionesWS %>%
  filter(departamento %in% c("CASANARE", "META", "ARAUCA", "VICHADA")) %>% 
  ggplot(aes(x = WS)) +
  geom_histogram(binwidth = 0.1, fill = "royalblue", color = "black") +
  facet_wrap(~ano) +
  geom_density(position = "identity") +
  labs(title = "Winner Strength (WF) by Year", x = "Winner Strength (WF)", y = "Frequency") +
  theme_minimal()
print(HistWS)


# --------------------------------------------------- # 
# Margin of Victory                                   #
# --------------------------------------------------- #

eleccionesMV <- elecciones %>%
  filter(!nombres %in% c("TARJETAS NO MARCADAS", 
                         "VOTOS NULOS", 
                         "VOTOS EN BLANCO")) %>% 
  group_by(municipio, ano) %>% #Group by municipality and year
  arrange(desc(votos)) %>% #Arrange each group by the number of votes
  mutate(rank = row_number()) %>%  #Create rank for keeping order
  arrange(municipio) %>% #Arragne dataset by municipality
  group_by(municipio, ano) %>% #Regroup by municipality
  filter(rank <= 2) %>%    # Keep top 2 candidates
  mutate(
    votosG = first(votos),  # First-place votes
    votosS = nth(votos, 2, default = 0), #Second place votes
    total_votos = sum(votos), na.rm = TRUE) %>%
  filter(rank == 1) %>%  # Keep only the winner's row
  mutate(MV = ((votosG / total_votos) * 100) - ((votosS / total_votos) * 100)) %>% 
  filter(elegido == 1)# Margin of Victory in percentage

#Histogram of Margin of Victory (MV) with facet-wrap by year
HistMV <- eleccionesMV %>%
  filter(departamento %in% c("CASANARE", "META", "ARAUCA", "VICHADA")) %>% 
  ggplot(aes(x = MV)) +
  geom_histogram(binwidth = 5, fill = "royalblue", color = "black") +
  facet_wrap(~ano) +
  geom_density() +
  labs(title = "Margin of Victory (MV) by Year", x = "Margin of Victory (MV)", y = "Frequency") +
  theme_minimal()
print(HistMV)
# ------------------------------ #
# Merge Panel Data with Elections####
# ------------------------------ #
panel1 <- panel %>%
  filter(ano %in% c(1999, 2002, 2006, 2010, 2014, 2018)) %>% 
  mutate(anoEle = ano + 1) %>% 
  left_join(eleccionesWS, by = c("codmpio", "anoEle")) 

panel2019 <- panel1 %>% 
  filter(ano.x == 2018)

panel2 <- panel %>% 
  filter(ano %in% c(1999, 2002, 2006, 2010, 2014, 2018)) %>%
  left_join(eleccionesMV, by = "codmpio")

# Merge with Garbiras-Díaz and Montenegro (2024) data

GDyM_Data_merge <-GDyM_Data %>%
  rename(codmpio = ID)

elecciones2019 <- eleccionesWS %>% 
  filter(ano == 2019)

full_panel <- panel %>% 
  filter(ano == 2019) %>% 
  left_join(GDyM_Data_merge, by = "codmpio") %>%
  left_join(elecciones2019, by = "codmpio")

# --------------------------------------------------- #
# Correlation of MDM and irregularities in elections ####
# --------------------------------------------------- #

#Run a correlation between MDM and report_MOE_any
correlationMDM_MOE <- full_panel %>%
  select(MDM, reportMOE_any) %>%
  cor(use = "complete.obs")

print(correlationMDM_MOE)
# plot the correlation
plot_correlation <- ggplot(full_panel, aes(x = MDM, y = reportMOE_any)) +
  geom_point() +
  geom_smooth(method = "lm", se = FALSE) +
  labs(title = "Correlation between MDM and logReport of Irregularities in Elections",
       x = "MDM", y = "Report of Irregularities in Elections") +
  theme_minimal()
print(plot_correlation)

#Regression MOE - MDM

regression_MOE_MDM <- lm(MDM ~ reportMOE_any, 
                         data = full_panel)
summary(regression_MOE_MDM)

coeftest(regression_MOE_MDM, vcov = vcovHC(regression_MOE_MDM, type = "HC1"))

#Regression MOE - Acueducto

regression_MOE_acueducto <- lm(MDM_acueducto ~ reportMOE_any,
                         data = full_panel)

summary(regression_MOE_acueducto)

coeftest(regression_MOE_acueducto, vcov = vcovHC(regression_MOE_acueducto, type = "HC1"))


#Regresion MOE high quality - MDM

regression_MOE_high_quality <- lm(MDM ~ reportMOE_any_quality,
                                  data = full_panel)
summary(regression_MOE_high_quality)

coeftest(regression_MOE_high_quality, vcov = vcovHC(regression_MOE_high_quality, type = "HC1"))

#Verifica si hay repetidos en codmpio
full_panel %>%
  count(codmpio) %>%
  filter(n > 1)  # Shows only duplicates

# Regresiones con dummy

regression_MOEd_MDM <- lm(MDM ~ d_reportMOE_late_any,
                      data = full_panel)

summary(regression_MOEd_MDM)

coeftest(regression_MOEd_MDM, vcov = vcovHC(regression_MOEd_MDM, type = "HC1"))


# Regresion con reportes MOE 2018

regression_MOE2018_MDM <- lm(MDM ~ reports_any_MOE_c2018,
                          data = full_panel)


summary(regression_MOE2018_MDM)

coeftest(regression_MOE2018_MDM, vcov = vcovHC(regression_MOE2018_MDM, type = "HC1"))


#Regresión con reportes MOE 2015

regression_MOE2015_MDM <- lm(MDM ~ reports_any_MOE_a2015,
                          data = full_panel)

summary(regression_MOE2015_MDM)

coeftest(regression_MOE2015_MDM, vcov = vcovHC(regression_MOE2015_MDM, type = "HC1"))


#Regresion con dummy de reportes de calidad el día de las elecciones

regresion_MOE_HQ_MDM <- lm(MDM ~ log1p(d_reportMOE_any_quality),
                           data = full_panel)

summary(regresion_MOE_HQ_MDM)

coeftest(regresion_MOE_HQ_MDM, vcov = vcovHC(regresion_MOE_HQ_MDM, type = "HC1"))


# Run a regression between y_cap_regalias and MOE reports

regression_MOE_regalias <- lm(reportMOE_any ~ log1p(y_cap_regalias),
                              data = full_panel)
summary(regression_MOE_regalias)

coeftest(regression_MOE_regalias, vcov = vcovHC(regression_MOE_regalias, type = "HC1"))

#Plot this

plot_MOE_regalias <- ggplot(full_panel, aes(y = reportMOE_any, x = log1p(y_cap_regalias))) +
  geom_point() +
  geom_smooth(method = "lm", se = FALSE) +
  labs(title = "Correlation between MOE reports and Royalties",
       x = "MOE reports", y = "Royalties") +
  theme_minimal()
print(plot_MOE_regalias)


#Run regression between media_irreg and MDM
regression_MDM_media_irreg <- lm(MDM ~ media_irreg + nbi2005 + l_pop2018 + assigment1, 
                                 data = full_panel)

summary(regression_MDM_media_irreg)

coeftest(regression_MDM_media_irreg, vcov = vcovHC(regression_MDM_media_irreg, type = "HC1"))

#Export the regression result as a JPG, without ggplot. Just put the table


#Regression between dummy of media irreg and MDM

regression_MDM_dmedia_irreg <- lm(MDM ~ d_media_irreg + nbi2005 + l_pop2018, 
                                 data = full_panel)

summary(regression_MDM_dmedia_irreg)

coeftest(regression_MDM_dmedia_irreg, vcov = vcovHC(regression_MDM_dmedia_irreg, type = "HC1"))


#Regression betweeen media_irreg about vote-buying and MDM

regression_MDM_media_irreg_vb <- lm(MDM ~ media_irreg_compra + nbi2005 + l_pop2018, 
                                  data = full_panel)

summary(regression_MDM_media_irreg_vb)

coeftest(regression_MDM_media_irreg_vb, vcov = vcovHC(regression_MDM_media_irreg_vb, type = "HC1"))

#Regression of dummy of media irreg about vote-buying and MDM

regression_MDM_dmedia_irreg_vb <- lm(MDM ~ d_media_irreg_compra + nbi2005 + l_pop2018, 
                                  data = full_panel)

summary(regression_MDM_dmedia_irreg_vb)

coeftest(regression_MDM_dmedia_irreg_vb, vcov = vcovHC(regression_MDM_dmedia_irreg_vb, type = "HC1"))

# Regression between other development indicators (MDM_porc_ds,MDM_recpropios 
# MDM_rendicion, MDM_r_educacion, MDM_mortalidad, SGR_total, SGR_adirectas,
# MDM_acueducto, MDM_alcantarillado, MDM_internet, MDM_r_servicios

#Dependent variables: reportMOE_late_any_quality, reportMOE_any, reportMOE_any_quality,
# media_irreg