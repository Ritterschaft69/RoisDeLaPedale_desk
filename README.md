# Rois de la Pédale

Prototype **desktop natif** de simulation cycliste, Godot **4.6.3**, sans serveur ni navigateur. Interface en français, mode démo, parcours GPX original et première tranche IGN hors ligne. Ce dépôt initial ne contenait aucun prototype à migrer.

## Lancer

Installer Godot 4.6.3 standard (pas besoin de .NET), puis ouvrir `project.godot` et presser F6/F5, ou :

```sh
godot --path .
```

Cliquer sur **Choisir un circuit**, sélectionner un des trois parcours, puis **Démarrer en mode démo**. Le dernier circuit choisi est mémorisé. La carte, le profil, le HUD et les activités enregistrées correspondent au circuit sélectionné. Flèches haut/bas ou boutons : watts simulés ; Espace/Échap : pause ; F11 : plein écran. Le mode démo ne représente jamais une mesure de home trainer. Paramètres et activités JSON sont stockés dans le répertoire applicatif Godot de l’utilisateur, pas dans le dépôt.

| Circuits installés hors ligne | Distance GPX | D+ brut non filtré |
| --- | --- | --- |
| Boucle de Saint-Dié-des-Vosges | 66,3 km | 1 585 m |
| Sortie vélo le matin | 102,4 km | 2 233 m |
| Col d’Oderen · Grand Ballon · Amic · Bramont · Brabant | 120,7 km | 2 229 m |

Les deux nouveaux GPX sont conservés sans modification de leurs 19 641 et 20 459 points. Leur décor est illustratif ; les données IGN installées restent limitées aux trois premiers kilomètres du circuit de Saint-Dié. Le catalogue est dans `assets/routes/catalog.json`. Les deux nouveaux fichiers présentent un saut initial de 18,8 m sur 0,13 m et de 10,8 m sur 0,68 m : le départ jouable est explicitement positionné à 12 m sur ces deux circuits, sans supprimer ni modifier les points sources. Le compteur et les activités ne créditent pas ces 12 m.

Sur cette machine cloud sans écran : `python tools/run_cloud.py --fixed-fps 60 -- --screenshot --geo-screenshot` démarre un affichage logiciel isolé, exécute une courte session et écrit `build/session.png`. Aucun lien web de prévisualisation.

## Ce qui fonctionne

- Session 3D native avec cycliste/vélo procéduraux, pédalage, caméra poursuite et shader toon à trois niveaux.
- Physique indépendante du rendu à 50 Hz : inertie mécanique, démarrage à force plafonnée, gravité signée, roulement, traînée et vent ; puissance lissée sur 0,5 s.
- GPX original conservé : **3 383 points**, **66,299 km** horizontaux, **1 585,4 m de D+ brut**. Altitudes et latitude/longitude inchangées.
- HUD, carte du tracé réel, profil altimétrique, puissance manuelle, roue libre, pause/reprise, récapitulatif et historique local.
- Première tranche **0–3 km** : emprises/hauteurs IGN BD TOPO, masques de végétation et relief RGE ALTI échantillonné ; toitures et façades estimées. **Au-delà, décor illustratif explicitement indiqué.**
- Caches de sources IGN et OSM, provenance et scripts reproductibles. L’application ne télécharge rien au lancement.

## Vérifier

Python 3.12 standard suffit aux outils, sans dépendance pip.

```sh
python -m unittest discover -s tests -v
godot --headless --path . --script tests/test_simulation.gd
godot --headless --path . --script tests/test_desktop.gd
godot --headless --path . --script tests/test_circuits.gd
godot --headless --path . --fixed-fps 60 -- --smoke
```

Les tests desktop écrivent des activités et préférences dans leur répertoire utilisateur : utiliser un `XDG_DATA_HOME` temporaire pour les isoler sous Linux. Dans le cloud, définir les trois répertoires XDG sous `/workspace` si le dossier utilisateur est en lecture seule.

## Reconstruire les données et exports

```sh
python tools/prepare_route.py --all            # prépare les trois circuits du catalogue
python tools/fetch_geodata.py                 # plan, aucun appel réseau
python tools/fetch_geodata.py --fetch          # tranche source de 3 km, cache HTTP
python tools/build_geoworld.py --terrain      # 549 points IGN puis cache de rendu
python tools/build.py --templates             # modèles officiels vérifiés SHA-512, exports natifs
python tools/install_nsis.py                  # compilateur d’installeur local, cloud Debian
python tools/build.py --installer             # exports + installeur Windows non signé
```

Le téléchargement initial des modèles officiels représente environ 1,26 Go. Les exports portables sont générés dans `build/`, exclus du suivi Git. Le paquet Windows est un exécutable x64 avec son fichier PCK ; garder les fichiers ensemble. Ne pas confondre un export produit sous Linux avec une exécution validée sous Windows.

L’installeur `build/RoisDeLaPedale-0.1.0-Setup.exe` installe l’application pour l’utilisateur courant, crée les raccourcis du menu Démarrer et une entrée de désinstallation. Il conserve les activités et préférences dans AppData lors de la désinstallation. Construction vérifiée sous Linux ; installation/désinstallation Windows à valider sur un vrai poste.

## Limites de ce lot

Bluetooth FTMS / ANT+, commandes de résistance, audio, LiDAR HD, couverture détaillée de toute la boucle et finition artistique ne sont **pas terminés**. Pas de signature de code. Pas de validation sur PC Windows ni home trainer physique. Les arbres et l’avatar restent des ressources procédurales de prototype ; le visuel de référence est une cible, pas un résultat atteint. Performance à mesurer sur un PC Windows de référence ; le rendu logiciel cloud n’est pas une mesure de GPU réel.

Le GPX et l’IGN diffèrent verticalement : les hauteurs IGN sources sont gardées, et un **raccordement visuel explicite** par station aligne le décor sur le GPX sans modifier ce dernier. Le référentiel vertical du GPX est inconnu. Les **30,3 km/h à 200 W** du cahier des charges sont incompatibles avec ses coefficients : l’équilibre mécanique donne **33,007 km/h** ; voir [architecture](docs/ARCHITECTURE.md).

[Audit et architecture](docs/ARCHITECTURE.md) · [Données et sources](docs/GEODATA.md) · [Licences et attributions](docs/THIRD_PARTY.md) · [Validation](docs/VALIDATION.md) · [Cahier des charges fourni](docs/CAHIER_DES_CHARGES.md)
