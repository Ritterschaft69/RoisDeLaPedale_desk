# Validation du lot 0.1 — 25 octobre 2026

## Ajout du choix des circuits

- **12 tests Python réussis**, dont vérification point par point des trois GPX, statistiques du catalogue et reconstruction déterministe.
- **34 contrôles de sélection réussis** (`tests/test_circuits.gd`) : clic réel des boutons de chacun des trois circuits, nouvelle origine et progression, raccordement visuel avant le départ, actualisation carte/profil, portée du cache IGN et retour à Saint-Dié, lancement de session sur chaque circuit, provenance des activités, refus d’un changement en cours de session, sauvegarde et restauration du choix, exclusion de l’offset initial du compteur d’activité.
- Les **10 contrôles desktop** existants passent avec le menu ajouté. Les **24 contrôles de simulation** restent la référence du moteur physique.
- Les nouvelles sources restent inchangées ; aucune donnée IGN supplémentaire n’est annoncée sur ces parcours.
- Le profil est dessiné par bandes triangulées explicites pour accepter les points GPX répétés et les profils touchant la ligne de base. Le test de sélection laisse dessiner le HUD en session pour chaque circuit ; une capture native de Sortie vélo le matin vérifie également le graphique.

Total de cette mise à jour : **80 contrôles automatisés réussis** (12 Python, 24 simulation, 10 desktop, 34 sélection). Le paquet Linux final a aussi été lancé depuis `/tmp` pour chacun des trois choix restaurés par les préférences : 6,157 m sur Saint-Dié, 5,584 m sur Sortie vélo le matin et 5,489 m sur Oderen / Grand Ballon après 2,64 s simulées. Chaque activité contient le bon identifiant, les échantillons, une distance positive et l’offset source attendu (0 / 12 / 12 m) ; aucune erreur de script ni de rendu dans ces trois lancements. Les archives Windows/Linux et l’installeur NSIS ont été reconstruits. L’exécution Windows reste non validée.

Les résultats ci-dessous décrivent le lot initial et sont conservés comme historique de validation.

Environnement : Linux x86-64, Godot **4.6.3 stable officiel**, Python 3.12.14. Rendu inspecté via Xorg dummy, OpenGL GL Compatibility, Mesa llvmpipe logiciel. Aucun matériel Bluetooth ni poste Windows disponible.

## Résultats exécutés

| Contrôle | Résultat |
| --- | --- |
| `python -m unittest discover -s tests -v` | **10 tests réussis** : intégrité GPX, distances, orientation, inverse de projection, reçus et empreintes, altitudes terrain et emprises IGN |
| `godot --headless --path . --script tests/test_simulation.gd` | **24 contrôles réussis** : démarrage/arrêt, conservation du travail, équilibre, pente, vent, roulement, aspiration, 30/60/144 FPS, source/pente GPX, données périmées, sauvegarde |
| `godot --headless --path . --script tests/test_desktop.gd` | **10 contrôles réussis** : scène native, couverture géographique, triangulation des 619 emprises, toiture, terrain, progression, pause/reprise avec boutons, résumé, historique et préférences |
| Import Godot et exports Linux/Windows | Réussis, scripts compilés, cache géographique inclus et sources brutes exclues du paquet |
| Archive des modèles officiels | **SHA-512 vérifié** contre `SHA512-SUMS.txt` de la release Godot officielle |
| Compilation NSIS 3.11 | Installeur Windows produit, contrôlé comme archive PE NSIS ; pas d’exécution Windows |
| Exécutable Linux packagé lancé depuis `/tmp`, sans le dépôt courant | Réussi : `SMOKE_OK`, **6,1569 m**, vitesse **3,6157 m/s**, temps simulé **2,64 s**, activité JSON créée |
| Trace réseau de cet exécutable Linux (`strace -f -e trace=network`) | Aucun socket AF_INET/AF_INET6 et aucune connexion réseau ; uniquement deux sockets locaux AF_NETLINK de détection matérielle |
| Capture native dans la tranche IGN à 1,2 km | Réussie, HUD et scène rendus, `build/session.png` inspecté |
| Accès aux sources | WFS IGN paginé, altimétrie IGN et requête POST Overpass réussis ; métadonnées CSW IGN et licences consultées |

Total : **44 contrôles automatisés réussis**, plus les vérifications d’export et de lancement. Les anciens essais ayant échoué ont été diagnostiqués : erreurs de typage GDScript corrigées ; exemple numérique 30,3 km/h du document incompatible avec ses propres coefficients ; hypothèses de test sur altitude initiale/temps de roue libre remplacées par vérification des données et des forces réelles. Aucun test désactivé pour obtenir ce résultat.

Le lancement tracé n’a pas été fait dans un espace réseau désactivé : la preuve porte sur l’absence d’appels réseau observée pendant cette courte session. Le contenu du PCK permet le démarrage hors ligne ; les acquisitions sont des outils explicites, jamais lancés par le jeu.

## Non validé / non terminé

- Installation, exécution, désinstallation et comportement GPU **sous Windows**.
- Bluetooth FTMS réel, reconnexion et contrôle de résistance ; ANT+ absent.
- Audio et choix du périphérique de sortie, non intégrés.
- 60 FPS en 1080p : aucune mesure sur matériel Windows de référence. `--fixed-fps` sert au test temporel, pas à annoncer une performance réelle.
- Sessions de plusieurs heures, veille/réveil, fuite mémoire et reprise après plantage.
- Terrain LiDAR HD, MNT 25 m et couverture IGN détaillée des 66 km : non réalisés ; tranche détaillée limitée à 3 km.
- Fidélité finale de l’art cel-shading, bâtiments remarquables, qualité avatar/vélo, LOD/instancing avancés : prototype à améliorer.
- Référentiel vertical GPX : inconnu ; correction d’affichage isolée et documentée, pas une validation topographique.
- Signature du binaire et de l’installeur : absente.

Le MVP complet du cahier des charges n’est donc pas déclaré accepté. Le lot fournit une base native exécutable, des données réelles vérifiables, un packaging construit et des limites identifiées.
