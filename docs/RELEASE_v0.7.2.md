# Rois de la Pédale 0.7.2 — Cycliste tricolore fournie

L’option **Accueil → Cycliste → Tricolore** remplace l’ancien personnage par le fichier `cycliste_lowpoly_roadbike_rigged (1).glb` fourni par l’utilisateur. Le GLB est conservé sans modification, avec son vélo, ses proportions, ses matériaux, son squelette à 18 os et son animation `Pedal_60_RPM`. Le choix reste mémorisé.

Le pédalage suit la cadence, vers l’avant. Les roues suivent indépendamment la vitesse, avec leur rayon de 0,34 m. En roue libre, les jambes s’arrêtent et les roues continuent de tourner. Le modèle orange, les trois vues, les paysages et la connexion Bluetooth restent disponibles.

Le modèle complet contient 23 456 triangles. La licence de cet asset fourni n’a pas été précisée ; elle ne se confond pas avec les licences CC0 des ambiances ou celles des données géographiques.

![Profil du GLB intégré](previews/v0.7.2-tricolour-side.png)
![Vue en simulation](previews/v0.7.2-tricolour-ride-0.png)

## Validation

52 tests Python et 312 vérifications natives réussis. L’exécutable Linux exporté a été contrôlé sur les quatre circuits et les deux cyclistes (8 combinaisons). Les tests vérifient notamment la conservation du GLB, les déformations sur un tour complet, l’alignement pieds/pédales, le sens de pédalage, le roulement indépendant et la mémorisation du choix. Onze captures natives documentent les vues du modèle et son intégration en simulation.

SHA-256 du GLB fourni : `bc9e434a777498e08e319f985977927ce75aedc916ecb0b1a8bca35d015ed3bf`.

## Installateur publié et vérifié

[Télécharger l’installateur Windows v0.7.2](https://github.com/Ritterschaft69/RoisDeLaPedale_desk/releases/download/v0.7.2/RoisDeLaPedale-0.7.2-Setup.exe). Fichier téléchargé après publication : 154689513 octets, en-tête Windows MZ et empreinte SHA-256 vérifiés.

SHA-256 : `872746f49de938894324e83a25297cf700b6f8e8a3e9c3eec15c29b24e5a03d1`.

[Fabrication GitHub réussie](https://github.com/Ritterschaft69/RoisDeLaPedale_desk/actions/runs/41809979723), source `353e44f59eb6675756f8f526dd4d0e7848e49d62`.
