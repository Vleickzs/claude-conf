<!-- backlog:start -->

## Systeme de ticketing (BACKLOG)

BACKLOG/ contient BUGS/, FEATURES/, IMPROVEMENTS/ avec PENDING/ et DONE/.
INDEX.md est un cache — ne JAMAIS l'editer manuellement.
Les IDs sont calcules par scan des fichiers existants (anti-conflit multi-sessions).
Le hook backlog-guard bloque les conflits d'ID.

Commandes : `/backlog-bug`, `/backlog-feat`, `/backlog-imp`, `/backlog-status`, `/backlog-init`

### Creation de tickets hors slash command

Si tu crees un ticket sans passer par `/backlog-bug`, `/backlog-feat` ou `/backlog-imp`, tu DOIS respecter ce format :

```markdown
# TYPE-XXX: Titre court

**Type:** Bug | Feature | Improvement
**Statut:** A faire
**Priorite:** Critique | Haute | Moyenne | Basse
**Complexite:** XS | S | M | L | XL
**Tags:** [libres, separes par virgule]
**Depends on:** none
**Blocked by:** —
**Date creation:** YYYY-MM-DD

---

## Description
[Description claire du probleme ou de la feature]

## Fichiers concernes
- `path/to/file.ext` — [role du fichier dans le contexte du ticket]

## Criteres d'acceptation
- [ ] [Critere specifique et verifiable — pas de generique "le bug est corrige"]

## Tests de validation
- [ ] [Commande exacte ou scenario a executer]
```

Regles :
- **ID** : scanner `BACKLOG/{TYPE}/PENDING/` et `DONE/` pour calculer max+1. JAMAIS lire INDEX.md.
- **Fichiers concernes** : identifier les fichiers reels a partir du contexte de conversation. Ne JAMAIS laisser `(A determiner)`.
- **Criteres d'acceptation** : decrire le comportement attendu apres fix/implementation, pas juste "c'est corrige".
- **Tests de validation** : donner les commandes a executer (`bash tests/test.sh`, `bun test`, etc.) ou le scenario manuel.

<!-- backlog:end -->
