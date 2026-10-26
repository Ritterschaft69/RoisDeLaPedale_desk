# Audit et décisions — lot 0.1

## Inventaire réel

À l’ouverture, le dépôt ne contenait que `README.md` et `LICENSE`, au commit `83e13e99aaacd04c6ad55b00ffaf879dc1f3eed8`, identique au `main` distant. Aucun moteur physique, scène 3D, code Bluetooth, donnée IGN ou configuration de build à conserver. La branche locale de travail est fournie par la plateforme ; aucun worktree supplémentaire créé.

Le GPX et le cahier des charges ont été fournis en pièces jointes. Le GPX a été copié tel quel ; son SHA-256 est enregistré dans le fichier dérivé. Une seule trace continue, 3 383 points, boucle revenant près du départ. Les valeurs 66,3 km et D+ 1 242 m du document ne sont pas imposées : la distance horizontale calculée est 66,299 km et le D+ brut 1 585,4 m. Aucun filtrage altimétrique des sources.

## Choix desktop

Godot 4.6.3 standard : rendu, interface, boucle physique et fichiers applicatifs natifs ; exports x64 Linux et Windows ; pas de navigateur, serveur ou compte. L’absence de code antérieur permet ce choix sans migration ni perte de composants. Le renderer GL Compatibility privilégie l’accessibilité matérielle et les tests logiciels cloud. Compromis : intégrer FTMS demandera une extension native par OS ; Godot ne fournit pas un accès FTMS universel prêt à l’emploi. Une interface de données et une politique d’expiration existent, mais aucun appareil n’est annoncé connecté.

## Modules

| Fichier | Responsabilité |
| --- | --- |
| `scripts/physics.gd` | Forces mécaniques et intégrateur implicite au point milieu |
| `scripts/trainer_input.gd` | Source démo, validation d’observations, expiration à 2 s et lissage 0,5 s |
| `scripts/route.gd` | Lecture brute par recherche binaire ; géométrie dérivée B-spline cubique C2 sur grille de 2 m, tangentes analytiques et pente sur 12 m |
| `scripts/world.gd` | Bande de route, terrain, végétation et fenêtre de visibilité |
| `scripts/geoworld.gd` | Lecture du cache IGN, interpolation terrain, emprises et toitures/fenêtres |
| `scripts/rider.gd` | Avatar/vélo procéduraux et animation des membres |
| `scripts/hud.gd` | Indicateurs et tracé GPX, sans tuiles distantes |
| `scripts/recorder.gd` | Activités JSON et statistiques intégrées dans le temps |
| `scripts/main.gd` | Écrans, cycle de session, paramètres et caméra |
| `tools/` | Import GPX, acquisition explicite, cache géographique et packaging |

Les données d’entrée produisent les watts ; la physique produit vitesse/distance ; le rendu les consomme. Le pas de simulation est fixé à 0,02 s par Godot. Les paramètres d’essai asphalte/gravier/mouillé sont explicitement manuels ; ils ne sont pas présentés comme des surfaces cartographiées.

## Modèle mécanique

Masse initiale : 75 kg cycliste + 9 kg vélo/équipement = 84 kg. Masse effective +2 kg d’inertie de roues estimée, distincte de la gravité et du roulement. Rendement 0,975 ; CdA 0,34 m² ; Crr 0,005 ; rho 1,2 kg/m³. Vent positif = vent frontal. La réduction d’aspiration n’affecte que la traînée ; c’est une capacité mathématique testée, pas un mode multijoueur.

Le solveur implicite au point milieu cherche une vitesse positive par dichotomie. La propulsion est bornée à 500 N au démarrage, ce qui peut limiter la puissance transmise à très basse vitesse. En dehors de cette borne, le travail moteur vaut exactement la puissance roue × dt à la tolérance du solveur. Si la résistance empêche le départ, la vitesse reste nulle. Aucune règle de gel sous 4 km/h et aucune « inertie 80 % » inventée.

L’équilibre plat vérifie `0.204 × v³ + 4.118793 × v = 195`, avec v en m/s, soit **33,0073 km/h**. À 30,3 km/h, ces forces ne consomment qu’environ 156 W roue, et non 195 W. Les coefficients demandés et la conservation du travail sont conservés ; l’exemple numérique du document est signalé comme incohérent.

## Géographie et limites

Projection : WGS84 → ECEF → plan tangent local ENU, puis x=est, z=−nord, y=altitude GPX. Les coordonnées géographiques sources sont gardées et testées point par point. La distance est horizontale haversine, rayon moyen explicitement 6 371 008,8 m ; ce n’est pas une distance routière corrigée du bruit GPS ou une géodésique ellipsoïdale de précision topographique.

Sur les 3 premiers kilomètres, le décor utilise de vraies emprises IGN. L’acquisition et le rendu sont séparés. Les toits, façades et arbres sont estimés/procéduraux. L’IGN reste prioritaire ; les sources OSM restent séparées, sans mélange de licences ni double ajout de bâtiments. Les bâtiments avec trous ne seraient pas remplis artificiellement ; cette tranche n’en contient pas. Le générateur n’est pas encore une reconstruction détaillée des architectures vosgiennes.

Les échantillons RGE ALTI ne constituent ni un nuage de points LiDAR HD ni un MNT à 25 m. Les altitudes GPX sont environ 12,6 m plus hautes que l’audit IGN initial : un champ de décalages visuels par station est stocké séparément, et un raccordement local des accotements maintient la route source. Une validation du référentiel vertical et une stratégie de terrain non replié pour épingles sont nécessaires avant couverture finale. Les données sources ne sont jamais recalées silencieusement.

## Suite du développement

1. Valider le référentiel vertical et produire des tuiles terrain, routes secondaires et sols urbains sur toute la boucle ; optimiser le streaming et la géométrie des épingles.
2. Extension native Bluetooth Windows FTMS : scan, notifications, contrôle borné séparé, tests sur matériel réel ; ANT+ seulement avec matériel adapté.
3. Remplacer les modèles de prototype, enrichir les façades et paysages ; instancing/LOD et profilage sur matériel de référence.
4. Audio local sous licences explicites et réglages de sortie.
5. Valider sur Windows l’installeur NSIS déjà produit, l’installation/désinstallation et le hors ligne ; sessions longues et signature si certificat disponible.

## Évolution 0.2.0

`lane_planner.gd` décide du décalage latéral et du freinage virtuel au pas physique fixe. `world_life.gd` gère les personnages, animaux et obstacles déterministes dans un ensemble local borné, ainsi que leur mouvement et les observations prévues. `scenery.gd` construit et partage les maillages d’arbres et de rochers ; le terrain Delaunay évite le repli des grands rubans. La physique longitudinale et les données GPX restent séparées de cette couche de conduite et du rendu. Les faunes, personnages, clôtures et obstacles ne sont pas attribués aux données IGN.

Depuis la version 0.3.0, `sample_raw()` conserve l’interpolation source pour les coordonnées et altitudes enregistrées. `sample()` remplace uniquement la position 3D par une B-spline cubique calculée sur une grille spatiale uniforme d’environ 2 m. Route, cycliste et pente physique partagent cette géométrie. Les distances GPX et le D+ brut ne sont pas recalculés à partir de la courbe. Les nœuds fantômes linéaires ancrent les extrémités ; l’extrapolation géométrique est limitée à 12 m. Le rendu interpole les deux derniers états physiques (au plus 20 ms de retard) ; l’évitement travaille sur l’état physique courant.
