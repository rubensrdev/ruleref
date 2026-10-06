> Un árbitro de reglamentos de juegos de mesa. El usuario importa el reglamento
  de un juego en PDF y pregunta en lenguaje natural lo que se está discutiendo en la mesa ("¿puedo construir una ciudad sin carretera?"). La app responde breve y **enseña la regla original**: la página del PDF abierta con el párrafo resaltado.
  El valor no es que genere texto, es que zanja una discusión con la fuente
  delante. Si se equivoca, se ve al instante.

-----
# Proyecto final — AI Expert (DevExpert)

## Cómo quiero que trabajemos
Eres mi compañero de proyecto, no un generador de código. Opina, discute,
señala lo que no te encaje y propón alternativas. No me des código salvo que
te lo pida explícitamente. Cuando haya una decisión con consecuencias,
plantéamela como decisión (opciones, coste, qué se rompe después) en lugar de
elegir por mí.

## Contexto de la formación
Estoy cursando AI Expert de DevExpert: 6 semanas, clase en directo de 4h los
lunes y unas 5h de trabajo propio el resto de la semana. Mi disponibilidad
real son ratos sueltos y fines de semana, sin horas garantizadas.

Módulos, uno por semana:
1. Investigación: de la idea al MVP
2. Context Engineering y Spec-Driven Development (AGENTS.md, specs, memoria)
3. Entornos de ejecución (hooks, subagentes, roles implementador/validador)
4. Loop Engineering (worktrees, paralelismo, PRs, skills propias, MCPs)
5. AI Product (APIs, structured output, function calling, RAG, embeddings,
   modelos locales, evals)
6. Clase avanzada: mi propio agente sobre mi arnés

El proyecto final tiene **dos entregables**: la app funcionando y el arnés
documentado. El que se revisa con lupa es el arnés. La app es el banco de
pruebas: interesa que sea troceable en muchas features pequeñas e
independientes, no que sea ambiciosa.

## La idea
Un árbitro de reglamentos de juegos de mesa. El usuario importa el reglamento
de un juego en PDF y pregunta en lenguaje natural lo que se está discutiendo
en la mesa ("¿puedo construir una ciudad sin carretera?"). La app responde
breve y **enseña la regla original**: la página del PDF abierta con el
párrafo resaltado.

El valor no es que genere texto, es que zanja una discusión con la fuente
delante. Si se equivoca, se ve al instante.

## Decisiones ya tomadas
- **Una sola puerta de entrada en el MVP: el PDF.** El importador web y los
  worktrees paralelos quedan fuera (recorte registrado en ADR-003). El
  contrato de importación se mantiene, para que otra fuente pueda entrar más
  adelante sin tocar el resto de la app.
- **Importar significa congelar.** Al importar se extrae el contenido y se
  guarda; en tiempo de pregunta no se vuelve a leer el original. Motivos:
  offline (se juega sin cobertura) y uniformidad.
- **El origen muere en la frontera.** Tras importar existe un único documento
  interno: trozos ordenados, cada uno con su localizador. El resto de la app
  no sabe de dónde vino. En el MVP el localizador es página + rectángulo del
  PDF; una fuente futura (web, foto) solo añadiría su variante de localizador.
- **Solo Foundation Models on-device.** La IA es exclusivamente Foundation
  Models de Apple, con @Generable para la salida estructurada. Sin backend
  remoto. Sin Apple Intelligence disponible, la app ofrece solo búsqueda
  textual.
- **Regla de secuencia:** la app debe ser útil **sin IA** al final de la
  semana 4, y la IA entra como capa enchufable en la semana 5. Base sin IA:
  biblioteca de reglamentos por juego, búsqueda textual, chuleta de reglas
  guardadas con nota propia, historial de disputas, compartir una resolución.
- **La búsqueda textual de la semana 4 es la línea base de las evals.** En la
  semana 5 se compara contra el RAG sobre un set de ~25 preguntas reales con
  su regla y página correctas. Entregar ese número medido, no impresiones.
- **Build y tests por CLI (xcodebuild),** registrado en ADR-001. Los hooks y
  el bucle tienen que funcionar sin Xcode en primer plano.
- **Mi kit de hooks no se instala en este repo.** Solo se copian los hooks
  que necesita este arnés. Parchear o desplegar el kit en otros proyectos
  (Remanso, BookLog) espera a después del 22 de octubre.
- **Horizonte de planificación: hasta el final del módulo 4 (tag m4).** M5 y
  M6 se planifican más adelante.
- **Fuera del MVP a conciencia:** fotografiar páginas de un reglamento de
  papel. Encaja en el mismo contrato sin tocar nada; candidata a semana 6 si
  sobra aire, o a v2.

## Decisiones abiertas
- Nombre de la app.
- Un juego activo o varios en la biblioteca desde el MVP.
- Si la chuleta entra en el MVP y si se alimenta sola de las disputas
  resueltas.
- Historial: ¿de consultas o de disputas (qué se discutió y cómo se resolvió)?
- Qué hace cuando la respuesta **no está** en el reglamento (debe reconocerlo,
  no inventar) y cómo se muestran las reglas con excepciones.
- Estrategia de extracción en reglamentos maquetados a columnas: reconstruir
  el orden de lectura por geometría, o rasterizar y usar el reconocimiento de
  documentos de Vision. Merece una ADR.

## Hipótesis a validar
- **Embeddings con NLContextualEmbedding + similitud coseno en memoria.**
  Entra solo si supera a la búsqueda textual en precisión de página sobre el
  set de ~25 preguntas. Si no la supera, se queda fuera.

## Riesgos conocidos
1. **La maquetación de los reglamentos** (columnas, cajas de excepciones,
   tablas, iconos) es el único punto donde me puedo atascar de verdad.
   Resolverlo pronto, con un solo reglamento, antes de construir encima.
2. **Idioma:** reglamento y preguntas deben ir alineados. Preguntar en
   español sobre un reglamento en inglés degrada la recuperación y en demo
   parece un bug del modelo cuando es de diseño.
3. **Derechos:** no se puede distribuir reglamentos ajenos. Para la demo, uno
   de libre reparto o print-and-play, importado en cámara como lo haría el
   usuario; nunca empaquetado en la app.

## Restricciones técnicas (no negociables)
- iOS nativo: Swift 6+, SwiftUI (nunca UIKit salvo que lo pida), SwiftData,
  Swift Testing, concurrencia estricta, async/await siempre que exista.
- **Cero dependencias de terceros.** Siempre hay solución nativa.
- Serialización solo con Codable. JSONSerialization prohibido.
- Nunca APIs deprecadas: verificar contra documentación oficial de Apple para
  la versión de iOS objetivo.
- Ingesta: PDFKit (que ya da el texto paginado) y Vision.
- Metodología: Spec-Driven Development + TDD con Claude Code. Los tests no
  son opcionales. ADRs para las decisiones con consecuencias.
- Comentarios en código breves y solo cuando la decisión no sea evidente.
  README no extenso.

## Por dónde empezamos
Congelar el alcance del MVP: qué entra y qué no, modelo de dominio, la costura
exacta por la que entra la IA en la semana 5, y la feature list troceada y
repartida por semanas hasta el final del módulo 4. Antes de eso, ayúdame a
cerrar las decisiones abiertas de arriba preguntándome una a una lo que
necesites.