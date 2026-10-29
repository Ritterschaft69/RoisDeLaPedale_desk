# v0.6.4 — Trois vues caméra

La touche **V** fait défiler : vue arrière actuelle → vue du cycliste → vue arrière éloignée → vue actuelle.

La vue du cycliste est placée à hauteur des yeux, dans sa voie, sans oscillations de pédalage ni roulis. L’avatar est masqué dans cette vue pour ne pas obstruer la caméra. La vue éloignée recule à 7,5 m et gagne en hauteur ; le cadrage d’origine reste inchangé.

Le changement fonctionne pendant la sortie et en pause, même à l’arrêt. Maintenir la touche ne répète pas le changement. Le choix est mémorisé et les filtres de stabilisation restent actifs.

Les quatre circuits, les ambiances sonores et le mode Légère sont conservés.

Validation : 262 contrôles automatiques réussis ; huit nouveaux contrôles couvrent les positions, le cycle des vues, l’arrêt, la pause, les répétitions de touche et la mémorisation. Captures natives des trois vues vérifiées.
Export Linux démarré avec succès sur les quatre circuits, avec les sons et l’enregistrement des activités.

Installateur publié et téléchargé pour contrôle : 115001947 octets ; SHA-256 `697fb75cac5a45fbde307a2769cea4fe56a71e9847ee1d724640f092d1a43d6d`, conforme à `SHA256SUMS.txt`. Compilation réussie : https://github.com/Ritterschaft69/RoisDeLaPedale_desk/actions/runs/40838323936.
