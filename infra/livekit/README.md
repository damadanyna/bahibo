# LiveKit + coturn auto-hébergés (VPS Banay)

Tout ce qu'il faut pour faire tourner les appels vocaux et les lives sans
aucun service payant : LiveKit (SFU, Apache-2.0) et coturn (STUN/TURN,
BSD-3-Clause) sur le VPS Ubuntu, derrière Nginx et Let's Encrypt.

Le détail fonctionnel (backend, app, bande passante, tests) est dans
[docs/voice-calls.md](../../docs/voice-calls.md).

## Prérequis

- Deux sous-domaines pointant sur l'IP du VPS : `livekit.<DOMAINE>` et
  `turn.<DOMAINE>` (enregistrements A).
- Docker + Docker Compose plugin, Nginx, certbot déjà installés (le
  backend en dépend déjà).

## Ports à ouvrir (UFW)

| Port | Proto | Rôle |
|---|---|---|
| 443 | tcp | Nginx → signalisation LiveKit (wss) |
| 7881 | tcp | Média LiveKit en TCP (secours quand l'UDP est bloqué) |
| 7882 | udp | Média LiveKit (UDP, le cas normal : un seul port multiplexé) |
| 3478 | tcp + udp | STUN / TURN (coturn) |
| 5349 | tcp | TURN sur TLS (passe les pare-feux « HTTPS seulement ») |
| 49160:49400 | udp | Relais coturn |

```bash
sudo ufw allow 443/tcp
sudo ufw allow 7881/tcp
sudo ufw allow 7882/udp
sudo ufw allow 3478
sudo ufw allow 5349/tcp
sudo ufw allow 49160:49400/udp
sudo ufw status numbered
```

Le port 7880 (signalisation en clair) reste sur `127.0.0.1` : ne pas
l'ouvrir.

**Installation existante (avant le 2026-09-13)** : le média passait par la
plage `50000:50200/udp`, soit deux ports par participant et ~100
participants au total, lives et appels confondus. Pour passer au port
unique :

```bash
sudo ufw allow 7882/udp
# copier le nouveau livekit.yaml, puis
docker compose restart livekit
sudo ufw status numbered      # repérer la règle 50000:50200/udp
sudo ufw delete <numéro>      # une fois LiveKit redémarré sans erreur
```

## Déploiement pas à pas

1. **Copier le dossier** sur le VPS, par exemple dans `/opt/banay-livekit`,
   puis remplacer dans `livekit.yaml`, `turnserver.conf` et
   `nginx-livekit.conf` :
   - `<DOMAINE>` → votre domaine ;
   - `<IP_PUBLIQUE>` → l'IP du VPS ;
   - `<SECRET_LIVEKIT>` → `openssl rand -base64 32` ;
   - `<MOT_DE_PASSE_TURN>` → `openssl rand -hex 16` (mêmes valeurs dans
     `livekit.yaml` et `turnserver.conf`).

2. **Certificats** (Nginx n'écoute pas encore sur `livekit.` : le mode
   standalone est le plus simple pour le premier tirage) :
   ```bash
   sudo certbot certonly --nginx -d livekit.<DOMAINE>
   sudo certbot certonly --standalone -d turn.<DOMAINE>
   ```
   Le renouvellement automatique de certbot couvre les deux ; ajouter un
   hook pour que coturn recharge le certificat :
   ```bash
   echo '#!/bin/sh
   docker restart banay-coturn' | sudo tee /etc/letsencrypt/renewal-hooks/deploy/coturn.sh
   sudo chmod +x /etc/letsencrypt/renewal-hooks/deploy/coturn.sh
   ```

3. **Nginx** :
   ```bash
   sudo cp nginx-livekit.conf /etc/nginx/sites-available/livekit.<DOMAINE>
   sudo ln -s /etc/nginx/sites-available/livekit.<DOMAINE> /etc/nginx/sites-enabled/
   sudo nginx -t && sudo systemctl reload nginx
   ```

4. **Lancer** :
   ```bash
   cd /opt/banay-livekit
   docker compose pull
   docker compose up -d
   docker compose logs -f --tail=50
   ```
   LiveKit doit afficher `starting LiveKit server` avec l'IP publique
   détectée ; coturn `listener opened` sur 3478 et 5349.

5. **Backend** : dans `backend/.env`,
   ```
   LIVEKIT_URL=wss://livekit.<DOMAINE>
   LIVEKIT_API_KEY=APIbanay
   LIVEKIT_API_SECRET=<SECRET_LIVEKIT>
   ```
   puis redémarrer le backend. Rien à changer dans l'app : elle reçoit
   l'URL et le jeton du backend à chaque appel ou live.

## Vérifier

- Signalisation : `curl -I https://livekit.<DOMAINE>` renvoie `200` (page
  « OK » de LiveKit).
- TURN : l'outil
  [Trickle ICE](https://webrtc.github.io/samples/src/content/peerconnection/trickle-ice/)
  avec `turn:turn.<DOMAINE>:3478`, utilisateur `banay` et le mot de passe,
  doit produire un candidat `relay`.
- Appel de bout en bout : deux téléphones, l'un en Wi-Fi, l'autre en
  données mobiles ; puis les deux en données mobiles (c'est là que TURN
  sert).

## Notes

- **Lives inclus** : `LIVEKIT_URL` est partagé avec les lives vendeurs.
  En auto-hébergement, chaque spectateur consomme jusqu'à ≈ 2,6 Mb/s de
  sortie du VPS en 1080p (hôte bien connecté) et ≈ 1,3 Mb/s en 720p :
  50 spectateurs ≈ 65 à 130 Mb/s, 200 ≈ 260 à 520 Mb/s. La limite est le
  débit réel du port Hostinger et le trafic mensuel
  inclus, plus le nombre de ports depuis le passage à `udp_port`.
  Les salles de live sont créées par le backend avec un délai de lecture
  (`playout_delay`) qui ne s'applique pas aux appels.
- **Alternative sans coturn** : LiveKit embarque son propre serveur TURN
  (section `turn:` de `livekit.yaml`, identifiants par session). coturn
  est retenu ici parce qu'il est imposé et plus souple (STUN partagé,
  TLS sur 5349).
- Un seul nœud, pas de Redis : suffisant tant que LiveKit tourne sur une
  seule machine.
