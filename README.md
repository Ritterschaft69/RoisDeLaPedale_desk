# Rois de la Pédale

**Windows : [télécharger l’installeur v0.6.5](https://github.com/Ritterschaft69/RoisDeLaPedale_desk/releases/download/v0.6.5/RoisDeLaPedale-0.6.5-Setup.exe)** · [Page de la préversion](https://github.com/Ritterschaft69/RoisDeLaPedale_desk/releases/tag/v0.6.5)
[Voir les circuits reconstruits et les captures natives](https://github.com/Ritterschaft69/RoisDeLaPedale_desk/releases/tag/v0.6.0)

Prototype **desktop natif**, Godot **4.6.3**, quatre circuits et données géographiques hors ligne. Aucun serveur ni navigateur requis.

## Cycliste fourni — 0.6.6

Le cycliste et son vélo sont remplacés par le GLB de l’archive fournie, avec ses matériaux et son squelette. Les jambes suivent la cadence et les roues la vitesse, indépendamment. Les trois vues et le masquage en vue du cycliste sont conservés. [Provenance et intégration](assets/models/imported-cyclist/README.md).

## Routes secondaires — 0.6.5

Les routes du décor sont découpées et plaquées sur les triangles du terrain affiché. Elles partagent l’asphalte et les accotements de la route principale ; les chemins non revêtus ont un aspect distinct. Les carrefours ouvrent les bandes de rive de la chaussée principale. Le raccord du relief proche à l’arrière-plan est corrigé. [Notes 0.6.5](docs/RELEASE_v0.6.5.md).

## Vues caméra — 0.6.4

La touche **V** fait défiler la vue actuelle, la vue du cycliste et une vue arrière plus éloignée. La stabilisation est conservée et le choix reste mémorisé.

## Ambiances sonores — 0.6.3

Dix enregistrements CC0 fournis par l’utilisateur accompagnent les paysages : campagne, village, forêt, lisière, eau et vent. Les transitions sont progressives. Les sons s’arrêtent dans les menus et pendant la pause ; le volume et l’activation sont mémorisés dans **Paramètres**. Les ambiances illustrent le décor, sans prétendre reproduire la faune ou la météo observées sur place. [Notes 0.6.3](docs/RELEASE_v0.6.3.md) · [Licences des sons](assets/audio/LICENSE.md).

## Nouveau circuit — 0.6.2

**Home sweet home** rejoint le menu : 12,29 km simulés, D+ IGN filtré 172 m. Le GPX original compte 1 659 points ; les données OSM/IGN et le décor sont disponibles hors ligne. [Notes 0.6.2](docs/RELEASE_v0.6.2.md).

## Performances — 0.6.1

Bâtiments et arbres regroupés par secteur, recherches spatiales indexées et construction progressive du décor. Les données IGN restent conservées. Sur Intel UHD Graphics 600, choisir **Légère** dans les paramètres : ce mode désactive les ombres et réduit la densité du décor. Le choix automatique ne remplace pas une préférence déjà enregistrée.

[Mesures comparatives et validation](docs/RELEASE_v0.6.1.md). Les gains mesurés dans le cloud ne prédisent pas les FPS sur votre PC.

## Circuits géographiques — 0.6.0

Les quatre GPX sont recalés sur les routes **OpenStreetMap**, puis rééchantillonnés tous les **deux mètres au maximum** et lissés pour la simulation. Le recalage utilise le réseau connecté et le sens de déplacement ; les lacets sont reconstruits le long des segments OSM, sans raccourci diagonal.

Le relief provient des **MNT numériques IGN LiDAR HD**, sur une grille de **10 m** près des parcours, complétée par un fond de relief à **100 m** jusqu’aux massifs lointains. Les hauteurs **MNH** guident la présence et la taille de la végétation près des routes. Les emprises et hauteurs des bâtiments, les zones de végétation et les surfaces d’eau viennent de la BD TOPO IGN. Les îles sont conservées dans les maillages d’eau. Les routes voisines OSM sont visibles aux abords et aux carrefours.

Les altitudes de simulation sont en **IGN69**, filtrées spatialement. Les accès des ponts/tunnels sont interpolés pour éviter les creux du terrain sous un ouvrage ; les ponts ne forcent pas le terrain à monter jusqu’au tablier. La caméra stabilisée, les vêtements continus du cycliste et le pédalage vers l’avant sont conservés.

Les GPX sources restent inchangés. Le jeu affiche la distance et le D+ du tracé reconstruit ; les données brutes restent accessibles séparément :

| Circuit source | Distance GPX | D+ GPX brut |
| --- | --- | --- |
| Saint-Dié-des-Vosges | 66,299 km | 1 585,4 m |
| Sortie vélo le matin | 102,362 km | 2 233,2 m |
| Oderen · Grand Ballon · Amic · Bramont · Brabant | 120,675 km | 2 229,2 m |
| Home sweet home | 12,237 km | 247,5 m |

Les activités enregistrent le tracé simulé et son altitude IGN ; chaque mesure conserve aussi les coordonnées, l’altitude et la station correspondantes du GPX original dans `source_gpx`. Le départ est à zéro sur les quatre circuits : les sauts altimétriques initiaux des GPX ne pilotent plus la pente simulée.

[Données, couverture et méthode](docs/GEODATA.md) · [Notes 0.6.0](docs/RELEASE_v0.6.0.md) · [Validation 0.6.0](docs/VALIDATION_v0.6.0.md)

## Lancer

Ouvrir `project.godot` dans Godot 4.6.3 standard, ou exécuter :

```sh
godot --path .
```

**Choisir un circuit**, puis **Démarrer en mode démo**. Flèches haut/bas : watts simulés ; Espace/Échap : pause ; F11 : plein écran ; H : masquer l’interface ; **V : vue du cycliste, arrière éloignée, puis arrière actuelle**. Conduite à droite et évitement automatiques ; passants et faune procéduraux. Le dernier circuit est mémorisé. Activités et paramètres sont stockés dans le répertoire applicatif de l’utilisateur.

## Vérifier

Les tests Python utilisent uniquement la bibliothèque standard. Les suites natives nécessitent Godot 4.6.3.

```sh
python -m unittest discover -s tests -v
godot --headless --path . --script tests/test_ambience.gd
godot --headless --path . --script tests/test_simulation.gd
godot --headless --path . --script tests/test_desktop.gd
godot --headless --path . --script tests/test_circuits.gd
godot --headless --path . --script tests/test_navigation.gd
godot --headless --path . --script tests/test_geometry.gd
godot --headless --path . --script tests/test_secondary_roads.gd
godot --headless --path . --script tests/test_route_smoothing.gd
godot --headless --path . --script tests/test_rider_model.gd
godot --headless --path . --script tests/test_imported_rider.gd
godot --headless --path . --script tests/test_garment_joints.gd
godot --headless --path . --script tests/test_camera_follow.gd
godot --headless --path . --script tests/test_circuit_geography.gd
godot --headless --path . --script tests/test_performance.gd
```

Isoler `XDG_DATA_HOME`, `XDG_CONFIG_HOME` et `XDG_CACHE_HOME` dans des répertoires accessibles en écriture pour les tests cloud. Le rendu natif sans écran est disponible via `python tools/run_cloud.py` ; ce rendu logiciel ne mesure pas les performances d’un GPU Windows.

## Reconstruire

Les caches installés suffisent pour jouer et construire les exports, sans réinterroger IGN/OSM. La préparation des données géographiques est une étape distincte, avec accès réseau et dépendances d’auteur optionnelles :

```sh
python tools/prepare_route.py --all
python -m pip install -r tools/requirements-geography.txt
python tools/circuit_geography.py --stage plan
python tools/circuit_geography.py --stage all
python tools/build.py --templates --target windows --installer
```

Les requêtes brutes sont mises en cache dans `build/geography/cache/`, les reçus et données de rendu dans `assets/geodata/circuits/`. Les données sources OSM dérivées et les formats binaires sont publiés avec leur attribution et leur licence. Les exports et installeurs restent dans `build/`, hors historique Git ; les installeurs publics sont joints aux GitHub Releases.

## Limites

Le MNT/MNH LiDAR HD est rééchantillonné à 10 m près du parcours et le relief lointain à 100 m ; les nuages LAZ complets ne sont pas embarqués. Les façades, toitures et formes individuelles des arbres sont procédurales ; les largeurs routières sans mesure sont estimées. Les tunnels ne sont pas reconstruits comme des ouvrages souterrains complets. Le recalage automatique reste une interprétation du GPX, et les intervalles non raccordés sont signalés dans les rapports et dans le jeu.

Bluetooth FTMS/ANT+, résistance du home trainer ne sont pas intégrés. Installeur non signé ; exécution et désinstallation sur Windows restent à vérifier sur un vrai poste. Le cycliste utilise désormais le modèle GLB fourni par l’utilisateur.

[Architecture](docs/ARCHITECTURE.md) · [Licences](docs/THIRD_PARTY.md) · [Cahier des charges](docs/CAHIER_DES_CHARGES.md)
