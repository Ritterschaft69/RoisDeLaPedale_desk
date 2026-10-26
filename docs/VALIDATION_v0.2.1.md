# Validation 0.2.1 — 26 octobre 2026

Le rendu et les modèles sont ceux de la [version 0.2.0](VALIDATION_v0.2.0.md). La trajectoire latérale est maintenant bornée par la vitesse longitudinale : aucun déplacement latéral lorsque le vélo est arrêté, et angle de déplacement modéré à basse vitesse. Un personnage ou chevreuil traversant attend avant d’entrer dans l’enveloppe d’un vélo immobilisé, puis reprend sa traversée quand celui-ci s’éloigne.

**113 contrôles** : 12 Python, 24 physique, 10 desktop, 34 circuits, 24 navigation/vie du décor et 9 géométrie. Les trois nouveaux scénarios vérifient l’absence de glissement à l’arrêt, l’attente d’un piéton et la reprise de sa traversée. Les essais de contournement utilisent l’encombrement longitudinal du vélo (environ 2 m) et des enveloppes conservatrices pour la tête et la queue des animaux.

Les limites documentées pour 0.2.0 restent valables, notamment l’absence de validation sur PC Windows et de mesure de performance GPU. Les captures de la version 0.2.0 restent représentatives : ce correctif change la conduite, pas les modèles ni le rendu.
