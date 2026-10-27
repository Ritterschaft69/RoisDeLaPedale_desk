# Données géographiques des trois circuits — 27 octobre 2026

La version 0.6.0 remplace la tranche de 3 km par des caches couvrant **les trois parcours complets**. Les anciens fichiers de la tranche Saint-Dié restent conservés pour l’audit historique ; le jeu charge prioritairement `assets/geodata/circuits/<id>/`.

## Sources effectivement utilisées

- Routes OSM : Overpass `way[highway] ... out geom`, avec reprise par petits extraits XML de l’API officielle OSM 0.6 lorsque Overpass est indisponible ; nœuds, géométrie et attributs conservés dans `osm_roads.json`. La base dérivée `osm_alignment.json` documente les raccords ; `osm_environment.json` sert au rendu des routes voisines. **© OpenStreetMap contributors, ODbL 1.0.**
- Relief : GeoTIFF **float32**, couche `IGNF_LIDAR-HD_MNT_ELEVATION.ELEVATIONGRIDCOVERAGE.LAMB93`, via WMS GetMap `FORMAT=image/geotiff`, grille de 10 m. Il s’agit d’altitudes numériques, pas de couleurs lues sur une carte.
- Hauteurs au-dessus du sol : couche numérique **MNH LiDAR HD**, même grille près du tracé. Elle guide les arbres, sans prétendre identifier chaque arbre réel.
- Bâtiments, végétation et eau : WFS `BDTOPO_V3:batiment`, `zone_de_vegetation`, `surface_hydrographique`, CRS84 explicite, pagination contrôlée et déduplication par identifiant.
- Métadonnées des dalles : WFS `IGNF_LIDAR-HD_METADONNEE:metadata`, dates de mission, système IGN69, URLs officielles MNT/MNH/MNS et LAZ conservés. Les nuages LAZ ne sont pas téléchargés.

Les deux fiches officielles [MNT](sources/IGNF_MNT-LIDAR-HD.xml) et [MNH](sources/IGNF_MNH-LIDAR-HD.xml) confirment la **Licence Ouverte**. La date d’acquisition du cache ne doit pas être confondue avec les dates des levés LiDAR, conservées dans les métadonnées de dalles.

## Couverture et résolution

Les tuiles Lambert-93 de 2 km couvrent un corridor d’au moins 400 m autour des GPX pour MNT+MNH et de 1 900 m pour le MNT des arrière-plans. La grille numérique MNT proche reste uniforme à 10 m pour éviter les raccords entre tuiles ; un modèle régional supplémentaire à 100 m couvre les silhouettes jusqu’à environ 16 km, avec une marge de téléchargement de 17 km autour des circuits. Sur ses 556 842 pixels, deux sont nodata ; aucune altitude de route ne dépend de ces pixels. La densité du maillage de rendu diminue au loin. Le terrain proche utilise une grille de rendu d’environ 12 m avec renforts près de la chaussée. La grille de 10 m est une réduction des produits LiDAR HD, pas leur précision native.

Les contrôles refusent un cache incomplet : données absentes, HTML d’erreur, image colorisée à la place de GeoTIFF float, pagination répétée, valeur nodata et altitude LiDAR absente sur un parcours. Les reçus conservent URLs, paramètres, tailles et SHA-256 des réponses.

## Recalage et simulation

1. Chaque GPX original est conservé octet pour octet. Le JSON source garde tous ses points, coordonnées, altitudes, distance horizontale et D+ brut.
2. Observations tous les 12 m ; candidats OSM dans un rayon de 40 m, coût de distance et de cap. Un Viterbi utilise les distances du graphe orienté et respecte les sens uniques et exceptions cyclables.
3. Les transitions reprennent les véritables segments du réseau. Deux voies qui se croisent sans nœud commun ne deviennent pas un carrefour ; les lacets ne sont pas remplacés par des diagonales.
4. Un intervalle sans raccord plausible utilise explicitement le GPX. Sa station source figure dans `unverified_source_intervals_m` ; ce tronçon est signalé dans le jeu.
5. Grille temporaire à 1 m, filtre binomial borné à 0,6 m de correction supplémentaire, puis rééchantillonnage uniforme à **2 m maximum** en distance horizontale reconstruite. La spline cubique C2 du moteur conserve une position et une tangente continues ; le maillage de route est affiné dans les virages.
6. Altitudes du MNT en IGN69, filtre gaussien longitudinal sigma 5 m. Les ponts/tunnels explicitement tagués interpolent les altitudes des accès ; la topographie sous un pont reste à son altitude de sol.

La distance simulée est celle du tracé dérivé, distincte de la distance GPX. La correspondance monotone vers la station du GPX est conservée dans chaque point. Les activités utilisent l’altitude et les coordonnées simulées, avec une copie séparée des valeurs originales dans `source_gpx`. Aucun ancien décalage vertical GPX/IGN n’est appliqué à ces nouveaux caches.

## Bâtiments, eau et végétation

Les emprises IGN sont conservées en place. Les objets en conflit avec la chaussée sont exclus du rendu. La triangulation travaille en coordonnées locales pour éviter les erreurs numériques loin de l’origine ; une géométrie refusée serait conservée dans `rejected_buildings.json`. Aucun bâtiment retenu pour ce lot n’est refusé par ce contrôle. Les bâtiments avec cour intérieure ne sont pas simplifiés en blocs pleins. Toits, façades, portes et fenêtres restent des estimations procédurales.

Les surfaces d’eau utilisent une triangulation contrainte réalisée avec Shapely/GEOS pendant la préparation ; leurs îles restent des trous. Le jeu lit seulement les triangles préparés. Les zones boisées et hauteurs de canopée ne constituent pas une segmentation 3D d’arbres individuels. Passants, animaux et obstacles sont des éléments de simulation.

## Reproduction et formats

`python tools/circuit_geography.py --stage plan` ne contacte aucun service. `--stage all` acquiert puis construit les trois circuits. Les étapes `vectors`, `water`, `rasters`, `build` peuvent être exécutées séparément ; les requêtes déjà reçues sont réutilisées. En cas d’erreur Overpass persistante, l’API officielle OSM fournit des zones d’environ 900 m, avec reconstruction complète des nœuds de chaque voie. `--osm-api` permet de sélectionner cette reprise directement. Les échecs ne sont pas considérés comme une couverture vide réussie.

Installer les dépendances de préparation avec `python -m pip install -r tools/requirements-geography.txt` ; elles ne sont nécessaires ni au jeu, ni aux tests, ni à la construction des exports à partir des caches existants. Godot 4.6.3 valide les polygones exportés. `tools/plot_geography.py` produit un aperçu de contrôle avec matplotlib, dépendance optionnelle.

Les formats, licences et attributions sont dans [la notice des caches](../assets/geodata/circuits/LICENSE.md). Les empreintes GPX protègent contre le chargement d’un cache d’un autre circuit. Le moteur garde au plus 32 tuiles numériques décodées en mémoire et ne fait aucun appel réseau.

[Historique de la tranche initiale](GEODATA_v0.1.0.md).

## Résultats installés

| Circuit | Distance simulée | D+ IGN filtré | Points simulés | Raccord OSM |
| --- | --- | --- | --- | --- |
| Saint-Dié | 66,603 km | 1 182 m | 33 303 | 100 % |
| Sortie vélo le matin | 102,157 km | 2 355 m | 51 080 | 100 % |
| Oderen · Grand Ballon | 120,652 km | 2 381 m | 60 328 | 99,93 % |

Les 84 m non raccordés d’Oderen correspondent aux stations GPX 108–192 m. Ils gardent le GPX et sont signalés dans le jeu. Le pourcentage de raccord est un résultat topologique automatique, pas une certification de terrain.
