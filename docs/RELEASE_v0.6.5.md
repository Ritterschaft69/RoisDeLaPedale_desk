# v0.6.5 — Routes secondaires intégrées au terrain

Les routes du décor ne sont plus placées sur des altitudes IGN indépendantes du maillage visible. Elles sont découpées sur les triangles du terrain réellement affiché et suivent ses faces jusque dans les creux et sur les bosses. La séparation résiduelle est de l’ordre de 2 à 3 cm pour éviter les conflits de profondeur.

- Asphalte et accotements partagés avec la route principale, coordonnées de texture cohérentes et normales dirigées vers le haut.
- Largeurs selon les attributs OSM disponibles ; estimations explicites sinon. Les chemins et pistes non revêtus conservent un matériau distinct et restent sans marquage routier.
- Jonctions des segments par bords communs, angles limités et lissage visuel borné à 45 cm ; les données OSM sources restent inchangées.
- Marquages des chaussées appropriées ; ouvertures des lignes de rive et des bandes de gravier à la rencontre des routes latérales.
- Arrière-plan découpé autour du terrain proche et raccordé à ses hauteurs de bord, pour éviter les superpositions de relief.

Les surfaces sont regroupées dans quatre lots au maximum. L’index de terrain est local à chaque portion et les géométries de routes mises en cache restent bornées à 64 voies. La construction progressive et son annulation lors d’un changement de circuit sont conservées. Les quatre circuits, les sons et les trois vues caméra restent disponibles.

Contrôle géométrique : les centres des triangles routiers suivent le terrain visible dans les deux modes de qualité sur les quatre circuits ; sur les cas audités, les écarts restent compris entre environ 1,7 et 3,3 cm, marquages compris. Il s’agit de cohérence avec le maillage affiché, pas d’une précision topographique centimétrique des données IGN rééchantillonnées.

Les croisements explicitement signalés comme ponts, tunnels ou niveaux distincts ne créent pas de fausse ouverture de carrefour.

Validation : 280 contrôles réussis, dont 18 contrôles dédiés aux routes secondaires, aux bosses du terrain, aux carrefours et aux croisements sans connexion. Captures natives de trois carrefours vérifiées. Export Linux démarré sur les quatre circuits avec les sons et l’enregistrement des activités.
