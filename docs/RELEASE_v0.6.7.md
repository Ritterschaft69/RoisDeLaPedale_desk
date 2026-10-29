# v0.6.7 — Deux cyclistes au choix

Depuis **Accueil → Cycliste**, choisir entre :

- **Orange · Modèle fourni** : le cycliste et le vélo déjà intégrés, conservés.
- **Bleu marine · Tricolore** : une seconde cycliste créée d’après les vues de référence, avec tenue ajustée, bandes tricolores, casque blanc ventilé, lunettes et tresse brune en relief.

Le sélecteur offre un aperçu 3D animé et mémorise le choix au redémarrage. Il n’instancie qu’un personnage à la fois et préserve les phases des animations lors d’un changement. L’aperçu est visible même si la vue du cycliste est enregistrée ; la vue de conduite est restaurée en quittant le sélecteur.

Le nouveau personnage possède sa propre géométrie, avec maillot et cuissard continus, bords de bandes découpés, raccords de peau et de chaussettes, casque ajouré et tresse à trois brins. Il réutilise le vélo et les animations indépendantes existants : jambes suivant la cadence, roues suivant la vitesse. Le GLB orange reste inchangé.

Les quatre circuits, les sons, les routes corrigées et les trois vues sont conservés. La recette Blender est fournie pour la création hors ligne ; Blender n’est pas nécessaire pour jouer.

Validation : 309 contrôles réussis, dont sélection, conservation des phases, remplacement sans doublon, corps déformé pendant un cycle complet, aperçu animé, mémorisation et retour à la vue de conduite. Export Linux testé sur les huit combinaisons de quatre circuits et deux personnages. Captures natives du personnage et du sélecteur vérifiées.
