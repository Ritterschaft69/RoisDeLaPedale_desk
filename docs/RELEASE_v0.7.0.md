# v0.7.0 — Connexion Bluetooth Elite Suito-T

**Périphériques → Rechercher → sélectionner le Suito-T → Démarrer avec le home trainer.** Brancher/réveiller le Suito-T, activer le Bluetooth du PC et fermer les autres applications vélo qui pourraient occuper la connexion.

La puissance reçue en FTMS ou Cycling Power alimente la physique, la cadence transmise anime le cycliste. Les contrôles de puissance démo disparaissent d’une sortie Bluetooth. Les activités sont distinguées des démonstrations et signalent les périodes de puissance absente. La vitesse reste celle de la simulation.

L’option de résistance suivant la pente est désactivée par défaut et n’apparaît utilisable que lorsque le home trainer annonce ce mode FTMS. La pente est bornée à ±10 %, les confirmations de commande sont attendues et une pause remplace les commandes précédentes. Une pente nulle et une pause sont demandées lorsque la session s’arrête. Une perte radio interrompt le pilotage ; le logiciel ne peut pas garantir un changement physique du home trainer une fois la liaison coupée.

La recherche et les opérations Bluetooth tournent dans un module autonome séparé du rendu. L’installateur Windows inclut ce module et son Python embarqué : aucune installation Python manuelle. Les échanges restent locaux et authentifiés ; aucun compte ou serveur distant. Le mode démo reste disponible par choix explicite. ANT+, CSC séparé, calibration/spin-down et profils propriétaires ne sont pas intégrés.

357 contrôles logiciels réussis, avec paquets FTMS/CPS, module de test local, priorité à la pause, mesures périmées, provenance des activités et tests de l’application existante. Le module gelé vérifie l’import du backend réel. Le cloud n’a ni adaptateur radio ni Suito-T à portée : **la connexion radio et la résistance physique restent à vérifier sur le PC équipé**.

[Guide Bluetooth](https://github.com/Ritterschaft69/RoisDeLaPedale_desk/blob/main/docs/BLUETOOTH.md). Les captures montrent l’écran réel et le diagnostic d’absence d’adaptateur dans le cloud ; elles ne présentent pas un Suito-T réel comme connecté.
