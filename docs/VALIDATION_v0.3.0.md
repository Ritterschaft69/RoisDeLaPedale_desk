# Validation 0.3.0 — 26 octobre 2026

130 contrôles réussis : 12 Python, 24 simulation, 10 desktop, 34 circuits, 24 navigation, 11 géométrie et 15 courbe de parcours.

La nouvelle suite parcourt tous les nœuds de la grille de chacun des trois GPX. Elle vérifie les tangentes analytiques de part et d’autre des raccords, les valeurs finies, les extrémités ancrées, le prolongement limité à 12 m et un écart horizontal inférieur à 1,5 m par rapport à la station source sur ces circuits. Le lissage est spatial et indépendant de la fréquence d’affichage : grille uniforme d’environ 2 m, B-spline cubique à poids positifs, tangente analytique. La pente utilise la même géométrie lissée. Les enregistrements conservent latitude, longitude et altitude sources ; les fichiers GPX et leurs métriques ne sont pas réécrits.

Le test de pédalage vérifie explicitement la succession haut → avant (axe local −Z) → bas → arrière, ainsi que l’opposition des pédales, le retour cyclique, la garde au sol et la rotation des roues proportionnelle à la distance. Le rendu interpole les deux états physiques successifs : il a au plus un pas de retard (20 ms), sans modifier les décisions d’évitement.

Captures natives Linux de face, de profil et de dos dans docs/previews/v0.3.0-*.png. Références utilisateur consultées visuellement ; aucune illustration substituée au rendu 3D. Géométrie procédurale stylisée, sans promesse d’identité visuelle avec les dessins. Les captures utilisent le rendu logiciel Mesa et ne mesurent pas les performances d’une carte graphique.

Installeur Windows construit et publié par GitHub Actions. Installation et exécution sur un vrai poste Windows non testées dans cet environnement Linux.
