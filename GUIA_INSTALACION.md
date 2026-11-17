# ESCUELA DE FORMACIÓN ANALÍTICA — GUÍA COMPLETA DE INSTALACIÓN

## 0. Qué recibes

Sitio React/Vite diseñado para GitHub Pages; catálogo de 13 cursos y 100 módulos; niveles COMPLETOS (4 básicos, 5 intermedios, 4 avanzados) con orden obligatorio; Supabase Auth y base de datos con Row Level Security; panel de administración; 70 % para aprobar módulos; certificados PDF individuales por curso; un certificado global de 2 páginas con anexo de los 13 cursos y 610 horas estimadas; verificación de certificado por código.

**IMPORTANTE:** GitHub Pages NO puede almacenar contraseñas ni calificar exámenes de manera segura. Las cuentas, respuestas correctas, intentos y certificados requieren Supabase. El código está preparado para conectarse a TU propio proyecto Supabase; no trae servidores ni cuentas creadas.

**ESTADO DEL CONTENIDO:** Los 100 módulos se han precargado con sus títulos y recursos generales, pero varios todavía no tienen video específico comprobado. Las preguntas de examen deben crearse y validarse por los administradores en el panel. No otorgues certificados reales hasta completar la curaduría de los videos y el banco de preguntas. El sistema muestra claramente qué módulos tienen videos pendientes.

## 1. Crear Supabase

1. Entra en https://supabase.com/dashboard e inicia sesión.
2. Crea un nuevo proyecto en una organización bajo tu control.
3. En **SQL Editor**, crea una consulta y ejecuta TODO el archivo `supabase/schema.sql`.
4. Crea una segunda consulta, pega TODO `supabase/seed.sql` y ejecútalo. Esto carga los 13 cursos (ordenados por nivel) y los 100 módulos; no publica las respuestas de las evaluaciones.
5. En **Authentication → Providers → Email**, habilita acceso con correo y contraseña. Desactiva la creación pública de cuentas por los estudiantes (opción de signups cuando esté disponible). Los administradores enviarán invitaciones.
6. En **Authentication → URL Configuration**, configura **Site URL** y **Redirect URLs** a la futura dirección exacta de GitHub Pages, por ejemplo `https://TU-USUARIO.github.io/escuela-formacion-analitica/`. Para pruebas locales agrega `http://localhost:5173/`.
7. En **Project Settings → API Keys** guarda la URL del proyecto y la clave **publishable/anon**. NO uses la clave secreta en Vite, GitHub Actions ni código cliente.

### Crear EXACTAMENTE tres administradores

1. En Supabase → **Authentication → Users → Add user**, crea tus tres cuentas de administrador con correo y contraseña seguros (o envía invitaciones desde el panel de Supabase).
2. En SQL Editor ejecuta las tres sentencias siguientes, **sustituyendo los correos** por los reales:

```sql
update public.profiles set role='admin' where email='ADMIN1@EJEMPLO.COM';
update public.profiles set role='admin' where email='ADMIN2@EJEMPLO.COM';
update public.profiles set role='admin' where email='ADMIN3@EJEMPLO.COM';
select email, role from public.profiles where role='admin';
```

3. Confirma que aparecen los tres correos y que NO otorgas el rol `admin` a otros usuarios. La tabla `profiles` no permite que un estudiante se conceda permisos.
4. Si la cuenta se creó antes de ejecutar el esquema y no aparece en `profiles`, introdúcela con:

```sql
insert into public.profiles(id,email,full_name,role)
select id,email,'Nombre del administrador','admin' from auth.users where email='ADMIN1@EJEMPLO.COM'
on conflict(id) do update set role='admin';
```

### Activar invitaciones por correo

El archivo `supabase/functions/invite-user/index.ts` contiene una Edge Function protegida: primero comprueba el usuario mediante Auth y después verifica su rol `admin` en la base de datos. SOLO ENTONCES usa la clave secreta guardada en Supabase para invitar participantes.

**Opción A (CLI recomendada):** instala Supabase CLI como indican https://supabase.com/docs/guides/cli, y en la carpeta del proyecto ejecuta:

```bash
supabase login
supabase link --project-ref TU_PROJECT_REF
supabase functions deploy invite-user --no-verify-jwt
```

La opción `--no-verify-jwt` desactiva únicamente la verificación preliminar de la plataforma: la función **rechaza solicitudes sin token de usuario válido o sin rol administrador**, verificado desde el servidor. Esta opción sirve para las claves publishable modernas, que no deben enviarse como bearer JWT. No quites la validación interna.

**Opción B (Dashboard):** Supabase → Edge Functions → Deploy a new function → Via Editor; ponle `invite-user`, pega el código TypeScript y desactiva la verificación JWT de plataforma en su configuración si es necesario. Verifica con una cuenta administradora antes de permitir invitaciones.

Configura un proveedor SMTP propio en Supabase Auth para enviar muchas invitaciones. El proveedor de correo predeterminado puede tener límites de uso y destinatarios.

## 2. Preparar el sitio localmente

1. Instala Node.js 22 (https://nodejs.org/).
2. Descomprime `escuela-formacion-analitica.zip`.
3. Abre una terminal en la carpeta del proyecto.
4. Ejecuta:

```bash
npm install
```

5. Copia `.env.example` a `.env` y reemplaza los dos valores:

```env
VITE_SUPABASE_URL=https://TU_PROJECT_REF.supabase.co
VITE_SUPABASE_ANON_KEY=TU_CLAVE_PUBLICABLE
```

6. Ejecuta:

```bash
npm run dev
```

7. Abre http://localhost:5173/ y prueba iniciar sesión con una cuenta de administrador.
8. Antes de publicar, comprueba que el panel permite invitar usuarios, que los estudiantes NO pueden ver cursos futuros y que las preguntas no aparecen antes de matricularse.

## 3. Publicar en GitHub Pages (paso a paso)

1. Abre https://github.com/new.
2. Crea un repositorio llamado por ejemplo **escuela-formacion-analitica**. Puedes dejarlo público porque el sistema real de autorización estará en Supabase, pero NO subas claves secretas, expedientes ni respuestas correctas.
3. Sube el contenido COMPLETO de la carpeta del proyecto (incluye `.github/workflows/deploy.yml`; no subas `node_modules`, `.env` ni la carpeta `dist`). Puedes hacerlo desde GitHub con **Add file → Upload files** o con Git.
4. En el repositorio, entra a **Settings → Secrets and variables → Actions** y crea estos dos secretos de repositorio:
   - `VITE_SUPABASE_URL` = dirección HTTPS del proyecto Supabase.
   - `VITE_SUPABASE_ANON_KEY` = clave pública publishable/anon (no secreta).
5. En **Settings → Pages**, selecciona **Build and deployment → Source: GitHub Actions**.
6. En **Actions** ejecuta el flujo **Publicar Escuela en GitHub Pages** si no se ha activado automáticamente al subir archivos a `main`.
7. Cuando termine, entra a `https://TU-USUARIO.github.io/escuela-formacion-analitica/`. La configuración Vite adapta automáticamente la ruta `base` al nombre del repositorio.
8. Vuelve a Supabase → **Authentication → URL Configuration** y registra exactamente esa URL como destino de redirección de invitaciones y recuperación de contraseña.
9. Envía una invitación de prueba desde el panel administrativo. El estudiante debe poder establecer su contraseña e iniciar sesión.

El flujo de GitHub instala dependencias con `npm install`, compila Vite y despliega `dist` automáticamente. No edites directamente `dist`; edita `src` y sube los cambios al repositorio.

## 4. Crear materiales y evaluaciones

1. Entra con una de las cuentas de administrador.
2. Abre **Administración**; en **Editar cursos y módulos**, selecciona el curso y módulo.
3. Edita el texto de la lección, el enlace directo a su video y el material de lectura. No uses videos con inserción bloqueada ni materiales protegidos que no puedan reutilizarse.
4. Pulsa **Agregar pregunta**. Escribe un enunciado claro y coloca cada respuesta en una línea distinta. La **primera opción es índice 0**, la segunda índice 1, etc. Indica el índice correcto; NO se envía al navegador del alumno.
5. Para una calificación suficientemente granular, carga **10 preguntas por módulo**. Esto permite aprobar exactamente con 7 respuestas correctas (=70 %). Si cargas solo cinco, el primer resultado aprobatorio posible será 80 %.
6. Revisa pedagógicamente los reactivos, fuentes y videos antes de aceptar matrículas reales.
7. En caso de error de evaluación, utiliza **Corrección de calificación** con razón documentada. Esto registra una nota correctiva y un registro de auditoría, sin borrar el histórico.

> IMPORTANTE: El sitio viene con la estructura de los 100 módulos pero **no con 1.000 preguntas oficiales**. Los administradores son responsables de completarlas. Por seguridad, las claves de respuesta no forman parte del repositorio público.

## 5. Funcionamiento para los alumnos

- No pueden registrarse libremente: un administrador los invita por correo.
- El alumno establece su contraseña desde la invitación (o mediante restablecimiento).
- El orden es **4 cursos básicos → 5 intermedios → 4 avanzados**.
- Solo puede automatricularse en el curso habilitado; el servidor verifica el curso anterior aprobado.
- Dentro del curso, solo puede continuar cuando haya obtenido **70/100 o más** en el módulo anterior.
- Tres intentos máximos por módulo; los administradores pueden revisar incidencias.
- No existen certificados de módulos.
- Al aprobar todos los módulos de un curso recibe **su certificado individual**.
- Al completar los 13 cursos recibe **certificado global de 2 páginas** con anexo de nombres y horas.
- Los certificados incluyen código verificable que puede consultarse en **Verificar certificado**.

## 6. Diseño de certificados

Archivo: `src/certificates.js`. Plantilla horizontal A4 con fondo blanco, bandas azul marino, doble marco y acentos dorados, de inspiración académica clásica. Toma como referencia visual general la categoría **Certificado de graduación clásico azul y dorado** de Canva: https://www.canva.com/es_es/certificados/plantillas/diploma/ . No reproduce ninguna plantilla protegida ni incorpora logos oficiales sin autorización.

Para el certificado GLOBAL la segunda página incluye la tabla de los 13 cursos y 610 horas académicas **estimadas**. La institución deberá aprobar el cómputo horario, las firmas, el sello y la denominación antes de su uso oficial. El PDF se genera en el navegador; el registro se valida en Supabase usando su código, por lo que alterar manualmente el PDF no cambia los datos registrados.

## 7. Seguridad y límites de esta primera versión

- GitHub Pages expone el HTML, CSS y JavaScript (normal); ninguna contraseña ni clave secreta se almacena allí.
- Supabase Auth guarda las credenciales; RLS controla lecturas y escrituras.
- Los alumnos no pueden modificar notas ni matrículas directamente; los procedimientos SQL controlan requisitos en el servidor.
- Las respuestas correctas se guardan en tabla protegida sin permisos de SELECT a alumnos.
- Para producción institucional deben configurarse políticas de privacidad, condiciones de uso, backups, límites de intentos de autenticación, auditoría continua, acceso mínimo, revisiones de seguridad y un proveedor de correo adecuado.
- El certificado PDF es **verificable en la base de datos**, pero no constituye una firma digital criptográfica ni un documento expedido por autoridad pública hasta que la institución lo respalde formalmente.
- La aplicación no incluye pruebas end-to-end ejecutadas contra una instancia Supabase real ni verificación en vivo de cada video. Prueba todos los flujos antes de operar con personal real.
