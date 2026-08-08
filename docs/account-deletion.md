# Suppression de compte Banay

*Publiee a l'adresse `https://banay-privacy.surge.sh/account-deletion.html`
(projet separe `privacy_banay`, accessible sans avoir l'application
installee). Cette page est exigee par la politique "Account Deletion" de
Google Play des lors qu'une application permet la creation de compte.*

## Option 1 : depuis l'application (recommande)

1. Ouvrez l'application Banay et connectez-vous.
2. Depuis l'onglet Messages, appuyez sur l'icone **⋮** (menu) en haut a
   droite.
3. Appuyez sur **Supprimer mon compte**.
4. Confirmez dans la boite de dialogue.

La suppression est immediate : votre compte est desactive, vous etes
deconnecte de tous vos appareils, et vous ne pouvez plus vous reconnecter
avec ce numero de telephone.

## Option 2 : sans l'application installee

Si vous n'avez plus acces a l'application, envoyez une demande de
suppression a **damadanyna@gmail.com** en indiquant le numero de telephone
utilise pour creer le compte.

Nous traiterons votre demande sous **30 jours**.

## Quelles donnees sont supprimees

- Numero de telephone, nom affiche, photo de profil, photo de couverture,
  localisation enregistree.
- Vos jetons de connexion : vous etes deconnecte de tous vos appareils.
- Vos notifications push sont desactivees.

## Quelles donnees sont conservees, et pourquoi

Certaines donnees sont conservees pour des raisons legales, de securite ou
de bon fonctionnement du service pour les autres utilisateurs, conformement
a la [politique de confidentialite](https://banay-privacy.surge.sh/index.html) :

- **Commandes passees** : conservees pour la comptabilite et la gestion des
  litiges, mais votre profil associe est anonymise ("Utilisateur
  supprime").
- **Messages de discussion deja envoyes** : conserves pour ne pas alterer
  l'historique de conversation de vos interlocuteurs, mais votre profil
  associe est anonymise.
- **Produits publies** : retires de la vente (masques du catalogue) plutot
  que supprimes, si des commandes y sont rattachees.
- **Journaux techniques serveur** : conserves au maximum 14 jours puis
  supprimes automatiquement, quelle que soit la date de suppression du
  compte.

## Delai de traitement

La suppression declenchee depuis l'application est immediate. Une demande
envoyee par email est traitee sous **30 jours**.

---

### Note technique

Correspond a l'endpoint backend `DELETE /profiles/me`
(`ProfilesService.deleteOwnAccount`, `backend/src/modules/profiles/`) et au
bouton "Supprimer mon compte" dans le menu de l'onglet Messages
(`lib/page/navigation/main_navigation_messages_panel.dart`). L'option 2
(email) n'a pas d'automatisation backend a ce jour : elle doit etre traitee
manuellement par un administrateur via l'admin panel ou un acces direct a
la base de donnees jusqu'a ce qu'un outil dedie existe. La version HTML
publiee vit dans le projet separe `privacy_banay/account-deletion.html`
(pas republiee automatiquement depuis ce fichier).
