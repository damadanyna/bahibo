# Appels vocaux Banay

Appel audio entre les deux participants d'une discussion (acheteur ↔
vendeur, vendeur ↔ vendeur, acheteur ↔ acheteur), façon WhatsApp, à coût
zéro : tout est auto-hébergé ou sur un plan gratuit.

## Où un service payant est habituellement utilisé, et ce qui le remplace

| Besoin | Service payant courant | Retenu ici | Licence | Gratuit en auto-hébergement |
|---|---|---|---|---|
| Serveur média (SFU) | LiveKit Cloud, Agora, Twilio, Daily | LiveKit server sur le VPS | Apache-2.0 | oui |
| Traversée de NAT (TURN) | Twilio NTS, Xirsys, Metered | coturn sur le VPS | BSD-3-Clause | oui |
| Jetons d'accès | (inclus dans le cloud) | `livekit-server-sdk` dans le backend | Apache-2.0 | oui |
| Signalisation d'appel | Pusher, Ably, Stream | Socket.IO déjà en place | MIT | oui |
| Réveil du téléphone | OneSignal payant, Twilio | Firebase Cloud Messaging (plan gratuit, illimité) | — | oui |
| Écran d'appel natif | Sinch, Bandwidth | `flutter_callkit_incoming` (CallKit iOS / UI plein écran Android) | MIT | oui |
| Codec audio | — | Opus (WebRTC) | BSD | oui |

Aucune téléphonie classique (PSTN) : l'appel n'existe qu'entre deux
comptes Banay, via Internet.

## Architecture

```
Appelant (Flutter)                    Backend NestJS                       Appelé (Flutter)
   │  POST /calls {conversationId}        │                                    │
   │─────────────────────────────────────▶│  VoiceCall RINGING                 │
   │◀── {callId, url, token} ─────────────│── socket calls:updated {url,token}▶│ call:incoming
   │                                      │── FCM data-only incoming_call ────▶│ (app fermée :
   │  rejoint la salle LiveKit            │   (mêmes url / token)              │  écran natif)
   │                                      │                                    │ rejoint la salle,
   │                                      │                                    │ micro coupé
   │                                      │◀── POST /calls/:id/accept ─────────│ décroche :
   │◀── socket call:accepted ─────────────│── {url, token} (secours) ─────────▶│ active le micro
   │ ═══════════ audio Opus via LiveKit (SFU) ± coturn (relais) ═════════════ │
   │  POST /calls/:id/end                 │                                    │
   │─────────────────────────────────────▶│  ENDED + ligne « 📞 Appel vocal · 2 min » dans le chat
```

- **Salle** : une salle LiveKit par appel (`call-<uuid>`), fermée 60 s
  après le départ du dernier participant.
- **Jeton** : signé par le backend, limité à la salle, au micro
  (`canPublishSources: [MICROPHONE]`, pas de données), valable 15 min
  (le temps de rejoindre ; LiveKit renouvelle en interne pour les
  reconnexions). Celui de l'appelé part avec l'invitation (événement
  socket, push, et `GET /calls/:id` tant que l'appel sonne) : le téléphone
  rejoint la salle pendant la sonnerie, micro non publié et sans s'abonner
  au micro de l'appelant (`autoSubscribe: false` : rien n'est entendu avant
  de décrocher, et Android ne bascule pas en mode « appel », ce qui
  couperait la sonnerie). Décrocher abonne au micro de l'appelant et
  active le sien pendant que `accept` part en parallèle. Le jeton renvoyé
  par `accept` ne sert que de secours.
- **Autorisation** : un appel n'est possible qu'entre les deux membres
  d'une conversation existante, et pas si l'un a bloqué l'autre
  (`ConversationsService.assertUsersCanInteract`).
- **États** : `RINGING → ACCEPTED → ENDED`, ou `DECLINED`, `MISSED`
  (45 s sans réponse), `CANCELLED` (l'appelant raccroche avant). Modèle
  Prisma `VoiceCall` (`callerUserId`, `calleeUserId`, `conversationId`,
  `roomName`, `status`, `createdAt`, `answeredAt`, `endedAt`) ; la durée se
  déduit de `endedAt − answeredAt`.
- **Événements Socket.IO** : un seul canal `calls:updated` dont le champ
  `type` vaut `call:incoming`, `call:ringing` (le téléphone appelé confirme
  qu'il sonne : l'appelant passe de « Appel… » à « Appel en cours… »),
  `call:accepted` ou `call:ended`
  (`reason` : `ended` / `declined` / `missed` / `cancelled`). Même
  convention que `live:updated` et `stories:updated`.
- **Push** : `incoming_call` (data-only sur Android, alerte sur iOS) puis
  `call_cancelled` (silencieux) pour retirer l'écran d'appel si l'appelant
  abandonne.

## Variables d'environnement (backend/.env)

| Variable | Exemple | Rôle |
|---|---|---|
| `LIVEKIT_URL` | `wss://livekit.banay.mg` | Signalisation, transmise à l'app avec le jeton |
| `LIVEKIT_API_KEY` | `APIbanay` | Clé déclarée dans `infra/livekit/livekit.yaml` |
| `LIVEKIT_API_SECRET` | 32 caractères min. | Secret associé |
| `FIREBASE_*` (déjà en place) | — | Push FCM |

Côté app, rien à configurer : URL et jeton arrivent du backend.

## Déploiement sur le VPS

Voir [infra/livekit/README.md](../infra/livekit/README.md) : ports UFW,
certificats, Nginx, `docker compose up -d`, puis migration Prisma
(`npx prisma migrate deploy`) et redémarrage du backend.

## Optimisation pour les réseaux malgaches

| Mesure | Où | Effet |
|---|---|---|
| Opus 24 kb/s (`AudioPreset.speech`) | `VoiceCallService._connectRoom` | ≈ 3 fois moins de data que le réglage « musique » |
| Flux continu (`dtx: false`, depuis le 2026-09-13) | idem | le tampon de gigue du récepteur ne se vide plus entre deux phrases : plus de premières syllabes coupées sur 4G |
| Redondance audio RED (`red: false` = activée, inversion du SDK 2.5.4 ; `audio.active_red_encoding` côté serveur) | idem, `infra/livekit/livekit.yaml` | chaque paquet porte aussi la trame précédente : une perte isolée est réparée sans retransmission |
| Pré-connexion pendant la sonnerie | `VoiceCallService._preconnectIncoming` | signalisation, ICE, DTLS et TURN sont faits avant de décrocher : le son passe dès l'acceptation (façon WhatsApp) |
| Client HTTP persistant | `AppApiClient._httpClient` | plus de poignée de main TCP + TLS à chaque requête : 0,5 à 1 s de moins sur `start`, `ringing`, `accept` |
| Annulation d'écho, réduction de bruit, gain automatique | `AudioCaptureOptions` | mains libres utilisable, voix stable |
| Reconnexion automatique | LiveKit client + événements `RoomReconnecting/Reconnected` | statut « Reconnexion… » sans couper l'appel |
| Qualité de connexion affichée | `ParticipantConnectionQualityUpdatedEvent` → pastille « Bonne connexion / Réseau faible / Connexion perdue » | l'utilisateur comprend d'où vient la coupure |
| TURN sur UDP 3478 et TLS 5349 | coturn | passe les CGNAT des opérateurs mobiles et les pare-feux « HTTPS seulement » |

Dégradation : Opus réduit lui-même son débit sous perte de paquets ; en
cas de coupure, LiveKit tente la reconnexion pendant ~15 s avant de
signaler la déconnexion (l'appel se termine proprement, ligne « Appel
vocal » écrite quand même).

## Consommation estimée

| | Débit | Par minute | Par heure |
|---|---|---|---|
| Voix seule, un sens (Opus 24 kb/s + RED + RTP/UDP), flux continu | ≈ 65 kb/s | ≈ 0,5 Mo | ≈ 30 Mo |
| Par téléphone (montant + descendant) | ≈ 130 kb/s | ≈ 1 Mo | ≈ 60 Mo |
| Côté VPS, par appel (2 flux entrants + 2 sortants) | ≈ 260 kb/s | | ≈ 120 Mo |

Un forfait de 100 Mo permet donc environ 1 h 40 d'appel, l'ordre de
grandeur de WhatsApp (0,5 à 1 Mo par minute). Avant le 2026-09-13 (DTX,
sans RED) : ≈ 10 à 12 Mo/h par sens, 4 à 5 h par forfait de 100 Mo ;
`dtx: true` et `red: true` dans `_connectRoom` y ramènent. Cent appels
simultanés coûtent ≈ 26 Mb/s au VPS, sous la capacité d'un port Hostinger.
Le relais TURN n'ajoute pas de trafic au-delà : le SFU relaie déjà tout.

## Tester en local

1. LiveKit en mode développement sur le PC (clés `devkey` / `secret`) :
   ```bash
   docker run --rm -p 7880:7880 -p 7881:7881 -p 50000-50050:50000-50050/udp \
     livekit/livekit-server --dev --node-ip <IP_LAN_DU_PC>
   ```
2. `backend/.env` :
   ```
   LIVEKIT_URL=ws://<IP_LAN_DU_PC>:7880
   LIVEKIT_API_KEY=devkey
   LIVEKIT_API_SECRET=secret
   ```
3. Deux téléphones réels sur le même Wi-Fi (pas d'émulateur : micro et
   écran d'appel natif indisponibles). TURN n'est pas nécessaire en LAN.
4. Scénarios : app ouverte / en arrière-plan / tuée côté appelé ; refus ;
   raccroché avant réponse ; coupure Wi-Fi 10 s pendant l'appel ; appel
   pendant un appel (réponse « déjà en appel »).

## App fermée : ce qui marche, ce qui reste à faire

- **Android** : le push data-only réveille l'app en arrière-plan, qui
  affiche l'écran d'appel natif (plein écran, sonnerie système, au-dessus
  de l'écran de verrouillage). Accepter lance l'app et l'appel ; refuser
  prévient le serveur depuis l'isolat d'arrière-plan. Les OEM agressifs
  (ColorOS, MIUI…) peuvent bloquer ce réveil : le dispositif
  « optimisation de batterie » déjà présent dans l'app s'applique.
- **iOS, app au premier plan ou en arrière-plan** : CallKit via le même
  plugin.
- **iOS, app tuée** : Apple n'accepte que les pushes VoIP (PushKit) pour
  réveiller une app sur un appel. Il faut un certificat VoIP (gratuit avec
  le compte développeur), le mode arrière-plan `voip`, le
  `PKPushRegistry` dans `AppDelegate.swift` (exemple dans le README du
  plugin) et un envoi APNs direct côté backend (`@parse/node-apn`, MIT).
  En attendant, l'appelé reçoit une alerte classique qui ouvre l'appel s'il
  sonne encore.
- **Play Store** : le plugin déclare les types de service d'avant-plan
  `phoneCall` et `microphone`. La console Play demande une déclaration
  (formulaire « Foreground service permissions », cas « appels ») à la
  prochaine publication.
