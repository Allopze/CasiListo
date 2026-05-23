# PLAN: Mejoras de UX, Funciones Premium y Reordenamiento para CasiListo

Este plan detalla las mejoras de interfaz y nuevas características propuestas para **CasiListo** diseñadas para enriquecer la usabilidad de la app para tu padre. Respetando plenamente la decisión de diseño de sembrar los ~290 productos sugeridos automáticamente (una excelente forma de evitar que tenga que introducirlos manualmente), este plan se enfoca en hacer que la gestión, búsqueda, ordenamiento y compartición de esa lista pre-sembrada sea lo más cómoda, rápida e intuitiva posible.

---

## User Review Required

> [!IMPORTANT]
> **Preservación del Seeding Masivo:**
> Confirmamos que el método `seedDefaultItems()` en `ContentView.swift` se mantendrá **intacto** y no se realizarán modificaciones para reducir los productos sembrados en el primer inicio. Este comportamiento es vital para asegurar que tu padre cuente con su inventario de compras listo desde el primer día.

> [!NOTE]
> **Priorización de la Interfaz:**
> Al tener ~290 ítems por defecto, el **reordenamiento manual** y la **compartición rápida** son las dos características de mayor impacto inmediato. El reordenamiento le permitirá subir sus productos más frecuentes al inicio de cada sección, y la compartición le permitirá enviar la lista final a sus familiares con un solo toque.

---

## Open Questions

> [!IMPORTANT]
> **¿Cómo prefieres que se maneje la compartición?**
> Proponemos una exportación de texto formateado simple estructurada por categorías que se copia al portapapeles o se envía mediante el `ShareLink` nativo (ideal para WhatsApp). ¿Es suficiente con compartir como texto plano o te gustaría considerar CloudKit en el futuro?

---

## Proposed Changes

A continuación se presentan los cambios organizados por componentes para implementar las mejoras de forma secuencial y modular:

### 1. Modelos de Datos (Soporte para Presupuestos y Precios)

Añadir campos opcionales de precio para calcular el total del carro y el presupuesto estimado.

***

#### [MODIFY] [ShoppingItem.swift](file:///Users/allopze/dev/CasiListo/CasiListo/Models/ShoppingItem.swift)
*   Añadir la propiedad opcional `price: Double?` (persistida con SwiftData) para el cálculo de costos opcional.
*   Añadir la propiedad opcional `estimatedCost: Double?` o derivarla.
*   Actualizar el inicializador para soportar este parámetro opcional con valor por defecto `nil`.

---

### 2. ViewModel de la Lista de Compra (Lógica de Negocio)

Implementar métodos para reordenar elementos y calcular la suma de precios.

***

#### [MODIFY] [ShoppingListViewModel.swift](file:///Users/allopze/dev/CasiListo/CasiListo/ViewModels/ShoppingListViewModel.swift)
*   Implementar una función `moveItem(from source: IndexSet, to destination: Int, within items: [ShoppingItem], context: ModelContext)` para reasignar dinámicamente los valores de `sortOrder` de los ítems de una categoría cuando el usuario los arrastre.
*   Implementar métodos para calcular el coste estimado acumulado de:
    1.  Todos los artículos pendientes.
    2.  Todos los artículos en el carrito (marcados como comprados).
*   Asegurar que la reordenación actualice los registros y guarde el contexto de SwiftData.

---

### 3. Vistas Principales (Visualización del Presupuesto, Reordenamiento y Compartición)

Modificar la UI para integrar los nuevos flujos con soporte completo de Liquid Glass e iOS 26.

***

#### [MODIFY] [ContentView.swift](file:///Users/allopze/dev/CasiListo/CasiListo/Views/ContentView.swift)
*   Agregar un botón de compartir en la barra de herramientas (`ToolbarItem` con `ShareLink`) que genere la lista estructurada por categorías (ej. `*Frutas y verduras*\n- Tomates\n- Manzanas`).
*   Integrar un visualizador de presupuesto discreto abajo de `SummaryBarView` si hay precios asignados.

#### [MODIFY] [CategorySectionView.swift](file:///Users/allopze/dev/CasiListo/CasiListo/Views/CategorySectionView.swift)
*   Añadir soporte para reordenación manual dentro del `ForEach` usando el modificador `.onMove(perform:)`.
*   Asegurar que el botón de colapsar la categoría no interfiera visualmente con el modo de edición y arrastre de la lista.

#### [MODIFY] [ItemRowView.swift](file:///Users/allopze/dev/CasiListo/CasiListo/Views/ItemRowView.swift)
*   Modificar la fila para mostrar el precio del producto junto a la cantidad si este ha sido ingresado (ej. *"Tomates (1 kg) - $1.99"*).

#### [MODIFY] [AddEditItemSheet.swift](file:///Users/allopze/dev/CasiListo/CasiListo/Views/AddEditItemSheet.swift)
*   Añadir un nuevo campo numérico opcional `Precio ($)` en la sección de detalles.
*   Asegurar que se guarde correctamente en el objeto `ShoppingItem`.

---

### 4. Barra de Entrada Rápida (Quick Add Bar)

Diseñar una barra minimalista en la base de la pantalla para añadir productos rápidamente.

***

#### [NEW] [QuickAddBarView.swift](file:///Users/allopze/dev/CasiListo/CasiListo/Views/Components/QuickAddBarView.swift)
*   Crear una barra flotante que se sitúa sobre `BottomAddBarView` o integrada en ella.
*   Consiste en un campo de texto simple y un botón `+` (con efectos de vidrio Liquid Glass adaptativos).
*   Permite escribir, autocompletar rápidamente con las sugerencias en chip, y presionar "Añadir" para agregarlo directamente sin pasar por la hoja modal completa.

---

## Verification Plan

### Automated Tests
*   **Unit Tests (`CasiListoTests.swift`):**
    *   Escribir pruebas unitarias para validar que `moveItem` reasigne correctamente los valores de `sortOrder` sin colisiones de índices.
    *   Probar que el cálculo de presupuestos maneje correctamente los valores `nil` y sume los precios flotantes con precisión de doble decimal.

### Manual Verification
*   **Gestos de Arrastre (Drag and Drop):**
    *   Abrir la app en el Simulador y probar que al entrar en modo edición o al pulsar prolongadamente un ítem se pueda arrastrar hacia arriba y abajo de su categoría, validando que persista el nuevo orden al reiniciar la app.
*   **Compatibilidad con iOS 26 (Liquid Glass):**
    *   Verificar que la nueva barra de añadido rápido (`QuickAddBarView`) se adapte perfectamente con `.glassEffect()` en simuladores de iOS 26+ y degrade graciosamente a `.ultraThinMaterial` en iOS 17/18.
*   **Dynamic Type:**
    *   Mover el slider de accesibilidad en Ajustes y verificar que los elementos del presupuesto, botones de compartir y precios se escalen en harmonía y no causen desbordamiento visual.
