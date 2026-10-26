# Validation 0.5.0 — 26 octobre 2026

142 contrôles réussis : 12 Python, 24 simulation, 10 desktop, 34 circuits, 24 navigation, 12 géométrie, 17 lissage et 9 modèle de cycliste.

Le contrôle du modèle inclut maintenant les surfaces courbes, le visage avec nez intégré et tous les maillages personnalisés présents dans le cycliste final : normales finies unitaires, sens des faces et absence de triangles dégénérés. Le casque conserve de véritables ouvertures vérifiées par intersection de rayons. Les tests du pédalage et de garde au sol passent après le déplacement du bassin et l’adaptation des longueurs des jambes.

Le buste et les bras utilisent des sections elliptiques le long de courbes de Bézier, avec recalcul des normales à partir de la surface déformée. Les muscles comportent un relief transversal discret. La peau du mollet s’arrête sous le haut de la chaussette : elle ne traverse plus le tissu blanc. Les aérations du casque ont un contour elliptique ; sa hauteur passe de 9,8 à 12,5 cm au-dessus de sa bordure. Le modèle compte 188 MeshInstance3D contre 181 dans la version précédente ; il ne s’agit pas d’une mesure de FPS.

Les captures de profil, de face et de dos ainsi que les 32 images du cycle de pédalage sont produites par `python tools/run_cloud.py --fixed-fps 60 --script res://tools/capture_rider.gd`. Elles sont écrites dans build/v05_*.png. Pour les portraits studio, le même éclairage est orienté vers la vue observée ; la capture du jeu utilise son éclairage normal. La pose statique de profil place la jambe proche en haut et vers l’avant, comme sur la référence. Le GIF assemble les 32 images sur une seconde. Les dessins fournis ne remplacent pas le modèle dans les captures.

Les matériaux conservent un rendu 3D stylisé. La bordure des vêtements utilise une passe d’encrage aux angles rasants, sans coque géométrique agrandie. Ce travail rapproche les proportions et accessoires ; il ne constitue pas une reconstruction photogrammétrique ni une reproduction exacte de l’illustration.

Les fichiers GPX et leur traitement sont inchangés par cette version. Export et installeur Windows construits par GitHub Actions ; installation, exécution et désinstallation sur Windows non testées dans ce cloud Linux.
