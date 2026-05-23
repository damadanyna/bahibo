# Banay V1 Release Checklist

Checklist technique concrete pour publier une V1 Android exploitable avec son backend.

## 1. Gate de decision V1

- [ ] Le scope V1 est fige pour cette release: auth numero + OTP, profil, catalogue, vendeur, chat, panier/commandes minimales.
- [ ] Les blocs explicitement hors V1 restent desactives ou non exposes: paiement, video, live shopping, analytics admin avances.
- [ ] La version Flutter a ete decidee dans `pubspec.yaml`. Valeur actuelle: `1.0.2+3`.
- [ ] Le backend cible de production est connu et joignable en HTTPS.
- [ ] Un test interne sur appareil reel Android a deja ete passe avant soumission Play Store.

## 2. Backend production readiness

Variables minimales a remplir a partir de `backend/.env.example`:

```env
HOST=0.0.0.0
PORT=4000
NODE_ENV=production
DATABASE_URL="postgresql://..."
JWT_ACCESS_SECRET="..."
JWT_REFRESH_SECRET="..."
JWT_ACCESS_EXPIRES_IN="15m"
JWT_REFRESH_EXPIRES_IN="30d"
CLOUDINARY_CLOUD_NAME="..."
CLOUDINARY_API_KEY="..."
CLOUDINARY_API_SECRET="..."
```

Checklist:

- [ ] `NODE_ENV=production` sur le serveur cible.
- [ ] `DATABASE_URL` pointe vers la base prod et non vers localhost.
- [ ] Les secrets JWT ne sont plus sur les placeholders `change-me-*`.
- [ ] Les variables Cloudinary sont remplies si avatar/chat media sont exposes en V1.
- [ ] Si OTP SMS reel est attendu pour la V1, le provider choisi est configure et teste. Sinon, ne pas promettre l'envoi SMS prod.
- [ ] Le backend build sans erreur depuis `backend/`:

```powershell
npm install
npm run prisma:generate
npm run build
```

- [ ] L'endpoint de sante repond sur l'URL publique:

```text
GET https://<backend-host>/api/v1/health
```

- [ ] Les endpoints critiques repondent en prod: auth, products, categories, conversations, notifications, cart, orders.

## 3. API mobile et connectivite

Points a verifier:

- [ ] En release, l'application pointe bien vers `https://77.37.51.154/api/v1` sauf si tu fournis explicitement `--dart-define=BANAY_API_BASE_URL=...`.
- [ ] Le certificat TLS du backend prod correspond bien a l'hote cible si tu gardes le pinning de certificat.
- [ ] Les connexions HTTP classiques et Socket.IO passent sur appareil reel Android en 4G/Wi-Fi.
- [ ] Les scenarios de fallback dev ne fuitent pas en prod: `BANAY_DEV_HOST`, IP LAN locale, `localhost`, `10.0.2.2`.
- [ ] Le chat realtime se reconnecte correctement apres mise en veille, changement de reseau et relance de l'app.

## 4. Signature Android

- [ ] Le keystore d'upload existe hors Git, par exemple `keystores/upload-keystore.jks`.
- [ ] `android/key.properties` existe et est rempli a partir de `android/key.properties.example`.
- [ ] Le keystore et `android/key.properties` ne sont jamais commites.
- [ ] Le meme keystore sera conserve pour toutes les mises a jour futures.

Commande de generation initiale du keystore:

```powershell
keytool -genkeypair -v -keystore keystores/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

Commande pour recuperer les SHA:

```powershell
keytool -list -v -keystore keystores/upload-keystore.jks -alias upload
```

## 5. Android config critique

- [ ] Le package Android reste `com.banay.app`.
- [ ] `android/app/google-services.json` correspond bien au projet Firebase de production.
- [ ] La cle Google Maps est disponible via `android/local.properties` ou variable d'environnement `GOOGLE_MAPS_API_KEY`.
- [ ] Les notifications push Firebase sont configurees pour le package release.
- [ ] La version Play Store a ete incrementee avant build. Regle: `versionCode` doit toujours augmenter.

Regle simple de versioning:

- Correctif: `1.0.2+3` -> `1.0.3+4`
- Feature non cassante: `1.0.2+3` -> `1.1.0+4`
- Gros changement produit: `1.0.2+3` -> `2.0.0+4`

## 6. Validation fonctionnelle V1

Avant publication, verifier au minimum sur un APK/AAB release installe depuis la track interne:

- [ ] Premier lancement sans session: langue -> numero -> OTP -> creation profil.
- [ ] Reconnexion automatique avec session existante.
- [ ] Upload avatar et affichage profil.
- [ ] Chargement home, categories, liste produits, detail produit.
- [ ] Navigation vendeur et ouverture du profil vendeur.
- [ ] Ouverture d'une conversation produit/vendeur.
- [ ] Envoi message texte, reception realtime, delivered/read, reouverture apres fermeture.
- [ ] Notification recue puis ouverture de l'ecran cible.
- [ ] Panier minimal et creation de commande si ce parcours fait partie de la V1.
- [ ] Aucun appel reseau critique ne casse si le backend redemarre ou si le reseau change.

## 7. Build et preflight

Depuis la racine du projet:

```powershell
flutter clean
flutter pub get
flutter analyze
flutter build appbundle --release
```

Sortie attendue:

```text
build/app/outputs/bundle/release/app-release.aab
```

Preflight final:

- [ ] `flutter analyze` ne remonte aucun blocage release.
- [ ] Le `.aab` est genere sans erreur de signature.
- [ ] Le backend prod est deja deploye avant de diffuser la build test.
- [ ] Une installation manuelle de la build release sur appareil reel a ete validee.

## 8. Play Console

- [ ] L'application Play Console existe pour `com.banay.app`.
- [ ] Store listing, icone, captures, politique de confidentialite, data safety et content rating sont completes.
- [ ] Play App Signing est active.
- [ ] Le premier envoi part sur la track `internal testing`.
- [ ] Le test interne valide install, login, chat, notifications et upgrade.
- [ ] Seulement apres validation, promotion en closed/open/prod.

## 9. Commandes de release recommandees

Backend:

```powershell
Set-Location .\backend
npm install
npm run prisma:generate
npm run build
```

Mobile:

```powershell
Set-Location ..
flutter clean
flutter pub get
flutter analyze
flutter build appbundle --release
```

## 10. Sortie attendue avant publication

Tu peux considerer la V1 techniquement prete quand les points suivants sont tous vrais:

- [ ] Backend prod build + healthcheck OK.
- [ ] Secrets et services externes prod OK.
- [ ] Build Android release signe OK.
- [ ] Test interne sur appareil reel OK.
- [ ] Listing Play Console complet.
- [ ] Version `pubspec.yaml` incrementee pour cette release.

## 11. Bloquants V1 restants

### Must-have avant publication

- [ ] Trancher le parcours OTP prod: soit Twilio/Firebase Phone Auth est configure et teste, soit la promesse produit est reduite pour ne pas vendre un SMS reel non branche.
- [ ] Renseigner et valider les variables prod backend critiques: `DATABASE_URL`, secrets JWT, Cloudinary et tout secret Firebase necessaire aux notifications.
- [ ] Verifier le backend prod en conditions reelles: build OK, `/api/v1/health` OK, endpoints critiques auth/catalog/chat/cart/orders OK.
- [ ] Verifier le reseau mobile release de bout en bout: HTTPS, certificat cible, Socket.IO, reprise apres changement de reseau et reprise apres relance.
- [ ] Fermer la validation chat sur appareil reel: ouverture conversation, envoi/reception, delivered/read, reprise des messages locaux, retour apres fermeture.
- [ ] Valider le parcours onboarding/profil sur build release: premier lancement, reconnexion, creation profil, upload avatar, retour session.
- [ ] Produire un `.aab` signe installable et le tester au moins sur la track interne Play Store.

### Can-slip si la V1 doit sortir vite

- [ ] Polissage likes, comments et follow tant que le flux principal catalogue -> produit -> chat reste stable. Le repo a deja des endpoints et du code UI pour ces blocs.
- [ ] Raffinements checkout et etats metier secondaires si le panier minimal et la creation de commande fonctionnent deja pour le scope retenu.
- [ ] Optimisations de notifications non critiques tant que les notifications essentielles ouvrent bien l'ecran cible.
- [ ] Edition profil avancee ou confort UX supplementaire si creation profil et avatar fonctionnent deja.
- [ ] Durcissement data non bloquant et seed de confort si les migrations actuelles permettent un deploy propre de la V1.

### Hors V1

- [ ] Paiement en ligne.
- [ ] Video postee.
- [ ] Live shopping.
- [ ] Analytics vendeur/admin avances.
