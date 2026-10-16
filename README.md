# RuleRef

[English](#english) · [Español](#español)

## English

*[Versión en español](#español)*

An iPhone rulebook referee for board games: import a game's PDF rulebook, search it, and see the original rule on its page with the passage highlighted.

### In short

- **What it is:** the final project for DevExpert's AI Expert course (October 2026), built by one developer with Claude Code.
- **What it really shows:** the harness, the system that builds the app. One agent implements, another validates, and I decide. The app is small on purpose; it is the test bed.
- **Where it stands:** the base app without AI is complete (tag `m4`): import, search, an explicit no-match state and the page viewer with the passage highlighted. Text search is measured against a set of real questions (below). On-device AI comes next, as one more feature of the loop, measured against that baseline.

### What the app does

- A library of games, each holding at most one rulebook imported from a single-column PDF with a text layer.
- Import once, then use it offline: the rulebook is frozen into ordered passages, each with a page locator.
- Text search inside one game's rulebook, case- and diacritic-insensitive, with an explicit no-match state instead of approximate results.
- Open a match in the page viewer with the passage highlighted.

### How it was built

- **Decide before coding.** A discovery interview produced the build brief, the domain model and the open decisions; scope cuts are written down with their reason ([ADR-003](docs/adr/0003-scope-cut.md)).
- **One gate.** [`init.sh`](init.sh) is the only definition of "builds and passes": house rules, a warnings-as-errors build, the tests and the string catalog.
- **Boundaries that are not text.** The rules that matter are hooks with their own test cases: the validator cannot write, the implementer cannot accept its own feature, no agent can approve a spec, and the Xcode project is mine ([hooks](.claude/hooks/README.md)).
- **State lives in the repo.** [`AGENTS.md`](AGENTS.md), [`PROGRESS.md`](PROGRESS.md) and [`feature_list.json`](feature_list.json): a new session rebuilds where we are from these files alone.
- **A spec per feature, approved by me.** Each feature has a spec in [`docs/specs/`](docs/specs/); it is valid only with my `Approval` line.
- **The loop.** `/feature-flow` picks the next feature, opens its branch, and hands it to the implementer and then to the read-only validator. I confirm the verdict and merge the PR on GitHub. Every validation in [`docs/validations/`](docs/validations/) also lists what it could not verify.

### Baseline: text search on real questions

25 questions about the Taifa rulebook, worded the way someone who does not know the rulebook would ask ([eval set](RuleRefTests/Fixtures/taifa-3.0-eval.json)), scored by page. Measured on the iOS 27.0 simulator:

| Metric | Result |
|---|---|
| Right page first (hit@1) | 3 of 21 |
| Right page in the first three (hit@3) | 4 of 21 |
| Says "no results" when the answer is not in the rulebook | 3 of 4 |

Search needs every word of the query in the same passage, so most questions find nothing. That is the number the AI has to beat. Full report: [`docs/eval/f16-baseline-taifa-3.0.json`](docs/eval/f16-baseline-taifa-3.0.json).

### Stack

iOS 26+, iPhone only, Swift 6, SwiftUI, SwiftData, Swift Testing, PDFKit, no third-party dependencies, built and tested via `xcodebuild`. See [ADR-001](docs/adr/0001-stack-and-build-doctrine.md).

### Build and test

`./init.sh` is the only command: it checks the toolchain and simulator, enforces the source rules (no JSONSerialization, UIKit, XCTest, third-party packages or bundled PDFs; Spanish translations complete; a valid `feature_list.json`), then builds with warnings as errors, runs the tests and checks that every string the compiler extracts from the app is in the catalog (the CLI build never adds them; add each key with its Spanish translation by hand). Requires Xcode 27 and an iPhone 18 Pro simulator with iOS 27.0.

### Documentation

- [`ARCHITECTURE.md`](ARCHITECTURE.md): folders of the app and test targets, and what each may use.
- [`DESIGN.md`](DESIGN.md): interface rules: SF Symbols, standard button roles and previews with sample data.
- [`AGENTS.md`](AGENTS.md): instructions for coding agents, with rules, workflow and Definition of Done. [`CLAUDE.md`](CLAUDE.md) only imports it.
- [`.agents/skills/`](.agents/skills/): the harness skills (`build-brief`, `feature-spec`, `feature-flow`, `feature-implementer`, `feature-validator`, `xcode-mcp`). `.claude/` holds the subagents, hooks and settings that wire them; [`.claude/hooks/README.md`](.claude/hooks/README.md) lists the hooks.
- [`feature_list.json`](feature_list.json): status of every feature, with dependencies, verification steps and evidence.
- [`docs/specs/`](docs/specs/) and [`docs/validations/`](docs/validations/): the approved spec and the validation record of each feature.
- [`docs/eval/`](docs/eval/): baseline reports of search on the eval set, exported from a focused test run.
- [`docs/idea.md`](docs/idea.md): original idea, course context and initial decisions (Spanish).
- [`docs/build-brief.md`](docs/build-brief.md): problem, goals, non-goals and feature slices up to m4.
- [`docs/domain-model.md`](docs/domain-model.md): core concepts and rules.
- [`docs/risks-and-open-questions.md`](docs/risks-and-open-questions.md): status of open decisions, assumptions and risks.
- [`docs/adr/`](docs/adr/): ADR-001 stack and CLI build doctrine; ADR-002 PDFKit line order, no reading-order reconstruction; ADR-003 scope cut; ADR-004 page viewer with PDFKit's `PDFView`, the one UIKit-backed view.
- [`CONTEXT.md`](CONTEXT.md): glossary of canonical terms.
- [`PROGRESS.md`](PROGRESS.md): log of work sessions, recording what closed and what comes next.

### Demo rulebook

The demo uses Taifa 3.0 (CC BY-NC-SA). It is used only as a test fixture and is never bundled in the app.

---

## Español

*[English version](#english)*

Un árbitro de reglamentos de juegos de mesa para iPhone: importas el reglamento en PDF de un juego, buscas en él y ves la regla original en su página, con el pasaje resaltado.

### En resumen

- **Qué es:** el proyecto final del curso AI Expert de DevExpert (octubre de 2026), hecho por un solo desarrollador con Claude Code.
- **Qué enseña de verdad:** el harness, el sistema con el que se construye la app. Un agente implementa, otro valida y yo decido. La app es pequeña a propósito: es el banco de pruebas.
- **En qué punto está:** la app base sin IA está terminada (tag `m4`): importar, buscar, un estado explícito de sin resultados y el visor de página con el pasaje resaltado. La búsqueda de texto está medida con un conjunto de preguntas reales (más abajo). La IA en el dispositivo es lo siguiente, como una feature más del loop, medida contra esa línea base.

### Qué hace la app

- Una biblioteca de juegos; cada uno guarda como mucho un reglamento, importado de un PDF a una columna con capa de texto.
- Se importa una vez y se usa sin conexión: el reglamento queda fijado en pasajes ordenados, cada uno con su página.
- Búsqueda de texto dentro del reglamento de un juego, sin distinguir mayúsculas ni tildes, con un estado explícito de sin resultados en lugar de resultados aproximados.
- Una coincidencia se abre en el visor de página con el pasaje resaltado.

### Cómo se construyó

- **Decidir antes de programar.** Una entrevista de descubrimiento produjo el build brief, el modelo de dominio y las decisiones abiertas; los recortes de alcance están escritos con su motivo ([ADR-003](docs/adr/0003-scope-cut.md)).
- **Una sola puerta.** [`init.sh`](init.sh) es la única definición de "compila y pasa": reglas de la casa, compilación con los warnings como errores, los tests y el catálogo de textos.
- **Fronteras que no son texto.** Las reglas que importan son hooks con sus propios casos de prueba: el validador no puede escribir, el implementador no puede aceptar su propia feature, ningún agente puede aprobar una spec y el proyecto de Xcode lo toco solo yo ([hooks](.claude/hooks/README.md)).
- **El estado vive en el repo.** [`AGENTS.md`](AGENTS.md), [`PROGRESS.md`](PROGRESS.md) y [`feature_list.json`](feature_list.json): una sesión nueva reconstruye dónde estamos solo con estos ficheros.
- **Una spec por feature, aprobada por mí.** Cada feature tiene su spec en [`docs/specs/`](docs/specs/), y solo vale con mi línea `Approval`.
- **El loop.** `/feature-flow` elige la siguiente feature, abre su rama y se la pasa al implementador y después al validador, que solo lee. Yo confirmo el veredicto y mergeo la PR en GitHub. Cada validación de [`docs/validations/`](docs/validations/) deja escrito también lo que no pudo comprobar.

### Línea base: la búsqueda de texto con preguntas reales

25 preguntas sobre el reglamento de Taifa, formuladas como las haría alguien que no se lo sabe ([eval set](RuleRefTests/Fixtures/taifa-3.0-eval.json)), puntuadas por página. Medido en el simulador de iOS 27.0:

| Métrica | Resultado |
|---|---|
| Página correcta en el primer resultado (hit@1) | 3 de 21 |
| Página correcta entre los tres primeros (hit@3) | 4 de 21 |
| Dice "sin resultados" cuando la respuesta no está en el reglamento | 3 de 4 |

La búsqueda exige todas las palabras de la consulta en el mismo pasaje, así que la mayoría de las preguntas no encuentran nada. Ese es el número que tiene que mejorar la IA. Informe completo: [`docs/eval/f16-baseline-taifa-3.0.json`](docs/eval/f16-baseline-taifa-3.0.json).

### Stack

iOS 26+, solo iPhone, Swift 6, SwiftUI, SwiftData, Swift Testing, PDFKit, sin dependencias de terceros, compilado y probado con `xcodebuild`. Ver [ADR-001](docs/adr/0001-stack-and-build-doctrine.md).

### Compilar y probar

`./init.sh` es el único comando: comprueba el toolchain y el simulador, hace cumplir las reglas del código (nada de JSONSerialization, UIKit, XCTest, paquetes de terceros ni PDFs dentro de la app; traducciones al español completas; un `feature_list.json` válido), compila con los warnings como errores, pasa los tests y comprueba que cada texto que el compilador extrae de la app está en el catálogo (la compilación por línea de comandos nunca los añade; cada clave se añade a mano con su traducción al español). Necesita Xcode 27 y un simulador iPhone 18 Pro con iOS 27.0.

### Documentación

La documentación del repo está en inglés, salvo `docs/idea.md`.

- [`ARCHITECTURE.md`](ARCHITECTURE.md): carpetas de los targets de la app y de los tests, y qué puede usar cada una.
- [`DESIGN.md`](DESIGN.md): reglas de interfaz: SF Symbols, roles estándar de los botones y previews con datos de ejemplo.
- [`AGENTS.md`](AGENTS.md): instrucciones para los agentes, con reglas, flujo de trabajo y Definition of Done. [`CLAUDE.md`](CLAUDE.md) solo lo importa.
- [`.agents/skills/`](.agents/skills/): las skills del harness (`build-brief`, `feature-spec`, `feature-flow`, `feature-implementer`, `feature-validator`, `xcode-mcp`). `.claude/` guarda los subagentes, los hooks y la configuración que las conecta; [`.claude/hooks/README.md`](.claude/hooks/README.md) lista los hooks.
- [`feature_list.json`](feature_list.json): estado de cada feature, con dependencias, pasos de verificación y evidencia.
- [`docs/specs/`](docs/specs/) y [`docs/validations/`](docs/validations/): la spec aprobada y el registro de validación de cada feature.
- [`docs/eval/`](docs/eval/): informes de la línea base de la búsqueda sobre el eval set, exportados de una ejecución de tests enfocada.
- [`docs/idea.md`](docs/idea.md): idea original, contexto del curso y decisiones iniciales.
- [`docs/build-brief.md`](docs/build-brief.md): problema, objetivos, lo que queda fuera y los cortes de features hasta m4.
- [`docs/domain-model.md`](docs/domain-model.md): conceptos y reglas del dominio.
- [`docs/risks-and-open-questions.md`](docs/risks-and-open-questions.md): estado de las decisiones abiertas, suposiciones y riesgos.
- [`docs/adr/`](docs/adr/): ADR-001, stack y doctrina de compilación por línea de comandos; ADR-002, orden de líneas de PDFKit sin reconstruir el orden de lectura; ADR-003, recorte de alcance; ADR-004, visor de página con `PDFView` de PDFKit, la única vista basada en UIKit.
- [`CONTEXT.md`](CONTEXT.md): glosario de términos canónicos.
- [`PROGRESS.md`](PROGRESS.md): registro de las sesiones de trabajo, con lo que se cerró y lo que viene después.

### Reglamento de la demo

La demo usa Taifa 3.0 (CC BY-NC-SA). Se usa solo como fixture de test y nunca va dentro de la app.
