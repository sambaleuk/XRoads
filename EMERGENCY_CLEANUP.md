# 🆘 Emergency Cleanup Guide

## L'App est Bloquée et Refuse de Fermer

### 🚨 Solution Rapide

```bash
# Option 1 : Utiliser le script de cleanup
chmod +x kill-app.sh
./kill-app.sh

# Option 2 : Commandes manuelles
killall -9 CrossRoads
killall -9 node
```

### 🔍 Pourquoi ça Arrive ?

L'app peut rester bloquée pour plusieurs raisons :

1. **Serveur MCP actif** - Le process Node.js continue de tourner
2. **Tasks async non annulées** - Les `Task` de monitoring continuent
3. **Git operations bloquées** - Des commandes git longues en cours
4. **Actors bloqués** - Avant les corrections, les actors pouvaient bloquer

### ✅ Corrections Appliquées

Les bugs suivants ont été corrigés pour éviter ce problème à l'avenir :

- ✅ **AppDelegate avec cleanup** - Appelle `appState.cleanup()` au quit
- ✅ **`appState.cleanup()`** - Annule tous les Tasks et stop le MCP server
- ✅ **Bouton Quit avec cleanup** - Cmd+Q fait maintenant un cleanup propre
- ✅ **GitService async** - Plus de `waitUntilExit()` bloquant
- ✅ **Timeout tasks annulés** - Plus de leak de Tasks en background

### 🧪 Tester le Fix

Après rebuild :

1. Lance l'app
2. Démarre le MCP server
3. Crée quelques worktrees
4. Lance des agents
5. **Ferme avec Cmd+Q** → Doit se fermer proprement en ~2 secondes

### 🆘 Si ça Bloque Encore

```bash
# Check quels processus tournent
ps aux | grep -E "(CrossRoads|node.*crossroads)"

# Kill tout
killall -9 CrossRoads node

# Nettoyer les pipes et sockets orphelins
lsof -c CrossRoads | grep PIPE
```

### 📝 Notes Techniques

**Avant** :
- Pas de `applicationWillTerminate`
- Serveur MCP jamais arrêté
- Tasks continuaient en background
- Actors bloqués par `waitUntilExit()`

**Après** :
- AppDelegate avec cleanup synchronisé
- Semaphore avec timeout 2s
- Tous les Tasks annulés
- MCP server proprement stoppé
- Tout async, pas de blocage

### 🔧 Debug

Si l'app refuse toujours de se fermer :

```bash
# Attache lldb pour voir où ça bloque
lldb -p $(pgrep CrossRoads)
(lldb) bt all  # Backtrace de tous les threads

# Ou utilise Activity Monitor → Sample Process
```

---

**Créé le** : 2026-02-03  
**Bugs corrigés** : #1, #3, #5, #6, #7 + Cleanup lifecycle
