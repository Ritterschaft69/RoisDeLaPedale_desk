# Cycliste autonome pour un autre simulateur

Le fichier `cycliste-universel.glb` est un **glTF 2.0 binaire autonome** : cycliste, vélo, matériaux PBR mats, squelette, poids et animations intégrés. Il ne dépend ni de Three.js, ni des parcours, ni du Bluetooth, ni des sons du simulateur d’origine. Il nécessite un moteur ou un importateur prenant en charge glTF 2.0, les animations et les maillages skinnés.

Le modèle conserve la posture assise corrigée. Les couleurs du vélo et des vêtements sont celles de l’application ; la réponse lumineuse peut varier selon le moteur cible.

## Dimensions et repère natif

- Unité : **mètre** ; échelle d’import : **1** si le moteur utilise les mètres.
- Haut : **+Y**, avant : **+Z** ; l’importateur peut convertir ces axes vers ceux du moteur.
- Origine approximativement au sol, au niveau du vélo. Ne pas ajouter automatiquement une hauteur de selle à la position du groupe.
- Rayon extérieur des roues : **0,3355 m**.
- **12 072 triangles**, **22 os**.
- Aucune texture, image ou ressource externe à télécharger.

## Deux animations indépendantes

| Clip | Durée | Utilisation |
|---|---:|---|
| `PedalForward_60rpm` | 1 seconde | Jambes, pédalier et pédales ; aucune piste de roue |
| `WheelRoll_1turn` | 1 seconde | Un tour complet des deux roues ; aucune piste de jambe |

Pour une cadence `RPM`, jouer la boucle de pédalage à la vitesse **`RPM / 60`**. Exemple : 90 RPM → vitesse de lecture 1,5. À cadence nulle ou absente, figer ce clip. Conserver la phase lors d’un changement de cadence pour éviter un saut de pose.

Pour une vitesse virtuelle `v` en m/s, jouer la boucle de roues à la vitesse **`v / (2 × π × 0,3355)`**. Exemple : 30 km/h → 8,333 m/s → environ 3,95 tours/s. Le moteur cible doit permettre de jouer les deux clips indépendamment, sans qu’une action arrête automatiquement l’autre.

Une autre possibilité est d’ignorer le clip de roues et de donner aux objets `Wheel_Front` et `Wheel_Rear` une rotation locale autour de **+X**, avec l’angle **`distance_m / 0,3355`** en radians. Ces rotations sont définies dans le repère natif du fichier ; utiliser les axes locaux après une conversion globale d’axes par le moteur.

**Ne pas utiliser simultanément le clip et une rotation manuelle pour les roues.** Les roues ne doivent pas être liées directement aux RPM : la cadence et la vitesse virtuelle restent deux données distinctes.

Le modèle s’anime sur place. Le simulateur cible déplace et oriente le groupe complet le long de son propre parcours. La conversion entre puissance, pente et vitesse appartient à sa physique ; aucune physique du simulateur d’origine n’est embarquée ici.

## Import et modification

Importer le GLB avec l’importateur glTF du moteur cible. Vérifier l’échelle, la direction avant, le skinning et les deux clips. Dans Blender : **Fichier → Importer → glTF 2.0**. Les outils d’import/export glTF gèrent la conversion d’axes ; éviter de tourner séparément l’armature et les maillages.

Conserver les noms des os et objets si le code cible les recherche, notamment `Hips`, `Wheel_Front`, `Wheel_Rear`, `Crankset`, `Pedal_L`, `Pedal_R`. La posture et les contacts sont adaptés à ce vélo : changer fortement le cadre ou la longueur des jambes demandera un ajustement du rig.

## Vérifications et provenance

Le fichier exporté a été rechargé avec un lecteur glTF indépendant de la scène de l’application. Les deux clips ont été joués ensemble : durées d’une seconde, pistes indépendantes, pédalage et roues vers l’avant, squelette de 22 os et 12 072 triangles contrôlés. Les empreintes et les noms de pistes sont dans `cycliste-universel.json`. L’import dans le simulateur cible reste à vérifier : aucun moteur cible précis n’a été fourni.

Source : `assets/models/cyclist-hy3d-rigged.glb`, dérivé des modèles utilisateur existants. Cet export n’attribue aucune nouvelle licence aux géométries ; la confirmation CC0 concernant les sons ne s’étend pas automatiquement à ce modèle.

Régénération : `node scripts/export-portable-cyclist.mjs`.
