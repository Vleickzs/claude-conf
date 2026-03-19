<p align="center">
  <h1 align="center">command-guard</h1>
  <p align="center">A PreToolUse hook that validates every shell command before Claude Code executes it</p>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/runtime-Bun-f9f1e1?style=flat-square&logo=bun" alt="Bun">
  <img src="https://img.shields.io/badge/hook-PreToolUse-blue?style=flat-square" alt="Hook">
  <img src="https://img.shields.io/badge/tests-32%20passing-brightgreen?style=flat-square" alt="Tests">
  <img src="https://img.shields.io/badge/license-MIT-yellow?style=flat-square" alt="License">
</p>

---

## The Problem

Claude Code can execute **any** shell command on your machine. It's powerful — and dangerous. One hallucinated `rm -rf /` and your day is ruined. Even with the permission system, `--dangerously-skip-permissions` mode removes all guardrails.

**command-guard** is a safety net that sits between Claude Code and your shell. It intercepts every `Bash` tool call via a [PreToolUse hook](https://docs.anthropic.com/en/docs/claude-code/hooks) and validates the command before execution.

## How It Works

Every command goes through a three-tier validation system:

| Tier | Action | Behavior | Bypass with permission? |
|------|--------|----------|------------------------|
| **DENY** | Hard block | Command is rejected. Period. | No — blocks even with `--dangerously-skip-permissions` |
| **ASK** | Confirmation required | Claude Code prompts you before executing | Yes — auto-approved in skip-permissions mode |
| **ALLOW** | Pass through | Command runs normally | N/A |

### DENY tier (hard block)

These commands are **always** blocked, no exceptions:

| Pattern | Catches |
|---------|---------|
| `rm -rf` | `rm -rf /`, `rm -rf .`, `rm -fr folder`, `rm -r -f dir`, `rm -f -r dir` |

The pattern detection is thorough — it catches flag reordering (`-rf`, `-fr`), separated flags (`-r -f`), and commands buried in chains (`mkdir x && rm -rf x`).

### ASK tier (confirmation required)

These commands trigger a confirmation prompt:

| Command | Why |
|---------|-----|
| `sudo` | Privilege escalation |
| `su` | User switching |
| `chmod` | Permission changes |
| `chown` | Ownership changes |
| `kill` | Process termination |
| `killall` | Mass process termination |
| `dd` | Raw disk writes |
| `mkfs` | Filesystem creation |
| `fdisk` | Partition editing |

Detection works on the main command and inside chained commands (`&&`, `||`, `;`, `|`).

### ALLOW tier (pass through)

Everything else. `git`, `npm`, `ls`, `cat`, `curl`, `rm file.txt`, `rm -r folder` — all fine.

## Security Logging

Every validated command is logged to `data/security.log` (JSON lines format):

```json
{
  "timestamp": "2025-07-14T10:30:00.000Z",
  "sessionId": "abc-123",
  "toolName": "Bash",
  "command": "rm -rf /",
  "blocked": true,
  "severity": "CRITICAL",
  "violations": ["rm -rf is forbidden - use trash instead"],
  "source": "claude-code-hook"
}
```

Commands are truncated to 500 characters in logs. The `data/` directory is gitignored.

## Installation

### Standalone

```bash
git clone https://github.com/Bidiche49/claude-conf.git
cd claude-conf/command-guard
bash install.sh
```

### Via claude-conf (interactive)

```bash
git clone https://github.com/Bidiche49/claude-conf.git
cd claude-conf
bash install.sh
# Select command-guard from the list
```

### What the installer does

1. Checks that Bun and jq are installed
2. Copies source files to `~/.claude/scripts/command-guard/`
3. Creates the `data/` directory for logs
4. Merges the PreToolUse hook into `~/.claude/settings.json` (preserves existing hooks)

### Manual setup

If you prefer to configure manually, add this to `~/.claude/settings.json`:

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "bun ~/.claude/scripts/command-guard/src/cli.ts"
          }
        ]
      }
    ]
  }
}
```

## Custom Rules

The validator is designed to be extended. Edit `~/.claude/scripts/command-guard/src/lib/validator.ts` to add your own rules.

### Adding a custom DENY rule

Example: block `gh repo delete` permanently.

```typescript
export class CommandValidator {
  validate(command: string, _toolName = "Unknown"): ValidationResult {
    // ... existing checks ...

    // rm -rf → DENY
    if (this.containsRmRf(command)) { /* ... */ }

    // Add your custom DENY rule here:
    if (this.containsGhRepoDelete(command)) {
      result.isValid = false;
      result.severity = "CRITICAL";
      result.violations.push("gh repo delete is forbidden - delete repos on github.com");
      result.action = "deny";
      return result;
    }

    // ... rest of validate() ...
  }

  // Add the detection method:
  containsGhRepoDelete(command: string): boolean {
    const patterns = [
      /\bgh\s+repo\s+delete\b/i,
      /\bgh\s+repo\s+rm\b/i,
      /\bgh\s+api\s+.*repos\/.*-X\s+DELETE/i,
    ];
    return patterns.some((p) => p.test(command));
  }
}
```

### Adding a custom ASK rule

To add commands that require confirmation instead of hard blocking, add them to the `DANGEROUS_COMMANDS` array at the top of `validator.ts`:

```typescript
const DANGEROUS_COMMANDS = [
  "sudo", "su", "chmod", "chown", "dd", "mkfs", "fdisk", "kill", "killall",
  // Add your own:
  "docker", "systemctl", "reboot",
];
```

### Adding a custom ALLOW rule (whitelist early return)

To always allow specific commands without further checks:

```typescript
validate(command: string, _toolName = "Unknown"): ValidationResult {
  const result: ValidationResult = { /* ... */ };

  // Whitelist: always allow these
  if (/^(flutter|dart)\s/.test(command)) {
    return result; // Already set to allow
  }

  // ... rest of validation ...
}
```

## Tests

```bash
cd ~/.claude/scripts/command-guard  # or the repo directory
bun test
```

```
 32 pass
 0 fail
 110 expect() calls
```

The test suite covers:
- **12 ALLOW cases** — safe commands that must pass through
- **9 DENY cases** — `rm -rf` variants that must be blocked
- **8 ASK cases** — dangerous commands that require confirmation
- **3 edge cases** — empty commands, accented characters, emojis

## Architecture

```
command-guard/
├── src/
│   ├── cli.ts                 # Entry point (reads stdin, outputs hook JSON)
│   ├── lib/
│   │   ├── types.ts           # TypeScript interfaces
│   │   └── validator.ts       # Core validation logic
│   └── __tests__/
│       └── validator.test.ts  # Test suite
├── data/                      # Security logs (gitignored)
├── package.json
├── tsconfig.json
├── install.sh
└── README.md
```

## Requirements

| Dependency | Version | Install |
|------------|---------|---------|
| [Bun](https://bun.sh) | 1.0+ | `curl -fsSL https://bun.sh/install \| bash` |
| [jq](https://jqlang.github.io/jq/) | any | `brew install jq` |
| [Claude Code](https://docs.anthropic.com/en/docs/claude-code) | any | `npm install -g @anthropic-ai/claude-code` |

## License

[MIT](../LICENSE) - Part of [claude-conf](https://github.com/Bidiche49/claude-conf)

---

<a id="francais"></a>

# Francais

## Le probleme

Claude Code peut executer **n'importe quelle** commande shell sur votre machine. C'est puissant, et dangereux. Un `rm -rf /` hallucine et votre journee est fichue. Meme avec le systeme de permissions, le mode `--dangerously-skip-permissions` supprime toutes les protections.

**command-guard** est un filet de securite entre Claude Code et votre shell. Il intercepte chaque appel a l'outil `Bash` via un [hook PreToolUse](https://docs.anthropic.com/en/docs/claude-code/hooks) et valide la commande avant execution.

## Fonctionnement

Chaque commande passe par un systeme de validation a trois niveaux :

| Niveau | Action | Comportement | Contournable ? |
|--------|--------|--------------|----------------|
| **DENY** | Blocage dur | Commande rejetee. Point. | Non — bloque meme avec `--dangerously-skip-permissions` |
| **ASK** | Confirmation requise | Claude Code demande confirmation | Oui — auto-approuve en mode skip-permissions |
| **ALLOW** | Passe directement | Execution normale | N/A |

### Niveau DENY (blocage dur)

Ces commandes sont **toujours** bloquees, sans exception :

| Pattern | Detecte |
|---------|---------|
| `rm -rf` | `rm -rf /`, `rm -rf .`, `rm -fr folder`, `rm -r -f dir`, `rm -f -r dir` |

La detection est robuste : elle capte la reordonnation des flags (`-rf`, `-fr`), les flags separes (`-r -f`), et les commandes enfouies dans des chaines (`mkdir x && rm -rf x`).

### Niveau ASK (confirmation requise)

Ces commandes declenchent une demande de confirmation :

| Commande | Raison |
|----------|--------|
| `sudo` | Escalade de privileges |
| `su` | Changement d'utilisateur |
| `chmod` | Modification de permissions |
| `chown` | Changement de proprietaire |
| `kill` | Arret de processus |
| `killall` | Arret massif de processus |
| `dd` | Ecriture disque brute |
| `mkfs` | Creation de systeme de fichiers |
| `fdisk` | Edition de partitions |

La detection fonctionne sur la commande principale et dans les commandes chainees (`&&`, `||`, `;`, `|`).

### Niveau ALLOW (passe directement)

Tout le reste. `git`, `npm`, `ls`, `cat`, `curl`, `rm fichier.txt`, `rm -r dossier` — aucun probleme.

## Journalisation

Chaque commande validee est enregistree dans `data/security.log` (format JSON lines). Les commandes sont tronquees a 500 caracteres. Le dossier `data/` est gitignore.

## Installation

### Autonome

```bash
git clone https://github.com/Bidiche49/claude-conf.git
cd claude-conf/command-guard
bash install.sh
```

### Via claude-conf (interactif)

```bash
git clone https://github.com/Bidiche49/claude-conf.git
cd claude-conf
bash install.sh
# Selectionnez command-guard dans la liste
```

### Installation manuelle

Ajoutez ceci dans `~/.claude/settings.json` :

```json
{
  "hooks": {
    "PreToolUse": [
      {
        "matcher": "Bash",
        "hooks": [
          {
            "type": "command",
            "command": "bun ~/.claude/scripts/command-guard/src/cli.ts"
          }
        ]
      }
    ]
  }
}
```

## Regles personnalisees

Le validateur est concu pour etre etendu. Editez `~/.claude/scripts/command-guard/src/lib/validator.ts`.

### Ajouter une regle DENY personnalisee

Exemple : bloquer `gh repo delete` definitivement.

```typescript
// Dans la methode validate(), apres le check rm -rf :
if (this.containsGhRepoDelete(command)) {
  result.isValid = false;
  result.severity = "CRITICAL";
  result.violations.push("gh repo delete est interdit");
  result.action = "deny";
  return result;
}

// Nouvelle methode :
containsGhRepoDelete(command: string): boolean {
  return /\bgh\s+repo\s+delete\b/i.test(command);
}
```

### Ajouter une regle ASK personnalisee

Ajoutez la commande au tableau `DANGEROUS_COMMANDS` en haut de `validator.ts` :

```typescript
const DANGEROUS_COMMANDS = [
  "sudo", "su", "chmod", "chown", "dd", "mkfs", "fdisk", "kill", "killall",
  "docker", "systemctl", "reboot",  // ← vos ajouts
];
```

### Ajouter une regle ALLOW (whitelist)

Pour toujours autoriser certaines commandes sans verification :

```typescript
validate(command: string, _toolName = "Unknown"): ValidationResult {
  const result: ValidationResult = { /* ... */ };

  if (/^(flutter|dart)\s/.test(command)) {
    return result; // Deja configure en allow
  }
  // ... suite de la validation ...
}
```

## Tests

```bash
bun test
```

32 tests, 110 assertions, 0 echecs. Couvre les commandes autorisees, bloquees, demandant confirmation, et les cas limites.

## Prerequis

| Dependance | Version | Installation |
|------------|---------|--------------|
| [Bun](https://bun.sh) | 1.0+ | `curl -fsSL https://bun.sh/install \| bash` |
| [jq](https://jqlang.github.io/jq/) | any | `brew install jq` |
| [Claude Code](https://docs.anthropic.com/en/docs/claude-code) | any | `npm install -g @anthropic-ai/claude-code` |

## Licence

[MIT](../LICENSE) - Fait partie de [claude-conf](https://github.com/Bidiche49/claude-conf)
