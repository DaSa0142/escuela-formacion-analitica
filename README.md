# Escuela de Formación Analítica

Aplicación web para GitHub Pages + Supabase. **Leer primero `GUIA_INSTALACION.md`** para la instalación y configuración completa.

- 13 cursos clasificados por nivel de CURSO completo; 100 módulos; 610 horas estimadas.
- Inicio de sesión por invitación de administradores, matrícula secuencial, 70 % por módulo.
- Certificado individual por curso y certificado global de dos páginas.
- Panel de tres administradores configurados desde Supabase (invitación, edición, exámenes y correcciones auditadas).

## Directorios

- `src/main.jsx`: interfaz, navegación, progreso, panel y evaluaciones.
- `src/catalog.json`: catálogo de referencia de 13 cursos y 100 módulos.
- `src/certificates.js`: generador PDF, certificado global de dos páginas.
- `supabase/schema.sql`: tablas, RLS y lógica de autorización segura.
- `supabase/seed.sql`: precarga catálogo, SIN preguntas/respuestas para evitar filtración pública.
- `supabase/functions/invite-user/index.ts`: invitación protegida mediante Supabase Edge Functions.
- `.github/workflows/deploy.yml`: compilación y despliegue automático en GitHub Pages.

## Desarrollo

```bash
npm install
cp .env.example .env
# Editar .env
npm run dev
```

**Pendientes antes de producción:** confirmar todos los videos, escribir preguntas específicas para los 100 módulos, validar objetivos/horas/certificados y probar con Supabase de producción.
