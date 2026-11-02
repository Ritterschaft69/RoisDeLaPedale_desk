# Bluetooth LE — Elite Suito-T

## Connecter le home trainer

1. Brancher le Suito-T, activer le Bluetooth du PC et pédaler quelques tours pour réveiller le home trainer.
2. Fermer les autres applications qui utilisent sa liaison Bluetooth : My E-Training, Upgrado, Zwift, etc., y compris sur un téléphone proche.
3. Dans le jeu, ouvrir **Périphériques**, attendre « Bluetooth prêt », puis cliquer **Rechercher les appareils (10 s)**.
4. Cliquer le Suito-T dans la liste et attendre l’état connecté. Vérifier que les watts et la cadence évoluent en pédalant.
5. Cliquer **Démarrer avec le home trainer**, ou revenir à l’accueil et utiliser ce même bouton.

La vitesse virtuelle reste calculée par la simulation à partir de la puissance, de la masse et du parcours ; la vitesse de roue éventuellement transmise ne remplace pas cette simulation. Les mesures absentes sont affichées « — » ; aucune cadence de démonstration n’est substituée.

## Résistance suivant la pente

L’option **Adapter la résistance à la pente** est désactivée par défaut. Elle n’est disponible que si les services et caractéristiques FTMS du périphérique annoncent la prise en charge du mode simulation vélo. L’activer dans Périphériques pour envoyer la pente pendant une sortie Bluetooth. Les valeurs sont bornées à **−10 à +10 %**, au maximum une modification par seconde. Les commandes demandent d’abord le contrôle et le démarrage de la machine et attendent ses confirmations.

En pause, au retour au menu et en fin de sortie, le module demande une pente nulle et la pause du home trainer. Il surveille les mesures et les messages du jeu ; des messages anciens ne relancent pas une commande de pente. Une pause reçue pendant une réponse GATT lente remplace la demande précédente. Les commandes refusées désactivent le pilotage, tout en conservant la lecture des mesures.

Si la radio est réellement coupée, le logiciel ne peut plus envoyer de commande au home trainer. Il interrompt le pilotage et met les entrées expirées à zéro ; le comportement physique après une coupure radio dépend du firmware du Suito-T. Les commandes de calibration/spin-down et les profils propriétaires Elite ne sont pas implémentés.

## Déconnexion et reprise

Après deux secondes sans nouvelle puissance, les watts passent à zéro et l’interface signale la perte du signal. Le jeu ne repasse jamais automatiquement en mode démo. Le cycliste peut continuer en roue libre selon la physique du parcours. Les notifications anciennes restées dans un tampon ne deviennent pas de nouvelles mesures.

En sortie Bluetooth, mettre en pause puis ouvrir **Connexion Bluetooth** pour rechercher/reconnecter le Suito-T sans perdre l’activité. Revenir à la pause et reprendre. **Utiliser le mode démo** est un choix explicite depuis l’accueil/Périphériques.

Les activités indiquent `input_source: bluetooth`, le nom du home trainer, `missing_power_s` et `power_valid` pour les échantillons enregistrés. Les moyennes incluent la période sans signal avec puissance zéro ; la durée manquante reste identifiable. Les adresses Bluetooth ne sont pas inscrites dans les activités.

## Systèmes et installation

L’installateur Windows inclut **RoisBluetooth.exe**, compilé sur Windows avec Bleak/WinRT et Python embarqué. Aucun Python, compte ou service en ligne n’est requis sur le PC pour jouer. Le PC doit disposer d’un adaptateur Bluetooth LE et de son pilote ; le module vise Windows 10/11 x64. Un adaptateur ANT+ seul ne remplace pas un adaptateur Bluetooth.

Les profils standards pris en charge sont **FTMS Indoor Bike Data** (`2AD2`) et **Cycling Power Measurement** (`2A63`). Le mode de pente utilise **Fitness Machine Control Point** (`2AD9`), seulement lorsque les capacités le permettent. Les firmwares qui n’exposent pas ces profils ne sont pas annoncés compatibles par défaut. Une mise à jour du firmware peut être nécessaire ; elle s’effectue avec les outils Elite, hors du jeu.

Le module Linux peut être gelé sur Linux avec `tools/build_bluetooth.py`. En développement, un interpréteur contenant Bleak peut aussi lancer les scripts de `bluetooth/` ; `RDP_BLUETOOTH_PYTHON` permet de sélectionner cet interpréteur lorsqu’aucun module gelé n’est présent.

## Validation réalisée et limite matérielle

357 contrôles logiciels réussis : formats FTMS/CPS, indicateurs optionnels, paquets tronqués, débordement des compteurs de cadence, expiration indépendante des mesures, commandes bornées, refus de contrôle, priorité à la pause, rejets des messages anciens, authentification locale, notifications UTF-8 fragmentées, écran de recherche, physique alimentée par les watts reçus, enregistrement et arrêt du module. Les tests radio utilisent un faux backend dans les tests uniquement ; il n’est pas livré avec le programme.

Le module autonome est vérifié après gel en important le backend réel et en décodant une mesure connue. Le cloud ne dispose pas d’adaptateur Bluetooth et n’est pas proche du Suito-T de l’utilisateur : **découverte radio, notifications réelles et résistance physique restent à valider avec ce matériel**. Aucune connexion effective à ce Suito-T n’est revendiquée à partir des seuls tests logiciels.
