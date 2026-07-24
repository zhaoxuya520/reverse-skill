# primary-path-demo

Reproducible showcase for reverse-skill's product surface:

```
task text → master-route → case-init (offline-sample) → case-guard
```

| Artifact | Meaning |
|----------|---------|
| [RESULT-CARD.md](RESULT-CARD.md) | Human-readable result card |
| [result-card.html](result-card.html) | Screenshot-friendly card |
| [route-matrix.md](route-matrix.md) | Live routing self-check |
| [cases/](cases/) | Copied case workspace |
| [routes/](routes/) | Per-sample route-scope.md |

Regenerate:

```bash
bash skills/scripts/demo-primary-path.sh
```

## Terminal GIF

Regenerate the README hero GIF:

```bash
bash skills/scripts/record-primary-path-demo.sh
```

- Output: [`docs/assets/primary-path-demo.gif`](../../docs/assets/primary-path-demo.gif)
- Scenes: [`terminal-scenes.txt`](terminal-scenes.txt)
- vhs alternative: [`docs/demo/primary-path.tape`](../../docs/demo/primary-path.tape)
