# Caméra stabilisée

Télécharger **RoisDeLaPedale-0.5.2-Setup.exe** ci-dessous.

La caméra utilise désormais un suivi indépendant du cycliste :

- Orientation amortie sur une portion de route de 16 m, avec tolérance aux petites variations de cap.
- Horizon horizontal et inclinaison de visée constante ; les mouvements du corps ne font pas rouler la caméra.
- Les petits écarts latéraux restent dans une zone de tolérance de 55 cm ; les grands contournements sont suivis progressivement.
- Hauteur filtrée pour atténuer les petites bosses, sans perdre le cycliste dans les descentes.
- Recul fixe de 4,2 m, sans zoom automatique ni retard longitudinal élastique.
- Caméra figée à l’arrêt et pendant la pause. Le départ et le changement de circuit réinitialisent directement le cadrage.

La position et la cible partagent le même repère stabilisé. L’ancienne cible immédiatement recalculée à partir du cycliste pouvait tourner plus vite que la position amortie, provoquant des rattrapages de cadrage.

Capture native sur un contournement d’obstacle : [voir la vidéo MP4 (4,8 s)](https://github.com/Ritterschaft69/RoisDeLaPedale_desk/releases/download/v0.5.2/v0.5.2-camera.mp4).

![Caméra stabilisée](https://github.com/Ritterschaft69/RoisDeLaPedale_desk/releases/download/v0.5.2/v0.5.2-camera.png)

159 contrôles réussis sous Linux, dont 11 pour le suivi caméra. Installeur Windows construit par GitHub Actions ; installation et exécution sous Windows non testées dans ce cloud. Les modèles, la conduite et les GPX ne sont pas modifiés par cette version.
