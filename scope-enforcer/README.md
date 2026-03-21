# scope-enforcer

**A PreToolUse hook that enforces file scope boundaries for parallel Claude Code workers.**

<p>
  <img src="https://img.shields.io/badge/shell-bash-green?style=flat-square" alt="Shell">
  <img src="https://img.shields.io/badge/hook-PreToolUse-blue?style=flat-square" alt="Hook">
  <img src="https://img.shields.io/badge/license-MIT-yellow?style=flat-square" alt="License">
</p>

> Part of [claude-conf](https://github.com/Bidiche49/claude-conf) — install standalone or with the full toolkit.

---

## The Problem

The supervisor declares a strict scope per worker (list of allowed files), but this constraint is purely behavioral — nothing technically prevents a worker from modifying a file outside its scope. In parallel execution, this means merge conflicts are one hallucination away.

## The Solution

**scope-enforcer** is a PreToolUse hook that intercepts every `Write` and `Edit` tool call. It checks the target file against a scope file written by the supervisor before the worker starts. If the file is not in the allowed list, the operation is blocked with a clear error message.

No scope file = full pass-through. The hook is completely transparent in normal (non-supervised) sessions.

## How It Works

1. The **supervisor** writes a scope file before launching a worker:
   ```json
   // .claude-sessions/worker-scope/{session_id}.json
   {
     "allowed_files": ["src/cli.ts", "src/lib/validator.ts"],
     "worker_ticket": "BUG-003"
   }
   ```

2. The **hook** intercepts Write/Edit calls and checks the target file against `allowed_files`.

3. If the file is **not allowed**, the hook returns exit code 2 with a block decision:
   ```
   File outside worker scope for BUG-003. Attempted: src/other.ts.
   Allowed: [src/cli.ts, src/lib/validator.ts]. Note this in your report.
   ```

4. After validation, the supervisor **cleans up** the scope file.

### Decision Matrix

| Condition | Result |
|-----------|--------|
| Tool is not Write/Edit | Pass-through |
| No session_id | Pass-through |
| No scope file for session | Pass-through |
| File in `allowed_files` | Pass-through |
| File NOT in `allowed_files` | **Blocked** |

## Installation

```bash
cd scope-enforcer
bash install.sh
```

The installer:
1. Copies the hook to `~/.claude/hooks/`
2. Adds PreToolUse entries in `settings.json` (Write + Edit matchers)
3. Creates `.claude-sessions/worker-scope/` directory

### Disable

```bash
echo 'scope-enforcer' >> ~/.claude-conf-disabled
```

## Supervisor Integration

The supervisor must:
1. **Write** a scope file before generating each worker prompt
2. **Include** in the worker prompt: "A hook enforces your file scope. If you need to modify a file not listed, note it in your report."
3. **Clean up** scope files after validating the worker's report

See `supervisor/commands/supervisor.md` for the full integration.

---

## Le Probleme

Le supervisor declare un scope strict par worker (liste de fichiers autorises), mais cette contrainte est purement comportementale — rien n'empeche techniquement le worker de modifier un fichier hors scope. En execution parallele, un conflit de merge est a une hallucination pres.

## La Solution

**scope-enforcer** est un hook PreToolUse qui intercepte chaque appel `Write` et `Edit`. Il verifie le fichier cible par rapport a un fichier de scope ecrit par le supervisor avant le demarrage du worker. Si le fichier n'est pas dans la liste autorisee, l'operation est bloquee avec un message d'erreur clair.

Pas de fichier de scope = pass-through complet. Le hook est totalement transparent en session normale (sans superviseur).

## Fonctionnement

1. Le **supervisor** ecrit un fichier de scope avant de lancer un worker
2. Le **hook** intercepte les appels Write/Edit et verifie le fichier cible
3. Si le fichier n'est **pas autorise**, le hook bloque l'operation (exit 2)
4. Apres validation, le supervisor **nettoie** le fichier de scope

## Installation

```bash
cd scope-enforcer
bash install.sh
```

### Desactiver

```bash
echo 'scope-enforcer' >> ~/.claude-conf-disabled
```
