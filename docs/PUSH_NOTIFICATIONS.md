# Notifications push — guide complet (Firebase + Supabase)

Flux : **création d’événement** → app Flutter appelle la **Edge Function** `notify-on-event` → la fonction calcule les destinataires (comme `PermissionService.canSeeEvent`) → **Firebase Admin** envoie **FCM** → les appareils avec token en base reçoivent la notif.

Les **rappels** (veille pour quiconque peut voir l’événement ; J-7 et J-3 pour les inscrits **Je participe**) partent de **`event-reminders`**, appelée **1× par jour** par un cron — voir § 2.7.

La notification affiche le **titre de l’événement** et un **texte** avec association (« Par … »), **catégorie** (libellé français), **date/heure** (`event_date`, format `fr-FR`) et **lieu** si présents.

Pour un événement **privé**, le titre est préfixé **`Privé ·`** et le corps rappelle que la notif est destinée aux **responsables** (toute association) **et administrateurs** — aligné avec `PermissionService` / liste des événements.

**Élargissement de visibilité** (modification d’un événement) : si la visibilité passe **privé → restreint**, **privé → public** ou **restreint → public**, une notif est envoyée uniquement aux utilisateurs qui **gagnent** l’accès (pas ceux qui le voyaient déjà). Le **texte de la notif** est le **même format** qu’à la création (titre + détails).

**Important :** le **créateur** de l’événement **ne reçoit pas** la notif (création ni élargissement). Pour tester, utilise **un autre compte** / **un autre téléphone** qui a le droit de voir l’événement.

---

## 1. Firebase (console + projet Android)

### 1.1 Projet et application Android

1. [Firebase Console](https://console.firebase.google.com) → créer / choisir le projet lié à ton app.
2. **Ajouter une app Android** si ce n’est pas fait :
   - **Package name** = `com.eventsphere.eventsphere` (identique à `applicationId` dans `android/app/build.gradle.kts`).
3. Télécharger **`google-services.json`** et le placer dans **`android/app/google-services.json`**.

### 1.2 FCM / API Google Cloud

1. Dans Firebase : **Paramètres du projet** → onglet **Cloud Messaging**.
2. Si demandé, activer **Firebase Cloud Messaging API** (souvent via lien vers **Google Cloud Console** pour le même projet).
3. Les notifications **données + notification** utilisent FCM v1 (Firebase Admin côté Supabase).

### 1.3 Fichier `firebase_options.dart` (Flutter)

À la racine du projet :

```bash
dart pub global activate flutterfire_cli
flutterfire configure
```

Sélectionner ce projet Firebase et l’app **Android**. Cela met à jour **`lib/firebase_options.dart`**.

### 1.4 Compte de service (pour Supabase Edge Function)

1. Firebase → **Paramètres du projet** → **Comptes de service**.
2. **Générer une nouvelle clé privée** (JSON). **Ne pas** commiter ce fichier.
3. Tu en auras besoin pour le secret **`FIREBASE_SERVICE_ACCOUNT`** sur Supabase (section 2).

---

## 2. Supabase

### 2.1 Table des tokens FCM

1. Dashboard → **SQL Editor**.
2. Exécuter le contenu de **`supabase/migrations/20250318120000_user_fcm_tokens.sql`** (table `user_fcm_tokens` + RLS : chaque utilisateur ne gère que ses lignes).

### 2.2 Secret Firebase pour la fonction

Dans un terminal (CLI Supabase connectée au projet) :

```bash
supabase secrets set FIREBASE_SERVICE_ACCOUNT='<colle ici le JSON sur une ligne ou utilise la méthode fichier selon la doc CLI>'
```

Sous Windows PowerShell, coller un gros JSON est pénible : utilise parfois un fichier temporaire ou le **dashboard** : **Project Settings → Edge Functions → Secrets** → ajouter `FIREBASE_SERVICE_ACCOUNT` avec le JSON complet.

### 2.3 Déployer la fonction + config

Depuis la racine du dépôt (avec `supabase link` déjà fait) :

```bash
supabase functions deploy notify-on-event
```

Le fichier **`supabase/config.toml`** définit **`verify_jwt = false`** pour cette fonction (évite des **401** à la passerelle). **L’authentification reste obligatoire dans le code** (`getUser` + créateur ou admin).

À chaque modification de **`index.ts`** ou **`config.toml`**, **redéployer** avec la commande ci-dessus.

### 2.4 Visibilité « privé » et RLS sur `events`

Si ta politique **SELECT** sur `events` n’autorisait les lignes `private` qu’aux responsables **de l’association de l’événement**, mets-la à jour : les événements privés doivent être visibles par **tout compte responsable** (au moins une ligne `memberships` avec `role = 'responsible'`) et les **admins**. La migration **`20250330140000_is_responsible_anywhere.sql`** ajoute `is_responsible_anywhere(auth.uid())` pour t’aider ; exécute-la puis adapte ta politique RLS existante.

### 2.5 Variables automatiques

`SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY` sont injectées automatiquement dans l’environnement des Edge Functions : rien à copier à la main pour celles-ci.

### 2.6 App Flutter — `.env`

Même projet que le dashboard :

- `SUPABASE_URL` = URL du projet (ex. `https://xxxxx.supabase.co`)
- `SUPABASE_ANON_KEY` = clé **anon** **public** (Settings → API)

Sans guillemets superflus autour des valeurs (le code fait un trim).

### 2.7 Rappels automatiques (`event-reminders`)

La migration **`20250330180000_event_push_reminders.sql`** crée la table **`event_push_reminders`** (anti-doublon) et la RPC **`get_events_needing_reminders`** (rôle **service_role** uniquement).

| Rappel | Quand (fuseau **Europe/Paris**) | Destinataires |
|--------|----------------------------------|---------------|
| **Veille** | Date de l’événement = **demain** | Tous les comptes qui **peuvent voir** l’événement (même logique que `notify-on-event`, sans exclure le créateur). |
| **J-7** | Dans **7 jours** | Uniquement les utilisateurs ayant cliqué **Je participe**. |
| **J-3** | Dans **3 jours** | Idem participations. |

1. Secret dédié (long, aléatoire) :

   ```bash
   supabase secrets set EVENT_REMINDERS_CRON_SECRET='génère une chaîne longue et garde-la secrète'
   ```

2. Déployer la fonction :

   ```bash
   supabase functions deploy event-reminders
   ```

3. **Planifier un appel HTTP une fois par jour** (ex. 7h30 heure de Paris → ~5h30 ou 6h30 UTC selon l’été/hiver), par exemple :
   - [Supabase Scheduled Functions](https://supabase.com/docs/guides/functions/schedule-functions) (si dispo sur ton plan), ou
   - `pg_cron` + `pg_net`, GitHub Actions, cron serveur, etc.

   Requête :

   ```http
   POST https://<PROJECT_REF>.supabase.co/functions/v1/event-reminders
   Authorization: Bearer <EVENT_REMINDERS_CRON_SECRET>
   Content-Type: application/json
   ```

   Corps vide `{}` suffit. **Ne pas** utiliser la clé anon : seul le secret configuré est accepté.

Les notifications utilisent le même canal FCM Android que les créations d’événements ; `data.notify_kind` vaut `reminder_day_before`, `reminder_participant_7d` ou `reminder_participant_3d`.

---

## 3. Tester sur Android

1. **Émulateur avec Google Play** (ou un vrai téléphone).
2. `flutter run` sur cet appareil (pas seulement Windows desktop : FCM n’y est pas initialisé).
3. Se connecter, **accepter les notifications** (Android 13+).
4. Vérifier en base qu’une ligne apparaît dans **`user_fcm_tokens`** pour cet utilisateur.
5. Avec **un autre** utilisateur (qui peut voir l’événement), créer un événement : le premier doit recevoir la notif.

---

## 4. Dépannage rapide

| Symptôme | Piste |
|----------|--------|
| Pas de ligne dans `user_fcm_tokens` | Permissions notif, Play Services, `google-services.json`, `firebase_options.dart`. |
| Function **401** avec `execution_id` null | Redéployer avec le `config.toml` du repo (`verify_jwt = false`). |
| Function **401** avec logs `getUser failed` | Session expirée ; se reconnecter ; vérifier `.env`. |
| Réponse **200** et `sent: 0`, `no tokens` | Destinataires sans token en base ; tester avec le 2e compte connecté sur Android. |
| **500** dans la fonction | Secret `FIREBASE_SERVICE_ACCOUNT` manquant / JSON invalide ; logs Edge Function. |
| Créateur ne reçoit rien | Comportement voulu ; tester avec un autre utilisateur. |
| **`event-reminders` 401** | Vérifier `Authorization: Bearer` = exactement `EVENT_REMINDERS_CRON_SECRET` (pas la clé anon). |
| Rappels jamais reçus | Cron non planifié ; secret non défini ; `event_date` null ; fuseau Paris : date ≠ J-1 / J-3 / J-7. |

---

## 5. Évolution possible

Déclencher l’envoi via **Database Webhook** sur `INSERT` dans `events` (ou **pg_net**) pour ne plus dépendre de l’appel client après insert — plus fiable si l’événement est créé ailleurs.
