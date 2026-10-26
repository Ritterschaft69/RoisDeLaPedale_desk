Deuxième préversion du simulateur desktop natif. Le téléchargement Windows se trouve dans **Assets → RoisDeLaPedale-0.2.0-Setup.exe**.

### Cycliste et vélo
- Cycliste remodelé : silhouette habillée, posture penchée, bras et jambes articulés, casque ventilé, gants, chaussettes et chaussures.
- Vélo de route plus détaillé : roues 700C, rayons, jantes, freins à disque, fourche, transmission et cintre courbé. Les roues suivent la distance parcourue, les pédales suivent la cadence.
- Caméra rapprochée et tableau de bord réorganisé pour garder le cycliste et les roues visibles. Touche H pour masquer l’interface et profiter du paysage.

### Route et paysages
- Asphalte et accotements texturés procéduralement, marquages plus fins, terrain triangulé continu.
- Éclairage toon corrigé, contours fins, ciel bleu, nuages et reliefs arrondis en arrière-plan.
- Végétation plus dense, arbres variés instanciés avec niveaux de détail, rochers, herbes, murets de pierre, clôtures et balises.
- Façades enrichies avec encadrements, volets, portes et cheminées ; les emprises et hauteurs IGN existantes sont conservées.

### Trajectoire et vie du décor
- Le cycliste roule à droite, à 1,55 m de l’axe du parcours.
- Contournement anticipé et progressif des obstacles, puis retour à droite. Si aucun passage n’est disponible, freinage virtuel et arrêt.
- Passants animés, traversées de piétons, chevreuils, renards et oiseaux. Leur simulation s’arrête en pause et reprend avec la session.
- Les personnages, animaux et obstacles sont des éléments de jeu procéduraux ; leurs positions ne proviennent pas d’un inventaire IGN ou OSM.

### Vérification et limites
110 contrôles automatisés passent : données et circuits, physique, écrans desktop, conduite/évitement et orientation des géométries. Des captures natives montrent le rendu et le contournement. La couverture IGN détaillée reste limitée aux trois premiers kilomètres de Saint-Dié ; les autres décors sont illustratifs. Le style reste un rendu 3D procédural à améliorer, sans prétendre reproduire exactement l’illustration fournie.

Version non signée. Installation et performances sur un vrai PC Windows restent à vérifier. Bluetooth réel et audio ne sont pas intégrés dans cette préversion.

![Route et cycliste](https://github.com/Ritterschaft69/RoisDeLaPedale_desk/releases/download/v0.2.0/v0.2.0-rural.png)

![Contournement d’un obstacle](https://github.com/Ritterschaft69/RoisDeLaPedale_desk/releases/download/v0.2.0/v0.2.0-avoidance.png)
