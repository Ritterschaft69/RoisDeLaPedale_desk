# Données IGN et OpenStreetMap

## Circuits supplémentaires

`assets/routes/sortie_matin.gpx` et `oderen_grand_ballon.gpx` sont les deux GPX fournis ensuite par l’utilisateur, conservés octet pour octet. Import : 19 641 points / 102,362 km / D+ brut 2 233,2 m, et 20 459 points / 120,675 km / D+ brut 2 229,2 m. Les fichiers JSON dérivés conservent toutes les coordonnées et altitudes ; leurs origines ENU sont indépendantes. `prepare_route.py --all` reconstruit les trois JSON et leurs statistiques dans le catalogue.

Les premiers couples de points des nouveaux fichiers présentent une discontinuité altimétrique de −18,8 m sur 0,134 m et de −10,8 m sur 0,685 m. Le catalogue indique explicitement `start_m: 12` pour ces deux circuits : la simulation démarre après cette anomalie, les données sources et les distances totales restent inchangées. Les activités enregistrent cet offset séparément et comptent seulement la distance réellement parcourue après le départ.

Aucune géométrie IGN de Saint-Dié n’est réutilisée sur ces deux circuits : le cache doit correspondre à l’empreinte du GPX sélectionné. La sélection de Saint-Dié recharge son cache après un autre circuit. Les nouveaux décors sont illustratifs. Les distances et D+ sont calculés selon la même méthode que le parcours original, sans filtrage des altitudes.

## Tranche IGN de Saint-Dié

Acquisition réalisée le 25 octobre 2026. La tranche initiale couvre les **0–3 km** du GPX, avec une boîte englobante élargie de 180 m (pas un découpage exact du corridor). Les requêtes sont rejouables, modérées et mises en cache. Aucun secret nécessaire. Le jeu lit uniquement les données locales.

| Source | Acquisition réelle | Utilisation du lot |
| --- | --- | --- |
| IGN BD TOPO `BDTOPO_V3:batiment` | 2 100 objets, millésime du service **2026-06-15** | 619 emprises à moins de 150 m du tracé, hauteurs et altitude minimale de sol si disponibles |
| IGN BD TOPO `BDTOPO_V3:zone_de_vegetation` | 335 objets | Masques polygonaux de végétation, trous conservés ; arbres procéduraux, espèces non mesurées |
| IGN RGE ALTI `ign_rge_alti_wld` | Audit de 27 points du tracé + grille de 549 points | 61 stations tous les 50 m et 9 positions latérales ; hauteurs sources et raccordement visuel séparés |
| OpenStreetMap / Overpass | 2 861 éléments | Bâtiments, forêts, voies et cours d’eau archivés séparément ; pas encore fusionnés au rendu |
| GPX fourni | 3 383 points | Route, pente, progression et altitude ; source exacte conservée |

Le cache de rendu `assets/geodata/world.json` contient les 619 bâtiments retenus, les masques et la grille. La boîte d’acquisition est `[6.961020470725159, 48.26160713088068, 7.001281529274841, 48.277507869119326]` en ordre longitude/latitude (CRS84). Les sources en boîte englobante débordent naturellement le corridor.

## Services et documents consultés

- [WFS officiel Géoplateforme](https://data.geopf.fr/wfs/ows?SERVICE=WFS&VERSION=2.0.0&REQUEST=GetCapabilities) : couches et millésimes vérifiés, pagination de 1 000 objets, sortie explicitement CRS84.
- [Métadonnées IGN BD TOPO](https://data.geopf.fr/csw?REQUEST=GetRecordById&SERVICE=CSW&VERSION=2.0.2&ID=IGNF_BD-TOPO&elementSetName=full) et [RGE ALTI](https://data.geopf.fr/csw?REQUEST=GetRecordById&SERVICE=CSW&VERSION=2.0.2&ID=IGNF_RGE-ALTI&elementSetName=full), enregistrées dans `docs/sources/` : données ouvertes, Licence Ouverte.
- [Code officiel des adresses de services IGN](https://github.com/IGNF/geoportal-access-lib/blob/master/src/Services/DefaultUrlService.js) et [requêtes altimétriques](https://github.com/IGNF/geoportal-access-lib/blob/master/src/Services/Alti/Request/model/AltiElevationRequest.js) : chemin de service, paramètres et ressource vérifiés.
- [Overpass API](https://overpass-api.de/api/interpreter), requête POST de lecture seule `out geom`, aucune écriture OpenStreetMap. Les multipolygones bruts restent disponibles ; leur assemblage OSM n’est pas annoncé terminé.
- [Copyright OpenStreetMap](https://www.openstreetmap.org/copyright), consulté et conservé : attribution et ODbL.
- [Licence Ouverte 2.0 officielle Etalab](https://github.com/etalab/licence-ouverte/blob/master/LO.md), texte conservé dans `docs/sources/licence_ouverte.md`.

Les pages `geoservices.ign.fr` redirigent maintenant vers `cartes.gouv.fr`. Les métadonnées CSW officielles ont permis de vérifier les licences même lorsque la redirection web était initialement refusée par le proxy. Les reçus XML et les sources, et non une supposition sur le nom du domaine, fondent l’attribution.

## Reproduction

`python tools/fetch_geodata.py --fetch` télécharge la tranche par défaut. Le plan peut être inspecté sans accès réseau. `--start-km`, `--length-km` et `--output` permettent d’auditer d’autres tranches, sans remplacer les sources existantes par inadvertance. Les réponses supérieures à 64 Mio, pages dupliquées, valeurs altimétriques absentes et erreurs Overpass sont refusées ; les acquisitions incomplètes restent marquées comme telles.

`python tools/build_geoworld.py --terrain` acquiert les 549 points de relief puis prépare le cache ; sans `--terrain`, il reconstruit depuis les fichiers déjà téléchargés, sans réseau. Le cache HTTP ignoré stocke les réponses brutes avec clés de requête ; les reçus incluent URL, paramètres non secrets et SHA-256.

Les couches normalisées sont conservées dans le dépôt pour ne pas dépendre du cache HTTP ignoré. Un nouveau téléchargement doit rester une action explicite, avec une couverture et des attributions documentées. La couverture complète et les données LiDAR HD restent à traiter, sans prétendre avoir installé ces ressources.
