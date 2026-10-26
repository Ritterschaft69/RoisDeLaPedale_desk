# Cycliste reconstruit et pédalage fluide

Télécharger **RoisDeLaPedale-0.4.0-Setup.exe**, puis lancer l’installeur Windows. Le numéro 0.4.0 est visible dans les propriétés du programme et de l’installeur.

Le modèle du cycliste a été reconstruit à partir des vues de face, de profil et de dos fournies : corps et vêtements en surfaces continues, muscles profilés, visage avec mâchoire, lunettes, casque blanc ajouré, gants, poches et fermeture du maillot, chaussettes et chaussures. Les proportions du vélo ont également été revues. Il s’agit toujours d’une interprétation 3D stylisée des illustrations.

Le pédalage a été contrôlé sur un cycle complet de profil : en haut du tour, le pied part vers l’avant (vers la droite dans l’animation ci-dessous). Après une longue pause du rendu, la phase visuelle avance désormais d’au plus 60° par image, pour éviter les sauts pouvant donner l’impression de pédaler à l’envers. À très faible fréquence d’affichage, les jambes ralentissent visuellement ; la cadence mesurée/simulée et la physique ne changent pas. Le modèle passe de 380 à 181 objets de maillage, sans promesse chiffrée de FPS.

Les trois parcours bénéficient d’un filtre spatial supplémentaire avant la B-spline cubique continue et l’interpolation d’affichage. La correction de chaque nœud de la grille de 2 m est limitée à 35 cm horizontalement et 25 cm en altitude. Les fichiers GPX, leurs coordonnées enregistrées et leurs métriques brutes sont conservés.

**Captures du moteur natif**, produites avec `tools/capture_rider.gd` :

![Pédalage de profil](https://github.com/Ritterschaft69/RoisDeLaPedale_desk/releases/download/v0.4.0/v0.4.0-pedalage.gif)
![Cycliste de dos](https://github.com/Ritterschaft69/RoisDeLaPedale_desk/releases/download/v0.4.0/v0.4.0-rear.png)
![Dans la simulation](https://github.com/Ritterschaft69/RoisDeLaPedale_desk/releases/download/v0.4.0/v0.4.0-ride.png)

139 contrôles réussis sous Linux. L’installeur Windows est construit par GitHub Actions ; son exécution sur un vrai poste Windows reste à vérifier. Bluetooth et audio non implémentés ; IGN sur les trois premiers kilomètres de Saint-Dié uniquement.
