# CasiListo — Dirección de diseño

Documento vivo del sistema visual de la app. Lo consulta cualquiera que toque una
vista: aquí está el porqué de cada token de [Theme.swift](CasiListo/Theme/Theme.swift).
La auditoría que lo originó está al final.

---

## 1. Brief

- **Qué es:** lista de compras nativa para iPhone, pensada para Jumbo y Líder:
  OCR de boletas, widget, notas de voz, catálogo de 355 productos.
- **Quién la usa:** una persona en el pasillo del súper, con una mano en el carro
  y la otra en el teléfono. Mira la pantalla en ráfagas de dos segundos.
- **Su trabajo:** que la compra se termine rápido y sin olvidos, y que después
  quede registro de lo que se pagó.
- **Idioma y voz:** español de Chile, tuteo, frases cortas. «Carro», no «carrito».
- **Restricciones:** SwiftUI + Liquid Glass (iOS 26), cero dependencias,
  AA en todo texto, Dynamic Type hasta AX5, Reduce Motion, VoiceOver. Los UI
  tests tocan labels en español: cualquier texto que cambie se revisa contra ellos.

## 2. Concepto

Tres territorios, una idea elegida.

| | Idea | Ancla | Momento firma | O / F / Fe / P |
| --- | --- | --- | --- | --- |
| **A. Nombre** | Cada lista es una cuenta regresiva hacia «¡Listo!»: la app habla con su propio nombre | «Casi listo» es literalmente el estado de una compra a medio hacer, y el logo es una C que se cierra en un visto | al marcar el último producto el panel se inunda de amarillo, el visto se dibuja y aparece «¡Listo!» | 4 / 5 / 5 / 1 |
| B. Material | La boleta térmica: el historial se imprime como papel de caja | la app ya lee boletas reales de Jumbo y Líder | la compra archivada sale como un ticket con borde dentado | 3 / 4 / 4 / 3 |
| C. Lugar | Las categorías son pasillos con su letrero colgante | el súper chileno | la lista se recorre como un pasillo | 3 / 3 / 3 / 3 |

**Elegido: A.** Es la única que no se puede mudar a otra app (el nombre la
sostiene) y es la más barata de hacer bien: tipografía, un panel y un visto.
**De B se toma** el resumen del historial: el detalle de una compra pasada es un
ticket térmico, con el total en monoespaciada y el borde inferior dentado.

### Tarjeta de concepto

```text
Idea:        Cada lista cuenta hacia atrás hasta «¡Listo!». El número grande es lo que falta.
Metáfora:    El visto bueno: la C del logo que se cierra en un check.
Firma:       Completar. El numeral rueda hacia abajo con cada producto, la barra se
             llena; con 75 % aparece «Casi listo»; con el último, el panel se inunda
             de amarillo, el visto se dibuja y el CTA de archivar sube a primer plano.
Emoción:     Avance. En tres segundos sabes cuánto te falta.
Verbo:       «Marcar»: un trazo corto y decidido, como un visto con lápiz. Los checks se
             dibujan (trim), los números ruedan (numericText), nada flota ni rebota.
Captura:     El panel carbón con el «12» amarillo gigante y «Casi listo» debajo.
```

### Escala de la frase (la voz del concepto)

| Estado | Numeral | Frase |
| --- | --- | --- |
| nada comprado | pendientes | «Todo por comprar» |
| 1 % a 74 % | pendientes | «N de M en el carro» |
| 75 % a 99 % | pendientes | «Casi listo» |
| 100 % | «¡Listo!» | «Todo en el carro» |

El nombre de la app aparece en pantalla exactamente cuando es verdad.

## 3. Sistema

### Paleta (por rol)

| Rol | Claro | Oscuro | Token |
| --- | --- | --- | --- |
| Suelo | `#F5F1EB` crema | `#1C1B1A` | `Color.appBackground` |
| Superficie | `#FFFFFF` | `#2A2928` | `Color.appCardBackground` |
| Tinta | `#1A1A1A` | `#F5F5F5` | `Color.appTextPrimary` |
| Tinta tenue | `#6E6E6E` | `#A0A0A0` | `Color.appTextSecondary` |
| Línea | `#EAE5DD` | `#3A3938` | `Color.appSeparator` |
| Acento (relleno) | `#F5C518` | `#F5C518` | `Theme.accentYellow` |
| Acento (tinta) | `#8A6A00` | `#F5C518` | `Theme.accentInteractive` |
| **Panel** (nuevo) | `#211F1C` carbón | `#0E0D0C` casi negro, filo amarillo al 28 % | `Theme.panel`, `Theme.panelEdge` |
| Tinta de panel | `#F5C518` / `#F2EEE8` / `#B3ADA4` | igual | `Theme.onPanelAccent` / `onPanel` / `onPanelSecondary` |

El panel carbón viene del fondo del ícono: el encabezado de cada lista es el ícono
de la app hecho pantalla. Medido: amarillo sobre carbón 10,1:1, tinta del panel
14,2:1 y tinta tenue 7,4:1 (en oscuro 11,9 / 16,8 / 8,7). En oscuro el panel
**baja** bajo el suelo en vez de subir: la primera versión lo aclaraba a gris y
el crítico lo leyó, con razón, como «una tarjeta gris más». Como panel y suelo
miden 1,1:1, el contorno lo dibuja un filo amarillo tenue, el del ícono.

Reglas: `accentYellow` rellena, `accentInteractive` escribe. Ningún literal
`Color(...)` fuera de Theme.swift. Los colores de estado (`statusPurchased`,
`statusSkipped`, `statusUnavailable`) tienen un solo origen.

### Tipografía

- **Display numérico:** SF Pro Rounded Heavy, 64 pt escalado con Dynamic Type,
  tracking −2, dígitos monoespaciados, `contentTransition(.numericText())`. Solo
  cuenta cosas: pendientes de la lista, total de la compra.
- **Texto:** SF Pro Rounded (la familia actual), de `caption` a `largeTitle`.
- **Datos de boleta:** SF Mono para precios y totales del historial: es la voz
  de la impresora térmica.

### Forma

Un radio para superficies de primer nivel (tarjetas de lista, de categoría, de
ajustes, panel, ticket): **20 pt** (`Theme.cornerRadius`), continuo. Dentro de
hojas modales y para contenido anidado (foto de boleta, campos), 16 pt
(`Theme.smallCornerRadius`). Controles y chips en cápsula.

### Movimiento

- Una sola familia: resortes críticamente amortiguados. `Theme.tickAnimation`
  (0,28 s) para lo pequeño (visto, chip), `Theme.defaultAnimation` (0,35 s) para
  filas, `Theme.panelAnimation` (0,5 s) para el panel. Lo grande se mueve más lento.
- El visto se dibuja (trim 0→1); el círculo se rellena. Al revertir, se borra.
- **Quieto en reposo, a propósito.** Es una herramienta de pasillo: nada se mueve
  si la persona no toca algo. La vida la ponen las respuestas al toque (visto,
  numeral que rueda, hápticos), no un loop decorativo que gasta batería.
- Reduce Motion: toda animación pasa por `Theme.*Animation(reduceMotion:)`, que
  devuelve `nil`. Los estados finales son idénticos; solo desaparece el viaje.

### Composición por pantalla

```text
Mis Listas                         Detalle de lista
┌───────────────────────────┐      ┌───────────────────────────┐
│ Mis Listas          (+)   │      │ ‹  🛒 Compra actual   (…) │
│┌─────────────────────────┐│      │ [Todos][Jumbo][Líder]     │
││ 355        en 2 listas  ││      │┌─────────────────────────┐│
││ por comprar             ││      ││ 355            (👁 ver)  ││
│└─────────────────────────┘│      ││ pendientes              ││
│ ┌───────────────────────┐ │      ││ ▓▓▓░░░░░░░░░░░░░░░░░░░  ││
│ │◉ Compra actual    …   │ │      ││ Todo por comprar        ││
│ │ 355 pendientes ▓░░░░  │ │      │└─────────────────────────┘│
│ │ (Leche)(Pan)(+353)    │ │      │ ┌ Aseo personal   12  ⌄ ┐ │
│ └───────────────────────┘ │      │ └───────────────────────┘ │
└───────────────────────────┘      └───────────────────────────┘
 panel resumen + tarjetas           panel firma + tarjetas de categoría

Historial (detalle)
┌───────────────────────────┐
│ ┌───────────────────────┐ │
│ │ TOTAL PAGADO          │ │  ← ticket: mono, guiones, borde dentado
│ │ $48.390               │ │
│ │ - - - - - - - - - - - │ │
│ │ ✓ 23  ⏱ 2  ⚠ 1        │ │
│ └/\/\/\/\/\/\/\/\/\/\/\/┘ │
│ Lácteos y huevos       4  │
└───────────────────────────┘
```

### Prueba de lo genérico

«Si le pidiera a un modelo genérico una app de lista de compras, ¿llegaría aquí?»
Llegaría a la crema con tarjetas blancas y un resumen en texto pequeño, que es
justo lo que había. Cambiado: el resumen pasa a ser un panel carbón con el
número como imagen; la frase de estado usa el nombre de la app; el visto se
dibuja en vez de aparecer; el historial adopta la voz de la boleta.

---

## 4. Auditoría de UI (08-11-2026)

Método: 23 capturas del simulador (25 después, con el momento firma) (iPhone 17 Pro, iOS 27, claro y oscuro) con
`ci/capture-screenshots.sh`, leídas pantalla por pantalla, más una lectura del
código de cada vista. Un crítico independiente puntuó las mismas capturas sin
ver código ni este documento, con la rúbrica de Awwwards adaptada a app nativa.

### Puntuación de partida (crítico independiente)

| Diseño | Usabilidad | Creatividad | Contenido | Accesibilidad visible | Plataforma | Ponderado |
| --- | --- | --- | --- | --- | --- | --- |
| 6,5 | 6,5 | 6,5 | 7 | 5 | 7,5 | **6,55** |

Su lectura de la idea: «una lista de compras cálida para Chile; fuera de la
paleta, nada en pantalla tiene una idea visual propia».

### Hallazgos

| # | Pantalla | Problema | Severidad | Arreglo |
| --- | --- | --- | --- | --- |
| A0 | barra rápida | **Al escribir la primera letra se cierra el teclado** («Arroz integral» queda en «A»). La fila vivía en un `ViewThatFits` con dos copias del `TextField`: al aparecer el segundo botón, la fila horizontal dejaba de caber según el ancho *ideal* del placeholder y el campo se reemplazaba por la copia vertical, sin foco. Verificado también en `HEAD` limpio: no lo introdujo este rediseño | **Crítica** | Un solo campo en `AnyLayout` con eje según Dynamic Type; regresión en `testQuickAddBarKeepsFocusWhileTyping` (suite del CI) |
| A1 | detalle de lista | El dato que se busca en el pasillo («355 pendientes») es el texto más pequeño de la pantalla: `caption` gris | Alta | Panel carbón con numeral de 64 pt (`SummaryBarView`) |
| A2 | detalle de lista | No hay progreso hasta el primer comprado, y entonces es una línea de 5 pt; la app se llama CasiListo y nunca lo dice | Alta | Barra de 8 pt siempre visible, frase de `ListProgress`, «Casi listo» al 75 % |
| A3 | detalle vacío | CTA «Añadir producto» con `.glassProminent`: oro con blanco en claro, amarillo con blanco en oscuro (1,6:1) | Alta (AA) | `.accentProminent` en ambos modos |
| A4 | Ajustes, boleta | Íconos amarillos sobre blanco (1,6:1), bajo el 3:1 de un gráfico | Alta (AA) | `accentInteractive` |
| A5 | Mis listas, título | Ícono de lista amarillo sobre su tinte amarillo (1,5:1) | Media (AA) | `ListBadgeView.iconColors`, ajuste a 3:1 para toda la paleta (test) |
| A6 | swipe «Editar» | Relleno `B8860B` con etiqueta blanca: 3,25:1 | Media (AA) | `Theme.swipeEditFill` (5,07:1, test) |
| A7 | historial detalle | Cada producto comprado aparece tachado: lo pagado parece anulado; precios en gris pegados al nombre; «Jumbo» en cada fila y truncado («Jum…») | Alta | Ticket térmico, sin tachado, precio en columna mono, tienda solo si la compra mezcla tiendas |
| A8 | historial | Recuentos como íconos sueltos («◎ 1»), sin total | Media | Recuentos en palabras, total en mono, insignia de tienda |
| A9 | catálogo | Al desplazarse queda una franja vacía sin título (el aviso «Añadiendo a…» vivía en un `safeAreaInset` opaco) | Media | El aviso pasa a ser la primera fila de la lista |
| A10 | detalle vacío | Chips de básicos con emoji, cortados contra el borde («Manzanas») | Media | `FlowLayout`, sin emoji, 44 pt de alto |
| A11 | plantillas | Emoji 3D junto a SF Symbols: dos lenguajes de íconos | Media | Insignias SF Symbol con color de la paleta |
| A12 | detalle de lista | Un `ellipsis.circle` por fila: 29 anillos idénticos por categoría | Baja | Glifo sin anillo, mismo blanco de 44 pt |
| A13 | Mis listas | Chips de vista previa truncados («Bolsas basur…»); la tarjeta resumen repetía la única tarjeta | Baja | Tantos nombres enteros como quepan; panel con reparto Jumbo/Líder |
| A14 | varias | Mayúsculas de título en español («Administrar Categorías», «Plantillas de Lista», «Resumen de Gasto», «Nota de Voz») | Baja | Mayúscula solo inicial |
| A15 | varias | Seis literales `Color(light:dark:)` fuera de Theme, contra la convención del proyecto | Baja | `Theme.destructive`, `statusSkipped`, `statusPurchased` |
| A16 | sistema | Radios mezclados (16 en tarjetas de lista y categoría, 20 en ajustes) | Baja | Un radio, 20 pt, para superficies de primer nivel |

| A17 | archivar | El `confirmationDialog` del sistema se anclaba sobre el panel carbón: su vidrio tomaba el negro y las opciones en oro medían 1,2:1 (regresión de la primera pasada de este rediseño); además, las dos opciones se veían iguales | Alta (AA) | `ArchivePurchasedSheet`: «Cerrar la compra», boleta como CTA amarillo, archivar bordeado |
| A18 | quick-add | El chip «Pan» de la lista vacía caía en Congelados: el prefijo «pan» calzaba con «Panoja» antes que con «Pan marraqueta» | Media | Pasada por palabra completa antes del prefijo crudo (`testQuickStaplesLandInTheirExpectedCategory`) |
| A19 | varias | `.shadow` sobre contenedores sombreaba cada texto (halos grises en el ticket) | Baja | Sombra en la silueta o `.compositingGroup()` |

### Fuera de alcance de esta pasada

- **Separación en oscuro**: tarjeta `#2A2928` sobre suelo `#1C1B1A` (1,2:1), en la
  línea de los grises de sistema de Apple. Subirlo obliga a recalibrar los
  contrastes medidos sobre tarjeta oscura en tres tests.
- **Widget**: no se tocó; debería heredar el panel carbón y la frase de `ListProgress`.

## 5. Resultado y siguiente pasada

Tres críticos independientes, cada uno nuevo y sin ver código ni este documento:

| Pasada | Diseño | Usabilidad | Creatividad | Contenido | Accesibilidad visible | Plataforma | Ponderado |
| --- | --- | --- | --- | --- | --- | --- | --- |
| Antes | 6,5 | 6,5 | 6,5 | 7 | 5 | 7,5 | 6,55 |
| Pasada 1 | 7 | 7 | 7 | 7,5 | 6 | 7 | 7,05 |
| Pasada 2 | 7 | 6,5 | 7 | 7,5 | 5,5 | 7,5 | 6,9 |

Las dos últimas leen la idea tal como está en la tarjeta de concepto («un contador
que cuenta hacia atrás en números amarillos, se vuelve amarillo en ¡Listo! y
archiva la compra como boleta»). La pasada 2 se midió *antes* de A17 (diálogo de
archivar a 1,2:1, su hallazgo principal), que ya está corregido.

Lo que más subiría la nota, según los críticos:

1. **El panel ocupa ~46 % de la pantalla** en listas largas: encogerlo a una franja
   fija de ~60 pt (numeral de 28 pt + barra) al hacer scroll. Es el siguiente
   paso natural del concepto; hoy lo cubre a medias el anillo del título.
2. **Barra rápida como `tabViewBottomAccessory`** de iOS 26: compartiría el vidrio
   de la barra de pestañas en vez de ser una franja opaca apilada encima.
3. **La idea vive en tres pantallas** (panel, ¡Listo!, boleta). Catálogo, Ajustes y
   la fila del historial siguen siendo patrón de sistema; la fila del historial
   podría ser un talón de boleta con el borde dentado.
4. **Tarjetas de Mis listas**: en listas grandes, los chips muestran los primeros
   productos («Vino, Botellines 187,5…»); con más de seis pendientes, mejor las
   categorías con más productos («Carnes 40 · Aseo 29»).
5. Detalles: «1.5 kg» en las plantillas (coma decimal chilena), «Guardar» de las
   hojas como botón de confirmación con relleno, y el texto de error en rojo del
   sistema (3,1:1) de la hoja de nueva lista.
