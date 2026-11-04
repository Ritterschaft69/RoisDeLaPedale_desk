# Cycliste tricolore — GLB fourni

Depuis 0.7.2, cette option utilise exactement le fichier utilisateur `cycliste_lowpoly_roadbike_rigged (1).glb`, renommé `cycliste-tricolore.glb`. Le binaire est conservé sans transformation ; son empreinte est enregistrée dans `metadata.json`. Il remplace le modèle procédural créé en 0.6.7–0.6.8. La licence du fichier fourni n’a pas été précisée ; aucune licence des sons ou des données géographiques ne lui est attribuée.

Le GLB autonome contient le vélo et la cycliste, 23 456 triangles, 18 os et le clip `Pedal_60_RPM` d’une seconde. Godot conserve les noms des nœuds sans interpréter le suffixe `_Wheel` comme un élément physique de véhicule. Les proportions et les matériaux sont ceux du fichier fourni. Le modèle est retourné de 180° pour suivre l’axe de la simulation, avec les pneus au sol.

Le clip fourni suit la cadence reçue, ou celle de la démonstration. Les deux roues tournent indépendamment selon la vitesse de déplacement et leur rayon de 0,34 m ; en roue libre, les jambes s’arrêtent et les roues continuent. L’option Orange conserve son propre modèle et ses deux clips. Le choix Tricolore reste mémorisé, et les trois vues avec V sont conservées.

L’ancien outil `tools/build_tricolour_cyclist.py` est une recette historique de la version 0.6.8 ; il ne sert pas à reconstruire cet asset fourni et ne doit pas être exécuté pour cette version.
