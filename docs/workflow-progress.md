# Bahibo Workflow Progress

Tableau d'avancement de reference pour suivre le workflow produit et technique.

## Legende

| Statut | Signification |
| --- | --- |
| Done | Termine et valide |
| In progress | En cours, partiellement livre |
| Next | Prochaine priorite |
| Later | Prevu pour une phase ulterieure |

## Vue Globale

| Phase | Chantier | Statut | Avancement | Notes |
| --- | --- | --- | --- | --- |
| Phase 1 | Fondation produit | In progress | 70% | Socle Flutter + NestJS + Prisma en place |
| Phase 2 | MVP metier | In progress | 35% | Auth, profils, catalogue, categories, cart, orders deja poses partiellement |
| Phase 3 | Media et live | In progress | 15% | Upload avatar Cloudinary branche, video/live pas encore faits |
| Phase 4 | Montee en charge | Later | 0% | Redis, jobs, observabilite, moderation, analytics, back-office |

## Workflow Detaille

| Ordre | Bloc | Statut | Ce qui est fait | Prochaine etape |
| --- | --- | --- | --- | --- |
| 1 | Authentification par numero | In progress | Saisie numero, OTP, verification OTP, session locale 30 jours, reconnexion automatique | Brancher un vrai provider SMS ou Firebase Phone Auth |
| 2 | Gestion des profils | In progress | Creation profil apres OTP, nom utilisateur, photo de profil, upload Cloudinary, avatarUrl persiste | Ajouter edition profil complete et remplacement/suppression avatar |
| 3 | Modele de donnees final | In progress | Prisma schema principal en place, auth/cart/orders/products/categories disponibles | Stabiliser migrations, contraintes et donnees manquantes |
| 4 | Catalogue + categories + vendeur | In progress | Endpoints categories et produits, seller profile public, shell principal avec product list | Finir les vues vendeur reelles et brancher les details API partout |
| 5 | Notifications + follow + likes + commentaires | In progress | Notifications de base presentes, UI sociale partiellement presente | Connecter likes/comments/follow au backend reel |
| 6 | Chat produit/vendeur | Next | UI chat deja presente cote Flutter | Creer backend chat et persistance messages |
| 7 | Panier + commandes | In progress | Modules cart, orders, shipments deja poses | Finaliser checkout et etats metier |
| 8 | Paiement | Later | Non commence | Choisir provider et flux MVP |
| 9 | Video postee | Later | Non commence | Definir Mux ou Cloudinary video |
| 10 | Live shopping | Later | Non commence | Definir Agora, 100ms ou IVS |
| 11 | Analytics vendeur et admin | Later | Non commence | Definir KPI et back-office |

## Detail Auth Et Profil

| Sujet | Statut | Details |
| --- | --- | --- |
| Choix langue au demarrage | Done | Si pas de session valide, l'app repasse par l'ecran language |
| Verification OTP | In progress | Verification OTP fonctionnelle; envoi SMS reel depend encore du provider configure |
| Session unique 30 jours | Done | Session locale glissante avec tentative de refresh au relancement |
| Redirection directe apres reconnexion | Done | Session valide envoie directement vers l'accueil |
| Nouveau compte sans mot de passe | Done | OTP valide puis nom/photo, sans saisie de mot de passe |
| Compte existant apres OTP | Done | Si numero deja connu, connexion directe apres OTP |
| Upload photo Cloudinary | In progress | Endpoint backend et upload Flutter branches; requiert variables Cloudinary dans backend/.env |

## Pre-requis Environnement

| Sujet | Statut | Notes |
| --- | --- | --- |
| PostgreSQL local | Required | Base Bahibo attendue par Prisma |
| Backend NestJS | Required | Port 4000 |
| URL Flutter vers IP locale PC | Done | Utilise l'IP LAN du PC pour telephone reel |
| Cloudinary | Required for avatar upload | CLOUDINARY_CLOUD_NAME, CLOUDINARY_API_KEY, CLOUDINARY_API_SECRET |
| Twilio | Optional | Requis seulement pour vrai envoi OTP SMS via backend |

## Prochain Sprint Recommande

| Priorite | Tache | Pourquoi |
| --- | --- | --- |
| P1 | Stabiliser l'onboarding numero + OTP + profil | C'est la porte d'entree de toute l'app |
| P1 | Finaliser persistance et affichage avatar Cloudinary | Necessaire pour un profil vendeur/client coherent |
| P2 | Brancher vraiment likes, comments, follow | Fait partie du coeur social du MVP |
| P2 | Connecter le chat au backend | Lot metier important apres auth/profil |
| P3 | Durcir migrations Prisma et seed | Evite les regressions data pendant la suite |
