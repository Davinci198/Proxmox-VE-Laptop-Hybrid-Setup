Thorium RAM-Engine v1.5
Performanță: Profilul browserului rulează integral din /dev/shm (RAM).
Protecție SSD: Reduce scrierile pe disk cu până la 90% prin mutarea bazelor de date SQLite în RAM.
Persistență: Salvare automată la fiecare 30 de minute via cron și restaurare automată la boot.
Metodă: rsync cu checksum pentru a asigura sincronizarea chiar și atunci când browserul este activ.
