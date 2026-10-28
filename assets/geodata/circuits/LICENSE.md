# Données géographiques

Les licences des données sont distinctes de celle du code du projet.

- **© OpenStreetMap contributors — ODbL 1.0** : `osm_roads.json`,
  `osm_alignment.json`, `osm_environment.json` et la géométrie dérivée de
  `route.bin` / `coordinates.bin`. Base source et transformations sont
  accessibles dans ce dépôt, avec formats ouverts documentés et scripts de
  reconstruction. Attribution : https://www.openstreetmap.org/copyright ;
  licence : https://opendatacommons.org/licenses/odbl/1-0/.
- **IGN BD TOPO® / LiDAR HD — Licence Ouverte 2.0** : emprises et hauteurs de
  bâtiments, zones de végétation, surfaces hydrographiques, modèles numériques
  MNT/MNH et métadonnées de dalles. Acquisitions les 27 et 28 octobre 2026. Les dates
  des missions LiDAR sont conservées dans chaque `lidar_metadata.geojson` ;
  elles sont antérieures à la date de téléchargement. Licence conservée dans
  `docs/sources/licence_ouverte.md` à la racine du dépôt.
- Les données GPX originales fournies par l’utilisateur restent dans
  `assets/routes/`, séparées des bases IGN et OSM. Leurs altitudes, coordonnées,
  empreintes et statistiques originales ne sont pas réécrites.

Les données OSM et IGN forment des caches distincts. L’altitude IGN est
échantillonnée le long de l’alignement OSM dérivé pour la simulation ; les
sources, attributions et transformations de cette base dérivée restent
accessibles. La base dérivée du tracé OSM est distribuée sous ODbL 1.0.

`terrain/*.bin` : float32 little endian, ligne nord vers sud, colonnes ouest
vers est ; centres de pixels définis dans `terrain/index.json`, EPSG:2154,
altitudes MNT en IGN69 et hauteurs MNH au-dessus du sol, mètres.
`route.bin` : quadruplets float32 x/y/z/station GPX source. `coordinates.bin` :
couples float64 latitude/longitude WGS84. La station simulée est l’indice du
point multiplié par `spacing_m` de `route.json`.

Les nuages LAZ complets ne sont pas téléchargés ni inclus. Les GeoTIFF
numériques MNT/MNH issus de LiDAR HD sont rééchantillonnés à 10 m près du
parcours ; le modèle MNT régional des arrière-plans est réduit à 100 m. Les toitures,
façades, espèces et formes individuelles des arbres restent des interprétations
procédurales ; ce ne sont pas des objets 3D extraits du nuage de points.
