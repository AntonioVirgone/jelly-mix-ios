---
name: Documentazione obbligatoria al completamento feature
description: Regola di processo — a fine feature creare sempre un documento con modifiche, scelte e modalità di test
type: feedback
---

Quando una feature è completata, creare sempre un documento markdown nella cartella `docs/feature/<step>/` che descriva:
- Tutti i file creati e modificati (con dettaglio delle modifiche)
- Le scelte di design prese e perché
- Le modalità di verifica e test (step-by-step, pre-requisiti, log attesi, errori attesi)
- Limitazioni note e prossimi step

**Why:** L'utente vuole tracciabilità completa delle decisioni e un riferimento per il testing manuale, specialmente utile quando le feature coinvolgono API di backend e flussi multi-device difficili da testare automaticamente.

**How to apply:** Subito dopo l'ultimo `git add` e prima del commit, scrivere il documento. Proporre il commit solo dopo che il documento è incluso nello staging.
