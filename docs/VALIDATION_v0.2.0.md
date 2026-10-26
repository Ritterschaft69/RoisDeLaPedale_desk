# Validation 0.2.0 — 26 octobre 2026

## Résultats

| Suite exécutée | Résultat |
| --- | --- |
| Tests Python des sources GPX, du catalogue et des données IGN | 12 réussis |
| Physique et enregistrement | 24 réussis |
| Cycle de session desktop | 10 réussis |
| Choix des trois circuits, données et activités | 34 réussis |
| Trajectoire et vie du décor | 21 réussis |
| Géométrie, normales et animation du vélo | 9 réussis |

Total : **110 contrôles réussis**, sans tests neutralisés. Les rendus natifs sont vérifiés avec Xorg et Mesa llvmpipe ; ce rendu logiciel ne mesure pas les performances d’un GPU Windows.

## Conduite et évitement

La position latérale est positive à droite dans le sens de parcours. Le contrôleur fonctionne au pas physique fixe de 0,02 s ; il observe les obstacles en coordonnées distance/écart, prévoit leur déplacement, choisit un passage dans les limites de la chaussée et borne vitesse et accélération latérales. Une mémoire du contournement évite un retour prématuré devant l’obstacle.

Tests : obstacle sur la voie droite à 2, 8 et 16 m/s ; absence de chevauchement, retour à droite et vitesse latérale maximale de 0,9 m/s ; piéton traversant ; obstacle de la voie opposée ; arrêt devant une chaussée entièrement bloquée. Une session intégrée de 50 s traverse réellement la zone des cônes et des personnages sans chevauchement des enveloppes corporelles testées. La pause gèle les personnages et animaux ; le redémarrage les remet en mouvement.

Le freinage de sécurité agit uniquement dans la simulation virtuelle. Il ne transmet aucune commande de résistance à un home trainer. Les vitesses et distances restent calculées par le moteur physique. Les coordonnées sources GPX restent celles de l’axe du parcours ; le décalage latéral est ajouté aux échantillons d’activité dans `lateral_m`.

## Géométrie et qualité visuelle

Les tests vérifient les normales externes des vêtements et des façades dans les deux sens d’emprise, les normales des toits et du terrain, le cycle des pédales, la rotation des roues et la roue libre. Ils couvrent la cause des anciennes hachures : des surfaces orientées vers l’intérieur perturbaient l’éclairage et les contours.

Les arbres utilisent des maillages partagés et des groupes MultiMesh, avec silhouettes simplifiées au loin. Le terrain utilise une triangulation Delaunay orientée vers le ciel, au lieu de larges rubans qui se repliaient dans les virages. Les animaux et piétons utilisent un ensemble local borné, renouvelé avec la progression ; les identités et les poses initiales sont déterministes pour un même parcours.

## Limites conservées

- Les animaux, passants, obstacles, clôtures et arrière-plans sont décoratifs/procéduraux. Ils ne constituent pas des mesures géographiques.
- Le cache IGN reste celui de Saint-Dié, 0–3 km. Les tracés GPX et leurs altitudes ne sont pas réécrits.
- Le style 3D est enrichi, mais la référence illustrée demeure une direction artistique, pas une égalité de rendu validée.
- Pas de validation Windows ni de certification à 60 FPS, de session de plusieurs heures, de Bluetooth réel ou d’audio dans ce lot.
