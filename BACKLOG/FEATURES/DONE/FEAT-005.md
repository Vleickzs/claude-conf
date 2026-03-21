# FEAT-005: Module claude-md-kit — cleanup, boost, init pour CLAUDE.md projet

**Type:** Feature
**Statut:** Fait
**Priorite:** Haute
**Complexite:** M
**Tags:** module, prompt-engineering, claude-md
**Depends on:** none
**Blocked by:** —
**Date creation:** 2026-03-21

---

## Description

Creer un module `claude-md-kit/` avec 3 commandes pour gerer le CLAUDE.md specifique a chaque projet :
- `/claude-md-cleanup` — nettoyer (virer doublons avec le global, generique, mort)
- `/claude-md-boost` — optimiser (prompt engineering senior + conventions stack du vrai code)
- `/claude-md-init` — generer from scratch pour un projet sans CLAUDE.md

Le CLAUDE.md projet est le levier #1 de productivite avec Claude Code. La plupart des utilisateurs le remplissent avec du generique, du copie-colle, ou des regles que Claude ignore. Ce module automatise l'ecriture d'un CLAUDE.md optimal.

Remplace le skill `setup-project` existant (trop ambitieux, scope trop large).

## User Story

**En tant que** utilisateur de Claude Code
**Je veux** un outil qui analyse mon projet et genere/optimise automatiquement mon CLAUDE.md
**Afin de** maximiser la performance de Claude sur mon projet sans etre expert en prompt engineering

## Livrable — Structure du module

```
claude-md-kit/
├── README.md
├── install.sh
└── commands/
    ├── claude-md-init.md        ← Generer from scratch
    ├── claude-md-cleanup.md     ← Nettoyer un existant
    └── claude-md-boost.md       ← Optimiser un existant
```

## Commande 1 : `/claude-md-init`

**Quand** : le projet n'a pas de CLAUDE.md (ou l'utilisateur veut repartir de zero).

**Comportement** :

1. **Verifier** si CLAUDE.md existe deja. Si oui, demander confirmation avant d'ecraser.

2. **Explorer le projet** en profondeur :
   - Structure des dossiers (ls, find)
   - Fichiers de config (package.json, pubspec.yaml, go.mod, Cargo.toml, pyproject.toml, composer.json, Makefile, *.xcodeproj, etc.)
   - Git history (git log --oneline -20)
   - Detecter si split (front/back) ou monolithe
   - Identifier la stack, le framework, l'ORM, le test runner, le linter

3. **Lire 4-6 fichiers representatifs** du code pour comprendre les patterns :
   - Un controller/handler/route
   - Un service/usecase
   - Un model/entity
   - Un test existant (s'il y en a)
   - Un fichier de config

4. **Lire le global CLAUDE.md** (`~/.claude/CLAUDE.md`) pour savoir ce qui est deja couvert (ne pas dupliquer)

5. **Generer le CLAUDE.md** avec cette structure :

```markdown
# CLAUDE.md — [Nom du projet]

## Projet
[Description 2-3 lignes : quoi, pour qui, stack principale]

## Regles specifiques a ce projet
[Regles qui ne sont PAS dans le global — specifiques a CE projet]
[Ex: "Ne pas lancer xcodebuild", "Utiliser les migrations Prisma", etc.]

## Build & Test
[Commandes exactes extraites de package.json/Makefile/etc.]
[Pas de commandes generiques — les VRAIES commandes du projet]

## Architecture
[Structure des dossiers simplifiee]
[Stack technique : tableau framework/lib/version]

## Conventions code (ce projet)
[Patterns extraits du VRAI code lu en etape 3]
[Format BON/MAUVAIS avec exemples du code existant]
[Specifiques a la stack : memory management iOS, hooks React, etc.]

## Configuration
[Variables d'env, API keys (pas les valeurs), endpoints, services]

## Etat actuel
[Branches actives, prochaines etapes si detectables dans git]
```

6. **Presenter le CLAUDE.md genere** a l'utilisateur, expliquer les choix. Attendre validation avant d'ecrire.

**Regles de generation** :
- JAMAIS de contenu generique ("soyez propre", "testez votre code") — ca ne sert a rien
- JAMAIS de duplication du global CLAUDE.md (ticketing, handoff, mindset, critical-thinking)
- TOUJOURS des instructions actionnables et specifiques
- Les conventions doivent venir du VRAI code, pas d'un template
- Les commandes build/test doivent etre les VRAIES commandes (lues dans package.json, Makefile, etc.)
- En cas de doute sur une convention, ne pas l'ajouter plutot qu'ajouter du generique

## Commande 2 : `/claude-md-cleanup`

**Quand** : le projet a un CLAUDE.md mais il est bloate (doublons avec le global, generique, mort).

**Comportement** :

1. **Lire** le CLAUDE.md du projet
2. **Lire** le global `~/.claude/CLAUDE.md` pour identifier ce qui est deja couvert par les modules
3. **Detecter les modules installes** en cherchant les markers dans le global :
   - `<!-- critical-thinking:start -->` → mindset + anti-complaisance couvert
   - `<!-- backlog:start -->` → ticketing couvert
   - Chercher aussi les references a handoff, supervisor dans le global
4. **Analyser chaque section du CLAUDE.md projet** :
   - Est-ce un doublon avec le global ? (meme concept, pas forcement meme texte) → MARQUER pour suppression
   - Est-ce du generique non specifique au projet ? ("soyez propre", "testez") → MARQUER
   - Est-ce specifique au projet ? → GARDER
   - Mix generique + specifique ? → GARDER seulement la partie specifique
5. **Presenter le diff** a l'utilisateur :
   ```
   SECTIONS A SUPPRIMER (doublons avec global) :
   - "Systeme de ticketing" (couvert par backlog-kit)
   - "Systeme de handoff" (couvert par handoff-kit)
   - "Pas de fix en pansement" (couvert par critical-thinking)

   SECTIONS A GARDER :
   - "Architecture" (specifique au projet)
   - "Memory Management" (conventions UIKit specifiques)
   ...

   SECTIONS A REFORMULER :
   - "Regles de developpement" — garder seulement la regle iOS-specifique (xcodebuild)
   ```
6. **Attendre validation** puis ecrire le CLAUDE.md nettoye

## Commande 3 : `/claude-md-boost`

**Quand** : le projet a un CLAUDE.md mais il est sous-optimal (pas assez specifique, mal structure, conventions manquantes).

**Comportement** :

1. **Faire le cleanup d'abord** (integre — pas besoin de lancer cleanup separement)
2. **Explorer le projet** comme pour init (structure, stack, code representatif)
3. **Analyser le CLAUDE.md actuel** avec un oeil de CTO / prompt engineer senior :
   - Les regles sont-elles actionnables ? (pas du blabla vague)
   - Les conventions viennent-elles du vrai code ou sont-elles generiques ?
   - Les commandes build/test sont-elles les vraies commandes ?
   - Manque-t-il des conventions importantes pour cette stack ?
   - La structure est-elle optimale pour que Claude performe ?
4. **Reecrire le CLAUDE.md** en :
   - Gardant l'intention de l'utilisateur (ce qu'il voulait exprimer)
   - Rendant chaque regle actionnable et specifique
   - Ajoutant des conventions stack-specifiques detectees dans le code :
     - **iOS/Swift** : memory management, deinit, weak self, patterns navigation
     - **React/Next** : hooks conventions, state management, component patterns
     - **Node/Express** : error handling, middleware, async patterns
     - **Flutter** : widget lifecycle, state management, platform channels
     - **Go** : error handling, goroutines, interfaces
     - **Python** : type hints, async, testing patterns
     - **etc.**
   - Ajoutant des patterns BON/MAUVAIS extraits du vrai code (pas generiques)
   - Restructurant dans l'ordre optimal (projet → regles → build → archi → conventions → config)
5. **Presenter le diff** entre l'ancien et le nouveau, section par section
6. **Attendre validation** puis ecrire

**Si CLAUDE.md n'existe pas** : rediriger vers `/claude-md-init` automatiquement.

**Regle d'or du boost** : chaque ligne ajoutee doit avoir un impact mesurable sur le comportement de Claude. Si une regle est ignoree par Claude ou ne change rien, elle ne devrait pas etre la. Privilegier 20 lignes percutantes a 100 lignes de remplissage.

## install.sh — Comportement

Simple, meme pattern que `supervisor/install.sh` et `oneshot/install.sh` :

1. Check deps (claude)
2. Copier les 3 commandes vers `~/.claude/commands/`
3. Backup des commandes existantes si presentes
4. Banner + resume

Pas de hook, pas de settings.json, pas de snippet CLAUDE.md. Juste 3 commandes.

## Criteres d'acceptation

- [ ] `bash install.sh` installe les 3 commandes
- [ ] `/claude-md-init` genere un CLAUDE.md from scratch adapte a la stack
- [ ] `/claude-md-init` ne duplique rien du global CLAUDE.md
- [ ] `/claude-md-init` extrait les vraies commandes build/test du projet
- [ ] `/claude-md-cleanup` identifie et propose la suppression des doublons
- [ ] `/claude-md-cleanup` garde les sections specifiques au projet
- [ ] `/claude-md-boost` fait le cleanup + ajoute des conventions stack-specifiques
- [ ] `/claude-md-boost` base ses conventions sur le vrai code (pas du generique)
- [ ] Les 3 commandes demandent validation avant d'ecrire
- [ ] `/claude-md-boost` redirige vers init si pas de CLAUDE.md
- [ ] L'install est idempotente

## Fichiers concernes

### A creer
- `claude-md-kit/README.md`
- `claude-md-kit/install.sh`
- `claude-md-kit/commands/claude-md-init.md`
- `claude-md-kit/commands/claude-md-cleanup.md`
- `claude-md-kit/commands/claude-md-boost.md`
