# Audit et décisions — lot 0.1

## Mise à jour géographique 0.6.0

Le mode courant charge les quatre caches `assets/geodata/circuits/<id>/`. La géométrie et la distance simulées viennent du recalage sur le réseau OSM ; `route.data` et `route.source_points` conservent le GPX original. `source_station()` relie la station simulée à celle du GPX. `sample_raw()` fournit les valeurs GPX correspondantes, tandis que `sample()` fournit la position de simulation en altitude IGN69 et les coordonnées WGS84 dérivées.

`IGNTerrain` lit les tuiles float32 MNT/MNH en Lambert-93, avec transformation locale auditée et arithmétique double pour les grandes coordonnées Lambert. Le cache décodé est limité à 32 tuiles. Relief proche, arrière-plans, zones boisées, bâtiments, surfaces d’eau et routes voisines utilisent ces données locales. Le chargement des quatre circuits ne nécessite aucun accès Internet.

Les métriques brutes, la tranche initiale et le raccordement vertical GPX/IGN décrits plus bas restent l’historique du premier lot ; ils ne pilotent plus les caches géographiques 0.6.0. Voir [méthode et limites actuelles](GEODATA.md).

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
| `scripts/geoworld.gd` | Lecture du cache IGN, interpolation terrain, emprises, routes voisines et jonctions |
| `scripts/terrain_overlay.gd` | Index spatial des faces visibles, découpage et projection des chaussées secondaires |
| `scripts/rider.gd` | Avatar/vélo procéduraux et animation des membres |
| `scripts/hud.gd` | Indicateurs et tracé GPX, sans tuiles distantes |
| `scripts/recorder.gd` | Activités JSON et statistiques intégrées dans le temps |
| `scripts/main.gd` | Écrans, cycle de session, paramètres et caméra |
| `scripts/ambience.gd` | Paysage sonore local, fondus, cinq voix au maximum et échantillonnage spatial à 1 Hz |
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
4. Audio local livré en 0.6.3 sous CC0, avec volume et désactivation ; validation sur les sorties audio Windows réelles à poursuivre.
5. Valider sur Windows l’installeur NSIS déjà produit, l’installation/désinstallation et le hors ligne ; sessions longues et signature si certificat disponible.

## Évolution 0.2.0

`lane_planner.gd` décide du décalage latéral et du freinage virtuel au pas physique fixe. `world_life.gd` gère les personnages, animaux et obstacles déterministes dans un ensemble local borné, ainsi que leur mouvement et les observations prévues. `scenery.gd` construit et partage les maillages d’arbres et de rochers ; le terrain Delaunay évite le repli des grands rubans. La physique longitudinale et les données GPX restent séparées de cette couche de conduite et du rendu. Les faunes, personnages, clôtures et obstacles ne sont pas attribués aux données IGN.

Depuis la version 0.3.0, `sample_raw()` conserve l’interpolation source pour les coordonnées et altitudes enregistrées. `sample()` remplace uniquement la position 3D par une B-spline cubique calculée sur une grille spatiale uniforme d’environ 2 m. Route, cycliste et pente physique partagent cette géométrie. Les distances GPX et le D+ brut ne sont pas recalculés à partir de la courbe. Les nœuds fantômes linéaires ancrent les extrémités ; l’extrapolation géométrique est limitée à 12 m. Le rendu interpole les deux derniers états physiques (au plus 20 ms de retard) ; l’évitement travaille sur l’état physique courant.

Version 0.4.0 : `rider_shapes.gd` produit les surfaces paramétriques fermées avec normales explicites, les tubes de couture et la coque ajourée du casque. `rider.gd` assemble et anime ces surfaces par cinématique inverse. Le pédalage visuel suit la cadence, avec un pas maximal de 60° pour éviter les sauts ambigus après un blocage du rendu. Le filtre spatial de `route.gd` utilise cinq nœuds binomiaux, avec une correction bornée à 35 cm dans le plan et 25 cm en hauteur avant la B-spline. `sample_raw()` et les données GPX restent indépendants de ce filtrage.

Version 0.5.0 : les sections du buste et des bras suivent des courbes de Bézier ; les normales sont recalculées sur les surfaces déformées. Le nez appartient au maillage du visage, les muscles ont un relief transversal et les chaussettes recouvrent la fin de la peau du mollet. `rider_shapes.gd` fournit ces générateurs et l’encrage aux angles rasants. Les captures studio orientent leur lumière principale vers la vue observée ; la capture de la simulation conserve son éclairage.

Version 0.5.1 : assets/models/jersey.res remplace le torse et les manches séparés ; assets/models/bib.res remplace le bassin et les deux volumes de cuissard. Ce dernier utilise un Skeleton3D à trois os et un Skin avec poids progressifs aux hanches. Les bas de cuissard ont des poids exclusifs à leur jambe ; la pose de référence les écarte légèrement pour préserver l’entrejambe. La recette procédurale est conservée sous authoring_source pour les outils de fusion hors ligne. Voir assets/models/README.md et tests/test_garment_joints.gd.

Version 0.5.2 : `camera_follow.gd` sépare le suivi de la caméra des rotations du cycliste et amortit le cap, les déports d’évitement et la hauteur. La position et la cible partagent un repère stabilisé ; le champ et le recul restent fixes. Le suivi nominal s’ancre sur la voie droite réelle et la caméra se fige à l’arrêt ou pendant la pause. Voir `tests/test_camera_follow.gd` et `tools/capture_camera.gd`.

Version 0.6.3 : dix sons CC0 dédoublonnés et convertis en Ogg stéréo, avec raccord de boucle fondu et niveau ajusté. Le mixeur conserve deux voix de fondu par couche (ambiance, vent), plus une voix occasionnelle pour la faune. Les requêtes de paysage se font une fois par seconde ; trois observations confirment une transition, puis un fondu de quatre secondes raccorde les ambiances. L’arrêt en pause/menu libère les flux. Le catalogue conserve les empreintes des fichiers fournis ; les sons restent des illustrations du paysage.

Version 0.6.4 : le même repère stabilisé propose trois cadrages (arrière d’origine, première personne et arrière éloigné). V change le cadrage sans réinitialiser le cap filtré, même à l’arrêt ou en pause. La vue du cycliste utilise sa position latérale, masque l’avatar et élargit le champ à 65° ; les vues arrière gardent 48°. Le mode est mémorisé dans les paramètres locaux.

Version 0.6.5 : les routes secondaires sont découpées sur les faces du terrain affiché via un index de 32 m. Le même découpage retire le chevauchement de l’arrière-plan sur le terrain proche et raccorde leurs bords. Les revêtements partagent les matériaux de la chaussée principale et sont regroupés en quatre lots au maximum. Les formes de voies sont lissées avec une correction bornée à 45 cm et gardées dans un cache de 64 entrées. Les carrefours ouvrent les accotements et les lignes de rive ; les ponts, tunnels et niveaux distincts explicitement signalés n’ouvrent pas de jonction. La préparation reste fractionnée sur plusieurs images.
