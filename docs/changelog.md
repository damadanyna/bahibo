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
