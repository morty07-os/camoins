# Historique et confirmation de réception

## Diagnostic constaté

Le parcours existant est `CustomerHistoryPage → ApiService.getTripHistory → GET /api/trips/history → authMiddleware → transport_requests.customer_id → HistoryResponse`.
La route historique précède `/api/trips/:id`, accepte les clients et filtre correctement leurs demandes `COMPLETED`. Les nombres SQLite sont compatibles avec les modèles Flutter ; la date n'empêche pas le chargement.

La base locale, examinée en lecture seule, contient deux demandes `ACCEPTED`, deux `PENDING`, une `CANCELLED` et aucune `COMPLETED`. Aucun trajet n'y est terminé non plus. Cela explique l'historique vide observé dans ces données ; aucun refus d'accès client à cette route n'a été reproduit. Les anciens enregistrements terminés sont couverts par un test de migration et d'API.

Deux défauts du frontend ont été corrigés : toutes les erreurs HTTP ou de décodage étaient remplacées par « Cannot connect to the server », et l'historique déjà ouvert n'était pas actualisé après un changement de transport. L'écran vide explique maintenant la confirmation nécessaire et propose d'ouvrir les conversations.

## Parcours et endpoints

- `POST /api/trips/:id/complete` : chauffeur propriétaire uniquement ; termine le trajet physique `IN_PROGRESS → COMPLETED` et place chaque demande acceptée dans `AWAITING_CUSTOMER_CONFIRMATION`.
- `POST /api/requests/:id/complete` : même contrôle de propriété, mais termine seulement la livraison associée ; conserve la sémantique de l'action individuelle existante.
- `POST /api/requests/:id/confirm` : client propriétaire uniquement ; `AWAITING_CUSTOMER_CONFIRMATION → COMPLETED`.
- `GET /api/conversations/:id` : participants uniquement ; fournit le statut persistant, les identifiants et les horodatages nécessaires à la carte.
- `GET /api/trips/history` : conserve l'historique client par demande ; le chauffeur voit aussi les livraisons confirmées individuellement avant la clôture du trajet partagé.

Chaque transition écrit ensemble le statut, l'horodatage, le message système et la notification dans une transaction `BEGIN IMMEDIATE`. Les événements Socket.IO sont émis après validation de la transaction. Les tentatives répétées ne créent pas de doublons. Aucune capacité n'est modifiée par la finalisation ou la confirmation.

La conversation reste unique par `request_id`, même pour plusieurs demandes entre les mêmes personnes. Les notifications utilisent les champs existants `request_id`, `trip_id`, `conversation_id`, exposés en camelCase dans Flutter. Les demandes en attente de confirmation restent accessibles dans Messages. Les demandes refusées ou annulées sont exclues ; les demandes non acceptées sont annulées lors de la clôture du trajet, comme auparavant, avec leur notification d'annulation.

## Migration

Au prochain démarrage du backend, migration SQLite idempotente : élargissement de la contrainte de statut, ajout de `driver_finished_at`, `customer_confirmed_at` et `messages.is_system`. Les dates utilisent `CURRENT_TIMESTAMP` SQLite (UTC), comme les autres écritures du projet.

La reconstruction de la table conserve les colonnes, identifiants, lignes, index, triggers et références, avec contrôle des clés étrangères. Aucun ancien `COMPLETED` n'est converti. Ses nouveaux horodatages restent `NULL`. La base réelle n'a pas été migrée ni réinitialisée pendant ce travail ; les tests utilisent des bases temporaires.

## Vérifications

- Suite backend `npm test` réussie ; test de finalisation enrichi puis réexécuté avec succès.
- Tests backend : anciens historiques, migration et dépendances, rollback sur échec de notification, authentification, propriété, transitions interdites, requêtes concurrentes, isolation de plusieurs clients/demandes, capacité inchangée, redémarrages, messages persistants, identifiants de navigation et événements Socket.IO réellement reçus.
- Tests Flutter ajoutés : requête d'historique authentifiée, parsing des nombres SQLite, distinction HTTP/JSON, bouton réservé au client propriétaire, confirmation et réouverture, navigation directe depuis la notification, actualisation d'un historique déjà monté et isolation lors du changement de conversation.
- Suite Flutter finale : 37 tests réussis, dont cinq nouveaux tests du parcours de confirmation.
- `flutter analyze` : aucune anomalie.
- `git diff --check` : réussi.

À vérifier manuellement sur appareils : présentation sur petits écrans, parcours avec deux comptes réels, mise en arrière-plan/reprise et interruption réseau réelle. Le push d'arrière-plan n'est pas configuré : le code FCM existant est commenté. Socket.IO fonctionne lorsque l'application est connectée ; les notifications et confirmations manquées sont restaurées par l'API à la réouverture/reconnexion.

## Fichiers modifiés ou ajoutés

Backend :

- `backend/completion.js`
- `backend/database.js`
- `backend/models.js`
- `backend/server.js`
- `backend/test/completion.test.js`
- `backend/test/booking-integrity.test.js`
- `backend/test/ratings.test.js`

Frontend :

- `frontend/lib/models/conversation.dart`
- `frontend/lib/models/transport_request.dart`
- `frontend/lib/pages/chat_page.dart`
- `frontend/lib/pages/customer_history_page.dart`
- `frontend/lib/pages/driver_history_page.dart`
- `frontend/lib/pages/driver_requests_page.dart`
- `frontend/lib/pages/messages_page.dart`
- `frontend/lib/pages/return_trip_details_page.dart`
- `frontend/lib/providers/notification_provider.dart`
- `frontend/lib/providers/transport_updates_provider.dart`
- `frontend/lib/services/api_service.dart`
- `frontend/lib/services/chat_repository.dart`
- `frontend/lib/services/notification_navigation_service.dart`
- `frontend/test/completion_test.dart`
- `frontend/test/notification_provider_test.dart`

Compte rendu : `COMPLETION_WORKFLOW.md`.
