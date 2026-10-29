# v0.6.6 — Cycliste GLB fourni

Le cycliste et le vélo sont remplacés par le modèle de `cycliste-autonome.zip`, conservé sans modification des géométries ni des matériaux.

- Modèle autonome : 12 072 triangles, 22 os, 38 objets de maillage, aucun téléchargement externe.
- Échelle métrique conservée et orientation +Z convertie vers le sens de déplacement du simulateur.
- Animations indépendantes : pédalage suivant la cadence ; roues suivant la vitesse et leur rayon de 0,3355 m. Roue libre possible sans arrêter les roues ni remettre les jambes à zéro.
- Suppression des pistes de réinitialisation croisées ajoutées par l’importeur, pour que l’animation des roues ne neutralise pas celle des jambes.
- Limitation des sauts de phase après un blocage du rendu conservée ; pédalage vers l’avant vérifié.
- Pneus alignés sur la chaussée et masquage du modèle conservé en vue du cycliste.

L’ancien modèle procédural reste dans les outils de création et les tests historiques ; ses vêtements ne sont plus inclus dans l’export du jeu. Les quatre circuits, les routes corrigées, les sons et les trois vues restent disponibles.

Validation : 293 contrôles réussis, dont douze contrôles dédiés à l’import, aux deux clips indépendants, au sens de rotation, au skinning et au cycle complet. Le SHA-256 confirme que le GLB est inchangé. Captures natives de profil, de face, de dos et en simulation vérifiées. Export Linux lancé avec succès sur les quatre circuits, avec les sons et les activités.
