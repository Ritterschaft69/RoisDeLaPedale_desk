# Cycliste et déplacement fluide

Télécharger **RoisDeLaPedale-0.3.0-Setup.exe** ci-dessous, puis lancer l’installeur Windows.

- Cycliste retravaillé à partir des vues fournies : posture abaissée, maillot orange avec volume suivant le buste, cuisses et mollets profilés, casque blanc à aérations, lunettes, chaussures et chaussettes détaillées. Le modèle reste une interprétation 3D procédurale stylisée des références.
- Sens du pédalage corrigé : le pied part vers l’avant au sommet du tour. Les deux pédales restent opposées ; les roues suivent la distance parcourue.
- Les trois parcours utilisent une grille de 2 m et une B-spline cubique continue, avec tangentes analytiques et prolongement géométrique limité aux extrémités. Le déplacement affiché est interpolé entre les pas de simulation à 50 Hz.
- Les fichiers GPX, distances sources et dénivelés bruts restent intacts. La pente simulée suit la courbe lissée ; les positions enregistrées gardent les coordonnées et altitudes sources.

Les aperçus ci-dessous sont des captures du moteur, pas les illustrations de référence.

![Profil](https://github.com/Ritterschaft69/RoisDeLaPedale_desk/releases/download/v0.3.0/v0.3.0-side.png)
![Dos](https://github.com/Ritterschaft69/RoisDeLaPedale_desk/releases/download/v0.3.0/v0.3.0-rear.png)

Validation : tests Python et Godot, rendu natif Linux. Installeur Windows généré par GitHub Actions ; exécution sous Windows à vérifier. Cette préversion conserve les limites de la démo (pas de Bluetooth ; IGN sur les trois premiers kilomètres de Saint-Dié uniquement).
