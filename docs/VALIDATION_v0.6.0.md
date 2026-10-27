# Validation 0.6.0 — 27 octobre 2026

200 contrôles : 25 Python, 24 simulation, 10 desktop, 37 circuits, 24 navigation, 13 géométrie, 17 lissage, 9 modèle, 6 raccords des vêtements, 11 caméra et 24 géographie native.

## Acquisition et intégrité

270 tuiles MNT de 2 km à 10 m, soit 10 800 000 pixels ; 156 tuiles MNH à 10 m, soit 6 240 000 pixels. Tous les pixels de ces tuiles proches sont numériques et valides. Le modèle régional à 100 m contient 556 842 pixels, dont deux nodata, hors des altitudes utilisées pour les parcours. Aucune station simulée des trois circuits ne manque d’altitude LiDAR.

Les contrôles vérifient les tailles des fichiers, SHA-256, empreintes des GPX, présence de tous les points sources, correspondance monotone des stations et conservation des extrémités originales. Les routes dérivées comportent 33 303, 51 080 et 60 328 points, espacés d’au plus deux mètres. Les données brutes GPX ne sont pas réécrites.

## Recalage et environnement

Tests indépendants du service réseau : lacet sans diagonale, croisement déconnecté tel qu’un pont, sens unique et exception cyclable, absence de voie avec repli GPX explicite, station uniforme et filtrage d’altitude conservant une pente constante. L’import XML officiel OSM est testé sur un téléchargement neuf, une relecture hors ligne et le refus d’une géométrie dont il manque un nœud.

Les caches sont chargés et parcourus sur toute la longueur des trois circuits dans Godot. Le référentiel local ENU vers Lambert-93 est audité sur 81 points indépendants par circuit et un domaine incluant les arrière-plans. Son erreur géométrique maximale reste inférieure au millimètre sur ces audits. L’interpolation numérique native, proche et lointaine, concorde avec les références de préparation à moins de 3 cm. La mémoire des tuiles proches décodées reste bornée à 32 entrées.

La triangulation des bâtiments utilise les coordonnées locales, comme le rendu, pour éviter les erreurs de précision loin de l’origine. Les caches de rendu contiennent respectivement 8 165, 5 508 et 23 327 emprises ; ces comptes par circuit peuvent se recouper. Aucun bâtiment retenu n’est refusé par la triangulation native. Les îles des surfaces d’eau restent des trous : aucun triangle d’eau testé ne les recouvre.

Un contrôle du virage réel vers 65,783 km d’Oderen vérifie les deux voies sur 45 m : le terrain triangulé reste sous l’asphalte, avec une marge minimale observée d’environ 5 cm. Le maillage de soutien utilise des stations de 3 m et plusieurs bandes sous la chaussée et les accotements.

## Paquets et rendu

`python tools/build.py --target linux` construit le paquet autonome. L’inspection avec `godot --headless --main-pack build/linux/RoisDeLaPedale.pck --script "$PWD/tests/test_circuit_geography.gd"` lit les données du PCK et passe les contrôles géographiques. Utiliser le chemin absolu du script de test lorsqu’il n’est pas inclus dans le paquet.

`python tools/smoke_linux_export.py` exécute réellement le binaire Linux exporté, hors du répertoire du projet et avec des dossiers utilisateur isolés, sur les trois circuits. Chaque session se termine et produit une activité avec le bon circuit, une altitude IGN69 et les valeurs GPX originales séparées. Il ne s’agit pas d’une validation d’exécution Windows.

Les captures `v0.6.0-saint-die.png`, `sortie-matin.png`, `grand-ballon.png` proviennent du moteur natif Mesa/llvmpipe, à des stations connues des circuits ; aucune image générée ne sert de preuve du rendu. `v0.6.0-geographie.png` est un aperçu des caches réels et des profils, produit par matplotlib. Ces captures ne mesurent pas les performances d’un GPU réel.

GitHub Actions exécute les suites et construit l’installeur Windows x64 ; la release contient l’installeur et son SHA-256. Installation/désinstallation sur un poste Windows et validation du matériel physique restent à effectuer.

## Publication vérifiée

Construction GitHub réussie : [run 40475089105](https://github.com/Ritterschaft69/RoisDeLaPedale_desk/actions/runs/40475089105), source `7d1581121ddda33d4ad5987478c54a6d7a3f05f2`. Les 175 contrôles natifs et les 25 tests Python passent dans ce run.

L’installeur publié a été téléchargé puis contrôlé : **90 096 495 octets**, SHA-256 `19ba6237a7d911dda0a4826075090e6dbc6a82d86ae1c3b6376419275abbb504`. Il correspond au fichier `SHA256SUMS.txt` joint à la release.
