# Banay Changelog

Archive chronologique des correctifs et changements notables, en complement
de `git log`. Chaque entree documente le symptome rapporte, la cause racine
identifiee et les fichiers touches, pour servir de reference rapide lors de
futurs diagnostics.

## 2026-08-08

### 1. Images transferees affichees en texte brut (URL) dans le chat

- **Symptome** : une photo "transferee" (fonction Partager/Forward) vers un
  autre utilisateur s'affichait comme un message texte contenant le nom du
  fichier et l'URL Cloudinary brute, au lieu d'une vignette image.
- **Cause** : `_forwardMessageToConversation` convertissait toujours le
  message d'origine en texte (`nomFichier\nURL`) avant envoi, meme pour les
  messages media, au lieu d'appeler les endpoints `media-messages`.
- **Correctif** : `lib/page/chat_page.dart` — detection des messages
  purement media et envoi via `sendMediaMessage` / `sendUserMediaMessage`
  avec un payload media complet reconstruit depuis `_ChatMessageMedia`.

### 2. Echecs d'upload produit silencieux ("Echec" fige a 24%)

- **Symptome** : sur connexion instable, l'upload d'un produit finissait en
  "Echec" avec le message generique "La synchronisation a echoue", sans
  reprise automatique.
- **Cause** : `CatalogApiService._sendMultipartRequest` ne protegeait que
  `request.send()` par un try/catch ; la lecture de la reponse
  (`http.Response.fromStream`) n'etait pas couverte, donc une coupure reseau
  pendant l'upload remontait une exception brute non reconnue comme erreur
  reseau.
- **Correctif** : `backend`-side aucun changement ; cote client,
  `lib/services/catalog_api_service.dart` — tout le corps de la requete est
  desormais dans le meme try/catch, normalise en `AppApiException`
  reconnue par la logique de reprise automatique.
- **Suivi ajoute** : les echecs d'upload produit sont maintenant journalises
  via `AppAnalytics.logUserEvent(status: 'failure')`
  (`lib/services/product_upload_queue_service.dart`), visibles dans le
  rapport QA local et auto-synchronises au backend. Cote backend,
  `NotificationsService.createEventLogBatch` ecrit desormais aussi ces
  evenements en echec dans le log serveur (`JsonFileLoggerService`, type
  `client_error`), visible dans le dashboard admin aux cotes des vraies
  erreurs HTTP.

### 3. Historique de discussion "efface" apres un message produit

- **Symptome** : apres avoir cliique sur "Cet article est-il disponible ?"
  depuis la fiche produit avec un contact deja existant, toute la
  discussion directe precedente (ex. 20 messages) semblait disparaitre,
  remplacee par la nouvelle conversation liee au produit.
- **Cause** : ce bouton ouvre le chat avec `productId` + `userId`, ce qui
  fait creer une conversation isolee scoppee au produit
  (`getOrCreateConversationForProduct`, cle unique
  `(buyer, seller, productId)`). Le cache local (`LocalConversationStore` et
  `ConversationsApiService`) enregistrait ce snapshot **aussi** sous la cle
  generique `user:<id>`, ecrasant le cache utilise par l'ouverture normale
  du chat avec ce contact.
- **Correctif** : `lib/services/local_conversation_store.dart` et
  `lib/services/conversations_api_service.dart` — une conversation liee a
  un produit n'est plus mise en cache sous l'alias generique `user:<id>`.
  Auto-reparateur : la prochaine ouverture normale du chat avec ce contact
  reecrit le bon cache.

### 4. Statut "distribue" uniquement a l'ouverture de l'app

- **Symptome** : le statut d'un message restait a "envoye" tant que le
  destinataire n'ouvrait pas explicitement l'application, meme s'il avait
  retrouve internet (donnees mobiles/wifi) entre-temps.
- **Cause** : `ChatRealtimeService.handleAppLifecycleStateChanged`
  deconnecte explicitement le socket temps reel des que l'app passe en
  arriere-plan. Le mecanisme existant de "marquer distribue a la
  reconnexion" (`ConversationsRealtimeGateway.handleConnection` ->
  `emitPendingMessageDeliveries`) ne se declenchait donc jamais tant que
  l'app n'etait pas ramenee au premier plan.
- **Decision produit** : approche "notification push silencieuse" retenue
  (memes principe que WhatsApp/Messenger), plutot que garder le socket
  connecte en arriere-plan (cout batterie, non fiable a moyen terme).
- **Correctif** :
  - Backend : nouvel endpoint `POST /conversations/delivery-ping`
    (`conversations.controller.ts`, `conversations.service.ts`) qui reutilise
    `emitPendingMessageDeliveries` (rendue publique dans
    `conversations-realtime.gateway.ts`).
  - Client : `ConversationsApiService.pingDelivery()` +
    `PushNotificationService.acknowledgeChatMessageDeliveryInBackground()`,
    branche dans `firebaseMessagingBackgroundHandler` (app fermee/arriere-plan)
    et `_handleForegroundMessage` (app ouverte mais chat pas affiche).
- **A tester sur appareil reel** : fiabilite Android bonne en general ; iOS
  plus restrictif si l'app a ete fermee manuellement (force-quit) par
  l'utilisateur — l'execution en arriere-plan peut alors etre retardee ou
  bloquee par le systeme.

## 2026-09-05

### 1. Notification permanente "Connecte pour vos messages" impossible a retirer

- **Symptome** : la notification du service de premier plan Android restait
  fixe dans le volet et ne pouvait pas etre glissee (capture sur OPPO R17 /
  ColorOS). Le passage en canal silencieux du 2026-09-04 ne suffisait pas.
- **Cause** : un service de premier plan Android exige une notification
  permanente ; sur Android 12 et anterieur le systeme la rend
  non-glissable, quel que soit le reglage du canal. Aucune solution cote
  code tant que le service tourne pour tout le monde.
- **Decision produit** : modele Telegram / Signal retenu. Le push FCM haute
  priorite (deja en place cote backend) devient le mecanisme principal en
  arriere-plan ; le service de premier plan passe en option **desactivee par
  defaut**, reservee aux telephones qui retardent les messages. WhatsApp /
  Messenger n'ont pas ce probleme grace a la liste blanche constructeur,
  non reproductible pour une app independante.
- **Correctif** :
  - `lib/services/foreground_connection_service.dart` — preference
    `banay_reinforced_connection_enabled`, `isEnabledByUser`,
    `setEnabledByUser()` (persiste + demarre/arrete), `startIfEnabled()`
    qui arrete aussi un service laisse actif par une version precedente.
  - `lib/auth/session_gate.dart` — `startIfEnabled()` remplace le demarrage
    systematique apres login. Les arrets au logout sont inchanges.
  - `lib/component/background_connection_sheet.dart` (nouveau) — feuille de
    reglage avec interrupteur "Garder Banay actif en arriere-plan", meme
    style que la feuille Theme.
  - `lib/page/navigation/main_navigation_messages_panel.dart` — entree
    "Connexion renforcee" dans le menu du panneau Messages, Android
    uniquement.
- **A tester** : quelques jours en push seul sur OPPO avec exemption
  batterie accordee. Si retards frequents, etape suivante envisagee : une
  banniere unique sur OPPO / Xiaomi / Vivo / Realme / Tecno proposant
  d'activer l'option.

### 2. Message marque "vu" alors que le destinataire ne l'a pas regarde

- **Symptome** : A envoie un message a B ; B est simplement dans l'app (liste
  Messages ou autre onglet) sans ouvrir la conversation, et A voit
  immediatement "vu". Effet secondaire : B ne recevait ni notification ni
  badge non lu pour ce message, et un appui sur la notification ne faisait
  rien.
- **Cause** : le panneau Messages garde jusqu'a cinq `ChatPage` integrees
  montees hors ecran (`Offstage`) pour une reouverture instantanee, et le
  shell garde le panneau monte sur les autres onglets (`IndexedStack`).
  Ces pages cachees ecoutent toujours le socket. Leur marquage automatique
  `_markConversationReadIfVisible` ne verifiait que `_route.isCurrent`
  (route du shell, toujours courante pour une page integree) et "liste en
  bas" (vrai aussi hors ecran). La meme page cachee se reenregistrait comme
  "conversation visible" dans `PushNotificationService`, ce qui coupait la
  notification de B.
- **Correctif** (client uniquement, aucun changement backend) :
  - `lib/page/chat_page.dart` — nouveau parametre optionnel
    `visibilityListenable` (null pour les routes classiques). Le marquage
    "lu" et l'enregistrement "conversation visible" sont conditionnes a la
    visibilite reelle ; au retour a l'ecran, les messages arrives entre-temps
    sont marques lus a ce moment-la ; `dispose` ne libere que
    l'enregistrement que la page possede.
  - `lib/page/navigation/main_navigation_messages_panel.dart` — un
    `ValueNotifier<bool>` par page en cache (vrai seulement pour la
    conversation active pendant que l'onglet Messages est selectionne),
    synchronise a l'ouverture, a la fermeture et au changement d'onglet.
  - `lib/component/main_navigation_shell.dart` — publie l'onglet courant via
    `mainNavigationSelectedTabNotifier` ; l'index `2` code en dur devient
    `mainNavigationMessagesTabIndex`.
- **Preserve volontairement** : cache de reouverture instantanee,
  suppression de la notification quand la conversation est vraiment a
  l'ecran, garde anti-course sur `createdAt` des accuses de lecture, routes
  ouvertes depuis une notification.
- **Point remarque, non corrige** : dans le shell,
  `openConversationFromNotification` fait un `pushReplacement` des qu'une
  conversation est visible ; si cette conversation visible est une page
  integree, c'est la route du shell qui serait remplacee. Correctif separe a
  prevoir.

### 3. Courbes d'activite visibles dans l'onglet "Statistique" du vendeur

- **Demande** : les courbes d'activite (likes, vues, ajouts produit,
  abonnes) n'etaient visibles que dans la page "Tableau de bord complet",
  ouverte en tapant sur la carte de l'onglet Statistique. Le vendeur doit
  les voir directement dans l'onglet.
- **Changement** :
  - `lib/component/seller_activity_curves_card.dart` (nouveau) — extraction
    de `dashboard_page.dart` : `SellerActivityRange` (periodes),
    `SellerActivitySnapshot.build()` (calcul des series a partir du catalogue
    et des compteurs profil), `SellerActivityRangeFilters` (chips de
    periode) et `SellerActivityCurvesCard` (les deux graphes, legende,
    info-bulle au tap). L'etat de selection vit dans la carte ; il est
    reinitialise uniquement quand la periode change, pas a chaque rebuild
    de l'hote.
  - `lib/page/dashboard_page.dart` — supprime (demande utilisateur, meme
    session) : la page "Tableau de bord complet" et son graphe a barres
    "Evolution des performances" n'existent plus. `SellerActivitySnapshot`
    ne calcule donc plus `growth` / `bars` (serie revenus).
  - `lib/page/navigation/main_navigation_account_panel.dart` — onglet
    Statistique : grille de metriques, puis filtres de periode + carte des
    courbes (style `_surfaceDecoration` du panneau). La carte "Tableau de
    bord" (valeurs de demonstration +18 %, barres fixes) qui servait de
    lien vers la page complete est retiree, ainsi que `_openFullDashboard`
    et `_accentSurfaceColor` devenus orphelins.

### 4. Nouvel onglet "Mes abonnes" dans le panneau vendeur

- **Demande** : lister les personnes abonnees a la boutique dans un onglet
  dedie, a cote de "Mes produits", "Statistique" et "Abonnement".
- **Changement** (`lib/page/navigation/main_navigation_account_panel.dart`) :
  - `_AccountPanelTab.followers` + onglet "Mes abonnes" (icone
    `people_alt_rounded`), place entre Statistique et Abonnement.
  - Chargement via `CatalogApiService.fetchSellerFollowers` (endpoint
    existant `GET /profiles/sellers/:id/followers`, deja utilise par la
    tuile "Abonnes" de la grille de metriques), au demarrage et au
    rafraichissement (en parallele de la liste des abonnements).
  - La section "Mes abonnements" est generalisee en
    `_buildPeopleListSection(...)` (titre, compteur, etat vide, liste)
    et sert aux deux onglets : meme payload (`displayName`, `avatarUrl`,
    `subtitle`, `role`, `sellerProfileId`, `userId`), meme tuile
    `_buildFollowedPersonTile`, meme navigation vers le profil.
- **Non modifie** : la tuile "Abonnes" de la grille de metriques ouvre
  toujours la page `UserListPage` plein ecran.

### 5. Bouton "Lancer un live" dans l'onglet Abonnés

- **Demande** : pouvoir demarrer un live depuis l'onglet Abonnés du panneau
  vendeur.
- **Changement** (`lib/page/navigation/main_navigation_account_panel.dart`) :
  carte `_buildLaunchLiveCard` en tete de l'onglet (icone live, texte
  "Vos abonnés sont prévenus et peuvent vous rejoindre en direct.", bouton
  "Démarrer"). Elle rebranche `_showLaunchLiveSheet` (feuille titre /
  categorie, deja presente mais sans point d'entree — l'analyseur la
  signalait comme inutilisee) qui enchaine sur `_openLivePreview` →
  `startCurrentUserLive` → `LivePreviewPage`. Aucun nouveau flux, aucun
  changement backend.
- **Note** : les onglets sont renommes "Produits" / "Statistique" /
  "Abonnés" / "Abonnement" et perdent leur marge interieure horizontale
  pour tenir a quatre ; les textes ajoutes ce jour portent les accents
  (regle demandee par l'utilisateur), les textes anciens restent tels quels.

## 2026-09-06

### 1. Carte de résultat "utilisateur" dans la recherche : nom répété 4 fois

- **Symptome** : pour un vendeur dont le nom de boutique = nom d'affichage,
  la carte affichait le meme texte en titre, sous-titre et dans deux puces,
  plus une ligne generique "Utilisateur BANAY de Madagascar.".
- **Causes** :
  - client `_SearchSuggestion.fromApi` copiait `label` dans `productName`
    pour tous les types → puce "produit" = titre (aussi vrai pour les
    cartes produit) ;
  - backend `search.service.ts` renvoyait `sellerName = displayName` pour un
    utilisateur → puce "boutique" = titre ; `subtitle = studioName` ;
    `description` = phrase generique de remplissage.
- **Changement** (decision utilisateur : pas de refonte, juste ces points) :
  - backend : helper `buildUserSearchPresentation` partage par
    l'autocompletion et la recherche. `subtitle` = province de Madagascar
    (`resolveMadagascarProvince`, repli sur le libelle de lieu),
    `sellerName` = nom de boutique seulement s'il differe du nom affiche,
    `description` = description de la boutique ou vide (plus de phrase
    generique ; le champ `about` du profil garde son repli), nouveau champ
    `isShop`. Le select de l'autocompletion inclut `description`.
  - client : `productName` seulement pour les produits ; puce produit
    supprimee (elle repetait toujours le titre) ; sous-titre et puce
    boutique masques s'ils repetent le titre ; badge "Boutique" (nouvelle cle
    `search_type_shop`, 7 langues) vs "Personne" selon `isShop`, icone
    boutique pour les vendeurs ; le titre d'un utilisateur est `label`
    (avant : `sellerName ?? label`).

### 2. Écran du live côté vendeur : refonte de l'interface

- **Demande** : reproduire, côté hôte, la lecture d'un écran de live grand
  public (identité en haut à gauche, fermeture en haut à droite,
  commentaires en bas, saisie en pied de page).
- **Changement** (`lib/page/live/live_preview_page.dart`) :
  - carte hôte en haut à gauche : avatar de la boutique avec pastille
    « LIVE » clignotante chevauchant le bas de l'avatar, nom de la
    boutique, compteur de spectateurs **réel** (`Room.remoteParticipants`)
    et titre du live ; nouveaux paramètres optionnels `sellerName` /
    `sellerAvatarUrl` (passés par le panneau vendeur, repli sur le titre +
    icône boutique sinon) ;
  - bouton fermer déplacé en haut à droite (confirmation inchangée) ;
  - rail vertical d'outils toujours visible sous l'en-tête : changer de
    caméra, micro, caméra, pause. Un outil désactivé passe en rouge
    (`liveIndicator`). Remplace le menu « engrenage » à deux taps ;
  - suppression des compteurs factices « 2.4k likes / 128 commentaires » ;
  - commentaires : nom en petit atténué, message en blanc plus lisible ;
  - libellés avec accents (« Changer de caméra », « Couper le micro »…).
- **Inchangé / à savoir** : les commentaires affichés côté hôte sont
  toujours les exemples locaux `_sampleComments` (aucun chat live n'existe
  encore côté backend ni côté spectateur) ; la page spectateur
  `live_watch_page.dart` n'est pas touchée.

### 3. Écran du live côté spectateur : refonte + composants partagés

- **Demande** : même lecture que la référence grand public pour celui qui
  regarde : vidéo plein écran, hôte en haut à gauche, Suivre + quitter en
  haut à droite, commentaires en bas, saisie + like en pied de page.
- **Changement** :
  - `lib/component/live/live_overlay_widgets.dart` (nouveau) — briques
    partagées hôte/spectateur : `LiveHostCard` (avatar + pastille LIVE
    chevauchante, nom, compteur spectateurs, titre), `LiveBadge`,
    `LiveBlinkingDot`, `LiveRoundButton` (46 px, état « coupé » rouge ou
    remplissage forcé), `LiveCommentsFeed` (ancré en bas, plus récent près
    de la saisie), `formatLiveCount`, `typedef LiveCommentEntry`.
  - `lib/page/live/live_preview_page.dart` — utilise ces briques à la place
    de ses helpers privés (introduits la veille dans ce même fichier).
  - `lib/page/live/live_watch_page.dart` — réécrit : vidéo `VideoViewFit.cover`
    plein écran + dégradés, carte hôte alimentée par la réponse `live/join`
    (nom/avatar/titre), compteur de spectateurs réel
    (`Room.remoteParticipants`), bouton **Suivre / Abonné** fonctionnel
    (`followSeller` / `unfollowSeller`, même flux que la page profil),
    bouton quitter, fil de commentaires (82 % de largeur), champ de saisie,
    bouton cœur avec retour haptique et compteur local.
  - backend `profiles.service.ts` — `getSellerLiveJoinInfo` renvoie
    `isFollowing` pour afficher le bon état du bouton sans second appel.
- **Limites connues** : commentaires et likes du spectateur sont locaux à
  son appareil (aucun canal temps réel live côté backend pour l'instant) ;
  c'est le prochain chantier si ces écrans doivent servir en production.

### 4. Qualité vidéo du live

- **Symptôme** : image du live jugée mauvaise côté spectateur.
- **Causes identifiées** :
  - la page spectateur affichait la vidéo dans un cadre réduit : le flux
    adaptatif (`adaptiveStream`) demandait donc une couche simulcast basse
    (360p ou moins) ; la refonte plein écran (entrée 3) corrige déjà ce point ;
  - côté hôte, l'encodage suivait le préréglage 720p par défaut du SDK
    (1,7 Mb/s, capture plafonnée à 24 i/s) sans préférence de dégradation,
    donc WebRTC baissait la résolution en premier sous contrainte réseau.
- **Changement** (`lib/page/live/live_preview_page.dart`) :
  `defaultVideoPublishOptions` explicite — 720p à 2,5 Mb/s / 30 i/s, échelle
  simulcast 360p + 180p, `DegradationPreference.maintainResolution` ; capture
  à 30 i/s. Résolution volontairement gardée à 720p : une échelle 1080p
  demande ~3,6 Mb/s d'envoi stable, rarement disponible en data mobile.
- **Hors code** : un live émis depuis l'émulateur utilise une caméra
  factice de basse qualité ; le débit montant de l'hôte reste le facteur
  dominant.

### 5. Live : commentaires et likes en temps réel entre spectateurs et hôte

- **Demande** : que les messages et les likes circulent réellement entre
  ceux qui regardent et celui qui diffuse (jusqu'ici, tout restait local).
- **Choix technique** : canal de données LiveKit (`publishData` /
  `DataReceivedEvent`) sur le salon déjà ouvert pour la vidéo — aucun
  nouveau gateway ni table, latence minimale, et la permission est portée
  par le jeton (`canPublishData`). Pas de persistance : un live chat n'en a
  pas besoin ; à ajouter si une modération a posteriori devient nécessaire.
- **Changement** :
  - `lib/services/live/live_room_channel.dart` (nouveau) — `LiveRoomChannel`
    : `sendComment` (fiable, 300 caractères max), `sendLike` (lossy),
    flux `comments` / `likes`, sujet `banay.live`, identité résolue depuis
    `/auth/me` pour les spectateurs (nom + avatar), fournie par l'hôte pour
    lui-même ; l'émetteur ré-affiche localement son propre message (LiveKit
    ne renvoie pas ses données à l'expéditeur).
  - `lib/component/live/live_overlay_widgets.dart` — `LiveCommentEntry`
    devient une classe sérialisable (`id`, `author`, `message`, `avatarUrl`,
    `isHost`, `userId`) ; la tuile affiche l'avatar réel et un tag
    « Vendeur » sur les messages de l'hôte ; `LiveHostCard` affiche le total
    de cœurs reçus.
  - `live_preview_page.dart` — suppression des commentaires factices
    `_sampleComments` ; canal démarré dès la connexion ; les cœurs des
    spectateurs incrémentent le compteur de l'hôte.
  - `live_watch_page.dart` — envoi des commentaires et des likes ; réception
    de ceux des autres spectateurs et des réponses de l'hôte.
  - backend `profiles.service.ts` — `buildLivekitToken` accepte
    `canPublishData` ; le jeton spectateur l'active (il valait `false`,
    calqué sur `canPublish`).
- **Limites** : liste plafonnée à 200 messages en mémoire ; compteur de likes
  local à chaque participant (chacun additionne ce qu'il reçoit), donc un
  spectateur arrivé en cours de live repart de zéro.

### 6. Live : débordement de 97 px quand le clavier est ouvert

- **Symptôme** : bande d'erreur « BOTTOM OVERFLOWED » sur l'écran hôte dès
  qu'on tape un commentaire.
- **Cause** : le fil de commentaires avait une hauteur fixe (192) dans une
  colonne qui, une fois le clavier ouvert, n'avait plus la place pour
  l'en-tête + le rail d'outils + le fil + la saisie.
- **Correctif** : dans les deux pages, le fil est placé dans un `Expanded`
  ancré en bas (il prend la place restante et se comprime sous le clavier) ;
  côté hôte, le rail d'outils est masqué pendant la saisie
  (`MediaQuery.viewInsetsOf(context).bottom > 0`).

### 7. Live : voile sombre trop présent et écran qui se met en veille

- **Symptôme** (hôte et spectateur) : « dégradé noir aux alentours de
  l'écran » sur la vidéo ; l'écran s'assombrit puis se verrouille pendant
  un live.
- **Changement** :
  - `lib/component/live/live_overlay_widgets.dart` — `LiveOverlayScrim`
    partagé : assombrissement limité aux bandes de texte (34 % en haut sur
    20 % de la hauteur, 50 % en bas sur le dernier tiers), le centre de
    l'image n'est plus voilé. Remplace le dégradé 76 % / 88 % dupliqué dans
    les deux pages.
  - `wakelock_plus ^1.5.2` ajouté (`flutter pub add`) ;
    `WakelockPlus.enable()` à l'ouverture des deux pages de live,
    `disable()` à leur fermeture. Aucune permission supplémentaire à
    déclarer côté Android.

### 8. Live en 1080p et couche haute demandée explicitement par le spectateur

- **Demande** : « je veux que la vidéo soit de la bonne résolution ».
- **Constat décisif** : en mode `adaptiveStream`, le SDK Flutter LiveKit
  envoie au serveur la taille du lecteur en pixels **logiques** (~412×915
  sur un téléphone), et le serveur sert la plus petite couche qui couvre
  cette taille. Un téléphone ne recevait donc jamais mieux que 720p, quelle
  que soit la capture de l'hôte.
- **Changement** :
  - hôte (`live_preview_page.dart`) : capture `h1080_169`, encodage 3,5 Mb/s
    / 30 i/s, échelle simulcast 540p + 216p (une couche 720p en plus
    coûterait un encodage de trop sur le téléphone de l'hôte),
    `maintainResolution` conservé ;
  - spectateur (`live_watch_page.dart`) : `adaptiveStream: false` et
    `setVideoQuality(VideoQuality.HIGH)` sur chaque piste vidéo souscrite →
    la couche 1080p est demandée ; le serveur descend seul en 540p/216p si
    le lien du spectateur ne suit pas.
- **Coût** : ~4 Mb/s d'envoi stable requis côté hôte ; en dessous, WebRTC
  baisse la fluidité avant la résolution.

### 9. Stories 24 h (photo) pour les boutiques, avec notification des abonnés

- **Demande** : un système de story « style TikTok » : une boutique publie
  une photo visible 24 h ; les abonnés sont notifiés ; un appui sur une story
  ouvre un lecteur plein écran qui enchaîne automatiquement les stories
  (barre de durée) puis passe à la boutique suivante jusqu'à la dernière
  boutique suivie ayant une story ; une carte « Créer une story » façon
  Facebook pour publier.
- **Décisions** :
  - photo uniquement (pas de vidéo : aucune dépendance lecteur vidéo dans
    l'app, et l'upload vidéo Cloudinary est un chantier à part) ;
  - seules les boutiques (profil vendeur) publient : ce sont elles qui ont
    des abonnés (`SellerFollow`), un client n'aurait aucune audience ;
  - 8 s par story (5 s jugées trop rapides à l'usage le 2026-09-07), plus
    environ 1 s par 30 caractères de légende, plafonné à 12 s ; 30 stories
    actives max par boutique ; image limitée à 1080×1920 sans recadrage
    (dossier Cloudinary `BANAY/stories`) ;
  - une story est « vue » dès son affichage dans le lecteur ; l'anneau de
    la boutique reste coloré tant qu'il reste une story non vue.
- **Backend** :
  - `prisma/schema.prisma` + migration `20260906_add_seller_stories` :
    tables `SellerStory` (`expiresAt`, `imagePublicId`, `caption`) et
    `SellerStoryView` (unique par story × spectateur). Lancer
    `npx prisma migrate deploy` (ou `prisma db push`) puis redémarrer le
    serveur (le `prisma generate` a régénéré les types, le moteur était
    verrouillé par le serveur de dev).
  - nouveau module `src/modules/stories` : `GET /stories/feed` (groupes par
    boutique : la sienne d'abord, puis non vues, puis vues), `POST /stories`
    (multipart `image` + `caption`), `POST /stories/:id/view`,
    `GET /stories/:id/viewers` (propriétaire), `DELETE /stories/:id`
    (propriétaire). Cron horaire `purgeExpiredSellerStories` : purge des
    lignes expirées depuis plus d'un jour + suppression de l'asset.
  - `cloudinary.service.ts` — variante `story` (`uploadStoryImage`).
  - `push-notifications.service.ts` — `sendStoryPublishedNotification`
    (type `story_published`, `tag`/`thread-id` `story-<sellerProfileId>` :
    plusieurs stories d'affilée remplacent la tuile au lieu de s'empiler).
    L'échec du push est journalisé, il ne fait pas échouer la publication.
  - `conversations-realtime.gateway.ts` — événement `stories:updated`
    (`created` / `deleted`) émis au vendeur et à ses abonnés.
  - `notifications.service.ts` — entrée `story_published` dans la liste des
    notifications (une par boutique, portée par sa story la plus récente,
    limitée aux stories encore actives).
- **Client** :
  - `lib/services/stories_api_service.dart` (nouveau) — modèles
    `StoryItem` / `StoryGroup` + appels API.
  - `lib/component/ui/following_stories_row.dart` (nouveau, révision du
    2026-09-07 : la première version en cartes 104×160 « trop Facebook »
    a été retirée) — une seule rangée façon TikTok qui fusionne stories et
    abonnements : cercles d'avatar, anneau dégradé (primaire → secondaire)
    quand une story n'est pas vue, anneau gris une fois vue, pastille rouge
    « LIVE » sous l'avatar en direct, cercle personnel avec bouton « + » en
    tête pour les boutiques (appui sur l'avatar : lit sa propre story si
    elle existe, sinon crée). Ordre : soi, lives, stories non vues, stories
    vues, autres abonnements. Un appui ouvre le live, sinon la story, sinon
    le profil. `DinamicFollowedPeopleHList` n'est plus utilisée sur
    l'accueil (ses helpers restent partagés avec les panneaux compte et
    profil) ; son état vide `FollowedPeopleEmptyState` devient public et
    est réutilisé.
  - `lib/page/story/story_viewer_page.dart` (nouveau) — lecteur plein
    écran : `PageView` par boutique, barres segmentées, timer par story
    démarré une fois l'image chargée (borne 8 s), appui gauche/droite, appui long
    pour figer, glisser vers le bas pour fermer, pause automatique en
    arrière-plan. Propriétaire : compteur de vues (liste en feuille) et
    suppression.
  - `lib/page/story/story_create_page.dart` (nouveau) — composeur :
    galerie ou appareil photo, aperçu plein écran, légende (300 car.),
    « Publier la story ».
  - `main_home_panel.dart` — rangée stories au-dessus des abonnements,
    rechargée sur `stories:updated` ; `notifications_page.dart` — un appui
    sur « Nouvelle story » ouvre directement le lecteur sur la boutique ;
    `chat_realtime_service.dart` — abonnement à `stories:updated`.
  - localisation : 24 nouvelles clés `home_story*` dans les 7 langues.
- **Correctif du 2026-09-07** : « Only images are supported for stories »
  à la publication. `MultipartFile.fromPath` sans `contentType` envoie la
  partie en `application/octet-stream` (les autres uploads du projet ne
  vérifient pas le MIME, d'où l'absence du symptôme ailleurs). Le client
  envoie désormais le vrai type (`http_parser`), et le backend accepte
  aussi un fichier reconnu par son extension quand le MIME est absent ou
  générique.
- **Extension du 2026-09-07 : stories pour tous les comptes, photo ou vidéo**
  - **Demande** : « tout le monde capable de créer des story (photo ou
    vidéo) ; si vidéo, utiliser notre barre de progression pour l'upload ».
  - **Audience d'une story** (nouvelle règle, un client n'ayant pas
    d'abonnés) : ses contacts = boutiques qu'il suit, ses abonnés s'il est
    une boutique, et toute personne avec qui il a une conversation ; les
    comptes bloqués dans un sens ou l'autre sont exclus. Le push reste
    réservé aux abonnés d'une boutique (un client ne déclenche pas de push).
  - **Vidéo** : 60 s max (limite de la caméra via `maxDuration`, vérifiée
    sur l'aperçu pour la galerie, puis côté serveur avec la durée renvoyée
    par Cloudinary), 60 Mo max (multer). Le fichier est stocké tel quel,
    sans transcodage serveur (un transcodage synchrone dépasserait les
    délais du reverse proxy) ; Cloudinary fournit l'image de couverture
    (première image en JPEG) et la durée.
  - **Backend** : migration `20260907_user_stories_video` (renomme
    `SellerStory`/`SellerStoryView` en `UserStory`/`UserStoryView`, auteur
    = `userId` rempli depuis le profil vendeur, colonnes `mediaType`,
    `mediaUrl`, `mediaPublicId`, `thumbnailUrl`, `durationSeconds`) ;
    `stories.service.ts` réécrit (feed par contacts, `resolveMediaType`,
    audience temps réel élargie) ; `POST /stories` accepte la partie
    `media` (ou `image`) + `mediaType` + `durationSeconds` ;
    `cloudinary.service.ts` — `uploadStoryVideo`, suppression d'assets
    `video` ; `notifications.service.ts` — dérivation adaptée à `UserStory`.
    À lancer : `npx prisma migrate deploy` (ou `prisma db push`, qui
    recrée la table en dev) puis redémarrer le serveur.
  - **Client** : `video_player ^2.11.1` ajouté ;
    `lib/component/upload_water_fill_progress.dart` (nouveau) — la barre
    « liquide » du chat (`WaterFillProgressLayer`, `WaterFillVisualState`)
    extraite de `chat_page.dart`, qui l'importe désormais au lieu de la
    définir ; page de création : quatre choix (photo galerie / appareil,
    vidéo galerie / caméra), aperçu vidéo en boucle, badge de durée,
    envoi avec le remplissage liquide et le pourcentage (progression
    réelle des octets envoyés, comme les produits) ; lecteur : la vidéo
    pilote la barre de progression et passe à la suivante à sa fin, image
    de couverture pendant le chargement, pause/reprise vidéo sur appui
    long, arrière-plan et glissement ; rangée : cercle personnel pour tout
    le monde, correspondance par identifiant utilisateur, cercles pour les
    contacts non boutiques ayant une story.
  - localisation : 5 nouvelles clés (`home_story_pick_video_*`,
    `home_story_video_too_long`, `home_story_video_preview_failed`,
    `home_story_uploading`) et sous-titre de création mis à jour, 7 langues.
- **Non couvert (suite possible)** : transcodage vidéo côté serveur
  (poids des vidéos), réponse à une story par message, entrée « story »
  sur la page profil.

## 2026-09-07

### 1. Stories vidéo : lecture trop lourde, puis « Finalisation en cours » à 100 %

- **Symptôme** : « ça charge trop lors de la lecture » d'une story vidéo ;
  et pendant la publication, le pourcentage restait figé à 100 % le temps
  que le serveur transfère le fichier vers Cloudinary.
- **Cause** : la vidéo était servie telle qu'enregistrée par le téléphone
  (1080p-4K, débit élevé, souvent 30-60 Mo pour 60 s). De plus, les MP4 de
  caméra placent l'atome `moov` en fin de fichier : le lecteur doit alors
  télécharger tout le fichier avant la première image. Le transcodage
  serveur avait été laissé de côté (voir « Non couvert » de l'entrée 9 du
  2026-09-06) car un transcodage synchrone dépasse les délais du reverse
  proxy.
- **Changement backend** :
  - `cloudinary.service.ts` — `uploadStoryVideo` demande deux
    transformations `eager` générées **en arrière-plan** (`eager_async`,
    la requête d'upload ne s'allonge pas) : rendu de lecture 720p H.264/AAC
    MP4 (`storyVideoTransformation`, `q_auto:good`, faststart) et l'image
    de couverture JPEG. Nouveau `buildStoryVideoPlaybackUrl` : reconstruit
    l'URL du rendu avec le **même objet de transformation** (chaîne
    identique `ac_aac,c_limit,h_1280,q_auto:good,vc_h264,w_720/mp4`, donc
    même asset dérivé).
  - `stories.service.ts` — la ligne garde l'URL d'origine ; `presentStory`
    renvoie dans `mediaUrl` l'URL du rendu optimisé (dérivée du
    `mediaPublicId`, ou de l'URL pour les anciennes lignes : les stories
    déjà publiées en profitent aussi, Cloudinary génère le rendu à la
    première demande) et l'original dans le nouveau champ
    `originalMediaUrl` (vidéo seulement). Aucune migration ; redémarrer le
    serveur.
- **Changement client** :
  - `stories_api_service.dart` — `StoryItem.originalMediaUrl` +
    `fallbackMediaUrl`.
  - `story_viewer_page.dart` — ouverture vidéo réécrite (`_openVideo`) :
    rendu optimisé d'abord, **3 essais espacés de 2,5 s** (Cloudinary
    refuse l'URL tant que le rendu d'une vidéo toute fraîche n'est pas
    prêt), puis repli sur l'original ; un dépassement de délai (lien lent)
    n'est pas réessayé. **Pré-chargement de la story suivante** : son
    lecteur est initialisé pendant la lecture en cours et adopté au
    passage (`_preloadedController`, un seul en avance, jeté dès que la
    suivante change) ; le poster est toujours préchauffé. Le lecteur en
    cours d'initialisation est suivi (`_pendingController`) pour être
    libéré immédiatement à un changement de story, comme avant.
  - `story_create_page.dart` — à 100 % d'octets envoyés, le remplissage
    liquide et le pourcentage disparaissent au profit d'un simple spinner
    et du texte « Finalisation en cours… » (nouvelle clé
    `home_story_finalizing`, 7 langues).
- **À savoir** : le rendu utilise le quota de transformations vidéo
  Cloudinary (une fois par story, puis mis en cache CDN). Si ce quota est
  épuisé, l'URL optimisée échoue et le lecteur retombe sur l'original.

### 2. Stories : « Finalisation en cours » très longue → upload direct vers Cloudinary

- **Symptôme** : après l'entrée 1, la barre atteignait 100 % vite mais la
  « finalisation » durait parfois plusieurs minutes pour une vidéo.
- **Cause** : le média transitait par le serveur BANAY, qui le renvoyait
  ensuite **intégralement** à Cloudinary une fois la requête reçue (multer
  en mémoire, aucun chevauchement). Deux transferts complets, le second
  limité par le débit montant de la machine qui héberge le backend. En
  dev (backend sur le PC), le trajet téléphone → PC passe par le Wi-Fi
  local et va vite ; le trajet PC → Cloudinary passe par la connexion
  internet, d'où l'asymétrie observée. S'y ajoutaient l'analyse du
  fichier par Cloudinary et l'attente des push avant la réponse.
- **Changement** : le média part **directement du téléphone vers
  Cloudinary**, sur le modèle déjà en place pour les photos et documents
  du chat (`createDirectChatImageUploadSignature`). Un seul transfert ;
  100 % signifie que Cloudinary a tout reçu ; la « finalisation » se
  réduit à un appel de confirmation.
  - backend `cloudinary.service.ts` — `createDirectStoryUploadSignature`
    (paramètres signés renvoyés tels quels dans `fields` ; pour une vidéo,
    `eager` + `eager_async` inclus dans la signature, chaîne construite
    via `generate_transformation_string` à l'identique du `build_eager`
    du SDK), `verifyUploadResponseSignature` (signature SHA-1
    `public_id` + `version` + secret renvoyée par Cloudinary : prouve que
    l'asset a bien été envoyé sur ce compte), `describeAsset` (Admin API :
    poids, durée, format), `buildStoryImageUrl` / `buildStoryVideoUrls`,
    `isDirectStoryPublicIdOf` (l'identifiant doit avoir été émis pour cet
    utilisateur : préfixe `BANAY/stories/<userId>-story-<type>-`).
  - backend `stories.service.ts` — `createDirectUploadSignature` (compte
    et quota vérifiés avant l'upload) et `createStoryFromDirectUpload`
    (préfixe + signature, identifiant pas déjà publié, quota, poids
    ≤ 60 Mo et durée ≤ 60 s relus depuis Cloudinary, asset supprimé si
    refusé) ; `createStory` (multipart) conservé pour les anciens builds,
    tronc commun extrait dans `finalizeStory` / `loadAuthorOrThrow` /
    `assertStoryQuota`. `STORY_UPLOAD_MAX_BYTES` déplacé du contrôleur au
    service. Nouvelles routes `POST /stories/direct-signature` et
    `POST /stories/direct` (DTO `create-direct-story.dto.ts`).
  - client `stories_api_service.dart` — `publishStory` : signature →
    upload multipart vers `api.cloudinary.com` (champs signés transmis
    verbatim, progression réelle) → confirmation. Repli automatique sur
    `createStory` si le backend n'a pas encore la route (404/501, cas d'un
    serveur non redémarré) ou si Cloudinary est injoignable depuis le
    téléphone. Flux de fichier suivi factorisé (`_trackedMultipartFile`).
  - client `story_create_page.dart` — vidéo > 60 Mo refusée au choix du
    fichier (nouvelle clé `home_story_video_too_large`, 7 langues), la
    limite multer ne s'appliquant plus.
- **À savoir** : `describeAsset` consomme un appel Admin API par
  publication (quota horaire large) ; en cas d'échec de cet appel, les
  valeurs du client (durée, format) servent de repli, la signature
  restant obligatoire. Redémarrer le serveur.

### 3. Stories : l'écran ne doit jamais se mettre en veille

- **Demande** : pendant l'envoi d'une story (et sa lecture), l'écran ne
  doit pas s'éteindre. Un écran verrouillé met l'app en pause et peut
  freiner le transfert vers Cloudinary ; en lecture, les stories
  s'enchaînent sans aucun appui, donc la temporisation système finit par
  couper l'écran.
- **Changement** : même mécanisme que les pages de live (`wakelock_plus`).
  - `story_create_page.dart` — `WakelockPlus.enable()` au début de
    `_publish`, `disable()` en cas d'échec (`_endPublishing`) et dans
    `dispose` (un envoi réussi ferme la page avec le verrou actif).
  - `story_viewer_page.dart` — `enable()` à l'ouverture, `disable()` à la
    fermeture.

### 4. Session : déconnexions intempestives (retour à l'écran de connexion)

- **Symptôme** : des utilisateurs se retrouvent « parfois » sur l'écran de
  connexion, alors que l'app doit rester connectée comme WhatsApp ou
  TikTok, avec ou sans internet.
- **Causes** (client uniquement, le backend n'est pas en cause) :
  1. `AppAuthService.restoreSession` exigeait un `POST /auth/refresh`
     réussi **à chaque lancement** et effaçait la session sur n'importe
     quel échec : hors ligne, délai dépassé (20 s sur data lente), serveur
     en redémarrage, 502 du proxy. Lancer l'app sans réseau suffisait.
  2. Rafraîchissements concurrents : 11 instances d'`AppApiClient`, chacune
     avec son propre verrou `_refreshSessionFuture`. Le jeton d'accès
     expire après 15 min ; au retour dans l'app, plusieurs écrans reçoivent
     un 401 en même temps et lancent chacun `/auth/refresh` avec le
     **même** jeton de rafraîchissement. Le backend fait tourner ce jeton
     (l'ancien est supprimé à la première utilisation) : le premier appel
     gagne, les suivants reçoivent « Refresh token not found » et
     `_invalidateSession` effaçait tout, **y compris les nouveaux jetons**
     que le gagnant venait de sauver. Même course possible avec l'isolat de
     push en arrière-plan (`pingDelivery` est un appel authentifié).
  3. `_performRefreshSession` effaçait aussi la session sur un 5xx ou une
     réponse illisible, alors que seul un 401/403 du refresh est définitif.
- **Correctif** :
  - `app_api_client.dart` — verrou de rafraîchissement **statique** (un
    seul refresh à la fois pour tout l'isolat) ; avant de rafraîchir après
    un 401, relecture du jeton d'accès en stockage : s'il a déjà changé
    (autre instance ou autre isolat), on réessaie sans rafraîchir ; sur un
    401/403 du refresh, relecture du jeton de rafraîchissement (deux fois,
    1,5 s d'écart) : s'il a été tourné entre-temps, la session est gardée.
    Seul un rejet définitif d'un jeton que personne n'a tourné efface la
    session ; hors ligne, timeout, 5xx et réponse illisible sont
    transitoires (la requête échoue, l'utilisateur reste connecté).
    Nouveau `refreshAccessTokenIfExpired` (lit `exp` du JWT localement,
    rafraîchit si expiré ou à moins de 60 s) et `sessionInvalidated`
    (`ValueNotifier` statique, émis uniquement sur rejet définitif).
  - `app_auth_service.dart` — `restoreSession` devient hors-ligne d'abord :
    une session locale valide ouvre l'app immédiatement ; le jeton d'accès
    est renouvelé en arrière-plan s'il a expiré ; plus aucun refresh
    bloquant ni effacement au lancement.
  - `main_navigation_shell.dart` — écoute `sessionInvalidated` et renvoie
    à `PhoneNumberPage` (même chemin que la déconnexion volontaire) :
    auparavant une session réellement révoquée laissait l'app en erreur
    jusqu'au prochain lancement.
  - `chat_realtime_service.dart` — sur `connect_error`, demande un
    `refreshAccessTokenIfExpired` (sans appel HTTP en cours, rien ne
    renouvelait le jeton refusé au handshake et la reconnexion bouclait).
- **Reste vrai** : l'utilisateur doit se reconnecter si le jeton de
  rafraîchissement expire (30 jours sans ouvrir l'app,
  `JWT_REFRESH_EXPIRES_IN`), après une déconnexion depuis les menus ou une
  suppression de compte.
- **Durcissement possible côté backend (non fait)** : fenêtre de grâce sur
  la rotation (accepter un jeton tout juste utilisé pendant ~60 s, colonne
  `usedAt` à ajouter) pour couvrir l'app tuée par l'OS entre la réponse du
  refresh et sa sauvegarde locale.

### 5. Publication Play Store 1.4.0+10

- `pubspec.yaml` : `1.3.0+9` → `1.4.0+10` (bump mineur : nouveautés stories
  vidéo, upload direct, session hors ligne ; `versionCode` 10).
- `docs/play-store-release.md` : valeur de version mise à jour.
- Bundle généré avec `flutter clean` / `flutter pub get` /
  `flutter build appbundle --release`, signé avec le keystore d'upload de
  `android/key.properties` (`keystores/upload-keystore.jks`). Sortie :
  `build/app/outputs/bundle/release/app-release.aab`.
- Préflight : `flutter analyze` ne remonte que des lints de style
  pré-existants et une erreur dans `test/widget_test.dart` (gabarit par
  défaut jamais adapté à `appLanguageProvider`, hors du bundle).
- **Backend à déployer avant diffusion** : routes `POST /stories/direct-signature`
  et `POST /stories/direct` (l'app retombe sur l'ancien chemin si elles
  manquent, mais la « finalisation » redevient longue).

## 2026-09-10

### 1. Live : profil « TikTok » (720p H.264, qualité automatique, économie de données)

- **Demande** : aligner le live sur TikTok Live pour la résolution hôte, le
  codec, la qualité spectateur adaptative, un mode économie de données et
  une consommation HD de l'ordre de 0,4 à 0,8 Go/h (contre ~1,6 Go/h en
  1080p, entrée 8 du 2026-09-06).
- **Changement hôte** (`lib/page/live/live_preview_page.dart`) :
  - capture `h720_169` à 30 i/s (au lieu de 1080p) ;
  - codec `h264` explicite (le SDK publiait en VP8 par défaut) : encodage
    matériel sur tous les téléphones, donc trois couches simulcast sans
    surchauffe ; le SDK retombe seul sur un codec activé côté serveur si
    H.264 manque ;
  - 1,5 Mb/s max (au lieu de 3,5), échelle simulcast 360p (450 kb/s) +
    180p (160 kb/s) ; `maintainResolution` conservé. Débit montant requis :
    ~2 Mb/s au lieu de ~4,5.
- **Changement spectateur** (`lib/page/live/live_watch_page.dart`,
  `lib/services/live/live_view_quality.dart` nouveau) :
  - `LiveViewQuality` : `auto` (Wi-Fi → couche HIGH 720p, données mobiles
    seules → MEDIUM 360p), `hd` (HIGH), `dataSaver` (LOW 180p) ; choix
    persistant (`shared_preferences`, clé `banay_live_view_quality`) ;
  - détection réseau via `connectivity_plus` (déjà dans l'app), réévaluée
    en cours de live : un passage Wi-Fi → 4G rebascule en 360p en mode auto ;
  - nouveau bouton rond « Qualité de la vidéo » en haut à droite (icône
    économie quand la couche servie est réduite) → feuille Automatique / HD /
    Économie de données avec la consommation estimée par heure ;
  - `adaptiveStream` reste désactivé : c'est la préférence + le réseau qui
    fixent la couche demandée, le SFU descend toujours seul sous congestion.
- **Test** : `test/services/live/live_view_quality_test.dart` (résolution
  des couches, persistance du nom, détection « mobile seul »).
- **Coût data estimé** : HD 720p ≈ 0,7 Go/h ; SD 360p ≈ 0,2 Go/h ; Éco 180p
  < 0,1 Go/h (audio 48 kb/s compris ≈ 0,02 Go/h).
- **Non aligné, volontairement** :
  - *encodage des variantes côté serveur* : LiveKit Cloud est un SFU sans
    transcodage ; l'équivalent WebRTC est le simulcast, désormais bon marché
    grâce au H.264 matériel. Une vraie chaîne « serveur » (LiveKit Egress →
    HLS multi-rendus + lecteur vidéo dans l'app) est un chantier séparé ;
  - *latence 3 à 10 s* : le WebRTC actuel reste sous la seconde, ce qui est
    un avantage pour un live de vente ; l'augmenter n'est pas un réglage
    disponible et n'apporterait rien sans la chaîne HLS ci-dessus.

### 2. Live : priorité à la fluidité (dégradation équilibrée, 360p à 30 i/s)

- **Question** : « est-ce que ça rend le live fluide ? » → oui pour l'hôte
  (encodeur matériel, lien montant divisé par deux) et pour le spectateur en
  4G (démarrage en 360p), mais deux réglages tiraient encore vers la
  saccade.
- **Changement** (`lib/page/live/live_preview_page.dart`) :
  - `DegradationPreference.maintainResolution` → `balanced` : sous
    congestion, WebRTC baisse un peu la résolution et un peu la cadence au
    lieu de sacrifier uniquement la cadence (image nette mais hachée) ;
  - couche simulcast 360p redéfinie en `VideoParameters` explicite à
    30 i/s / 500 kb/s (préréglage SDK : 20 i/s / 450 kb/s), pour que le
    spectateur en données mobiles ait la même fluidité qu'en Wi-Fi ;
    ~10 % de données en plus sur cette couche (~0,25 Go/h).
- La couche 180p (mode Économie) reste à 15 i/s : elle vise les liens trop
  faibles pour mieux.

### 3. Live spectateur : boutons « Abonné » et « Qualité » retirés, saisie vidée à chaque envoi

- **Symptôme** : sur un téléphone étroit, la rangée du haut débordait de
  24 px à droite (carte hôte + Abonné + Qualité + Quitter). Après un envoi
  par l'icône « envoyer », le texte restait dans le champ.
- **Changement UI** (`lib/page/live/live_watch_page.dart`) : suppression des
  boutons Suivre / Abonné et Qualité, de la feuille de choix et du suivi
  vendeur depuis le live. La qualité reste automatique et invisible :
  Wi-Fi → 720p, données mobiles seules → 360p, réévaluée en cours de live.
  `lib/services/live/live_view_quality.dart` réduit à
  `resolveLiveViewQuality` + `isCellularOnly` ; la préférence persistante
  (`banay_live_view_quality`) est retirée, test ajusté.
- **Cause du champ non vidé** : `DynamicIconInput` ne vide le champ
  (`autoClearOnSubmit`) que sur le chemin `onSubmitted` (touche Envoyer du
  clavier), et seulement après la fin de l'envoi ; l'icône « envoyer »
  appelle `_submitComment` directement, sans vider.
- **Correctif** : `_submitComment` vide le contrôleur dès la validation du
  texte, avant l'aller-retour réseau, sur les deux pages (spectateur et
  hôte `live_preview_page.dart`, qui avait le même défaut).

### 4. Abonnés notifiés d'un live ou d'une story, avec ouverture directe

- **Demande** : les abonnés d'un vendeur reçoivent une notification quand il
  lance un live ou publie une story ; l'appui ouvre directement le live ou
  la story.
- **État avant** : la story avait déjà un push (`story_published`) et une
  entrée dans la liste, mais l'appui sur le push ouvrait la liste des
  notifications, pas la story. Le live n'avait ni push ni entrée : seuls
  l'événement temps réel `live:updated` et la pastille LIVE de l'accueil.
- **Backend** :
  - `push-notifications.service.ts` — nouveau
    `sendLiveStartedNotification` (`type: live_started`, tag
    `live-<sellerProfileId>` : un redémarrage remplace la tuile). Le
    fan-out aux abonnés (liens de suivi → jetons → envoi → purge des jetons
    invalides) est extrait dans `sendToShopFollowers`, partagé avec la story
    (comportement inchangé, message de log légèrement reformulé) ;
  - `profiles.service.ts` `startCurrentUserLive` — envoi du push après
    l'événement temps réel, **non attendu** (l'hôte ne doit pas patienter
    sur FCM, un échec est loggé et ne casse pas le démarrage). Garde
    anti-doublon : pas de push si la session précédente est encore ouverte
    et a démarré il y a moins de 10 min (reconnexion / relance de l'app) ;
  - `notifications.service.ts` — entrée `live_started` (« En direct »,
    « <boutique> est en direct : <titre> ») pour chaque boutique suivie en
    live, bornée à 12 h (une session jamais fermée ne doit pas rester
    « en direct » des jours) ; id `notif-live-<session>-<startedAt>` pour
    que le prochain live revienne non lu.
- **App** :
  - `lib/services/notification_navigation.dart` (nouveau) —
    `openLiveFromNotification` (ouvre `LiveWatchPage`) et
    `openStoryFromNotification` (recharge le fil, ouvre `StoryViewerPage`
    sur la boutique, `false` si la story a expiré) ; partagés par le push
    et la liste in-app pour atterrir au même endroit ;
  - `push_notification_service.dart` — à l'appui d'un push `live_started`
    ou `story_published`, ouverture directe via ces helpers ; les autres
    types (ou une story expirée) retombent sur la liste comme avant. Les
    notifications affichées en premier plan réutilisent un id par boutique
    pour les stories / lives (miroir du `tag` backend) ;
  - `notifications_page.dart` — cas `live_started` (visuel « En direct »,
    appui → live) ; `_openStoryNotification` délègue au helper (duplication
    supprimée, imports story retirés).
- **Comportement si le live est déjà fini** : `LiveWatchPage` affiche
  « Impossible de rejoindre le live » (le backend répond
  `Live session not found`).
- **À déployer** : backend (aucune migration).

### 5. Live : « tapoter pour aimer » façon TikTok, cœurs flottants

- **Demande** : le système de tapotement de TikTok dans l'interface du live,
  avec une interface soignée.
- **Composant** (`lib/component/live/live_tap_hearts.dart`, nouveau) :
  `LiveTapHeartsLayer` + `LiveTapHeartsController`. Couche plein écran
  placée au-dessus du voile et sous les contrôles. Tous les cœurs sont
  dessinés dans un seul `CustomPaint` piloté par un `Ticker` (arrêté quand
  il n'y a plus de cœur) : des dizaines de cœurs simultanés coûtent un seul
  repaint par image. Chaque cœur : apparition avec léger rebond, montée
  avec balancement et inclinaison, rétrécissement et fondu en fin de vie ;
  rendu « verre » (ombre douce, dégradé deux tons, reflet). Palette :
  rouge live, couleur primaire du thème, rose, orange, violet, jaune.
  - `burstAt(position)` : un grand cœur + deux satellites et un anneau qui
    s'élargit sous le doigt (tap) ;
  - `celebrate(count)` : vague de cœurs (max 6, décalés de 110 ms) qui
    montent depuis le coin du bouton J'aime, pour les likes reçus du salon.
- **Spectateur** (`live_watch_page.dart`) : un tap n'importe où sur la vidéo
  (hors boutons et fil de commentaires) compte un like, vibre légèrement et
  fait éclore un cœur à l'endroit du tap. Le bouton J'aime fait la même
  chose avec un cœur qui part du coin. Les likes sont comptés localement
  tout de suite et **envoyés par lots** toutes les 350 ms
  (`sendLike(count:)`) au lieu d'un paquet par tap ; le reliquat est envoyé
  à la fermeture. Les likes des autres spectateurs déclenchent la vague de
  cœurs. Désactivé tant que le flux n'est pas affiché.
- **Hôte** (`live_preview_page.dart`) : même couche, transparente aux
  touches (l'hôte ne s'auto-like pas) ; les likes reçus font monter les
  cœurs pour qu'il voie l'engouement.
- **Inchangé** : `LiveRoomChannel` (le champ `count` existait, borné à 50 à
  la réception).

### 6. Appel vocal entre deux utilisateurs depuis la discussion (façon WhatsApp)

- **Demande** : un appel vocal entre les deux participants d'une
  discussion, lancé depuis la ChatPage.
- **Architecture (rien de nouveau côté infra)** :
  - *audio* : une salle LiveKit audio seule par appel (`call-<id>`), Opus
    24 kb/s avec DTX (≈ 11 Mo/h), jeton limité au micro ;
  - *signalisation* : la passerelle temps réel existante, nouvel événement
    `calls:updated` (`call:incoming`, `call:accepted`, `call:ended`) ;
  - *réveil du destinataire* : push FCM `incoming_call` (data-only sur
    Android : l'app dessine elle-même une notification plein écran,
    catégorie « appel », sonnerie, et la retire sur `call_cancelled` ;
    alerte classique sur iOS) ;
  - *historique* : une ligne « 📞 Appel vocal · 2 min 05 », « 📞 Appel vocal
    manqué » ou « 📞 Appel vocal refusé » dans la discussion (message TEXT
    envoyé par l'appelant, push uniquement pour l'appel manqué).
- **Backend** :
  - `prisma/schema.prisma` + migration `20260910_add_voice_calls` : enum
    `VoiceCallStatus` (RINGING, ACCEPTED, DECLINED, MISSED, CANCELLED,
    ENDED) et modèle `VoiceCall` (conversation, appelant, appelé, salle,
    horodatages) ;
  - `modules/livekit/` (nouveau) : `LivekitService` (URL + jeton) extrait de
    `ProfilesService`, qui y délègue désormais ;
  - `modules/calls/` (nouveau) : `POST /calls` (sonne l'autre participant,
    409 si l'un des deux est déjà en appel), `POST /calls/:id/accept`,
    `/decline`, `/end`, `GET /calls/:id`. Sonnerie bornée à 45 s côté
    serveur (→ MISSED) ; lignes RINGING/ACCEPTED orphelines expirées
    paresseusement (redémarrage serveur, app tuée) pour ne jamais bloquer
    un utilisateur en « déjà en appel » ;
  - `conversations-realtime.gateway.ts` : `emitCallEvent` ;
  - `push-notifications.service.ts` : `sendIncomingCallNotification`,
    `sendCallCancelledNotification`, helper `sendToUser` ;
  - `conversations.service.ts` : `assertUsersCanInteract` rendu public
    (blocage respecté pour les appels) ; `sendMessage` accepte
    `{ skipPush }` pour les lignes système.
- **App** :
  - `services/calls_api_service.dart`, `services/voice_call_service.dart`
    (nouveaux) : session unique (`ValueNotifier`), écoute du socket,
    connexion LiveKit, micro / haut-parleur, minuterie de sonnerie 45 s,
    vibration périodique côté appelé, dédoublonnage socket + push,
    raccrochage automatique si l'autre disparaît de la salle ;
  - `page/call/voice_call_page.dart` (nouveau) : écran plein écran (avatar
    avec anneaux pulsés, nom, état ou durée, boutons Micro / Raccrocher /
    Haut-parleur, ou Refuser / Accepter) ; retour bloqué pendant l'appel ;
  - `chat_page.dart` : icône téléphone dans l'en-tête (masquée sans
    conversation serveur ou si bloqué) → `VoiceCallService.startCall` ;
  - `push_notification_service.dart` : canal Android « Appels Banay »
    (importance max, usage sonnerie), notification plein écran depuis
    l'isolat d'arrière-plan, routage `incoming_call` / `call_cancelled`,
    ouverture de l'appel depuis la notification ;
  - `chat_realtime_service.dart` : abonnement `calls:updated` ;
  - `session_gate.dart` : `VoiceCallService.instance.bind()` après la
    connexion du socket ;
  - Android : permissions `USE_FULL_SCREEN_INTENT`, `VIBRATE`, activité
    `showWhenLocked` / `turnScreenOn` ; iOS : mode arrière-plan `audio`,
    texte micro mis à jour.
- **Limites connues (v1)** :
  - pas de sonnerie audio in-app (aucune lib audio dans le projet) : en
    premier plan l'appelé vibre et voit l'écran ; en arrière-plan / app
    tuée, la notification sonne avec le son des messages ;
  - pas de CallKit / ConnectionService : sur iOS app tuée, l'appel arrive
    en notification classique ; sur Android 14+, passer l'app en
    arrière-plan pendant un appel peut couper le micro (service
    d'avant-plan de type `microphone` non déclaré) ;
  - un seul appel à la fois par utilisateur ; pas de vidéo.
- **À déployer** : migration Prisma (`prisma migrate deploy`) puis backend.

### 7. Appels vocaux : auto-hébergement (LiveKit + coturn), écran d'appel natif, qualité réseau

- **Demande** : cahier des charges « coût zéro » (aucun service payant,
  LiveKit auto-hébergé + coturn sur le VPS, tokens backend, signalisation
  Socket.IO, FCM gratuit), écran natif CallKit / ConnectionService,
  reconnexion, optimisation data pour Madagascar, documentation.
- **Infra** (`infra/livekit/`, nouveau) : `docker-compose.yml`
  (livekit-server Apache-2.0 + coturn BSD-3, `network_mode: host`),
  `livekit.yaml` (signalisation sur 127.0.0.1:7880 derrière Nginx, média
  7881/tcp + 50000-50200/udp, `turn_servers` udp 3478 + tls 5349),
  `turnserver.conf` (long-term credentials, TLS Let's Encrypt, réseaux
  internes refusés, relais 49160-49400/udp), `nginx-livekit.conf`
  (wss + timeouts 1 h), `README.md` (UFW, certificats, déploiement).
- **Backend** : jeton d'appel ramené à 15 min (le temps de rejoindre) ;
  `.env.example` documente `LIVEKIT_*`. Rien d'autre : les modules
  `calls` / `livekit` de l'entrée 6 sont déjà indépendants du fournisseur
  (LiveKit Cloud → VPS = changer `LIVEKIT_URL` et les clés).
- **App** :
  - `flutter_callkit_incoming` 3.1.5 (MIT) ajouté ; wrapper
    `lib/services/incoming_call_native_ui.dart` (afficher / retirer /
    marquer connecté / appels actifs). Remplace la notification locale
    plein écran de l'entrée 6 (méthodes et canal `banay_calls`
    supprimés) ;
  - `voice_call_service.dart` : appel entrant en arrière-plan → écran
    natif (sonnerie système, écran verrouillé) ; écoute des événements
    natifs (accepter, refuser, fin, timeout, mute iOS) ; reprise après
    démarrage à froid via `activeCalls()` (appel accepté sur l'écran natif
    alors que l'app était tuée) ; `adaptiveStream` / `dynacast` activés,
    `AudioCaptureOptions` (écho, bruit, gain) explicites ; états
    `isReconnecting` (`RoomReconnecting/Reconnected`) et `quality`
    (`ParticipantConnectionQualityUpdatedEvent`) ;
  - `voice_call_page.dart` : pastille de qualité (3 barres + libellé) en
    appel, statut « Reconnexion… » ;
  - `push_notification_service.dart` : isolat FCM → écran natif ;
    `callkitBackgroundHandler` enregistré au démarrage pour qu'un refus sur
    l'écran natif, app tuée, prévienne le serveur.
- **Docs** : `docs/voice-calls.md` (tableau des services payants évités
  et de leurs remplaçants avec licences, architecture, variables
  d'environnement, optimisation Madagascar, consommation ≈ 10–12 Mo/h par
  téléphone, test local, limites).
- **Non couvert, documenté** : réveil iOS app tuée (PushKit + envoi APNs
  direct, gratuit mais à câbler) ; déclaration Play Console des services
  d'avant-plan `phoneCall` / `microphone` apportés par le plugin.

### 8. Appel vocal : « Appel… » puis « Appel en cours… » quand le téléphone de l'autre sonne

- **Demande** : comme WhatsApp, l'appelant ne doit voir « Appel en
  cours… » que lorsque l'invitation a réellement atteint le téléphone de
  l'autre ; avant (ou si l'autre est injoignable) il voit « Appel… ».
- **Avant** : « Sonnerie… » s'affichait dès la réponse du serveur, même
  téléphone éteint.
- **Backend** : `POST /calls/:id/ringing` (appelé uniquement,
  idempotent, ignoré si l'appel n'est plus en sonnerie) → événement
  `call:ringing` à l'appelant. Aucune migration.
- **App appelée** : accusé envoyé dès que l'appel entrant est affiché, par
  le socket / le push au premier plan (`_handleIncoming`) comme depuis
  l'isolat FCM quand l'app est en arrière-plan ou tuée (après affichage de
  l'écran natif).
- **App appelante** : `VoiceCallSession.peerReached` ; « Appel… » pendant
  la création et tant que l'accusé n'est pas arrivé, « Appel en cours… »
  ensuite. Un accusé qui arriverait avant le retour de la requête de
  démarrage est conservé (`_earlyRingingAckCallId`) puis appliqué.
- Sans accusé, l'appelant reste sur « Appel… » jusqu'à « Pas de réponse »
  (45 s) : signe que l'autre n'est pas joignable.

### 9. Live « pendu » quand le vendeur perd sa connexion : battement de cœur + balayage serveur

- **Symptôme** : données épuisées, batterie vide ou app tuée pendant un
  live → la pastille « en direct » restait visible pendant des jours et un
  spectateur qui cliquait tombait sur une salle vide (écran noir).
- **Cause** : la session n'était fermée que par l'appel « stop » de l'app
  hôte, jamais envoyé dans ces cas ; aucune vérification côté serveur ni
  borne de durée ; `getSellerLiveJoinInfo` délivrait un jeton tant que la
  ligne existait.
- **Backend** (`profiles.service.ts`, `profiles.controller.ts`,
  `profiles-live.scheduler.ts` nouveau, `livekit.service.ts`) :
  - `POST /profiles/me/live/heartbeat` : l'hôte ping toutes les 30 s
    (`updatedAt` de la session sert d'horodatage, aucune migration) ; 404
    si la session est déjà fermée ;
  - `ProfilesLiveScheduler` (`@Interval` 30 s) → `expireStaleLiveSessions` :
    toute session sans ping depuis 90 s est fermée et `live:updated`
    (`isLive: false`) est émis au vendeur et à ses abonnés. Nettoie aussi
    les lignes déjà bloquées en base ;
  - `getSellerLiveJoinInfo` : refuse (404 « Ce live est terminé ») et
    ferme la session si le ping est périmé, ou si LiveKit ne voit pas
    l'hôte dans la salle une minute après le démarrage
    (`LivekitService.listParticipantIdentities`, `RoomServiceClient`) ;
  - `isLive` de la liste des boutiques suivies et l'entrée « En direct »
    des notifications appliquent la même borne de 90 s ;
  - `stopCurrentUserLive` et le balayage partagent `endLiveSession`.
- **App hôte** (`live_preview_page.dart`) : minuterie de ping dès le
  passage en direct ; sur 404 → état « Live interrompu » (diffusion
  coupée, seul bouton « Fermer ») ; bandeau « Connexion perdue,
  reconnexion en cours… » tant que LiveKit n'est pas reconnecté.
- **App spectateur** (`live_watch_page.dart`) : 404 à la jointure ou
  `live:updated isLive:false` pendant le visionnage → écran « Ce live est
  terminé » au lieu d'une attente infinie.
- **Délai** : un live mort disparaît au plus 2 min après le dernier ping.
- **À déployer** : backend seulement (pas de migration).

### 10. Appel vocal coupé automatiquement à 45 s côté appelant

- **Symptôme** : appel accepté, audio des deux côtés, puis coupure à
  45 s exactement après le lancement (deux appels en base : 45,1 s et
  45,2 s, terminés par l'appelant).
- **Diagnostic** : la minuterie de sonnerie de l'appelant (45 s → « Pas de
  réponse ») n'était pas annulée : l'appelant ne traitait pas l'événement
  socket `call:accepted`. Un test de bout en bout (socket authentifié +
  API) montre que le serveur l'émet bien en < 1 s ; le défaut est côté
  app. L'abonnement aux événements d'appel (`VoiceCallService.bind()`)
  n'était créé qu'au démarrage de session : une app relancée à chaud
  (hot reload) après l'ajout de cette ligne ne l'exécutait jamais. En
  appelé, le téléphone recevait quand même l'appel via le push, d'où
  l'asymétrie observée.
- **Correctif** (`voice_call_service.dart`) :
  - `bind()` est appelé par chaque point d'entrée (`startCall`,
    `handleIncomingPush`, `openIncomingCall`) et reste idempotent (la
    reprise des appels natifs ne tourne qu'une fois) ;
  - filet indépendant du socket : `ParticipantConnectedEvent` LiveKit
    (l'autre participant rejoint la salle) passe l'appel sortant en actif
    et annule la minuterie, même si `call:accepted` n'arrive jamais.
- **Note** : après un hot reload, redémarrer complètement l'app sur le
  téléphone pour que le code de démarrage de session s'exécute.

### 11. Appels : icônes entrant / sortant / manqué, notification « Appel manqué » unique, live sans doublon

- **Lignes d'appel dans la discussion** (`chat_page.dart`, `_CallLine` +
  `_CallLineRow`) : le texte posté par l'appelant (« 📞 Appel vocal · 2 min
  05 », « … manqué », « … refusé ») est rendu selon le point de vue du
  lecteur : sortant (flèche verte `call_made`) pour l'appelant, entrant
  (`call_received`) pour l'autre ; manqué en rouge `call_missed` chez celui
  qui l'a manqué, en ambre `call_missed_outgoing` « Pas de réponse » chez
  l'appelant ; refusé en rouge `call_end` / ambre. Durée ou état en
  sous-titre. Les anciens messages sont reconnus par leur préfixe, sans
  migration.
- **Notification d'appel manqué** : push dédié `missed_call` (« Appel
  manqué — X a essayé de vous appeler ») envoyé à l'appelé seul, pour les
  appels sans réponse ou annulés par l'appelant ; l'appui ouvre la
  discussion (`push_notification_service.dart`, routage conversation). La
  ligne de chat n'envoie plus de push (elle doublait), et la notification
  d'appel manqué du plugin natif est désactivée (elle doublait aussi).
  Appels terminés ou refusés : aucune notification.
- **Live déjà à l'écran** : `LiveWatchPage.isWatching()` ; une notification
  (push ou liste) pour le live déjà en cours de visionnage n'ouvre plus un
  second lecteur (`notification_navigation.dart`).

### 12. Appel entrant : réponse par glissement vers le haut (façon Messenger)

- **Demande** : répondre ou refuser en glissant, comme sur Messenger.
- **Changement** (`voice_call_page.dart`, `_SlideUpCallButton`) : sur
  l'écran d'appel entrant dans l'app, les deux boutons se glissent vers
  le haut le long d'une piste ; trois chevrons pulsent au-dessus comme
  indice et s'effacent pendant le geste ; l'action se déclenche aux trois
  quarts de la course avec un retour haptique ; un bouton relâché avant
  revient en place par ressort. Un simple appui ne répond plus, ce qui
  évite les réponses accidentelles (poche, pouce posé).
- **Hors périmètre** : l'écran natif Android affiché quand l'app est en
  arrière-plan ou tuée (plugin `flutter_callkit_incoming`) garde ses
  boutons par appui ; son interface n'est pas modifiable depuis Flutter.

### 13. Appel vocal : tonalité de retour d'appel (« bip-bip ») et sonnerie in-app

- **Demande** : un bip régulier côté appelant pendant que ça sonne chez
  l'autre, comme sur Messenger.
- **Dépendance** : `audioplayers` 6.7 (MIT) ajouté ; aucune autre
  bibliothèque audio n'existait dans le projet.
- **Sons** (`assets/sounds/`, déclarés dans `pubspec.yaml`) : générés par
  un script Dart maison (aucun fichier tiers, aucune licence à suivre) :
  `ringback.wav` (deux bips à 440 Hz, 0,6 s) et `ringtone.wav` (deux
  phrases de cloche ascendantes puis pause, 3,1 s, jouée en boucle).
- **Service** (`lib/services/call_tones.dart`) : `startRingback` rejoue le
  bip-bip toutes les 4 s, routé comme la voix (écouteur, ou haut-parleur
  si activé), sans prendre le focus audio pour ne pas perturber WebRTC ;
  `startRingtone` en boucle sur le haut-parleur ; `stop`. Tout échec
  (pas de périphérique audio) est ignoré : l'appel n'en dépend pas.
- **Intégration** (`voice_call_service.dart`) : bip-bip dès que l'appel
  sortant est créé, arrêté à la réponse ou à la fin ; sonnerie pour l'appel
  entrant affiché dans l'app (l'écran natif Android/iOS a déjà la sienne),
  arrêtée à l'acceptation, au refus ou à la fin.

### 14. Sonnerie d'appel dans l'écran natif Android, vibration réelle selon le mode sonnerie

- **Demande** : utiliser la sonnerie générée comme sonnerie d'appel, en
  garder une copie dans « Objets 3D », et vibrer à l'appel entrant si le
  téléphone l'autorise.
- **Copies** : `C:\Users\Banay\3D Objects\banay_sonnerie_appel.wav` et
  `banay_bip_appel_sortant.wav`.
- **Écran natif Android** (`flutter_callkit_incoming`) :
  `android/app/src/main/res/raw/banay_ringtone.wav` (même son que
  `assets/sounds/ringtone.wav`), `ringtonePath: 'banay_ringtone'` dans
  `incoming_call_native_ui.dart`. Le plugin la joue en boucle et vibre de
  lui-même en suivant le mode sonnerie du téléphone. iOS garde la sonnerie
  système (l'ajout d'un fichier au bundle demande Xcode).
- **Appel entrant affiché dans l'app** (`voice_call_service.dart`) :
  - `MainActivity.kt` expose le mode sonnerie Android (`banay/ringer` →
    normal / vibrate / silent), lu par `lib/services/ringer_mode.dart` ;
  - normal → sonnerie + vibration ; vibreur seul → vibration seule ;
    silencieux → écran seul ; iOS / inconnu → comme normal (l'interrupteur
    latéral iOS coupe le son de lui-même) ;
  - vibration de type appel (900 ms, pause 1,1 s, en boucle) via le paquet
    `vibration` 3.2 (MIT) quand l'appareil a un vibreur, sinon le tic
    haptique d'avant ; arrêtée à l'acceptation, au refus ou à la fin.

### 15. Sons d'appel fournis par l'équipe : retour d'appel en boucle, sonnerie mp3, son de fin d'appel

- **Contexte** : les sons générés (entrée 13) ont été remplacés dans
  `assets/sounds/` par des fichiers maison : `ringback.wav` (40 s),
  `ringtone.mp3`, et un nouveau `rington_end_call.wav`. L'ancien
  `ringtone.wav` référencé par le code n'existait plus → erreur de
  synchronisation des assets au `flutter run`.
- **Assets** : les deux WAV livrés en 24 bits / 48 kHz (5,7 Mo) sont
  convertis en 16 bits / 24 kHz mono (1,9 Mo et 55 Ko) par un script Dart ;
  les originaux sont gardés dans `assets/sounds/originals/`, hors du
  bundle (seul le dossier `assets/sounds/` est déclaré). Le raw Android
  `banay_ringtone.wav` est remplacé par `banay_ringtone.mp3` (même nom de
  ressource, l'écran natif ne change pas).
- **`call_tones.dart`** : `startRingback` joue `ringback.wav` en boucle (plus
  de minuterie de 4 s : le fichier porte déjà sa cadence) ; `startRingtone`
  joue `ringtone.mp3` en boucle ; nouveau `playEndCall` joue
  `rington_end_call.wav` une fois, sur son propre lecteur pour ne pas être
  coupé par l'arrêt des autres sons.
- **`voice_call_service.dart`** : son de fin joué à chaque fin d'appel
  (raccroché, refusé, sans réponse, annulé, perdu), sur la même sortie que
  la voix.

### 16. Sonnerie d'appel entrant en boucle garantie

- **Dans l'app** (`call_tones.dart`) : en plus du mode boucle du lecteur,
  un redémarrage manuel (`seek(0)` + `resume`) sur l'événement de fin, qui
  n'est émis que si la plateforme ignore la boucle ; idem pour le retour
  d'appel. Vibration avec intensités explicites (`[0, 255, 0]`) : l'amplitude
  par défaut « -1 » du paquet est refusée par certains HAL (émulateur).
- **Écran natif Android** : le plugin boucle la sonnerie à partir
  d'Android 9 seulement ; `res/raw/banay_ringtone.mp3` est désormais le
  mp3 répété six fois (≈ 49 s, 1,5 Mo) pour couvrir toute la fenêtre de
  sonnerie de 45 s sur Android 6 à 8 aussi.
- Vérifié sur l'émulateur par un appel réel de 25 s déclenché par l'API :
  lecteur créé une seule fois, focus audio « sonnerie » pris, aucune
  erreur audio.

### 17. Sons d'appel saturés, et bannière d'appel entrant façon WhatsApp

- **Saturation** : mesure des fichiers livrés — retour d'appel à 0 dBFS de
  crête (21 120 échantillons écrêtés, RMS −8 dBFS), fin d'appel à −1,8 dBFS
  de crête. Trop chaud pour un écouteur ou un petit haut-parleur.
  Reconversion depuis les originaux avec −8 dB (retour d'appel → crête
  −8 dBFS, RMS −16) et −6 dB (fin d'appel → crête −7,8 dBFS) ; volume de
  lecture 0,8 (retour, fin) et 0,7 (sonnerie mp3, non retouchée) dans
  `call_tones.dart`. L'écrêtage présent dans la source elle-même ne peut
  pas être retiré ; le niveau, lui, ne fait plus forcer le haut-parleur.
  Copies « Objets 3D » mises à jour.
- **Bannière** (`lib/component/call/incoming_call_banner.dart`, nouveau ;
  `voice_call_service.dart`) : un appel qui arrive pendant que l'app est
  utilisée n'ouvre plus l'écran plein écran mais une carte en haut de
  l'écran, par-dessus la page en cours (overlay racine) : avatar, nom,
  « Appel vocal Banay · entrant », boutons rond Refuser / Répondre ; un
  appui sur la carte ouvre l'écran complet (glissement). Sonnerie et
  vibration inchangées. Répondre ouvre l'écran d'appel en cours ; refus,
  annulation ou fin retirent la carte. Appel ouvert depuis une
  notification (native Android, alerte iOS) : écran complet direct.

### 18. Accueil d'appel : retour à l'interface d'origine

- **Demande** : reprendre l'interface de réception d'appel du départ.
- **Changement** : la bannière en haut d'écran (entrée 17) et la réponse
  par glissement (entrée 12) sont retirées ; un appel entrant ouvre à
  nouveau l'écran plein avec les boutons Refuser / Accepter par appui,
  bouton Accepter légèrement pulsé. `incoming_call_banner.dart` supprimé,
  `_SlideUpCallButton` retiré de `voice_call_page.dart`,
  `voice_call_service.dart` sans overlay. Sonnerie, vibration, sons et
  écran natif inchangés.

### 19. Écran d'appel en plein écran

- **Changement** (`voice_call_page.dart`) : barres d'état et de navigation
  masquées pendant tout l'appel (`SystemUiMode.immersiveSticky`, un
  glissement depuis un bord les fait réapparaître un instant) ; retour au
  mode normal (`edgeToEdge`) à la fermeture de l'écran.

### 20. Version 1.5.0+11

- `pubspec.yaml` : `1.4.0+10` → `1.5.0+11` (bump mineur : appels vocaux,
  écran natif d'appel, sons, vies fermées automatiquement, notifications
  live/story/appel manqué ; `versionCode` 11).
- `docs/play-store-release.md` : valeur de version mise à jour.
- **Avant diffusion** : backend déployé avec la migration
  `20260910_add_voice_calls` et `LIVEKIT_URL` pointant sur le serveur
  retenu ; à la première publication, la console Play demandera la
  déclaration des services d'avant-plan `phoneCall` / `microphone`
  (plugin d'appel).

### 21. Play Console : déclaration des services d'avant-plan

- `AndroidManifest.xml` : `FOREGROUND_SERVICE_CAMERA` retiré du manifeste
  fusionné (`tools:node="remove"`). Le plugin d'appel ne l'ajoute au
  service qu'en appel vidéo (`isVideo`), jamais pour les appels audio de
  Banay ; la console Play ne demandera plus de justification caméra.
- Réponses au formulaire : Micro → « Entrée audio en arrière-plan »
  (appels vocaux) ; Appel téléphonique → « VoIP, API de
  télécommunications » ; Messagerie à distance → « Autre » (connexion
  temps réel maintenue pour la réception des messages, option « Connexion
  renforcée » activée par l'utilisateur).

### 22. Play Console : refus de `USE_FULL_SCREEN_INTENT` (1.5.1+12)

- Avis Google (2026-09-11) : « L'utilisation de l'autorisation n'est pas
  directement liée à l'objectif principal de l'appli » ; retrait exigé de
  tous les codes de version (sous-ensembles de test et production).
- `AndroidManifest.xml` : `USE_FULL_SCREEN_INTENT` retiré du manifeste
  fusionné (`tools:node="remove"`) ; la permission venait à la fois du
  plugin `flutter_callkit_incoming` et de notre propre déclaration.
- Conséquence UX Android : l'appel entrant arrive comme notification
  « heads-up » (sonnerie, vibration, Accepter / Refuser) au lieu de prendre
  tout l'écran ; toucher la notification ouvre l'écran d'appel du plugin,
  y compris sur l'écran verrouillé (`isShowFullLockedScreen` inchangé, il ne
  dépend pas de la permission). Écran éteint : l'allumage automatique n'est
  plus garanti, il dépend de l'OEM.
- `lib/services/incoming_call_native_ui.dart` : commentaires mis à jour,
  aucun changement de comportement côté Dart (l'appli n'appelait pas
  `requestFullIntentPermission`).
- `pubspec.yaml` : `1.5.0+11` → `1.5.1+12` ; le versionCode 11 est celui
  signalé et doit passer en « Non inclus » dans la nouvelle version Play.
- Console Play : créer une version avec le nouvel AAB dans chaque
  sous-ensemble concerné, déployer à 100 %, puis vérifier dans l'explorateur
  de collections que le code 11 apparaît « Inactif ».

## 2026-09-13

### 1. Live spectateur : 720p demandé sur tous les réseaux (image pixellisée en 4G)

- **Symptôme** : après validation Play, test en 4G (Samsung S21 / S22
  Ultra) : image du live « pleine de pixels » et saccadée, alors que
  TikTok Live est net et fluide sur le même réseau.
- **Cause (pixellisation)** : depuis l'entrée 1 du 2026-09-10, le spectateur
  en données mobiles seules demandait la couche MEDIUM (360p, 500 kb/s),
  quelle que soit la qualité réelle de sa 4G. Étirée en plein écran
  (`VideoViewFit.cover`) sur un téléphone 1080×2400, une image 360×640 est
  agrandie 3 fois : c'est le rendu observé. TikTok ne plafonne pas selon le
  type de réseau, il suit le débit mesuré.
- **Correctif** (`lib/page/live/live_watch_page.dart`) :
  `setVideoQuality(VideoQuality.HIGH)` sur chaque piste vidéo souscrite,
  Wi-Fi ou données mobiles ; le SFU mesure de toute façon le lien descendant
  de chaque spectateur et ne sert 360p / 180p que si le lien ne suit
  vraiment pas. Détection `connectivity_plus` (Wi-Fi ⇄ mobile) retirée de
  la page ; `lib/services/live/live_view_quality.dart` et son test
  supprimés (ils ne renvoyaient plus qu'une constante). `adaptiveStream`
  reste désactivé (entrée 8 du 2026-09-06 : taille logique du lecteur).
- **Coût data** : spectateur 4G ≈ 0,7 Go/h (720p à 1,5 Mb/s) au lieu de
  ≈ 0,25 Go/h ; choix validé par l'utilisateur.
- **Saccades, non couvertes par ce correctif** : elles viennent du lien
  montant de l'hôte (3 couches simulcast ≈ 2,2 Mb/s à tenir ; dès qu'il
  fléchit, WebRTC coupe la couche 720p pour tous les spectateurs) et de
  l'absence de tampon en WebRTC (< 1 s de latence : chaque rafale de pertes
  4G devient un gel, là où TikTok masque avec 3 à 10 s de tampon). Un S21 /
  S22 Ultra (Exynos ou Snapdragon) encode H.264 en matériel : l'encodeur
  n'est pas en cause sur ces appareils. Pistes : couche haute à 1,2 Mb/s et
  retrait de la couche 180p côté hôte ; à terme, chaîne serveur (Egress →
  HLS + lecteur avec tampon) déjà notée dans l'entrée 1 du 2026-09-10.
- **Rappel** : sur Android, libwebrtc n'a pas d'encodeur H.264 logiciel et
  n'active le H.264 matériel que sur puces Qualcomm / Exynos ; un hôte
  MediaTek / Unisoc retombe en VP8 logiciel (3 couches 720p / 30 i/s sur
  CPU), ce qui contredit « encodage matériel sur tous les téléphones » de
  l'entrée 1 du 2026-09-10.

### 2. Live : tampon de lecture côté spectateur (playout delay) et hôte allégé

- **Demande** : plus de micro-coupures d'image et de son, comportement
  « comme TikTok ».
- **Ce que fait TikTok** : l'hôte envoie un seul flux, le serveur fabrique
  les rendus, le spectateur lit en HLS/FLV avec 3 à 10 s de tampon qui
  absorbent gigue et pertes. Le live Banay est en WebRTC : lecture dès
  réception (< 1 s), donc chaque rafale de pertes 4G se voit. L'équivalent
  LiveKit d'un tampon est le *playout delay* de salle, appliqué ici.
- **Backend** (`backend/src/modules/livekit/livekit.service.ts`,
  `profiles.service.ts`) : `ensureLiveRoom` crée la salle
  `seller-live-<id>` via `RoomServiceClient.createRoom` avec
  `minPlayoutDelay: 1000`, `maxPlayoutDelay: 3000` et `syncStreams: true`
  avant l'événement `live:updated` et le jeton de l'hôte (sinon le premier
  spectateur l'aurait auto-créée avec les réglages temps réel). Idempotent
  (salle existante renvoyée telle quelle), non bloquant (échec = avertissement
  et lecture temps réel). Les salles d'appel vocal ne passent pas par là.
  `listParticipantIdentities` réutilise le nouveau `roomServiceClient()`.
- **Effet spectateur** : le téléphone garde au moins 1 s de vidéo avant
  affichage (extension RTP `playout-delay`, honorée par libwebrtc
  Android / iOS), jusqu'à 3 s sous forte gigue ; l'audio est aligné sur la
  vidéo par `syncStreams`. Latence hôte → spectateur ≈ 1,2 à 1,5 s (TikTok :
  3 à 10 s) ; les commentaires et likes (canal de données) ne sont pas
  retardés. La redondance audio (`red`) et le FEC Opus étaient déjà actifs
  par défaut dans le SDK Flutter.
- **Hôte** (`lib/page/live/live_preview_page.dart`) : couche 720p ramenée
  de 1,5 à 1,2 Mb/s (échelle totale ≈ 1,9 Mb/s au lieu de ≈ 2,2) pour laisser
  de la marge au lien montant 4G : sous l'estimation de débit, WebRTC coupe
  la couche 720p pour tous les spectateurs. HD ≈ 0,55 Go/h côté spectateur.
- **Limite** : le lien montant de l'hôte reste la borne, comme sur TikTok.
  La parité complète (rendus fabriqués côté serveur, tampon de plusieurs
  secondes) demande la chaîne Egress → HLS + lecteur avec tampon (entrée 1
  du 2026-09-10).
- **Backend à déployer avant diffusion** : sans lui, l'app fonctionne mais
  la salle reste en lecture temps réel. Réglage à ajuster dans
  `LIVE_MIN_PLAYOUT_DELAY_MS` / `LIVE_MAX_PLAYOUT_DELAY_MS` si l'essai
  terrain montre un décalage son/image au démarrage (libwebrtc rattrape
  l'audio par pas de 80 ms/s : ≈ 12 s pour 1 s de tampon).

### 3. Live : hôte en 4G faible et nombre de spectateurs (VPS Hostinger)

- **Demande** : améliorer « fluidité, hôte en 4G faible » et « nombre de
  spectateurs » sans changer d'architecture (LiveKit auto-hébergé sur le
  VPS Hostinger, coût zéro).
- **Hôte, échelle à deux couches** (`lib/page/live/live_preview_page.dart`) :
  720p 1,2 Mb/s + 360p 400 kb/s à 30 i/s, couche 180p retirée. Cause du
  gain : libwebrtc n'active la couche 720p que si l'estimation du lien
  montant couvre la cible de chaque couche inférieure plus le plancher
  intégré du 720p (600 kb/s). Avec 180p + 360p à 500 kb/s il fallait
  ≈ 1,3 Mb/s de lien montant ; un hôte 4G faible restait sous ce seuil et
  tous les spectateurs voyaient du 360p. Avec 360p à 400 kb/s le seuil
  tombe à ≈ 1,05 Mb/s (maintien à 1,0). Contrepartie : sous ≈ 400 kb/s de
  lien descendant, le SFU met la vidéo en pause au lieu de servir une
  vignette 180p.
- **Serveur, port UDP unique** (`infra/livekit/livekit.yaml`,
  `infra/livekit/README.md`) : `udp_port: 7882` remplace la plage
  `50000-50200`. Selon la doc LiveKit, une plage coûte deux ports par
  participant : 201 ports = ~100 participants au total, lives et appels
  confondus ; un live suivi saturait le serveur et bloquait les appels. Le
  port unique lève cette limite ; il reste le débit réel du port Hostinger
  (≈ 1,3 Mb/s par spectateur HD) et le trafic mensuel. README : règle UFW
  `7882/udp`, procédure de migration pour l'installation existante.
- **Vérifié dans la doc LiveKit** : `room.playout_delay` existe aussi en
  réglage serveur mais s'appliquerait aux appels ; on garde la création par
  salle via l'API (entrée 2), qui a priorité sur les valeurs par défaut.
  `pli_throttle`, `packet_buffer_size_video`, `congestion_control` restent
  aux valeurs par défaut, adaptées.
- **Non fait, en attente d'accord** : indicateur de qualité réseau affiché
  à l'hôte (changement d'interface). Chaîne Egress → HLS + CDN (entrée 2,
  niveau 3) non lancée : latence de 3 à 8 s à valider d'abord.
- **À déployer** : VPS (`livekit.yaml` + UFW + redémarrage du conteneur),
  backend (entrée 2), puis nouvelle version de l'app.

### 4. Live : image figée toutes les ~3 s après l'entrée 2 (délai de lecture)

- **Symptôme** (test local, backend de dev sur LiveKit Cloud) : qualité
  d'image correcte mais gel court et régulier, toutes les 3 s environ.
- **Cause** : le délai de lecture était donné comme plage (1000 à 3000 ms).
  Dans `pkg/sfu/playoutdelay.go` de LiveKit, le SFU recalcule le délai à
  chaque rapport RTCP du spectateur (cible = gigue × 10, + 2 ms par point de
  NACK au-delà de 60 %), le déplace d'au plus 80 ms par seconde à
  l'intérieur de la plage et renvoie l'extension RTP à chaque changement.
  Côté téléphone, libwebrtc applique le nouveau plancher sans lissage
  (`current_delay_.Clamped(min, max)` dans `VCMTiming`) : chaque hausse
  fige l'image de la différence, chaque baisse fait un saut. Sur un
  spectateur 4G dont la gigue fluctue, le délai oscillait en permanence.
  Sur Wi-Fi (gigue × 10 < 1000 ms) il restait au minimum : pas de symptôme.
- **Correctif** (`backend/src/modules/livekit/livekit.service.ts`) : une
  seule valeur, envoyée comme `minPlayoutDelay` et `maxPlayoutDelay`
  (bornes égales = extension envoyée une fois, jamais modifiée). Défaut
  800 ms : couvre les rafales de gigue 4G et une retransmission (aller-retour
  ≈ 250 ms), audio réaligné en ≈ 10 s au lieu de 12. Variable
  `LIVE_PLAYOUT_DELAY_MS` (backend/.env, documentée dans `.env.example`) :
  `0` désactive le tampon, plafond 10 000. `syncStreams` conservé.
- **Pour retester** : arrêter le live, attendre 30 s (la salle LiveKit
  survit ≈ 20 s au départ du dernier participant et garde ses réglages ;
  `createRoom` ne modifie pas une salle existante), relancer le backend
  puis le live. Si le gel persiste avec `LIVE_PLAYOUT_DELAY_MS=0`, la cause
  n'est pas le tampon : regarder le lien montant de l'hôte (bascule de la
  couche 720p autour de 1,0 Mb/s, entrée 3).
- **Écarté** : aucun minuteur de 3 s côté app (battement de cœur hôte à
  30 s, envoi des likes à 350 ms).

### 5. Live : « MediaConnectException: Timed out waiting for PeerConnection to connect »

- **Symptôme** (test local, après l'entrée 4) : erreur du SDK LiveKit à la
  connexion.
- **Ce que dit l'erreur** : `Engine.connect` du SDK Flutter a bien obtenu
  la réponse `join` (URL et jeton corrects, serveur joignable en WSS) mais
  la connexion média principale (ICE, TURN si nécessaire, DTLS) n'a pas
  atteint l'état connecté dans les 10 s par défaut. Ce n'est pas un rejet
  de la salle ni du jeton : c'est le chemin UDP/TCP du média.
- **Écarté par lecture du code serveur LiveKit** : `min == max` pour le
  délai de lecture est accepté sans erreur (`pkg/sfu/playoutdelay.go`) ;
  le délai n'ajoute qu'une extension d'en-tête RTP à la négociation vidéo
  (`pkg/rtc/transport.go`) ; `sync_streams` n'a d'effet particulier que
  pour Firefox (`pkg/rtc/participant.go`). Aucun n'intervient dans ICE.
- **Causes probables, à vérifier dans l'ordre** :
  1. Backend de dev pointé sur le VPS avec le nouveau `livekit.yaml`
     (entrée 3) sans `sudo ufw allow 7882/udp` : UDP bloqué, repli TCP 7881
     seul. Vérifier `ss -lun | grep 7882` et `ufw status`.
  2. LiveKit local en Docker : `--node-ip` doit être l'IP LAN actuelle du PC
     (elle change, voir l'entrée « Dev login LAN IP » de la mémoire) et les
     ports UDP du serveur doivent être publiés.
  3. Réseau du téléphone : UDP et TCP média bloqués (Wi-Fi d'entreprise,
     certains APN) ou 4G trop lente pour boucler ICE + DTLS en 10 s.
- **Isolation** : `LIVE_PLAYOUT_DELAY_MS=0` court-circuite entièrement
  `createRoom` ; si l'erreur persiste ainsi, la salle n'est pas en cause.
- **Robustesse** (`lib/services/live/live_connect_options.dart`, nouveau ;
  `live_watch_page.dart`, `live_preview_page.dart`) : délais `connection`
  et `peerConnection` du SDK portés de 10 à 20 s pour les deux pages live
  (les appels gardent les valeurs par défaut). Couvre une 4G lente, pas un
  port bloqué.

### 6. Live : couche haute en 1080p (netteté)

- **Demande** : plus de résolution et de netteté.
- **Changement** (`lib/page/live/live_preview_page.dart`) : capture 1080p
  (1920×1080, soit 1080×1920 en portrait, 1:1 sur un écran full-HD là où
  le 720p était agrandi 1,5 fois), échelle simulcast à trois couches :
  1080p 2,5 Mb/s, 720p 1,2 Mb/s, 360p 400 kb/s, toutes à 30 i/s.
- **Pourquoi trois couches** : libwebrtc n'active une couche que si le lien
  montant couvre les cibles des couches inférieures plus le plancher de la
  couche (600 kb/s en 720p, 800 kb/s en 1080p). Seuils : 720p ≈ 1,05 Mb/s
  (inchangé), 1080p ≈ 2,5 Mb/s. Un hôte 4G continue donc à servir du 720p
  comme avant ; un hôte en Wi-Fi ou fibre sert du 1080p. `dynacast` met en
  pause les couches sans spectateur. Sous contrainte de débit, la
  dégradation `balanced` réduit la résolution source (1080p → 720p → 540p)
  plutôt que d'envoyer du 1080p en blocs.
- **Coût** : spectateur en 1080p ≈ 1,1 Go/h (720p ≈ 0,55 Go/h). VPS :
  jusqu'à ≈ 2,6 Mb/s par spectateur (README mis à jour). Encodage hôte :
  trois sessions H.264 matérielles (1080p + 720p + 360p) au pire ; sans
  H.264 matériel (MediaTek / Unisoc, repli VP8 logiciel) le 1080p est
  hors de portée, voir le rappel de l'entrée 1.
- **Caméra frontale limitée à 720p** : le SDK prend le meilleur format
  disponible, les couches inférieures en découlent.
- `live_watch_page.dart` : commentaire de `_applyVideoQuality` mis à jour,
  aucun changement de comportement (couche HIGH déjà demandée).

### 7. Live : son jugé « un peu de mauvaise qualité »

- **Vérifié dans le SDK LiveKit 2.5.4 et flutter_webrtc 1.2.1** :
  - `Room.connect` appelle `NativeAudioManagement.start()`, qui met Android
    en profil « communication » (`MODE_IN_COMMUNICATION`, usage
    `VOICE_COMMUNICATION`) pour tout participant, hôte ou spectateur. C'est
    le chemin audio des appels : capture par la source micro « voix »,
    anti-écho et réduction de bruit matériels (Android ≥ 10), sortie avec
    le traitement « VoIP » du constructeur. D'où le rendu « téléphone ».
  - Ce profil n'est pas modifiable en cours de session
    (`Helper.setAndroidAudioConfiguration` : « must be set before initiating
    a WebRTC session »), et les attributs de lecture sont fixés à la
    création de l'unique module audio du processus, partagé avec les appels
    vocaux. Le seul interrupteur, `bypassVoiceProcessing` au démarrage de
    l'app (source `MIC`, sans anti-écho, mode média), est global : les
    appels en haut-parleur auraient de l'écho. Non appliqué.
  - Publication par défaut : Opus 48 kb/s avec DTX (silence non transmis,
    bruit de confort côté récepteur) : l'ambiance de la boutique s'allume
    et s'éteint à chaque phrase.
- **Changement** (`lib/page/live/live_preview_page.dart`) :
  `defaultAudioPublishOptions` = Opus 64 kb/s sans DTX (flux continu,
  ≈ 30 Mo/h de plus par spectateur) ; `defaultAudioCaptureOptions` =
  filtre passe-haut activé (ronflement du téléphone tenu en main). Le
  reste de la capture (anti-écho, réduction de bruit, gain automatique)
  inchangé. Les appels vocaux gardent leurs propres options (24 kb/s, DTX).
- **Effet du tampon de lecture sur le son** : avec `syncStreams`, le
  téléphone du spectateur rattrape le retard vidéo en étirant l'audio par
  pas de 80 ms/s (NetEq) : ≈ 10 s de voix légèrement « tirée » au début de
  chaque visionnage pour 800 ms. La version plage 1000-3000 de l'entrée 2
  faisait osciller ce retard en permanence, donc étirement continu : c'est
  probablement une part de ce qui a été entendu. Comparer avec
  `LIVE_PLAYOUT_DELAY_MS=0` pour trancher.
- **Pistes plus lourdes, sur décision** : `bypassVoiceProcessing` global si
  les appels passent au second plan ; ou un correctif natif dans
  flutter_webrtc pour changer de profil audio par session.

### 8. Appels vocaux : établissement lent et voix qui se coupe

- **Symptôme** : plusieurs secondes entre « décrocher » et le son ; voix
  coupée par moments selon le réseau ; loin du ressenti WhatsApp.
- **Causes (établissement)** :
  1. `AppApiClient` utilisait `http.get` / `http.post` de haut niveau : un
     client neuf, donc une poignée de main TCP + TLS, à chaque requête.
     Depuis Madagascar vers le VPS : 0,5 à 1 s par requête, et un appel en
     enchaîne trois (`start`, `ringing`, `accept`). Toute l'app en pâtissait.
  2. L'appelé ne rejoignait la salle LiveKit qu'après avoir décroché, et
     après l'aller-retour `POST /calls/:id/accept` qui lui donnait le jeton :
     HTTP + signalisation WSS + ICE + DTLS ≈ 3 à 5 s après le tap. WhatsApp
     établit le chemin média pendant la sonnerie.
- **Causes (coupures)** : DTX vidait le tampon de gigue du récepteur à
  chaque silence, les premières syllabes suivantes sautaient sur 4G ; pas
  de redondance audio : `livekit_client` 2.5.4 copie `AudioPublishOptions.red`
  tel quel dans `disable_red` du protocole, donc la valeur par défaut
  `true` **désactivait** RED.
- **Correctifs** :
  - `lib/services/app_api_client.dart` : un `IOClient` partagé (keep-alive
    60 s, sous les 75 s de Nginx) pour toutes les requêtes.
  - Backend (`calls.service.ts`, `push-notifications.service.ts`,
    `conversations-realtime.gateway.ts`) : le jeton LiveKit de l'appelé part
    avec `call:incoming` (socket + push) et avec `GET /calls/:id` tant que
    l'appel sonne ; `accept` le renvoie toujours, en secours.
  - `lib/services/voice_call_service.dart` : `_preconnectIncoming` rejoint
    la salle pendant la sonnerie, micro non publié et `autoSubscribe: false`
    (sinon l'appelé entendrait le micro de l'appelant avant de décrocher,
    et la piste audio distante ferait passer Android en mode « appel » et
    prendrait le focus audio de la sonnerie) ; `accept()` s'abonne au micro
    de l'appelant (`_subscribeRemoteAudio`, plus `TrackPublishedEvent` pour
    les publications tardives), puis lance
    `POST accept` et l'activation du micro en parallèle (repli : connexion
    avec le jeton de l'invitation, puis celui de la réponse) ; côté
    appelant, la bascule « actif » de secours passe de
    `ParticipantConnectedEvent` à `TrackSubscribedEvent`, sinon l'entrée
    anticipée de l'appelé compterait comme une réponse. Audio : `dtx: false`,
    `red: false` (= RED activé, voir ci-dessus), 24 kb/s inchangé.
  - `infra/livekit/livekit.yaml` : `audio.active_red_encoding: true`, le SFU
    fabrique la redondance vers chaque récepteur si l'émetteur ne l'envoie
    pas.
- **Coût data** : ≈ 30 Mo/h par sens (≈ 60 Mo/h par téléphone), l'ordre de
  WhatsApp, contre ≈ 10 à 12 avant ; `docs/voice-calls.md` mis à jour, avec
  le retour arrière en deux drapeaux.
- **Non couvert** : la latence bouche-à-oreille (≈ 0,6 à 0,8 s via le VPS en
  Europe) et les rafales de pertes 4G longues ; WhatsApp relaie en région ou
  en pair-à-pair, hors de portée avec un SFU seul.
- **À déployer** : backend, VPS (`livekit.yaml` + redémarrage), nouvelle
  version de l'app. Compatibilité : une app ancienne ignore `url` / `token`
  dans l'invitation et garde l'ancien chemin.

### 9. Live : liste des spectateurs et accès à leur profil

- **Demande** : voir qui regarde le live (liste) et ouvrir le profil d'un
  spectateur, côté hôte comme côté spectateur.
- **Source des données** : la salle LiveKit elle-même, aucun nouvel
  endpoint. Le backend met désormais le nom d'affichage dans le `name` du
  jeton spectateur et `{userId, avatarUrl}` dans ses `metadata`
  (`profiles.service.ts` → `getSellerLiveJoinInfo`, `livekit.service.ts`
  → `buildToken({ metadata })`). L'identité reste `viewer-<userId>-<ms>`,
  unique par connexion. Les anciens jetons (`name: viewer-<id>`) donnent
  « Spectateur » sans avatar jusqu'au redéploiement du backend.
- **App** :
  - `lib/services/live/live_viewers.dart` (nouveau) : `liveViewersOf(room)`
    lit les participants `viewer-*` (métadonnées, repli sur l'identité),
    une entrée par utilisateur même connecté depuis deux téléphones, soi
    en premier puis par nom ; l'hôte n'est jamais listé.
  - `lib/component/live/live_viewers_sheet.dart` (nouveau) : feuille
    « Spectateurs » avec compteur, rafraîchie à chaque entrée / sortie
    (`ListenableBuilder` sur la salle), ligne = avatar, nom, « Vous »,
    chevron ; tap → profil public.
  - `lib/component/open_user_profile.dart` (nouveau) :
    `pushUserProfileById` (page vendeur si le compte est vendeur avec
    boutique, page utilisateur sinon, spinner pendant le chargement, état
    d'erreur). Remplace la copie qui vivait dans `app_comments_sheet.dart` ;
    `main_home_panel.dart` garde sa variante (toujours page utilisateur).
  - `LiveHostCard` : nouveau `onViewersTap`, l'œil + compteur devient
    tapable (zone de touche élargie) ; branché dans `live_watch_page.dart`
    et `live_preview_page.dart` quand le direct est en cours.
- **Hors périmètre** : pas d'historique des spectateurs partis, pas de
  notification d'arrivée dans le flux de commentaires.

### 10. Live : fil de commentaires plus haut et défilant, arrivées annoncées

- **Demande** : pouvoir faire défiler les commentaires, et voir passer un
  message quand quelqu'un entre dans le live.
- **Constat** : le fil (`LiveCommentsFeed`) était déjà une liste défilante,
  mais enfermée dans une boîte fixe de 192 px : trois ou quatre lignes
  visibles, d'où l'impression d'un fil figé.
- **Changement** (`lib/component/live/live_overlay_widgets.dart`) : le fil
  prend la hauteur de ses lignes jusqu'à 42 % de l'écran (`maxHeightFactor`,
  façon TikTok), puis défile, le plus récent en bas. En dessous de ce
  plafond il ne réserve que la hauteur utile : les taps sur la vidéo
  au-dessus du dernier commentaire continuent d'envoyer des cœurs. Sous
  le clavier il se réduit avec son parent (`LayoutBuilder`). Même widget
  côté hôte et côté spectateur.
- **Arrivées** : `LiveCommentEntry.isSystem` (nouveau champ, `false` par
  défaut, sérialisé mais jamais envoyé) rendu en ligne discrète « Nom a
  rejoint le live » avec petit avatar (`_buildSystemRow`).
  `liveJoinCommentFor(participant)` dans `lib/services/live/live_viewers.dart`
  construit la ligne à partir du nom et de l'avatar du jeton (entrée 9) ;
  l'hôte n'est jamais annoncé. Branché sur `ParticipantConnectedEvent`
  dans `live_watch_page.dart` (écouteur existant) et `live_preview_page.dart`
  (nouvel `EventsListener`, libéré dans `dispose`). Chaque téléphone
  fabrique la ligne localement : rien ne passe par le canal de données, et
  un spectateur ne voit que les arrivées postérieures à la sienne.
- **Départs et fondu** (même jour, sur demande) : « Nom a quitté le live »
  sur `ParticipantDisconnectedEvent` (`liveLeaveCommentFor`), ignoré quand
  la salle n'est plus connectée, sinon la fin du live annoncerait tout le
  monde d'un coup ; fondu de 32 px en haut du fil (`ShaderMask`, `dstIn`)
  pour que les lignes anciennes se dissolvent dans la vidéo au lieu d'être
  coupées.

### 11. Accueil : fil trié par la ville de l'utilisateur, puis par date

- **Demande** : d'abord les publications de la ville où se trouve
  l'utilisateur, puis les plus récentes.
- **Avant** : le backend prenait les 240 produits les plus récents, les
  classait en mémoire (ville exacte → mélange stable quotidien ; sinon par
  distance ; sinon par date) et découpait la page. Deux écarts avec la
  demande : les produits de la ville étaient mélangés, pas triés par date,
  et un produit plus ancien que le 240e n'apparaissait jamais, même de la
  bonne ville. L'app re-triait ensuite chaque page (vendeurs suivis puis
  certifiés en tête), ce qui brouillait l'ordre serveur.
- **Backend** (`products.service.ts`, `findAll`) : « même ville » =
  `sellerProfile.city` égal à la localité de l'utilisateur (première partie
  du libellé, insensible à la casse) **ou** position du vendeur dans un
  carré de 25 km autour de celle de l'utilisateur (`SAME_CITY_RADIUS_KM`).
  Deux seaux paginés en SQL, tous deux par `createdAt desc` puis `id` :
  la page parcourt le seau « ville » puis enchaîne sur le reste, sans
  plafond de candidats. Le complément est écrit clause par clause (un `NOT`
  sur des colonnes nulles aurait fait disparaître les vendeurs sans ville
  ni position). Supprimés : `rankProductsByLocation`,
  `isExactLocationMatch`, `computeStableShuffleScore`, tri par distance.
- **App** (`main_home_panel.dart`) : plus de re-tri local ;
  `_productRankScore` et `_isSellerCertified` retirés. Le badge « suivi »
  (`_isFollowedSeller`) reste affiché.
- **Sans localisation** (ni libellé ni position) : simple ordre par date.
- **À déployer** : backend ; l'app recompilée pour l'ordre exact des pages.

### 12. Version 1.6.0+13

- `pubspec.yaml` : `1.5.1+12` → `1.6.0+13` (bump mineur : nouveautés
  live et appels ; `versionCode` 13, le 12 étant déjà envoyé sur Play).
- **Contenu de la version** (entrées 1 à 11 de ce jour) : live en 1080p
  avec tampon de lecture et hôte allégé, liste des spectateurs avec accès
  au profil, fil de commentaires plus haut et défilant avec arrivées et
  départs annoncés, son du live en flux continu ; appels vocaux plus
  rapides à établir (pré-connexion pendant la sonnerie, client HTTP
  persistant) et voix sans coupures (flux continu, redondance audio) ;
  fil d'accueil trié par la ville de l'utilisateur puis par date.
- `docs/play-store-release.md` : valeur de version mise à jour.
- **Préflight** : `flutter analyze` sans erreur dans `lib/` (deux
  avertissements préexistants d'éléments inutilisés dans le panneau
  compte) ; `test/widget_test.dart`, test « compteur » du modèle Flutter
  jamais adapté et qui ne compilait plus, supprimé : `flutter test`
  repasse au vert.
- **Avant diffusion, dans cet ordre** : VPS (`infra/livekit/livekit.yaml`
  : port UDP 7882 ouvert dans UFW, redondance audio, redémarrage du
  conteneur), backend (jeton spectateur avec nom et avatar, jeton appelé
  avec l'invitation, délai de lecture des salles de live, tri du fil),
  puis l'AAB. Une app 1.5.x reste compatible avec le nouveau backend.
- **Texte « Nouveautés » Play Console** :
  « Lives en HD avec image plus nette et plus stable, liste des personnes
  qui regardent, commentaires qui défilent. Appels vocaux plus rapides à
  connecter et sans coupures. Fil d'accueil trié par votre ville, puis
  par nouveauté. »

### 13. Production : LiveKit Cloud, pas le VPS

- **Constat pendant le déploiement** : sur le VPS, `backend/.env` pointe sur
  `wss://bahibo-zs2ptdrd.livekit.cloud`, Docker n'est pas installé et UFW
  n'ouvre que SSH, 80 et 443. La pile `infra/livekit` (LiveKit + coturn)
  n'a jamais été lancée : lives et appels passent par LiveKit Cloud.
- **Conséquences sur les entrées de ce jour** : les modifications de
  `infra/livekit/livekit.yaml` (entrée 3 : `udp_port`, entrée 8 :
  `active_red_encoding`) sont sans effet tant que l'auto-hébergement n'est
  pas réel ; le plafond d'une centaine de participants (entrée 3) n'existe
  pas sur Cloud, qui choisit aussi le point de présence le plus proche de
  chaque téléphone. Le délai de lecture des salles de live (entrée 2) passe
  par l'API `createRoom` et s'applique tel quel sur Cloud. À surveiller à
  la place : la consommation facturée au-delà du palier gratuit (tableau de
  bord LiveKit Cloud).
- `infra/livekit/README.md` : avertissement en tête. La règle UFW
  `7882/udp` ajoutée par erreur est à retirer (`ufw delete allow 7882/udp`).
- **Déploiement effectif de la 1.6.0+13** : backend seul (`git pull`,
  `npm install`, `prisma migrate deploy`, `prisma:generate`, `npm run
  build`, redémarrage), puis l'AAB.

## 2026-09-14

### 1. Live : image toujours « pas nette » après le passage en 1080p (hôte en 4G)

- **Symptôme** : test S21 / S22 Ultra, hôte et spectateur en 4G : image pas
  nette malgré la capture 1080p de l'entrée 6 du 2026-09-13. Demande : « la
  meilleure qualité possible, 4K voire 8K selon la connexion ».
- **À vérifier d'abord (état périmé)** : l'APK de debug présent dans
  `build/app/outputs/flutter-apk/` date du 13/09 à 20 h 31 (1.5.1+12) et ne
  contient pas le passage en 1080p (commit `edddeb7`, 22 h 22) ; seul l'AAB
  1.6.0 de 23 h 01 le contient. Si les téléphones tournent encore ce debug,
  le test portait sur l'ancienne échelle 720p. Contrôler la version dans
  Paramètres > Applications > Banay.
- **Cause principale** (lue dans libwebrtc m137,
  `modules/video_coding/utility/simulcast_rate_allocator.cc` et
  `video/config/encoder_stream_factory.cc`) : en simulcast, l'allocateur
  sert d'abord les cibles des couches basses et ne donne à la couche haute
  que le reste. Avec [360p 400 kb/s, 720p 1,2 Mb/s, 1080p 2,5 Mb/s], la
  1080p s'allume dès 2,4 Mb/s de lien montant mais reçoit « lien − 1,6 »,
  soit 0,8 à 1,4 Mb/s sur une 4G à 2,4–3 Mb/s (0,014 bit par pixel) ; le
  SFU l'envoie telle quelle au spectateur (qualité HIGH) : une 1080p
  affamée, pire que la 720p qu'elle remplaçait. Elle n'a ses 2,5 Mb/s
  qu'au-delà de 4,1 Mb/s de lien montant. En simulcast, le réducteur de
  résolution piloté par le QP est désactivé (`SimulcastEncoderAdapter`
  renvoie `ScalingSettings::kOff`) : une couche affamée ne se réduit jamais
  d'elle-même, et `balanced` ne réagit qu'à la surcharge CPU. Repères 4G
  Madagascar (nPerf 2024, débit montant moyen) : Airtel 3,7 Mb/s (2,3 en
  heure de pointe), Telma 6,9, Orange 11,9 ; 51 à 59 % des mesures sous
  5 Mb/s.
- **Causes secondaires vérifiées** : débit par pixel trop bas sur toutes
  les couches (1080p à 2,5 Mb/s = 0,04 bit/pixel ; repère 0,1 ; préréglage
  SDK 3,0 Mb/s ; TikTok LIVE Studio 3,5–4,5) ; profil H.264 Constrained
  Baseline imposé par le SDK (`engine.dart` préfère `42e01f`, et libwebrtc
  Android ne propose le profil High que pour des encodeurs nommés
  `OMX.Exynos.`, jamais pour les noms Codec2 des Android 11+) : non
  modifiable depuis Dart ; rendu spectateur : une 1080p portrait est
  agrandie 1,25× sur un écran 1080×2400 (1,6× sur 1440×3088), bords rognés
  par `cover` : la mention « 1:1 » de l'entrée 6 du 2026-09-13 était fausse.
- **Correction du « rappel » de l'entrée 1 du 2026-09-13** : sur Android 10
  et plus, libwebrtc prend l'encodeur H.264 matériel de n'importe quel
  constructeur (`HardwareVideoEncoderFactory` teste
  `isHardwareAccelerated()`) ; la liste blanche Qualcomm / Exynos ne vaut
  que pour Android 9 et antérieur. Un hôte MediaTek / Unisoc récent encode
  donc bien en H.264 matériel. Reste vrai : libwebrtc n'embarque aucun
  encodeur H.264 logiciel.
- **4K / 8K, écarté** : la table de débits libwebrtc plafonne tout ce qui
  dépasse 1080p sur la ligne 1080p (plancher 800 kb/s) : une couche 2160p
  s'allumerait au même seuil de 2,4 Mb/s et serait encodée à 1,4 Mb/s (de la
  4K en bouillie), et n'atteindrait ses 8 Mb/s qu'au-delà de 9,6 Mb/s de
  lien montant stable, alors que le sondage initial de débit est plafonné à
  5 Mb/s ; trois encodeurs dont un 4K sur chemin CPU (LiveKit ne négocie pas
  l'extension `video-orientation`, donc rotation I420 et mises à l'échelle
  logicielles) ; 3,6 Go/h par spectateur ; et l'écran du S21 fait 1080 px de
  large : aucun gain visible. 8K : hors de portée d'un téléphone en WebRTC.
  TikTok Live n'offre pas de 4K (LIVE Studio plafonne à 1080p et recommande
  720p, l'app mobile émet en 720p) ; sa netteté en 4G vient d'une source
  modeste bien alimentée, transcodée côté serveur, avec 3 à 5 s de tampon.
- **Changement** (`lib/page/live/live_preview_page.dart`) :
  - échelle à deux couches : 540p 700 kb/s + 1080p 4 Mb/s, 30 i/s. Seuil
    d'allumage de la 1080p : 1,5 Mb/s de lien montant (au lieu de 2,4 ;
    1,66 pour se rallumer après une baisse, hystérésis ×1,2 sur le plancher,
    contre 2,56 avant) ; elle reçoit « lien − 0,7 » : 1,8 Mb/s à 2,5 de
    lien, 3,3 à 4, plafond 4 Mb/s pour un hôte en Wi‑Fi, fibre ou 5G. Deux
    encodeurs matériels au lieu de trois. Le spectateur dont le lien
    descendant ne suit pas reçoit la 540p (agrandie 2,5×, contre 3,75× pour
    l'ancienne 360p) ;
  - `backupVideoCodec` désactivé : tous les téléphones décodent le H.264,
    et la piste VP8 de secours aurait lancé un second encodage simulcast
    (trois couches VP8, préréglages SDK) sur l'hôte au premier abonné
    réclamant VP8 ;
  - journal de diagnostic **en debug uniquement**, toutes les 6 s :
    `live uplink <total> kb/s, rtt <ms>, <encodeur>: q 540x960 30fps
    690 kb/s - | h 1080x1920 30fps 1450 kb/s bandwidth`. À lire pendant le
    prochain test 4G : `h` absent ou à quelques centaines de kb/s = lien
    montant insuffisant ; `bandwidth` = limité par le réseau ; `cpu` =
    téléphone en surcharge ; nom de l'encodeur (`c2.exynos…`, `c2.qti…`) =
    encodage matériel ;
  - commentaires réalignés sur ce que fait vraiment libwebrtc (l'ancien
    texte attribuait à `balanced` une baisse de résolution sous pression de
    débit, inexacte en simulcast) ;
  - **caméra arrière par défaut** (accord utilisateur) : un live montre la
    boutique et les articles, et le capteur principal est plus grand et
    moins bruité que le capteur selfie (le bruit consomme des bits que la
    1080p n'a pas en 4G). Le bouton de bascule reste.
- **Coût data** : spectateur en 1080p jusqu'à ≈ 1,8 Go/h (4 Mb/s) contre
  ≈ 1,1 ; en 540p ≈ 0,3 Go/h. Facturation LiveKit Cloud au Go descendant en
  proportion.
- **Non fait, sur décision** : `maintainResolution` à la place de
  `balanced` (net mais saccadé sous surcharge CPU) ; chaîne serveur
  (Ingress WHIP/RTMP avec transcodage, ou Egress HLS) : seule façon de
  découpler les rendus spectateur du lien montant de l'hôte. Contraintes
  relevées sur LiveKit Cloud (tarifs du 2026-09-14) : plan Build gratuit =
  2 ingress simultanés et 60 min de transcodage par mois, donc 2 lives à la
  fois au maximum ; plan Ship 50 $/mois = 100 ingress simultanés, 600 min
  incluses puis 0,02 $/min vidéo (≈ 1,2 $ par heure de live) ; latence
  supplémentaire de l'ordre de 1 à 3 s ; et l'app hôte doit publier en WHIP
  (flutter_webrtc n'a pas de client WHIP, à écrire sur `RTCPeerConnection`).
- **Test** : hôte et spectateur sur la même 4G qu'avant, puis hôte en
  Wi‑Fi ; comparer le journal debug et la netteté. Version à reconstruire :
  l'AAB 1.6.0+13 porte encore l'échelle à trois couches.

### 2. Version 1.6.1+14

- `pubspec.yaml` : `1.6.0+13` → `1.6.1+14` (correctif : qualité du live ;
  `versionCode` 14, le 13 étant déjà envoyé sur Play).
- **Contenu de la version** (entrée 1 de ce jour) : live en 1080p mieux
  alimentée (échelle à deux couches 540p + 1080p, plafond 4 Mb/s), piste
  VP8 de secours retirée, caméra arrière par défaut, journal de diagnostic
  du lien montant en debug. Aucun changement backend : une app 1.6.0 reste
  compatible, le backend déployé le 2026-09-13 suffit.
- `docs/play-store-release.md` : valeur de version mise à jour.
- **Préflight** : `flutter analyze` sans erreur dans `lib/` (les deux
  avertissements préexistants du panneau compte demeurent) ; `flutter pub
  get` puis `flutter build appbundle --release` (build incrémental, sans
  `flutter clean` ; `flutter test` non relancé) →
  `build/app/outputs/bundle/release/app-release.aab`, 71,3 Mo, 14/09 16 h 35.
- **Texte « Nouveautés » Play Console** :
  « Lives plus nets : l'image HD reçoit désormais tout le débit disponible,
  et la caméra arrière est utilisée par défaut pour montrer la boutique. »

## 2026-09-18

### 1. Appels vocaux : l'appel ne sonne pas toujours, ou échoue au décrochage

- **Symptôme** (tests entre amis, Android) : parfois le téléphone appelé ne
  sonne pas ; parfois, après avoir décroché, l'appel « ne passe pas ».
- **Causes** :
  1. `chat_message_delivery_ping` (push data-only envoyé après chaque
     message de chat) partait en priorité **haute** sans jamais produire de
     notification visible. FCM rétrograde alors l'app en priorité normale,
     et la victime suivante est le push `incoming_call`, lui aussi data-only,
     dont le TTL est de 45 s : en veille (Doze), livré trop tard = jeté.
  2. App tuée, « Accepter » sur la notification native : le serveur
     n'apprenait l'acceptation qu'après le démarrage complet de l'app (moteur
     Flutter, session, socket, `GET /calls/:id` : 5 à 12 s en 4G). Décroché
     tard dans la fenêtre de 45 s, le minuteur serveur passait l'appel en
     `MISSED` avant, et `accept` répondait 409. De plus l'isolat d'actions du
     plugin (`callkitBackgroundHandler`) n'est démarré que par
     `registerBackgroundHandler`, appelé au démarrage de l'app : dans un
     processus réveillé par FCM il n'existait pas, donc même le refus depuis
     l'app tuée n'atteignait pas le serveur.
  3. `accept()` coupait l'appel au premier échec réseau de
     `POST /calls/:id/accept` (non rejoué car non idempotent), même quand le
     son passait déjà. Et quand l'appelé échouait après l'acceptation
     (LiveKit injoignable, micro refusé), rien ne le disait au serveur :
     l'appelant restait « en appel » dans le silence.
- **Correctif** :
  - `backend/.../push-notifications.service.ts` : ping de distribution en
    priorité `normal` (le push de chat qui le précède a déjà réveillé le
    téléphone ; en Doze, seule la coche « distribué » est retardée).
  - `backend/.../calls.service.ts` : `acceptCall` idempotent pour l'appelé
    (appel déjà `ACCEPTED` → 200 avec `url` / `token`, sans ré-émettre
    `call:accepted`) ; `getCall` remet aussi `url` / `token` à l'appelé quand
    l'appel est déjà `ACCEPTED`. Changements additifs : une app 1.6.1 se
    comporte comme avant.
  - `lib/services/push_notification_service.dart` : le handler FCM
    d'arrière-plan enregistre `callkitBackgroundHandler` juste après avoir
    affiché l'écran d'appel (idempotent) ; ce handler envoie désormais
    `accept` dès l'appui sur « Accepter », comme il le faisait pour le refus.
  - `lib/services/voice_call_service.dart` : `openIncomingCall(answered:
    true)` reconstruit aussi un appel déjà `ACCEPTED` et ne relance plus la
    sonnerie in-app (elle pouvait démarrer après `accept()`) ; `_sendAccept`
    rejoue l'acceptation jusqu'à 3 fois (6 s par essai) sur erreur réseau
    seulement, une réponse du serveur restant définitive ; tout échec de
    `accept()` envoie `POST /calls/:id/end` ; un `call:accepted` tardif ne
    remet plus le chronomètre à zéro.
- **Déploiement** : backend **avant** l'app (une nouvelle app face à
  l'ancien backend recevrait 409 sur la confirmation d'acceptation).
- **Connu, non traité ici** : entre l'acceptation anticipée et la fin du
  démarrage à froid, l'appelant voit l'appel « actif » quelques secondes sans
  son. Restent aussi ouverts : pas de service d'avant-plan pour l'appelant ni
  pour le décroché in-app, pas de capteur de proximité, appel manqué visible
  seulement par push + ligne de chat, ligne `ACCEPTED` orpheline (6 h).
- **Vérification** : `flutter analyze` (2 fichiers) et `tsc --noEmit` sans
  erreur. **Non testé sur appareil** : à valider app tuée / en fond / au
  premier plan, décroché tôt et tard (> 35 s), refus app tuée, coupure réseau
  au moment de décrocher.

### 2. Appels vocaux : bip et conseil quand la connexion devient instable

- **Demande** : pendant un appel, prévenir l'utilisateur que sa connexion
  est instable, par un bip et un texte.
- **Avant** : seule la pastille changeait (« Connexion instable » pendant
  une reconnexion LiveKit), et elle ne suivait que la qualité du
  **correspondant**. Téléphone contre l'oreille, rien n'était perçu.
- **Ajout** :
  - `lib/services/voice_call_service.dart` : le déclencheur est la
    **mauvaise qualité, lien toujours établi** (voix hachée, mots qui
    sautent), pas la coupure. Deux sources : (a) `isLinkDegraded`, mesuré
    sur la voix reçue avec le moniteur de stats de livekit
    (`AudioReceiverStatsEvent`, toutes les 2 s) : fenêtre dégradée dès 10 %
    de paquets perdus ou 100 ms de gigue ; 2 fenêtres dégradées pour lever
    l'alerte, 3 fenêtres saines pour la retirer (une rafale isolée ne bipe
    pas, un lien limite n'oscille pas) ; une fenêtre sans trafic
    (correspondant en sourdine) compte comme saine ; si le SFU juge le lien
    du **correspondant** faible, la dégradation lui est attribuée et rien
    n'est levé ici. (b) `localQuality`, verdict du SFU sur ce téléphone
    (`poor` / `lost` ; l'événement `ParticipantConnectionQualityUpdatedEvent`
    du participant local était ignoré), plus lent et plus indulgent que la
    mesure. `isConnectionUnstable` = appel actif et ((a) ou (b) ou
    reconnexion en cours, cas extrême déjà signalé « Connexion instable »
    auparavant). Chaque bascule écrit en debug « Voice call link degraded:
    loss x %, jitter y ms » : à lire avant de toucher aux seuils
    (`_degradedLossRatio`, `_degradedJitterMs`). Un écouteur unique sur `session`
    (`_syncUnstableAlert`) joue le bip à l'entrée dans l'état instable puis
    toutes les 5 s, avec un plancher de 4 s entre deux bips quand la qualité
    oscille, et se tait dès le retour à la normale ou la fin de l'appel.
  - `lib/services/call_tones.dart` : `playUnstableConnection` ; la lecture
    ponctuelle est factorisée dans `_playOnce` (partagée avec
    `playEndCall`), sur la route de l'appel (écouteur ou haut-parleur), sans
    prise de focus audio.
  - `assets/sounds/unstable_connection.wav` : double bip 440 Hz, 0,45 s,
    −14 dBFS (généré, libre de droits). Le dossier `assets/sounds/` est déjà
    déclaré dans `pubspec.yaml`.
  - `lib/page/call/voice_call_page.dart` : pastille « Connexion instable »
    (ambre) dans cet état, et dessous le conseil « Déplacez-vous vers un
    endroit où le réseau est meilleur. ».
- **Choix** : un réseau faible côté correspondant ne bipe pas et n'affiche
  pas le conseil (l'utilisateur n'y peut rien) ; la pastille continue de
  l'indiquer (« Réseau faible »).
- **Vérification** : `flutter analyze` sans erreur sur les 4 fichiers.
  **Non testé sur appareil** : appeler depuis une zone de réseau faible
  (1 à 2 barres, en mouvement, ou Wi‑Fi en limite de portée) sans couper la
  connexion ; vérifier le bip dans l'écouteur puis en haut-parleur, son
  arrêt environ 6 s après le retour d'un bon réseau, et la ligne debug pour
  juger les seuils.

### 3. Visionneuse d'images produit : description repliée (« Voir plus »)

- **Demande** : au-delà de 25 caractères, replier la description avec
  « … » comme sur Facebook, et l'afficher en entier au clic (voir plus /
  voir moins).
- **Avant** : la carte d'information avait déjà un état déplié au clic
  (`_isDescriptionExpanded`, remis à zéro à chaque changement de produit),
  mais il ne touchait que le titre et le fond : la description s'affichait
  toujours en entier, quelle que soit sa longueur.
- **Correctif** : `lib/page/image_viewer_page.dart` —
  `_ImageViewerOverlay._buildDescription` : jusqu'à 25 caractères, texte
  inchangé ; au-delà, les 25 premiers caractères (comptés en graphèmes, un
  emoji n'est jamais coupé ; sauts de ligne aplatis) suivis de « … Voir
  plus », et déplié, le texte entier suivi de « Voir moins ». Le clic reste
  celui de la carte (`onDescriptionTap`, inchangé). La carte dépliée est
  plafonnée à 45 % de la hauteur d'écran et défile à l'intérieur : une très
  longue description ne passe plus sous la barre du haut.
- **Vérification** : `flutter analyze` sans erreur. Non testé sur appareil.

## 2026-09-22

### 1. Version 1.6.2+15

- `pubspec.yaml` : `1.6.1+14` → `1.6.2+15` (correctifs : appels vocaux ;
  `versionCode` 15, le 14 étant déjà envoyé sur Play).
- **Contenu de la version** (entrées du 2026-09-18) : appel qui sonne plus
  sûrement (ping de distribution en priorité normale, acceptation envoyée
  dès l'appui sur « Accepter » depuis l'app tuée, acceptation rejouée sur
  erreur réseau), bip et conseil quand la connexion devient instable pendant
  un appel, description repliée « Voir plus » dans la visionneuse d'images
  produit.
- **Backend requis** : déployer le backend du 2026-09-18 (`calls.service.ts`
  : `acceptCall` idempotent, `push-notifications.service.ts`) **avant** de
  diffuser cette build, sinon la confirmation d'acceptation reçoit 409.
- `docs/play-store-release.md` : valeur de version mise à jour.
- **Préflight** : `flutter analyze lib` sans erreur (les deux avertissements
  préexistants du panneau compte demeurent) ; `flutter pub get` puis
  `flutter build appbundle --release` (build incrémental, sans
  `flutter clean` ; `flutter test` non relancé) →
  `build/app/outputs/bundle/release/app-release.aab`, 71,3 Mo, 22/09 13 h 54
  (Gradle 294 s).
- **Texte « Nouveautés » Play Console** :
  « Appels plus fiables : le téléphone sonne plus sûrement et le décrochage
  passe même en cas de réseau lent. Un bip vous prévient si la connexion
  devient instable pendant un appel. Descriptions longues repliées dans la
  visionneuse photo. »
- **Rappel** : les correctifs d'appel n'ont pas encore été validés sur
  appareil (voir l'entrée 1 du 2026-09-18) ; passer par la track interne
  avant la production.
- Envoyée sur Play le jour même ; les tests d'appel faits dessus ont donné
  les entrées 2 à 4, publiées en `1.6.3+16` (entrée 5).

### 2. Appelé : ça sonne et vibre, mais aucun appel entrant ne s'affiche

- **Symptôme** (test entre deux téléphones) : le téléphone appelé sonne et
  vibre, rien ne s'affiche ; l'appelant ne peut pas être décroché.
- **Cause** : conséquence directe du retrait de `USE_FULL_SCREEN_INTENT`
  exigé par Google (entrée 22 du 2026-09-13). Le plugin pose bien sa
  notification avec `setFullScreenIntent`, mais sans la permission Android
  l'ignore : `CallkitIncomingActivity`, la seule surface qui **allume
  l'écran**, n'est jamais lancée d'elle-même. Écran éteint → le téléphone
  sonne dans le noir ; écran allumé → seulement une bannière heads-up (fine
  bande sur Samsung en style « Bref »). Le cas « app au premier plan »
  (notre propre page) n'est pas concerné.
- **Correctif**, sans réintroduire la permission refusée :
  - `packages/banay_call_screen` (plugin Flutter local, Android) : une
    méthode `show(params)` reconstruit le `Bundle` du plugin
    (`Data(map).toBundle()`) et lance `CallkitIncomingActivity` nous-mêmes.
    Android 10+ n'autorise ce lancement depuis l'arrière-plan **que** si
    l'utilisateur a accordé « Afficher par-dessus d'autres applis »
    (`SYSTEM_ALERT_WINDOW`, déclaré dans le manifeste du plugin local).
    Plugin plutôt que canal dans `MainActivity` : il doit exister dans
    l'isolat FCM, celui qui fait sonner une app tuée. La notification reste
    posée telle quelle (`activeCalls`, reprise à froid, boutons inchangés) ;
    Accepter / Refuser sur l'écran rejoignent les mêmes broadcasts du
    plugin, et `clearIncomingNotification` (fin, refus, timeout) ferme aussi
    l'écran. Compilé contre `project(':flutter_callkit_incoming')`, câblé
    automatiquement par Flutter (`PluginHandler.configurePluginDependencies`)
    depuis la dépendance du `pubspec.yaml` du plugin.
  - `lib/services/incoming_call_native_ui.dart` : après
    `showCallkitIncoming`, sur Android, `_bringToScreen` tente l'écran plein
    écran ; sinon `FlutterForegroundTask.wakeUpScreen()` (déjà en dépendance,
    1 s de `SCREEN_BRIGHT_WAKE_LOCK | ACQUIRE_CAUSES_WAKEUP`) allume l'écran
    de verrouillage, où la notification Accepter / Refuser est visible.
  - `lib/services/call_screen_permission_service.dart` : demande unique
    (clé `call_screen_overlay_prompt_shown_v1`), précédée d'un court
    dialogue (titre / message dans les 7 langues,
    `callScreenPermissionTitle` / `callScreenPermissionMessage` ; boutons
    « Plus tard » / « Autoriser » existants), car le système n'offre qu'une
    page de réglages nue. `Permission.systemAlertWindow.request()` ouvre
    cette page et rend la main au retour.
  - `lib/main.dart` : `_showCallScreenPromptIfNeeded` après l'invite
    batterie, seulement avec une session valide (sinon reporté au lancement
    suivant la connexion).
- **Limites** : sur MIUI / ColorOS, un réglage OEM séparé (« fenêtres
  contextuelles en arrière-plan ») peut encore bloquer le lancement ; la
  notification et le réveil d'écran restent. Le dialogue n'est proposé
  qu'une fois : l'utilisateur qui a choisi « Plus tard » devra activer
  l'autorisation lui-même dans les réglages de l'app.
- **Vérification** : `flutter analyze` sans erreur ; AAB construit (entrée
  5). **Non testé sur appareil** : à valider écran éteint / verrouillé /
  allumé, app tuée et en fond, avec et sans l'autorisation ; vérifier que
  l'écran se ferme quand l'appelant raccroche et que le décroché depuis
  l'écran ouvre bien l'app en appel.

### 3. Appelant : l'écran reste allumé contre l'oreille

- **Symptôme** : pendant l'appel, l'écran ne s'éteint pas près de
  l'oreille ; la joue appuie sur les boutons (haut-parleur, raccrocher).
- **Cause** : aucune gestion du capteur de proximité ; au contraire
  `WakelockPlus.enable()` (`_markActive`) force l'écran allumé. Point noté
  « ouvert » dans l'audit du 2026-09-18.
- **Correctif** : dépendance `proximity_sensor` (^1.4.0).
  `lib/services/voice_call_service.dart` — écouteur de session
  `_syncProximity` : voulu quand l'appel n'est pas terminé, **pas en
  haut-parleur**, et (sortant, dès l'appui sur « appeler » : l'appelant
  écoute la tonalité) ou (entrant, à partir du décroché : pendant la
  sonnerie on regarde l'écran). Android : `setProximityScreenOff(true)`
  **avant** d'écouter le flux (le plugin acquiert alors
  `PROXIMITY_SCREEN_OFF_WAKE_LOCK`, celui du composeur du téléphone ; il
  l'emporte sur le keep-screen-on de `wakelock_plus`), libéré à
  l'annulation de l'abonnement ; iOS : l'écoute active
  `isProximityMonitoringEnabled`, l'OS fait le reste. Sans capteur, le flux
  émet une erreur journalisée et l'écran reste allumé. Bascule
  haut-parleur ↔ écouteur : le verrou est relâché puis repris.
- **Vérification** : `flutter analyze` sans erreur. **Non testé sur
  appareil** : écran noir contre l'oreille, retour à l'écran quand on
  l'éloigne, pas d'extinction en haut-parleur, écran rallumé à la fin.

### 4. Mise à jour Play jamais proposée sans redémarrage à froid

- **Symptôme** : après publication, l'app installée ne propose pas la mise
  à jour.
- **Causes possibles**, dans l'ordre à vérifier : (1) vérification faite
  uniquement au montage du shell, jamais au retour depuis l'arrière-plan ;
  un processus Android vit des jours sans démarrage à froid. (2) Version
  pas encore visible pour ce compte (test interne → testeurs seulement ;
  propagation Play de plusieurs heures). (3) Flux « flexible » (priorité
  Play < 4) : boîte Play puis snackbar, au plus une fois par 12 h. (4) App
  installée par USB / APK : `InAppUpdate.checkForUpdate()` lève une erreur
  avalée par le `catch` (installée depuis Play sur les téléphones de test,
  d'après l'utilisateur).
- **Correctif (1)** : `lib/component/main_navigation_shell.dart` —
  `WidgetsBindingObserver`, `checkForUpdate` aussi sur `resumed` ;
  `lib/services/app_update_service.dart` — au plus une vérification Play
  par 15 min (`_checkInterval`), la limite de 12 h entre deux invites
  demeure.

### 5. Version 1.6.3+16

- `pubspec.yaml` : `1.6.2+15` → `1.6.3+16` (correctifs : appels ;
  `versionCode` 16, le 15 étant déjà sur Play). Contenu : entrées 2 à 4 de
  ce jour. Aucun changement backend depuis le 2026-09-18.
- `docs/play-store-release.md` : valeur de version mise à jour.
- **Nouveau plugin local** `packages/banay_call_screen` (voir entrée 2) et
  nouvelle dépendance `proximity_sensor`. Nouvelle permission dans le
  manifeste fusionné : `SYSTEM_ALERT_WINDOW` (accès spécial accordé par
  l'utilisateur ; pas de formulaire de déclaration Play à ce jour).
- **Préflight** : `flutter analyze lib packages/banay_call_screen/lib` sans
  erreur (les deux avertissements préexistants du panneau compte demeurent) ;
  `flutter pub get` puis `flutter build appbundle --release` (incrémental,
  sans `flutter clean` ; `flutter test` non relancé) →
  `build/app/outputs/bundle/release/app-release.aab`, 71,3 Mo, 22/09 15 h 44
  encore en 1.6.2+15, reconstruit en 1.6.3+16 (heure ci-dessous, complétée
  après le build). Manifeste fusionné vérifié : `SYSTEM_ALERT_WINDOW` présent,
  `USE_FULL_SCREEN_INTENT` toujours absent ; `GeneratedPluginRegistrant`
  enregistre `BanayCallScreenPlugin` et `ProximitySensorPlugin` (donc aussi
  dans l'isolat FCM).
- **Texte « Nouveautés » Play Console** :
  « Appels plus fiables : le téléphone sonne plus sûrement, l'écran s'allume
  à l'arrivée d'un appel et le décrochage passe même en cas de réseau lent.
  L'écran s'éteint près de l'oreille pendant l'appel, et un bip vous
  prévient si la connexion devient instable. »
