# Mobile Integration Guide — Step 4: Meccanica Cuori
> JellyMix API · Prerequisito: Step 3 integrato

---

## Panoramica

Questo step aggiunge la meccanica dei **cuori scambiati tra amici**:

- Inviare un cuore a un amico (push notifica al destinatario)
- Richiedere cuori a tutti gli amici in batch (push a tutti gli amici)
- Evadere una richiesta cuore ricevuta
- Consumare un cuore quando si perde un livello
- Endpoint pubblico per leggere i parametri di configurazione

> **Nota architetturale:** `heartsCount` è il contatore server-side dei cuori ricevuti dagli amici. La ricarica automatica dei cuori nel tempo è gestita **solo lato client** tramite `lastHeartConsumedAt` + `heartRechargeMinutes` (già integrato nello Step 1).

---

## Base URL e Auth

Tutti gli endpoint (tranne `GET /hearts/config`) richiedono `Authorization: Bearer <firebase_id_token>`.

---

## 1. Parametri Configurazione Cuori

### `GET /hearts/config` — Pubblico, no token

```
GET /hearts/config
→ 200 OK
{
  "heartRechargeMinutes": 30,
  "maxHearts": 5,
  "maxHeartsReceivedPerDay": 10
}
```

**Quando chiamare:** all'avvio dell'app, prima di mostrare la UI dei cuori. Usare `heartRechargeMinutes` per il timer di ricarica locale.

---

## 2. Inviare un Cuore a un Amico

### `POST /hearts/send/:friendId`

```
POST /hearts/send/550e8400-e29b-41d4-a716-446655440000
Authorization: Bearer <token>
→ 204 No Content
```

**Comportamento:**
- Il server verifica che `friendId` sia un amico dell'utente corrente
- Max 1 cuore al giorno per coppia (sender → receiver)
- Il receiver deve avere `heartsCount < maxHearts`
- Il receiver non deve aver raggiunto `maxHeartsReceivedPerDay`
- Se tutte le condizioni sono soddisfatte, `receiver.heartsCount` viene incrementato di 1
- Una push notification viene inviata al receiver

**Errori possibili:**
| Status | Messaggio | Azione consigliata |
|--------|-----------|-------------------|
| 403 | Puoi inviare cuori solo agli amici | Nascondere pulsante per non-amici |
| 409 | Hai già inviato un cuore oggi a questo amico | Disabilitare pulsante fino a mezzanotte |
| 409 | Il giocatore ha già il massimo dei cuori | Mostrare "cuori pieni" |
| 409 | Il giocatore ha raggiunto il limite giornaliero | Mostrare "limite raggiunto oggi" |

**Gestione UI:**
```
// Pattern ottimistico
sendHeartButton.isEnabled = false   // Disabilita immediatamente
try {
  await api.sendHeart(friendId)
  // Successo — mantieni disabilitato per oggi
} catch (e) {
  // Ripristina se errore
  sendHeartButton.isEnabled = true
  showError(e.message)
}
```

---

## 3. Richiedere Cuori a Tutti gli Amici

### `POST /hearts/request`

```
POST /hearts/request
Authorization: Bearer <token>
→ 201 Created
{
  "requested": 3
}
```

**Comportamento:**
- Crea/aggiorna una `HeartRequest` per ogni amico (scade in 24 ore)
- Invia una push notifica batch a tutti gli amici tramite FCM multicast
- Se non ci sono amici: `{ "requested": 0 }` (nessuna push)
- Se già esiste una richiesta per un amico, viene aggiornata (`expiresAt` + `status` → PENDING)

**Quando chiamare:** quando il giocatore ha cuori ≤ 0 o sta per finirli. Mostrare il numero di amici notificati.

---

## 4. Vedere le Richieste Cuore Ricevute

### `GET /hearts/requests/incoming`

```
GET /hearts/requests/incoming
Authorization: Bearer <token>
→ 200 OK
[
  {
    "id": "req-uuid-1",
    "status": "PENDING",
    "expiresAt": "2026-05-18T08:00:00.000Z",
    "createdAt": "2026-05-17T08:00:00.000Z",
    "requester": {
      "id": "user-uuid",
      "playerNumber": 42,
      "displayName": "Player42",
      "avatarCode": "avatar_01"
    }
  }
]
```

**Nota:** restituisce solo le richieste `PENDING` non scadute. Se la lista è vuota, nessun amico ha richiesto cuori attivamente.

---

## 5. Evadere una Richiesta Cuore

### `POST /hearts/fulfill/:requestId`

```
POST /hearts/fulfill/req-uuid-1
Authorization: Bearer <token>
→ 204 No Content
```

**Comportamento:**
- Verifica che la richiesta sia destinata all'utente corrente
- Applica tutta la logica di `sendHeart` (cap giornalieri, maxHearts, amicizia)
- Marca la `HeartRequest` come `FULFILLED`

**Errori possibili:**
| Status | Messaggio | Azione consigliata |
|--------|-----------|-------------------|
| 403 | Non puoi evadere questa richiesta | Non mostrare mai questo (filtrare lato client) |
| 404 | Richiesta non trovata | Aggiornare la lista |
| 409 | Richiesta non più in stato PENDING | Aggiornare la lista (già evasa) |
| 400 | Richiesta scaduta | Aggiornare la lista |
| 409 | Il giocatore ha già il massimo dei cuori | Mostrare "cuori pieni" all'amico |

**Flusso UI consigliato:**
1. `GET /hearts/requests/incoming` → mostro lista amici che chiedono cuori
2. Utente preme "Invia cuore" su un amico
3. `POST /hearts/fulfill/:requestId` → 204
4. Rimuovere la riga dalla lista

---

## 6. Consumare un Cuore

### `POST /hearts/consume`

```
POST /hearts/consume
Authorization: Bearer <token>
→ 200 OK
{
  "heartsCount": 4,
  "lastHeartConsumedAt": "2026-05-17T08:30:00.000Z"
}
```

**Quando chiamare:** immediatamente dopo che il giocatore **perde** un livello (non quando completa).

**Comportamento client:**
1. Chiamare `POST /hearts/consume`
2. Aggiornare `heartsCount` locale con il valore restituito
3. Aggiornare il timer di ricarica con `lastHeartConsumedAt`
4. Se `heartsCount == 0`: mostrare schermata "cuori finiti" + pulsante "Chiedi agli amici"

**Errori:**
| Status | Messaggio | Azione |
|--------|-----------|--------|
| 400 | Nessun cuore disponibile | Non chiamare se `heartsCount == 0` |

---

## 7. Push Notifications Ricevute

Il client deve gestire i seguenti tipi di push notifica:

| `data.type` | Titolo | Azione da eseguire |
|-------------|--------|-------------------|
| `HEART_RECEIVED` | "Hai ricevuto un cuore!" | Aggiornare `heartsCount` (chiamare `GET /users/me` o aggiornare localmente) |
| `HEART_REQUEST` | "Richiesta cuori" | Mostrare badge su schermata amici/cuori |

**Payload push `HEART_RECEIVED`:**
```json
{
  "type": "HEART_RECEIVED",
  "senderId": "uuid-del-mittente"
}
```

**Payload push `HEART_REQUEST`:**
```json
{
  "type": "HEART_REQUEST",
  "requesterId": "uuid-del-richiedente"
}
```

Alla ricezione di `HEART_REQUEST`: chiamare `GET /hearts/requests/incoming` per aggiornare il badge/lista.

---

## 8. Modello Dati Locale Consigliato

```
User {
  heartsCount: Int           // da server (cuori amici)
  lastHeartConsumedAt: Date? // da server (per timer ricarica)
  maxHearts: Int             // da GET /hearts/config
  heartRechargeMinutes: Int  // da GET /hearts/config
}

// Cuori totali visualizzati = heartsCount + heartsRecharged
// dove heartsRecharged = floor(minutiDa(lastHeartConsumedAt) / heartRechargeMinutes)
// capped a maxHearts - heartsCount
```

---

## 9. Sequence Diagram — Invio Cuore

```
Client A          API              DB                Client B (push)
   |                |               |                     |
   |-- POST /hearts/send/:B ------->|                     |
   |                |-- check friendship -------->|       |
   |                |-- check daily limit ------->|       |
   |                |-- check B.heartsCount ------>|      |
   |                |-- $transaction ------------>|       |
   |                |   create Heart              |       |
   |                |   user.heartsCount += 1     |       |
   |                |<-- ok ----------------------|       |
   |<-- 204 --------|                             |       |
   |                |-- FCM push (fire&forget) ---------->|
   |                |                             |  HEART_RECEIVED
```

---

## 10. Checklist Integrazione

- [ ] `GET /hearts/config` all'avvio — salvare `heartRechargeMinutes`, `maxHearts`
- [ ] `POST /hearts/consume` dopo ogni livello perso — aggiornare `heartsCount` e timer
- [ ] `POST /hearts/request` quando cuori ≤ 0 — mostrare numero amici notificati
- [ ] `GET /hearts/requests/incoming` al login e a ricezione push `HEART_REQUEST`
- [ ] `POST /hearts/fulfill/:requestId` da schermata richieste
- [ ] `POST /hearts/send/:friendId` da schermata amici
- [ ] Gestire push `HEART_RECEIVED` → aggiornare `heartsCount` UI
- [ ] Gestire push `HEART_REQUEST` → badge su schermata cuori/amici
- [ ] Disabilitare "Invia cuore" se già inviato oggi (409 o stato locale)
