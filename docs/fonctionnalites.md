# Fonctionnalites de l'application Bahibo

## Resume global

Bahibo est une application mobile de social commerce (marketplace + messagerie) orientee experience vendeur/acheteur.

## Fonctionnalites principales

1. Authentification par numero + OTP, avec reconnexion automatique et gestion de session.
2. Onboarding utilisateur avec choix de langue, creation de profil et photo avatar (upload Cloudinary en cours de stabilisation).
3. Navigation principale en 4 onglets: Accueil, Recherche, Messages, Compte.
4. Catalogue produits et categories, avec vues produit et espace vendeur.
5. Messagerie temps reel acheteur-vendeur, avec persistance locale, outbox, statuts envoye/distribue/vu, badge non lus et push notifications.
6. Notifications in-app (dont feedback utilisateur vers admin).
7. Panier, commandes et expeditions deja poses mais encore en finalisation cote parcours complet.
8. Localisation (permission + synchro position) pour contextualiser l'experience (proximite/livraison).
9. Support multi-langue et theme clair/sombre.
10. Backend modulaire (auth, profils, produits, categories, chat, notifications, recherche, panier, commandes, expeditions) avec API versionnee.

## Etat actuel

1. MVP en cours, avec socle technique en place.
2. Les briques coeur (auth, catalogue, chat, commandes) existent deja.
3. Paiement, video/live shopping et analytics avances restent majoritairement a implementer.
