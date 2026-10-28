# v0.6.1 — Performances

Les bâtiments sont regroupés par matériau et secteur, les arbres par secteur pour masquer les groupes hors champ. Les petites branches internes des conifères et la tessellation des feuillages ont été allégées. Les données IGN et les trois circuits restent disponibles hors ligne.

Les recherches de bâtiments et routes utilisent un index spatial. Le décor suivant se construit progressivement pendant que le précédent reste visible. Les changements de circuit annulent proprement la construction en cours. Les géométries de bâtiments et les nuages sont réutilisés.

Le mode Légère désactive les ombres et réduit la densité du décor proche. Il est choisi par défaut sur Intel UHD Graphics 600 en absence de préférence enregistrée. Si une préférence Standard existe déjà, sélectionner Légère dans les paramètres.

Mesure comparative reproductible : `tools/benchmark_render.gd`, mêmes positions, caméra et résolution, Godot 4.6.3, Mesa llvmpipe (rendu logiciel cloud), médiane de 12 images après 5 images de chauffe. Standard : ville Grand Ballon 137,159 → 123,716 ms/image (−9,8 %), 1652 → 988 appels de dessin ; forêt Sortie matin 273,388 → 171,785 ms/image (−37,2 %), 1 860 851 → 1 213 835 primitives. Ces résultats ne constituent pas une mesure de FPS sur Windows/UHD 600.

Avec le mode Légère (`-- --light` dans le benchmark), les mêmes scènes passent à 73,159 ms en ville et 76,280 ms en forêt sur ce moteur logiciel. La désactivation des ombres évite aussi une partie importante des passes de dessin.

Les XML GPX et l’ancien cache géographique de démonstration sont retirés du paquet exporté ; leurs sources sont conservées dans le dépôt. Le jeu utilise les parcours JSON dérivés et les caches IGN actuels.

Installateur Windows non signé ; validation matérielle sur UHD 600 encore nécessaire.

Validation : 208 contrôles automatiques réussis, dont 8 nouveaux sur les index spatiaux, le chargement progressif, son annulation et le mode léger. Capture native du décor forestier vérifiée. Export Linux lancé avec succès sur les trois circuits, dont enregistrement des coordonnées GPX et altitudes IGN.

Installateur publié et téléchargé pour contrôle : 89 806 428 octets ; SHA-256 `1cfa5c957343c58858f4543ee012560c88e770438687acce9b713b8e251ba9da`, conforme à `SHA256SUMS.txt`. Compilation GitHub : https://github.com/Ritterschaft69/RoisDeLaPedale_desk/actions/runs/40767764050.
