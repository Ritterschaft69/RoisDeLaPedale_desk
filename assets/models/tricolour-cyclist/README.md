# Cycliste tricolore — seconde option

La géométrie de cette cycliste a été créée pour le projet à partir des caractéristiques des vues de référence fournies : silhouette sportive, tenue ajustée bleu marine à bandes bleu/blanc/rouge, casque blanc ventilé, lunettes, gants, chaussettes et chaussures blanches, tresse brune composée de trois brins entrelacés.

Révision 0.6.8 : silhouette reconstruite avec un dos abaissé, un cou raccourci, une tête adulte agrandie, des bras et des cuisses affinés. Les épaules rejoignent le maillot continu ; la taille du maillot entre dans le bassin. La tresse suit le dos et les chaussettes couvrent les mollets sans surfaces superposées. Les proportions sont exprimées en mètres relativement au vélo.

Le maillot et le cuissard sont construits comme des volumes continus puis remesillés et allégés. Les bandes sont découpées dans les triangles afin de conserver des bords nets. Le corps est skinné ; le casque, le visage, la tresse et les détails sont de la géométrie 3D, sans texture tirée de l’image.

Le vélo, le squelette à 22 os et les deux clips proviennent du GLB utilisateur existant. Les anciennes surfaces du personnage sont retirées de cette nouvelle scène. Le fichier du cycliste orange reste inchangé. La provenance du vélo et des animations reste celle du modèle fourni ; la licence CC0 des sons ne leur est pas appliquée.

Une décimation hors ligne maintient le personnage sous 35 000 triangles sans ajouter de traitement au jeu. Les bandes sont découpées après cette réduction.

`metadata.json` conserve les empreintes et le nombre de triangles de la nouvelle géométrie. Recette de création hors ligne (Blender 4.3.2, non requis pour jouer) :

```sh
blender -b --factory-startup -t 2 --python-exit-code 1 --python tools/build_tricolour_cyclist.py
```

L’option est sélectionnée depuis Accueil → Cycliste. Un seul modèle est instancié à la fois, le choix est mémorisé et les phases de pédalage/roulement sont conservées lors du changement. Les trois vues restent utilisables ; l’aperçu du sélecteur reste visible même lorsqu’une vue du cycliste est enregistrée.
