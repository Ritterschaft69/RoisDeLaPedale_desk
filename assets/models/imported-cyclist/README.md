# Cycliste fourni par l’utilisateur

Le GLB est copié octet pour octet depuis `cycliste-autonome.zip`, fourni pour remplacer le cycliste le 29 octobre 2026. `metadata.json` et `SOURCE_LISEZ-MOI.md` sont les documents de l’archive, conservés comme description et provenance de l’asset ; leurs références à un projet source ne sont pas des dépendances de ce simulateur.

- SHA-256 : `bb1b9a9385bc27e0c18f88979c0d1feed14b44c29c7cbbab205b9e0368a6e9e3`.
- 12 072 triangles, 22 os, matériaux intégrés, aucune ressource externe.
- Les unités sont des mètres. Le modèle est tourné de 180° autour de Y pour convertir son avant +Z vers le -Z du simulateur. L’échelle et les matériaux fournis sont conservés.
- Les deux animations sont pilotées séparément : cadence pour les jambes/pédales, vitesse divisée par le rayon 0,3355 m pour les roues. Les pistes constantes ajoutées par l’importeur Godot sont retirées des bibliothèques de lecture, afin que chaque animation ne réinitialise pas l’autre.
- Le contact des pneus est ajusté de 0,5 mm au niveau de l’origine ; l’avatar est placé sur la surface de la chaussée, sans ancienne surélévation de 2 cm.

Le modèle est intégré à la demande de l’utilisateur. Aucune nouvelle licence n’est attribuée à ses géométries ; la licence CC0 des sons ne lui est pas appliquée. Le fichier et ses matériaux ne sont pas modifiés. Le code d’adaptation est dans `scripts/rider.gd`.
