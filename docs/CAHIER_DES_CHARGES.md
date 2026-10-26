# Cahier des charges — Simulateur cycliste 3D pour home trainer (logiciel de bureau)

**Version :** 1.0 — 25 octobre 2026  
**Destinataire :** Codex / équipe de développement  
**Statut :** spécification de référence consolidée

## 0. Mission principale à Codex

Transformer le projet existant en **logiciel de bureau installable**, destiné à la simulation cycliste sur home trainer, **et non en application web dépendante d'un navigateur ou d'un serveur**. Réutiliser prioritairement le code, le moteur physique, la scène 3D et le parcours existants. L'utilisateur doit pouvoir lancer une session, connecter son home trainer compatible, pédaler et voir son cycliste progresser dans un monde 3D avec vitesse calculée physiquement. Le logiciel doit rester utilisable localement sans connexion Internet une fois ses parcours et ressources installés.

**Avant de coder :** inspecter le dépôt et identifier la stack, le moteur 3D, les composants réutilisables, les formats des données géographiques, le protocole matériel et les modes d'exécution. Ne pas présumer du langage actuel. Réaliser une migration progressive si la stack existante est orientée web ; proposer une solution de bureau intégrant le code réutilisable plutôt qu'une réécriture totale. Documenter les choix et leurs compromis.

## 1. Vision produit et périmètre

### Objectif
Logiciel de simulation de cyclisme indoor inspiré des fonctionnalités d'un jeu de cyclisme virtuel, avec identité graphique originale. Affichage d'un avatar cycliste sur un parcours 3D, piloté par les watts d'un home trainer. Expérience visuelle Cel-Shading traditionnelle avec environnement vosgien crédible, bâtiments semi-réalistes et ambiance sonore discrète.

### Public et plateformes
- **Priorité : Windows 10/11 64 bits**, distribution par installeur ou paquet installable et exécutable natif/packagé.
- **Secondaire : macOS**, puis Linux si les bibliothèques de périphériques et le moteur de rendu le permettent.
- Utilisation à la souris et au clavier ; support manette facultatif.
- **Offline-first :** simulation, moteur physique, scènes déjà téléchargées, réglages et sauvegarde d'activités doivent fonctionner sans Internet.
- Aucune obligation de compte ni d'abonnement pour lancer une session locale.

### Hors périmètre de la première version
- Multijoueur en temps réel, classement, cloud et boutique ; architecture extensible seulement.
- Reconstruction photogrammétrique exacte de chaque bâtiment.
- Météo live obligatoire ou modélisation détaillée des collisions automobiles.
- Reproduction de contenus protégés d'autres jeux.

## 2. Différence obligatoire entre logiciel de bureau et application web

Le produit final doit :
1. S'installer sur l'ordinateur avec un lanceur identifiable, une icône, une version et une désinstallation propre.
2. Exécuter sa boucle de simulation et le rendu localement, **sans navigateur externe** et sans connexion à un site distant.
3. Accéder aux capteurs compatibles par des interfaces adaptées à l'OS, avec gestion des permissions Bluetooth/USB/ANT+.
4. Stocker ses paramètres, caches de parcours, préférences audio/graphique et historique d'entraînements dans des répertoires applicatifs appropriés.
5. Gérer le plein écran, le fenêtré, la résolution et le changement de périphériques audio.
6. Signaler les erreurs matérielles et fournir des logs locaux diagnostiques.
7. Inclure les ressources indispensables dans le package ou dans un téléchargement explicite avec cache local.

**Choix d'implémentation :** si le projet existe en JavaScript/TypeScript ou avec un moteur WebGL, étudier un conteneur desktop (par exemple Tauri ou Electron) **sans transformer le projet en service web** ; un framework desktop packagé reste acceptable si son rendu et sa logique tournent localement. Si la stack est un moteur de jeu natif (Godot, Unity, Unreal ou autre), privilégier son export desktop. Décider **après audit**, sans migration de principe.

## 3. Parcours de référence et géodonnées

- Parcours **déjà fourni dans le projet** : départ de **Saint-Dié-des-Vosges** en direction du **col du Bonhomme**.
- La capture de la version courante présente un parcours de **66,3 km et D+ 1 242 m**. **Ces valeurs sont indicatives de l'interface observée et doivent être vérifiées dans les données existantes** ; ne pas imposer ces valeurs ni recréer le parcours.
- Le projet indique utiliser **tracé GPX, terrain LiDAR HD IGN, relief à 25 m, bâtiments et forêts BD TOPO**. Auditer ce qui est effectivement intégré et la résolution/source exacte avant toute modification.
- Préserver strictement les coordonnées, le tracé, les distances, les altitudes, les pentes et la progression.
- Traiter correctement les systèmes de coordonnées, la projection locale, le repère 3D et les unités.
- Si nécessaire, lisser la pente sur une fenêtre spatiale configurable (12 m initialement), sans altérer les données géographiques sources.
- Le terrain et la route ne doivent pas présenter de trous, sauts de maillage, bâtiments flottants ou obstacles décoratifs sur la chaussée.
- Générer/cache des portions de parcours pour usage hors ligne ; streaming local sans arrêt de la simulation.

## 4. Moteur physique : source de vérité

**Équation longitudinale :**

\[ m_{eff}\,\frac{dv}{dt} = F_{prop} - F_{gravity} - F_{rolling} - F_{aero} \]

Avec :
- `m = riderMassKg + bikeMassKg + equipmentMassKg`.
- `theta = atan(gradientDecimal)` ; `F_gravity = m * 9.80665 * sin(theta)` (force résistante signée : négative en descente).
- `F_rolling = Crr * m * 9.80665 * cos(theta)` opposée au mouvement.
- `F_aero = 0.5 * rho * CdA_effective * v_air_relative * abs(v_air_relative)` (convention du vent explicitée).
- `P_wheel = max(0, P_smoothed) * drivetrainEfficiency`.
- Gestion de `F_prop` sans division par zéro : intégration énergétiquement cohérente ou méthode de démarrage à force plafonnée justifiée et testée.
- `m_effective = m + sum(I_wheel / wheelRadius^2)` si inerties connues ; sinon estimation documentée.
- `speedMps >= 0` pour la première version ; traitement du blocage à l'arrêt sur une montée.

### Paramètres initiaux inspirés du modèle fourni
| Paramètre | Valeur initiale | Remarque |
|---|---:|---|
| Lissage de puissance | 0,5 s | Fenêtre temporelle, indépendante des Hz Bluetooth |
| Rendement transmission | 0,975 | configurable |
| CdA de référence | 0,34 m² | configurable selon position |
| Crr asphalte | 0,005 | configurable |
| Crr gravier | 0,0095 | configurable |
| Crr terre | 0,012 | configurable |
| Route mouillée | Crr × 1,12 | option simulation |
| Aérodynamisme matériel | CdA × [0,91 ; 1] | bonus maximal de 9 % |
| Densité d'air | ~1,2 kg/m³ en référence | dépendance à altitude et température |
| Vent exposé | 60 % du vent météo | estimation configurable, abrité selon environnement |
| Aspiration peloton | jusqu'à 32 % de réduction de traînée | extension multijoueur |
| Aspiration groupe compact | jusqu'à 45 % | extension, selon distance et alignement |
| Zone d'aspiration | ~8 m | indication initiale configurable |
| Pas physique fixe | 0,02 s (50 Hz) | indépendant du FPS |
| Seuil arrêt gameplay | sous 4 km/h sans pédalage | optionnel, ne pas bloquer les descentes |

**Précision importante :** une règle d'« inertie à 80 % » apparaît sur l'image d'origine sans définition mathématique suffisante ; ne pas l'inventer et préférer un modèle mécanique explicite.

### États et interfaces conceptuelles
- `RiderConfig` : masses, rendement, CdA, inerties, rayon des roues, paramètres pneus.
- `EnvironmentState` : pente, surface, pluie, altitude, température, densité d'air, vent, protection, drafting.
- `RiderState` : vitesse, distance, altitude, accélération, watts, watts lissés, cadence, pédalage, état arrêté.
- `CyclingPhysicsEngine.step(state, inputs, dt)` : retour d'un nouvel état et des forces diagnostiques.
- `TrainerInputAdapter` : puissance/cadence/état connexion ; données périmées → politique explicite (ne pas figer indéfiniment les watts).
- `RouteSampler` : position/distance sur tracé → pente et environnement.

### Validation physique minimale
- À 0 W sur plat : ralentit progressivement.
- À puissance constante : accélère puis atteint un équilibre crédible.
- En montée à puissance égale : plus lent que sur plat ; en descente à 0 W : accélération possible.
- Sur gravier ou mouillé : roulement accru.
- Vent frontal/arrière : effet cohérent ; aspiration réduit la traînée seulement.
- Pas de `NaN` au démarrage ; résultats indépendants du FPS.
- Test indicatif : masse totale 84 kg, 200 W pédalier, CdA 0,34, Crr 0,005, rho 1,2, rendement 97,5 %, plat, sans vent → vitesse d'équilibre d'environ **30,3 km/h** (tolérance explicite selon intégrateur).

## 5. Home trainer et matériels

### Fonctionnalités de base
- Découvrir, associer, connecter et déconnecter un home trainer compatible.
- Lire puissance (W), cadence (rpm) si disponible, et état de connexion.
- Afficher statut, dernier signal reçu, déconnexions, reconnexion et gestion de données absentes.
- Simuler aussi en **mode démo** avec puissance contrôlée manuellement pour le développement et les tests.

### Protocoles
- Priorité à **Bluetooth FTMS** lorsque le trainer le prend en charge ; examiner services caractéristiques et permissions réels.
- ANT+ FE-C est une **extension** nécessitant interface/clé et support logiciel compatibles ; ne pas affirmer que tout PC le gère sans matériel.
- Si l'appareil le permet, gérer le mode simulation de résistance (pente / paramètres pris en charge). Séparer physiquement et dans le code `TrainerResistanceController` et `CyclingPhysicsEngine`.
- Fournir une politique de sécurité des commandes : bornes, fréquences, reprise après déconnexion, arrêt propre, pas de résistance imprévue.
- Respecter les spécifications des protocoles et leur disponibilité sur l'OS ; privilégier des adaptateurs isolés et testables.

## 6. Direction artistique : Cel-Shading cartoon traditionnel

**Cible visuelle approuvée :** la **première image de référence**, présentant un cycliste vu de dos, une route sinueuse, des ombres nettes en grands aplats, une palette vive et des contours fins. Utiliser ce principe esthétique, **mais pas son décor méditerranéen**. Transposer le style aux paysages vosgiens existants.

### Rendu attendu
- Shader toon à **2–4 niveaux de lumière** avec transitions franches, légers ajustements anti-scintillement.
- Outlines foncés fins et stables sur cycliste, vélo, bâtiments proches et rochers/arbres choisis ; éviter contour sur chaque feuille.
- Couleurs lumineuses, non photoréalistes ; formes simplifiées **mais pas placeholders low-poly**.
- Ombres portées lisibles, cohérentes avec éclairage ambiant et directionnel.
- Distances atmosphériques subtilement bleutées ; ciel travaillé ; aucun bloom/DOF excessif.
- Système centralisé de `ToonMaterial` / presets route, herbe, conifère, feuillu, rocher, cycliste, vélo.
- Caméra poursuite stable au-dessus/derrière le cycliste, permettant de lire la route ; vues alternatives optionnelles.

### Problèmes visibles du prototype à corriger
- Terrain actuellement trop nu/plat visuellement.
- Routes en ruban gris sans accotements ni transitions naturelles.
- Bâtiments en cubes primitifs.
- Avatar et vélo de qualité placeholder.
- Forêts insuffisamment présentes ; absence perceptible d'outlines et d'ombres toon structurantes.

### Environnement vosgien
- Sapins, épicéas, hêtres et autres feuillus ; lisières, clairières et prairies **selon les données d'occupation du sol** si présentes.
- Relief arrondi vosgien, talus, rochers, zones boisées, paysage de montagne tempérée.
- Éviter palmiers, mer, voiliers, cyprès méditerranéens dominants, architectures provençales et relief fantastique.
- Bande de qualité prioritaire autour de la route, par exemple 0–30 m haute qualité, 30–100 m qualité moyenne, puis simplification, ajustables.
- Pas d'arbre ni de roche placés sur la chaussée ; variations procédurales déterministes.

## 7. Bâtiments : réalistes, géolocalisés, procéduraux

**Décision produit ferme :** pas de reconstruction exacte maison par maison. Les bâtiments doivent être **fidèles dans leur implantation**, plausibles dans leur volume et leur architecture, et générés automatiquement.

### Source de vérité
1. Emprise, orientation, catégorie et hauteur issues d'abord des données **IGN BD TOPO déjà intégrées**.
2. Compléments OSM si utiles, en vérifiant licences/attributions, couverture, cohérence et doublons.
3. Alignement avec terrain LiDAR / altimétrie locale et système de coordonnées.
4. Hauteurs/toitures absentes = **estimations déclarées**, jamais précision inventée.
5. Pas de téléchargement/scraping de panoramas Google Street View pour reconstruire des façades sans autorisation/licence appropriée. Google Street View peut servir à consulter visuellement sous les conditions de son service, sans l'exploiter comme base de données dérivée illicite.

### Générateur
Pipeline : `footprint -> catégorie -> hauteur connue/estimée -> volume -> toiture -> façades -> portes/fenêtres -> matériaux -> ancrage terrain -> LOD`.

Familles : maison individuelle rurale, maison de village, ferme, petit immeuble urbain, annexe/dépendance, bâtiment remarquable à traitement spécifique.

- Toitures à deux pans et quatre pans, annexes, toit plat si justifié ; sélection selon emprise et typologie, faîtage et pente plausibles.
- Façades enduites claires, pierre/teintes naturelles, toitures brun-rouge ou gris compatibles avec le secteur.
- Ouvertures répétées mais non mécaniques, dimensions plausibles, alignements corrects ; volets/cheminées/gouttières selon distance/performance.
- Seed stable par identifiant géographique pour que l'apparence d'une maison ne change pas d'une session à l'autre.
- LOD initial suggéré : <40 m riche, 40–150 m intermédiaire, >150 m silhouette ; ajuster après mesure.
- Prioriser les zones traversées à vélo ; éviter bâtiments flottants/enterrés, coupés par la route ou incohérents avec le terrain.
- Matériaux de bâtiments **semi-réalistes** et sobres intégrés au monde cartoon, sans effet « cubes avec toit ».

## 8. Audio environnemental léger

Moteur `CyclingAudioEngine` découplé, non musical par défaut, avec 5 catégories :
1. `AmbientNature` : oiseaux tempérés espacés, feuillage, conifères, ambiance calme ; pas de jungle exotique.
2. `TireRolling` : pneus sur asphalte, éventuellement gravier/terre si données de surface réelles.
3. `BikeMechanics` : chaîne/pédalage et roue libre, sans boucles agressives ; dépendance cadence/état si disponible.
4. `AerodynamicWind` : souffle doux dépendant de la vitesse relative à l'air (ou vitesse virtuelle en fallback).
5. `SpatialEvents` : ruisseau, village, cloches lointaines seulement si localisation/source crédible.

Volume de départ **relatif** : master 55 %, nature 22 %, roulement 28 %, mécanique 15 %, vent 18 %, événements 12 %. Mixage à calibrer à l'oreille ; ces chiffres ne sont pas des dB et ne s'additionnent pas directement.

- Transitions et crossfades doux, silence à l'arrêt pour roulement.
- Sons discrets permettant écoute de musique personnelle.
- Réglage des volumes, mute et périphérique de sortie, préférences locales.
- Ressources locales sous licence compatible ; ne pas prétendre posséder d'enregistrements indisponibles.
- Protéger des pics sonores ; gestion correcte du cycle de vie audio.

## 9. HUD et expérience utilisateur desktop

Conserver ce qui fonctionne déjà dans l'écran existant : gros indicateurs puissance (W), vitesse (km/h), cadence (tr/min), pente (%), mini-carte, nom du parcours, distance et D+ ; améliorer sans masquer la route.

Écrans minimum :
- Accueil / démarrer une session.
- Choix du parcours disponible (celui des Vosges en premier).
- Périphériques / association trainer / statut.
- Session 3D plein écran ou fenêtrée.
- Pause/reprise/fin et récapitulatif.
- Paramètres graphiques, audio, unités, périphériques.

À la fin d'une session, sauvegarder localement : date, durée, distance virtuelle, dénivelé, puissance moyenne/max, cadence si présente, points de temps, statistiques pertinentes et statut d'achèvement ; l'export FIT/GPX/CSV est une extension à planifier selon besoins et formats.

Une session doit rester jouable sans home trainer via mode démo clairement indiqué ; ne pas simuler des watts « mesurés » dans l'interface utilisateur.

## 10. Performance, stabilité et qualité

- Cible à mesurer : 60 FPS en 1080p sur matériel Windows de référence **à définir** ; 30 FPS possible en qualité réduite si nécessaire, sans compromettre la simulation.
- LOD, instancing des arbres, frustum culling, caches de terrain, distance d'affichage, ombres simplifiées.
- Ne pas faire dépendre la simulation physique du rafraîchissement graphique.
- Paramètres graphiques Low / Medium / High et ajustement résolution/plein écran.
- Sessions longues : pas de fuite mémoire, chargement progressif, nettoyage ressources GPU/audio, gestion veille/réveil et reconnexion.
- Logs structurés locaux, messages utilisateur compréhensibles ; récupération après plantage lorsque possible.
- Ressources en provenance de données tierces : documenter licences, attributions, éventuels caches et règles de redistribution.

## 11. Découpage logiciel suggéré (à adapter à la stack)

```text
DesktopShell / NativeLauncher
  ├── UI / HUD / Settings / Session screens
  ├── DeviceManager
  │     ├── BluetoothFtmsAdapter
  │     ├── AntFecAdapter (future)
  │     └── TrainerResistanceController
  ├── Simulation
  │     ├── CyclingPhysicsEngine
  │     ├── RiderState + RiderConfig
  │     └── RouteSampler
  ├── GeoWorld
  │     ├── GPX / coordinate transforms
  │     ├── Terrain / elevation / road meshes
  │     ├── Vegetation procedural generator
  │     └── BuildingProceduralGenerator (IGN/OSM)
  ├── Rendering
  │     ├── ToonMaterials / OutlinePass
  │     ├── Lighting / Atmosphere
  │     ├── RiderAnimator / Camera
  │     └── QualityProfiles / LOD
  ├── CyclingAudioEngine
  ├── SessionRecorder / LocalStorage
  └── Diagnostics / Installer / Packaging
```

Règle : les périphériques produisent des observations, le moteur physique produit la position/vitesse, le rendu/audio les consomment sans devenir sources de vérité concurrentes.

## 12. Livrables et phases recommandées

### Phase 0 — Audit et décision desktop
Analyser repo, stack, commandes de lancement, dépendances, système d'exploitation cible, données GPS/IGN, rendu et Bluetooth. Produire une note d'architecture courte. Décider packaging desktop et éléments à conserver.

### Phase 1 — Exécutable desktop minimal
Application installable Windows qui lance **le parcours existant**, avec mode démo, rendu 3D, HUD et stockage paramètres local. Aucune exigence cloud.

### Phase 2 — Physique et trainer
Connecter (ou valider) la physique et l'acquisition des watts ; contrôler les erreurs et la stabilité ; résistances trainer seulement si protocole confirmé.

### Phase 3 — Qualité visuelle
Toon shader et outlines, route/relief/végétation vosgienne, cycliste/vélo, caméra, lumière ; produire une *vertical slice* nettement meilleure que les captures low-poly actuelles.

### Phase 4 — Bâtiments
Remplacer les cubes par générateur de volumes/toits/façades, emprises IGN respectées, LOD et variété déterministe.

### Phase 5 — Audio et polish
Roulement, roue libre, vent, ambiance forestière et sons contextuels localisés ; paramètres et tests de session longue.

### Phase 6 — Packaging et assurance qualité
Installeur signé si infrastructure de signature disponible, release versionnée, README installation/dépannage, tests automatiques et manuels.

## 13. Critères d'acceptation MVP

- [ ] Exécutable de bureau installé et lancé localement sous Windows.
- [ ] Lancement sans connexion Internet d'un parcours précédemment installé.
- [ ] Parcours Saint-Dié-des-Vosges → col du Bonhomme **identique** en géographie et altitude.
- [ ] Déplacement par watts home trainer compatible, avec mode démo de test.
- [ ] Simulation cohérente montée/descente/roulement/aérodynamique/roue libre.
- [ ] HUD exact pour watts, vitesse, cadence, pente, progression ; statut capteurs.
- [ ] Cel-Shading immédiatement perceptible : ombres quantifiées, silhouettes, palette vive.
- [ ] Végétation et relief vosgiens suffisamment riches à proximité de la route.
- [ ] Bâtiments géolocalisés, toitures et façades procédurales crédibles, plus de simples cubes.
- [ ] Audio discret, dynamique et désactivable.
- [ ] Paramètres persistants, pause, fin de session, sauvegarde locale.
- [ ] Performance mesurée et rapports de tests disponibles.
- [ ] Attribution et licences des jeux de données et ressources documentées.

## 14. Tests automatisés et manuels obligatoires

- Tests physiques (forces, watts, freinage naturel, départ à 0 m/s, pente et vent, invariance FPS).
- Tests géographiques (distance cumulée, projection, altitude, orientation, absence de discontinuités).
- Tests de génération bâtiments (emprise, stabilité seed, chevauchement route, placement sur pente, géométries complexes).
- Tests de ressources desktop (lancement hors ligne, chemin de données, mises à jour de configuration, packaging).
- Tests FTMS simulés et sur appareil réel si disponible, déconnexion/reconnexion, valeurs aberrantes.
- Tests visuels et profils de rendu (LOD, artefacts outlines, qualité ombres, absence scintillement).
- Tests audio (mute, transitions, absence de clips/son à l'arrêt, nettoyage ressources).
- Test manuel de session longue et recherche de fuite mémoire.

## 15. Instructions opérationnelles finales pour Codex

1. **Lire ce document et examiner le dépôt avant toute refonte.**
2. Faire un inventaire de ce qui existe / manque ; différencier clairement implémenté, partiellement implémenté et à construire.
3. Produire un plan de migration **vers logiciel desktop** basé sur le code réel, incluant moteur 3D, empaquetage et accès Bluetooth.
4. Implémenter en petits lots testables ; conserver une version exécutable à chaque étape.
5. **Ne pas remplacer ni recalculer le parcours existant** sans besoin explicitement vérifié.
6. Garder une séparation stricte entre physique, rendu, matériel, son et interface.
7. Ne pas télécharger ni redistribuer d'images Street View en violation des conditions de licence ; privilégier IGN/OSM et assets dûment licenciés.
8. Ne pas annoncer une fonctionnalité comme opérationnelle sans exécution/tests appropriés.
9. En cas de données/ressources absentes, utiliser des placeholders explicitement signalés mais ne pas les laisser passer pour rendu final.
10. Fournir à la fin de chaque lot : fichiers modifiés, fonctionnalités, commande de lancement, tests passés, points restant à traiter.

**Priorité globale : produire un véritable logiciel de simulation cycliste installable, fluide et utilisable localement, en valorisant le parcours existant des Vosges et une direction artistique Cel-Shading de qualité, avec bâtiments géographiquement crédibles et ambiance sonore légère.**
