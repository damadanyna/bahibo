# Politique de confidentialite Banay

*Derniere mise a jour : [A COMPLETER avant publication, ex. 8 aout 2026]*

Cette politique de confidentialite decrit comment **Dama Dany**, exploitant
l'application sous le nom "Banay" ("nous"), collecte, utilise, partage et
protege les donnees des utilisateurs de l'application mobile Banay
("l'Application"). Aucune societe n'est encore immatriculee pour ce
projet : cette mention devra etre mise a jour avec la raison sociale des
qu'une entite sera formalisee.

La version publiee reellement en ligne se trouve dans le projet separe
`privacy_banay` (deploye sur `https://banay-privacy.surge.sh/index.html`,
URL referencee dans l'ecran de connexion de l'Application). Ce document-ci
est une reference plus detaillee sur les traitements de donnees identifies
dans le code (voir note technique en bas de page) ; utilise-la pour enrichir
la page live si besoin, elle n'est pas republiee automatiquement.

## 1. Qui sommes-nous

- Editeur : Dama Dany (exploitant individuel, entite non encore immatriculee)
- Adresse : [A COMPLETER]
- Contact vie privee : damadanyna@gmail.com
- Pays d'exploitation principal : Madagascar (l'Application est egalement
  disponible dans d'autres pays selon la configuration du compte)

## 2. Donnees que nous collectons

### 2.1 Donnees de compte et d'identification

- Numero de telephone, utilise pour la creation de compte et la verification
  par code a usage unique (OTP).
- Nom affiche et photo de profil (avatar), fournis volontairement par
  l'utilisateur lors de la creation ou de la modification de son profil.
- Role du compte (acheteur, vendeur/boutique).

### 2.2 Contenu que vous publiez ou echangez

- Produits publies par les vendeurs : titre, description, prix, categorie,
  photos.
- Messages de discussion (chat) entre acheteurs et vendeurs, y compris texte,
  photos et documents joints.
- Commentaires, mentions "j'aime" et abonnements a des boutiques.
- Panier et commandes.

### 2.3 Localisation

- Position approximative ou precise, uniquement lorsque vous utilisez
  volontairement le selecteur d'adresse (par exemple pour indiquer une
  adresse de livraison). L'Application ne suit pas votre position en
  arriere-plan.

### 2.4 Camera et microphone

- Utilises uniquement lorsque vous les activez explicitement : prise de
  photo pour un produit ou un message de discussion, ou demarrage d'une
  diffusion en direct ("Live Shopping"), qui transmet votre flux video/audio
  aux spectateurs de la diffusion.

### 2.5 Notifications

- Jeton d'appareil (Firebase Cloud Messaging) utilise pour vous envoyer des
  notifications push (nouveaux messages, mises a jour de commande,
  activite sur vos produits).

### 2.6 Donnees techniques et journaux serveur

- Adresse IP, type d'appareil/navigateur (user-agent), horodatage et
  chemin des requetes envoyees a nos serveurs, conserves a des fins de
  securite, de diagnostic et de support technique.
- Ces journaux sont conserves pendant une duree limitee (actuellement 14
  jours) puis supprimes automatiquement.

### 2.7 Mesure d'audience et stabilite (Firebase)

- Statistiques d'utilisation anonymisees/agregees (ecrans consultes,
  evenements d'usage) via Firebase Analytics, pour comprendre l'usage de
  l'Application et l'ameliorer.
- Rapports de plantage (crash reports) via Firebase Crashlytics, pour
  identifier et corriger les bugs.
- Ces services sont fournis par Google et peuvent impliquer un transfert de
  donnees vers les serveurs de Google. Voir la section 6.

## 3. Pourquoi nous utilisons ces donnees

- Creer et securiser votre compte (verification par OTP).
- Fournir les fonctionnalites principales : catalogue, publication de
  produits, discussion acheteur/vendeur, panier, commandes, diffusions en
  direct.
- Vous envoyer des notifications liees a votre activite dans l'Application.
- Assurer la securite du service, prevenir la fraude et les abus.
- Diagnostiquer les problemes techniques et ameliorer la stabilite et la
  performance de l'Application.
- Moderer le contenu genere par les utilisateurs (voir section 8).

Nous n'utilisons pas vos donnees a des fins de publicite ciblee et ne
vendons aucune donnee personnelle a des tiers.

## 4. Avec qui nous partageons des donnees

Nous ne partageons vos donnees qu'avec les prestataires necessaires au
fonctionnement de l'Application, chacun agissant comme sous-traitant :

| Prestataire        | Role                                              | Donnees concernees                          |
| ------------------- | -------------------------------------------------- | -------------------------------------------- |
| Cloudinary           | Hebergement des photos/documents (profil, produits, chat) | Fichiers media uploades                      |
| Google Firebase      | Notifications push, analytics, crash reporting     | Jeton d'appareil, evenements d'usage, crashs |
| LiveKit               | Infrastructure de diffusion video/audio en direct  | Flux video/audio pendant un live actif       |
| [A COMPLETER : hebergeur backend/serveur] | Hebergement de l'API et de la base de donnees | Toutes les donnees de compte et de contenu |

Nous pouvons egalement divulguer des donnees si la loi l'exige, ou pour
proteger les droits, la securite ou la propriete de Banay, de ses
utilisateurs ou du public.

## 5. Duree de conservation

- Les donnees de compte sont conservees tant que le compte est actif.
- Les messages et le contenu publie sont conserves tant qu'ils ne sont pas
  supprimes par l'utilisateur ou dans le cadre d'une moderation.
- Les journaux techniques serveur sont conserves 14 jours puis supprimes
  automatiquement.
- En cas de suppression de compte, les donnees personnelles identifiables
  sont supprimees ou anonymisees dans un delai raisonnable, sous reserve des
  obligations legales de conservation.

## 6. Transferts internationaux

Certains prestataires (Google Firebase, Cloudinary, LiveKit) peuvent traiter
des donnees en dehors de votre pays de residence. Ces prestataires
appliquent des garanties de protection des donnees reconnues (clauses
contractuelles types ou equivalent).

## 7. Securite

- Le numero de telephone et les jetons de session sont stockes de maniere
  chiffree sur l'appareil (stockage securise natif Android/iOS).
- Les communications entre l'Application et nos serveurs sont chiffrees en
  transit (HTTPS/TLS).
- L'acces aux donnees en interne est limite aux personnes qui en ont besoin
  pour exploiter le service.

## 8. Contenu genere par les utilisateurs et moderation

L'Application permet aux utilisateurs de signaler un contenu ou un
utilisateur, et de bloquer un autre utilisateur (dans les discussions).
Les signalements sont examines et peuvent entrainer la suppression du
contenu ou la suspension d'un compte en cas de violation des regles
d'utilisation.

## 9. Vos droits

Selon votre pays de residence, vous disposez de droits sur vos donnees
personnelles, notamment :

- Acceder aux donnees que nous detenons a votre sujet.
- Demander la correction de donnees inexactes.
- Demander la suppression de votre compte et des donnees associees.
- Vous opposer a certains traitements ou en demander la limitation.
- Demander la portabilite de vos donnees.

Pour exercer ces droits, contactez-nous a **[A COMPLETER : email de
contact]**. Vous pouvez egalement supprimer votre compte directement depuis
l'Application (onglet Messages > menu > "Supprimer mon compte"), ou suivre
la procedure decrite sur la page
[Suppression de compte](https://banay-privacy.surge.sh/account-deletion.html) si vous n'avez
plus acces a l'Application.

## 10. Mineurs

L'Application n'est pas destinee aux personnes de moins de [A COMPLETER,
ex. 16] ans. Nous ne collectons pas sciemment de donnees aupres d'enfants
en dessous de cet age. Si vous pensez qu'un enfant nous a fourni des
donnees personnelles, contactez-nous pour en demander la suppression.

## 11. Modifications de cette politique

Nous pouvons mettre a jour cette politique de confidentialite. Toute
modification substantielle sera signalee dans l'Application ou par
notification. La date de derniere mise a jour figure en haut de cette page.

## 12. Nous contacter

Pour toute question relative a cette politique ou a vos donnees
personnelles : **[A COMPLETER : email de contact]**.

---

### Note technique (a retirer avant publication)

Ce document liste les traitements de donnees identifies dans le code de
l'application au 2026-08-08 (auth OTP, profil, localisation, camera/micro
pour le Live Shopping, chat et media, notifications push Firebase,
Firebase Analytics/Crashlytics, Cloudinary, LiveKit, journaux serveur avec
retention 14 jours). A faire relire par un juriste avant publication,
notamment pour la conformite avec la reglementation applicable a Madagascar
et dans les autres pays ou l'Application est disponible, et pour completer
les champs `[A COMPLETER]` restants (raison sociale, adresse, age minimum).
La page live est `https://banay-privacy.surge.sh/index.html`, deja
referencee dans `lib/auth/phoneNumber.dart`.
