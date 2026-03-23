# explore

Structured parallel exploration for Claude Code.

---

## What it does / Ce que ca fait

**EN:** Adds the `/explore <topic>` slash command. It launches a structured, parallel exploration of your codebase, documentation, and the web to answer any question in depth.

**FR:** Ajoute la commande `/explore <topic>`. Lance une exploration structuree et parallele du codebase, de la documentation et du web pour repondre a toute question en profondeur.

## Process / Processus

### 1. Plan (30s max)
- Break the topic into 2-3 specific sub-questions
- Identify what to search: codebase, docs, web, or all

### 2. Explore (parallel agents)
- 1-2 agents for codebase search
- 1 agent for web/docs if needed
- Each agent has a focused, specific question

### 3. Synthesize
- Merge findings, identify conflicts or gaps
- Produce a structured report with `file:line` references

## Report format / Format du rapport

```
### Exploration: [topic]

#### Key findings
- Finding 1 — with file:line references

#### Architecture / Patterns
- How the codebase handles this

#### Recommendations
- Concrete recommendations (if applicable)

#### Files explored
- path/to/file — what was found
```

## Install

```bash
bash explore/install.sh
```

## Usage

```
/explore how does authentication work in this project
/explore what logging patterns are used
/explore how should we implement caching
```

## Rules

- Max 2 parallel agents — more creates context fragmentation
- Always includes `file:line` references
- If topic is too broad, narrows it automatically
- Stops after 2 minutes if stuck, reports partial findings
