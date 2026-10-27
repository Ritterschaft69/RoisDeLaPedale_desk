# Rois de la Pédale v0.6.0 — Circuits OSM et relief IGN LiDAR HD

**[Installer Windows x64](https://github.com/Ritterschaft69/RoisDeLaPedale_desk/releases/download/v0.6.0/RoisDeLaPedale-0.6.0-Setup.exe)** · [SHA-256](https://github.com/Ritterschaft69/RoisDeLaPedale_desk/releases/download/v0.6.0/SHA256SUMS.txt)

Les trois circuits utilisent désormais les routes OpenStreetMap recalées sur leurs GPX et le relief numérique IGN LiDAR HD. Les caches sont inclus : aucun téléchargement au lancement.

| Circuit | Distance simulée | D+ IGN filtré | Raccord automatique au réseau OSM |
| --- | --- | --- | --- |
| Saint-Dié | 66,603 km | 1 182 m | 100 % |
| Sortie vélo le matin | 102,157 km | 2 355 m | 100 % |
| Oderen · Grand Ballon | 120,652 km | 2 381 m | 99,93 % |

- Tracés rééchantillonnés à **2 m maximum**, spline continue et maillage affiné dans les virages. Les vrais segments du réseau sont suivis aux carrefours et dans les lacets.
- **MNT LiDAR HD à 10 m** autour des parcours ; **MNH à 10 m** pour la hauteur et la présence de végétation ; fond topographique régional à **100 m** pour les massifs lointains.
- Bâtiments IGN en place, hauteurs et zones boisées, lacs et rivières avec leurs îles, routes voisines OSM. Les façades, toitures et arbres restent des interprétations procédurales.
- Altitudes en IGN69 ; accès de ponts/tunnels interpolés sans creux artificiel du sol sous un ouvrage. Le terrain ne remonte pas jusqu’au tablier des ponts.
- Raccord du terrain sous la chaussée renforcé pour éviter les intrusions d’herbe dans les virages.
- GPX originaux inchangés. Les activités conservent séparément les valeurs simulées et les valeurs GPX dans `source_gpx`. Le départ est à zéro pour les trois circuits, sans utiliser les sauts altimétriques initiaux des GPX.
- Caméra stabilisée, cycliste aux vêtements continus, pédalage vers l’avant et évitement automatique conservés.

Sur Oderen, les **84 m entre les stations GPX 108 et 192 m** restent issus du GPX et sont signalés dans le jeu, faute de raccord topologique plausible. Le taux de raccord décrit le résultat de l’algorithme, pas une certification de terrain. Les distances et D+ simulés diffèrent des métriques GPX brutes conservées dans les sources.

**Validation : 200 contrôles**, plus trois sessions dans l’export Linux autonome et inspection des données réellement embarquées. Captures natives des trois circuits et aperçu des tracés/profils joints à cette release. L’installeur Windows est produit par GitHub Actions ; son exécution sur un poste Windows reste à valider.

Sources et formats ouverts : [caches de la version](https://github.com/Ritterschaft69/RoisDeLaPedale_desk/tree/v0.6.0/assets/geodata/circuits), [méthode](https://github.com/Ritterschaft69/RoisDeLaPedale_desk/blob/v0.6.0/docs/GEODATA.md), [validation](https://github.com/Ritterschaft69/RoisDeLaPedale_desk/blob/v0.6.0/docs/VALIDATION_v0.6.0.md).

© OpenStreetMap contributors — ODbL 1.0. IGN BD TOPO® / LiDAR HD — Licence Ouverte 2.0. Les nuages LAZ complets ne sont pas embarqués. Installeur non signé ; Bluetooth/FTMS, résistance et audio non intégrés.
