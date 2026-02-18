### A exécuter un par un et attendre que ce soit bien terminé avant de passer à la ligne suivante (ça peut prendre quelques minutes par ligne!)
if (!require("lme4")) install.packages("lme4", dependencies = TRUE)
if (!require("afex")) install.packages("afex", dependencies = TRUE)
if (!require("emmeans")) install.packages("emmeans", dependencies = TRUE)
if (!require("openxlsx")) install.packages("openxlsx")

library(lme4)
library(afex)
library(emmeans)
library(openxlsx)

df <- read.csv("H:/Home/Documents/Psychoacoustique/Rstudio/FakeDataset.csv",header=TRUE,sep=",")

# Modèle linéaire mixte pour les mesures répétées
modele <- lmer(
  Réponse ~ Facteur1 * Facteur2 * Facteur3 + (1 | Sujet),
  data = df
)

# Résumé du modèle
summary(modele)

# ANOVA pour tester les effets des facteurs
anova_table <- anova(modele)
print(anova_table)
write.xlsx(anova_table,file = "ANOVA.xlsx",rowNames=FALSE)
# Post-hoc avec ajustement des comparaisons multiples
emmeans_results <- emmeans(modele, ~ Facteur1 * Facteur2 * Facteur3)
ComparaisonParPaire <- pairs(emmeans_results)
write.xlsx(ComparaisonParPaire,file = "ComparaisonParPaire.xlsx",rowNames=FALSE)

# Visualisation des résultats (facultatif)
# if (!require("ggplot2")) install.packages("ggplot2", dependencies = TRUE)
# library(ggplot2)
# 
# ggplot(data, aes(x = Facteur1, y = Réponse, fill = Facteur2)) +
#   geom_boxplot(position = position_dodge()) +
#   facet_wrap(~Facteur3) +
#   theme_minimal() +
#   labs(title = "Analyse des mesures répétées",
#        x = "Facteur 1",
#        y = "Réponse",
#        fill = "Facteur 2")
