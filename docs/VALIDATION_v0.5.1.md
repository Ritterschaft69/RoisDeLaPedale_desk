# Validation 0.5.1 — 26 octobre 2026

148 contrôles réussis : 12 Python, 24 simulation, 10 desktop, 34 circuits, 24 navigation, 12 géométrie, 17 lissage, 9 modèle et 6 raccords de vêtements.

Les nouveaux tests lisent les ressources réellement utilisées par le jeu. Ils vérifient que le maillot et le cuissard ont chacun un seul composant connexe, sans bord libre ni arête non-manifold. Les poids de squelette sont finis, positifs et normalisés à la précision de leur stockage 16 bits. Les bas de cuissard ne reçoivent pas de poids de la jambe opposée. Sur 32 phases du pédalage, les pivots restent aux hanches, les os suivent la cinématique inverse et tous les sommets déformés restent finis dans les limites du cycliste.

Le maillot a été fusionné hors ligne avec ajout des volumes de deltoïdes, puis lissé et triangulé. Le cuissard est fusionné dans une pose de référence où les cuisses sont légèrement écartées, afin de ne pas créer de pont entre elles sous l’entrejambe. Le squelette applique une rotation par cuisse avec des poids progressifs autour du bassin. Les fichiers Godot compressés totalisent environ 400 Ko ; la génération nécessite Blender, mais ni l’exécution ni les builds usuels ne le requièrent. Les scripts de génération sont conservés dans tools/ et leur procédure est décrite dans assets/models/README.md.

Des gros plans des épaules et des hanches, les trois vues habituelles, un cycle complet de profil et un cycle rapproché du cuissard sont capturés dans le moteur avec tools/capture_rider.gd. Ils permettent d’examiner les raccords au lieu de les masquer dans une vue d’ensemble. L’éclairage studio est orienté vers le côté observé ; la capture en jeu garde son environnement normal.

Le modèle reste stylisé. La déformation du cuissard n’est pas une simulation de tissu et ne supprime pas tous les plis de flexion. L’installation et l’exécution sur un vrai poste Windows restent à vérifier.

Le paquet Linux autonome a été exporté avec les ressources fusionnées puis exécuté en mode headless : SMOKE_OK, 6,16 m parcourus, vitesse 3,62 m/s et activité sauvegardée, sans erreur de chargement. Cette vérification confirme l’inclusion des ressources dans un export ; elle ne remplace pas un essai Windows.
