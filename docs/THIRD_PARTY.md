# Licences et attributions

- **Code du projet** : licence GPL-2.0 existante à la racine, conservée.
- **Godot 4.6.3** : copyright des contributeurs Godot, licence MIT. Texte dans `docs/licenses/Godot-LICENSE.txt` ; notices des composants embarqués dans `docs/licenses/Godot-COPYRIGHT.txt`, à distribuer avec les exécutables. [Licences Godot](https://godotengine.org/license/).
- **Open Sans** Regular et Semibold : copyright Google 2010–2011, Apache-2.0. Notices et texte complet dans `assets/fonts/LICENSE.txt` et `assets/fonts/Apache-2.0.txt`.
- **IGN — BD TOPO® et RGE ALTI®**, acquisition 2026-10-25 : Licence Ouverte, confirmée dans les métadonnées CSW `docs/sources/IGNF_BD-TOPO.xml` et `IGNF_RGE-ALTI.xml`. Texte officiel de Licence Ouverte 2.0 dans `docs/sources/licence_ouverte.md`. Millésime WFS BD TOPO : 2026-06-15. Les formes procédurales et corrections d’affichage ne sont pas des mesures IGN.
- **© OpenStreetMap contributors** : sources routières et bases dérivées sous [ODbL 1.0](https://opendatacommons.org/licenses/odbl/1-0/), [copyright et attribution](https://www.openstreetmap.org/copyright). Depuis 0.6.0, tracés recalés et routes voisines sont rendus. Sources, bases dérivées et formats ouverts : `assets/geodata/circuits/`, disponibles dans le dépôt public. Les notices sont distinctes de la licence du code.
- **GPX fournis par l’utilisateur** : sources originales conservées séparément pour le projet demandé, sans les présenter comme des données IGN/OSM.
- **Cahier des charges fourni** : document de référence utilisateur, conservé dans `docs/`.
- **Ancien avatar/vélo, arbres, toitures, façades et icône** : géométries/presets procéduraux créés pour ce projet. Aucun asset récupéré d’un jeu tiers, aucune image Street View utilisée.

Le style toon est une cible graphique. L’image fournie n’est ni intégrée ni redistribuée comme texture ou fond.

- **IGN LiDAR HD — MNT/MNH**, acquisitions 2026-10-27 et 2026-10-28 : Licence Ouverte, fiches officielles `docs/sources/IGNF_MNT-LIDAR-HD.xml` et `IGNF_MNH-LIDAR-HD.xml`. MNT et MNH numériques rééchantillonnés à 10 m près des parcours, MNT à 100 m au loin ; pas de nuages LAZ dans le paquet. BD TOPO étendue aux quatre circuits, avec surfaces hydrographiques. Dates des missions LiDAR conservées par dalle.
- **Shapely / GEOS et Pillow** : outils optionnels de préparation uniquement, non embarqués dans le jeu. Le jeu lit les géométries et grilles préparées ; il ne dépend pas de ces bibliothèques au lancement.

Sources et bases dérivées de cette version : https://github.com/Ritterschaft69/RoisDeLaPedale_desk/tree/v0.6.0/assets/geodata/circuits . Le dépôt fournit les formats ouverts et les scripts de transformation.

- **Ambiances La Sonothèque** : dix enregistrements fournis par l’utilisateur sous **CC0 1.0 Universel**, doublons retirés, niveau ajusté et conversion Ogg avec raccords fondus. [Notice et identifiants](../assets/audio/LICENSE.md), noms sources et empreintes dans `assets/audio/catalog.json`. Les ambiances sont illustratives, sans relevé acoustique local.

- **Cycliste et vélo GLB fournis par l’utilisateur**, intégrés en 0.6.6 : géométries, skin, matériaux et clips fournis dans `cycliste-autonome.zip`, sans nouvelle licence attribuée par ce projet. Provenance et empreintes dans `assets/models/imported-cyclist/`. La déclaration CC0 des sons ne s’étend pas à ces géométries.
