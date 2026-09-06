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
