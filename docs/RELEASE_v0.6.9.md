# v0.6.9 — Tracés corrigés et paysages optimisés

## Parcours

Les quatre circuits sont révisés à partir des sources conservées : 4 observations GPS isolées et 18 sommets de recalage créant de courts allers-retours sont écartés de la géométrie simulée. Les angles seuls ne suffisent pas à supprimer un point : les directions d’approche et de départ mesurées dans le GPX doivent confirmer l’anomalie. Les vrais lacets et demi-tours restent conservés. Les GPX, leurs distances et dénivelés bruts ne sont pas modifiés ; les correspondances de station restent monotones. Chaque correction est décrite dans `assets/geodata/circuits/<id>/route_cleanup.json`. Les altitudes IGN et les caches de décor sont recalculés hors ligne.

| Circuit | Observations GPS écartées | Sommets du recalage écartés | Distance simulée |
| --- | ---: | ---: | ---: |
| Saint-Dié | 0 | 0 | 66,603 km |
| Sortie vélo le matin | 0 | 12 | 102,076 km |
| Oderen · Grand Ballon | 1 | 6 | 120,618 km |
| Home sweet home | 3 | 0 | 12,280 km |

## Bâtiments

Les fenêtres, cadres et volets sont peints sur une petite texture répétée sur les murs. Aucune boîte 3D n’est construite par fenêtre. Le matériau est partagé, opaque, avec mipmaps et disparition progressive des détails au loin ; les pignons restent sans fenêtres. La passe d’encrage supplémentaire des bâtiments est supprimée. Un même bâtiment de référence passe de **2 404 à 40 triangles**, toiture et cheminée comprises (−98,3 %). Les emprises et hauteurs IGN restent conservées.

## Forêts par parcelles

Les parcelles boisées IGN sont converties en enveloppes de canopée continues. Les trous des polygones, les routes, les bâtiments, l’eau et les clairières détectées dans le MNH restent ouverts. Les haies, vignes, vergers et landes ne deviennent pas des massifs de forêt fermée. Le MNT fournit le relief ; le MNH guide les hauteurs lorsqu’il est disponible, avec une hauteur de 13 m interprétée en absence de mesure de canopée.

Une texture de feuillage et une petite carte de relief suggèrent les houppiers ; branches et feuilles ne sont pas reconstruites en géométrie. Quelques arbres restent près de la route pour la lisière. Les enveloppes sont opaques, sans empilement de transparences ni ombres supplémentaires. Elles sont raccordées au terrain réellement affiché, même quand le relief lointain utilise un maillage simplifié.

Les secteurs de 256 m sont compressés séparément et seuls les secteurs proches sont lus. Le cache est borné à 192 secteurs et la préparation est fractionnée. Les normales inutiles sont retirées des fichiers, puis recalculées sur la géométrie affichée ; les quatre caches forestiers occupent environ 20 Mo compressés. Le mode Léger utilise des volumes jusqu’à 550 m et conserve les boisements plus lointains par la couleur du relief. Le mode normal porte les volumes jusqu’à 1 450 m.

## Mesures et validation

Sur le rendu logiciel du cloud, mode Léger, dans deux vues comparables :

| Vue | Primitives avant | Primitives après | Temps médian avant | Temps médian après |
| --- | ---: | ---: | ---: | ---: |
| Oderen, village vers 32 km | 192 268 | 106 282 | 39,15 ms | 27,49 ms |
| Sortie matin, vers 32 km | 117 693 | 125 927 | 35,77 ms | 37,44 ms |

La réduction des fenêtres aide nettement les scènes bâties ; les forêts ajoutent du contenu dans les vues moins bâties, qui peuvent rester un peu plus coûteuses. Ces mesures ne prédisent pas les FPS sur Intel UHD 600. Le mode Léger reste recommandé sur cette puce.

322 contrôles réussis : conservation des sources et des vrais virages, hauteurs et intégrité des forêts, trous et exclusions des parcelles, façades sans géométrie par fenêtre, raccord à deux terrains d’affichage différents, cache borné, routes secondaires, audio, personnages, vues et quatre circuits. Les micro-triangles de découpe routière qui s’effondrent à grande distance de l’origine sont écartés pour conserver des normales valides.

Export Linux contrôlé sur les huit combinaisons de quatre circuits et deux personnages, y compris la présence des caches forestiers et des sons.
