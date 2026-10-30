// Bootstrap propio de Flutter Web.
//
// Flutter genera por defecto un service worker que guarda main.dart.js y sirve
// la version anterior hasta que el navegador la reemplaza. En este proyecto eso
// hacia que, tras cada despliegue, se siguiera viendo la app vieja ("proximamente"
// en el boton de recuperar contrasena). Al no pedir `serviceWorkerSettings`, el
// loader no registra ese service worker y cada visita descarga la version actual.
{{flutter_js}}
{{flutter_build_config}}

_flutter.loader.load();
