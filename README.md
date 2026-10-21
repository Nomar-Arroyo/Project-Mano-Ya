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

## Proyecto de 3er Trimestre (ITSU)

Proyecto de fin de trimestre (ITSU) que se desarrolla y **se expone como una
tesis**: abarca desde el planteamiento del problema y la arquitectura hasta la
implementación, las pruebas y la defensa final ante el jurado.

**Integrantes:**

- **Nomar Arroyo** · nomar.arroyo.itsu@gmail.com
- **Ana Anselmi** · anaanselmi.itsu@gmail.com
- **Alan Mendoza** · alanmendoza.itsu@gmail.com

---

## Tabla de contenido

- [Proyecto de 3er Trimestre (ITSU)](#proyecto-de-3er-trimestre-itsu)
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

# 2. Ejecutar en modo desarrollo sin Supabase (modo mock)
flutter run

# Ejecutar con la configuración local de Supabase (.env, no se sube a Git)
.\tool\run_flutter_with_env.ps1 run

# 3. Compilar APK de depuración
flutter build apk --debug

# 4. Compilar para web
flutter build web
```

## Configuración de Supabase

La app funciona en **modo mock** cuando no se proporcionan credenciales. Para
usar Supabase, copia `.env.example` a `.env` y completa `SUPABASE_URL` y
`SUPABASE_ANON_KEY` con la URL del proyecto y la clave pública `sb_publishable_`
(o la clave pública heredada `anon`). Después ejecuta:

```powershell
.\tool\run_flutter_with_env.ps1 run
```

El script pasa esos valores a Flutter como `--dart-define`; Flutter no carga
archivos `.env` directamente. Para compilar, se puede usar `build` en lugar de
`run` y agregar los argumentos de plataforma, por ejemplo:

```powershell
.\tool\run_flutter_with_env.ps1 build apk --release
```

No pongas una clave `sb_secret_` ni `service_role` en Flutter; son credenciales
privilegiadas. El registro, login y cierre de sesión por correo usan Supabase
Auth y el rol/perfil básico se guarda en metadata del usuario. Los catálogos de
trabajadores, trabajos y cobros siguen en modo mock hasta conectar el esquema
de tablas correspondiente.

## Roles

- **Cliente**: busca trabajadores, filtra por oficio/zona, contacta por WhatsApp
  o solicita presupuesto, notifica pagos.
- **Trabajador**: gestiona su disponibilidad, recibe solicitudes, envía
  solicitudes de cobro (con plan de cuotas) y confirma pagos recibidos.

## Estado de integración

- **Conectado a Supabase Auth** cuando se inicia mediante
  `.\tool\run_flutter_with_env.ps1 run`: registro, inicio/cierre de sesión,
  restauración de sesión y metadata básica del perfil.
- **Pendiente del esquema de tablas**: catálogo de trabajadores, trabajos y
  cobros todavía usan datos mock. Para conectarlos se necesitan los nombres de
  tablas/columnas y sus políticas RLS.
- Google OAuth y MFA/2FA requieren configuración adicional en Supabase.

## Verificación

```bash
dart analyze       # Análisis estático (debe terminar sin hallazgos)
dart format lib    # Formato de código
```

---

Hecho con dedicación para **Mano Ya** · *Tus Oficios a la Mano*.
