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
