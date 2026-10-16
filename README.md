# Mano Ya — Tus Oficios a la Mano

Aplicación híbrida (móvil/web) desarrollada en **Flutter** que conecta a
**clientes** con **trabajadores de oficios** (construcción, belleza, costura,
mantenimiento, automotriz y eventos) en su zona.

Incluye autenticación con roles, perfil avanzado con 2FA, catálogo de oficios
con geolocalización y contacto directo por WhatsApp, y un módulo completo de
cobro con cuotas/hitos, confirmación de pago y generación de recibo en PDF.

> Backend previsto: **Supabase** (Auth, PostgreSQL, Storage y Realtime). Mientras
> se integran las credenciales reales, la app funciona en **modo mock** para que
> sea 100% navegable y compilable.

---

## Tabla de contenido

- [Características](#-características)
- [Stack tecnológico](#-tech-stack)
- [Arquitectura del proyecto](#-arquitectura-del-proyecto)
- [Requisitos](#-requisitos)
- [Puesta en marcha](#-puesta-en-marcha)
- **Configuración de Supabase** (#-configuración-de-supabase)
- [Roles de usuario](#-roles-de-usuario)
- [Estado del proyecto](#-estado-del-proyecto)
- `test` y verificación

## Características

- **Autenticación y perfiles**: registro/login con Email y Google, selección
  obligatoria de rol (`Cliente` / `Trabajador`), foto de perfil, edición de
  datos y **Verificación en 2 Pasos (2FA)**.
- **Tema claro/oscuro** con detección del tema del sistema y toggle manual,
  junto con una **splash screen** de bienvenida.
- **Catálogo de oficios** con las 6 categorías principales, búsqueda por
  ciudad/zona (autocompletado geolocalizado) y filtro por disponibilidad.
- **Ficha y confianza**: insignias de *Identidad Verificada*, *Trabajo
  Garantizado* y *Disponible Hoy*, además de valoraciones.
- **Comunicación por WhatsApp**: enlace directo `wa.me` con mensaje
  predeterminado estructurado para contactar al trabajador.
- **Módulo de cobro**: solicitud de cobro con datos bancarios/pago móvil,
  **plan de cuotas/hitos** (pago único, 2, 4 o quincenal) con tabla de estado
  (`Pagada` / `Pendiente`), confirmación de pago y **recibo en PDF** con el
  sello *"TRABAJO PAGADO / GARANTIZADO"*.

## Stack tecnológico

| Área | Tecnología |
| --- | --- |
| Framework | Flutter (Dart) — móvil y web |
| Estado | Riverpod |
| Navegación | go_router |
| Backend | Supabase (Auth, PostgreSQL, Storage, Realtime) |
| Geolocalización | OpenStreetMap Nominatim (+ distancia Haversine) |
| PDF | paquete `pdf` |
| Otros | `url_launcher` (WhatsApp), `image_picker`, `shared_preferences`, `intl` |

## Estructura del proyecto

```
lib/
├── core/                     # Infraestructura compartida
│   ├── config/               # Configuración (Supabase vía dart-define)
│   ├── constants/            # Paleta de colores
│   ├── routes/               # Rutas de la app (go_router)
│   ├── services/             # Servicios: Supabase, Storage, PDF, WhatsApp,
│   │                         #   Maps (Nominatim), notificaciones
│   └── theme/                # Temas claro/oscuro y su persistencia
├── features/
│   ├── auth/                 # Autenticación (dominio, datos y UI)
│   ├── billing/              # Cobros, cuotas, confirmación de pago y recibo
│   ├── home/                 # Contenedor con la navegación inferior
│   ├── profile/              # Perfil de usuario y edición
│   ├── requests/             # Solicitud de presupuesto
│   ├── shared/               # Modelos y widgets compartidos
│   ├── splash/               # Pantalla de bienvenida
│   └── workers/              # Catálogo, detalle y trabajadores
└── main.dart                 # Punto de entrada
```

Cada módulo de la carpeta `features/` sigue una separación por capas:
`domain/` (modelos), `data/` (repositorios) y `presentation/`
(providers, páginas y widgets).

## Requisitos

- Flutter SDK (canal estable) y Dart.
- Android Studio / SDK de Android para compilar el APK.
- (Opcional) Un proyecto en Supabase con credenciales.

## Puesta en marcha

```bash
# 1. Instalar dependencias
flutter pub get

# 2. Ejecutar en modo desarrollo (modo mock, sin Supabase)
flutter run

# 3. Compilar APK de depuración
flutter build apk --debug

# 4. Compilar para web
flutter build web
```

## Configuración de Supabase

La app funciona en **modo mock** cuando no se proporcionan credenciales. Para
conectar el backend real, pasa las credenciales mediante `--dart-define`:

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://TU-PROYECTO.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=TU_ANON_KEY
```

Las claves esperadas están documentadas en `.env.example`:

```
SUPABASE_URL=
SUPABASE_ANON_KEY=
```

> Sin `SUPABASE_URL` y `SUPABASE_ANON_KEY`, `SupabaseService` no se inicializa y
> la aplicación usa los repositorios de datos de ejemplo (mock).

## Roles

- **Cliente**: busca trabajadores, filtra por oficio/zona, contacta por WhatsApp
  o solicita presupuesto, notifica pagos.
- **Trabajador**: gestiona su disponibilidad, recibe solicitudes, envía
  solicitudes de cobro (con plan de cuotas) y confirma pagos recibidos.

## Estado del proyecto

El desarrollo se organizó en 4 fases (todas completadas sobre datos mock):

1. **Paso 1** — Cliente de Supabase, temas claro/oscuro y splash screen.
2. **Paso 2** — Autenticación y perfil (foto, 2FA, disponibilidad, cerrar sesión).
3. **Paso 3** — Geolocalización, catálogo de oficios y WhatsApp.
4. **Paso 4** — Cobro, cuotas/hitos, confirmación de pago y recibo en PDF.

## Verificación

```bash
dart analyze       # Análisis estático (debe terminar sin hallazgos)
dart format lib    # Formato de código
```

---

Hecho con dedicación para **Mano Ya** · *Tus Oficios a la Mano*.
