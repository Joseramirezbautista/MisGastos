# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

> **Nota:** Toda comunicación, código y documentación en este repositorio debe estar en **español**.

## Descripción del proyecto

**MisGastos** es una app Flutter para el seguimiento de gastos personales, en español (locale es_MX). Soporta Android, iOS y Windows.

## Comandos

```bash
flutter pub get          # Instalar dependencias
flutter run              # Ejecutar en dispositivo/emulador conectado
flutter test             # Correr todas las pruebas
flutter test test/widget_test.dart  # Correr una sola prueba
flutter analyze          # Análisis estático
dart format lib/         # Formatear código
flutter build apk        # Compilar APK de Android
flutter build windows    # Compilar escritorio Windows
```

## Arquitectura

La app usa el patrón **StatefulWidget + SQLite** sin librería de manejo de estado adicional (sin Provider, Bloc, Riverpod, etc.).

### Flujo de navegación

```
SplashScreen (intro animado de 3s)
└── MyHomePage (navegación inferior, 5 pestañas)
    ├── Pestaña 0: ReportesPage       — gráfica de pastel por categoría
    ├── Pestaña 1: GastosDiariosPage  — calendario + lista/formulario de gastos diarios
    ├── Pestaña 2: mensual.dart       — pendiente de implementar
    └── Pestaña 3: Empresas.dart      — pendiente de implementar
```

### Capa de datos

`DatabaseHelper` es un singleton en `lib/database_helper.dart` que gestiona una base de datos SQLite (`gastos.db`) con una sola tabla `gastos`:

| Columna | Tipo | Notas |
|---|---|---|
| id | INTEGER | Clave primaria, auto-incremento |
| categoria | TEXT | Una de 7 categorías predefinidas |
| monto | REAL | Monto del gasto |
| descripcion | TEXT | Descripción opcional |
| fecha | TEXT | Fecha en formato ISO |

El modelo `Gasto` está definido localmente tanto en `gastos_diarios_page.dart` como en `reportes_page.dart` (duplicado, no compartido).

### Detalles clave de implementación

- **Categorías de gasto** están codificadas: `Comida, Transporte, Entretenimiento, Servicios, Salud, Ropa, Otros`
- **GastosDiariosPage** muestra un `TableCalendar` con totales diarios como marcadores, y un modal bottom-sheet para crear/editar gastos
- **ReportesPage** muestra un `PieChart` de `fl_chart` con el desglose por categoría
- El locale se inicializa al arrancar: `await initializeDateFormatting('es_MX', null)`
- El tema usa Material Design 3 con color semilla verde
