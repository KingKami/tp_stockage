# TP Stockage
TP linux Stockage Raid

## Objectif

- Mettre en œuvre les connaissances sur iSCSI, mdadm, LVM et les systèmes de fichiers.
- Modélisez l'empilement de volumes suivant :
    <img src="img/schema.png" alt="schema" width="500">
- Créez une dizaine de fichiers de 2Mo à partir de données aléatoires sur chacun des LV.
- Snapshotez le système de fichier LV1, détruisez le fichier précédemment créé et restaurez le.
- Simulez la panne d'un disque sur la machine 3 et son remplacement.
- Montez le ISCSI automatiquement au démarrage et configurez l’authentification CHAP
