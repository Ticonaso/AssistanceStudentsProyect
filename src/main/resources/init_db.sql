-- ============================================================
--  SISTEMA DE CONTROL DE ASISTENCIA ACADÉMICA
--  IESTP "Pedro P. Díaz" - P.E. Desarrollo de Sistemas de Información
--  Base de Datos: PostgreSQL 15.x
--  Solo estructura: tablas, constraints e índices
--  La lógica de negocio va en Spring Boot (backend)
-- ============================================================

DROP SCHEMA IF EXISTS asistencia CASCADE;
CREATE SCHEMA asistencia;
SET search_path TO asistencia;

CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- ============================================================
-- TABLA: roles
-- RF-04: Control de permisos según rol (ADMIN / DOCENTE)
-- ============================================================
CREATE TABLE roles (
    id          SERIAL PRIMARY KEY,
    nombre      VARCHAR(30)  NOT NULL UNIQUE,
    descripcion TEXT,
    activo      BOOLEAN      NOT NULL DEFAULT TRUE
);

INSERT INTO roles (nombre, descripcion) VALUES
    ('ADMIN',   'Administrador del sistema con acceso completo'),
    ('DOCENTE', 'Docente con acceso a registro de asistencia de sus cursos');

-- ============================================================
-- TABLA: usuarios
-- RF-01: Inicio de sesión con usuario y contraseña
-- RF-02: Crear, editar y eliminar cuentas
-- RF-04: Permisos por rol
-- RF-05: Cierre de sesión seguro (JWT)
-- ============================================================
CREATE TABLE usuarios (
    id                SERIAL PRIMARY KEY,
    rol_id            INTEGER      NOT NULL REFERENCES roles(id),
    nombres           VARCHAR(100) NOT NULL,
    apellidos         VARCHAR(100) NOT NULL,
    dni               CHAR(8)      NOT NULL UNIQUE,
    correo            VARCHAR(150) NOT NULL UNIQUE,
    password_hash     TEXT         NOT NULL,
    telefono          VARCHAR(15),
    primer_ingreso    BOOLEAN      NOT NULL DEFAULT TRUE,
    intentos_fallidos SMALLINT     NOT NULL DEFAULT 0,
    bloqueado_hasta   TIMESTAMPTZ,
    activo            BOOLEAN      NOT NULL DEFAULT TRUE,
    eliminado         BOOLEAN      NOT NULL DEFAULT FALSE,
    creado_en         TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    actualizado_en    TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

-- Seed: administrador inicial (contraseña: Admin@2026 — cambiar en producción)
INSERT INTO usuarios (rol_id, nombres, apellidos, dni, correo, password_hash, primer_ingreso)
VALUES (
    (SELECT id FROM roles WHERE nombre = 'ADMIN'),
    'Administrador', 'Sistema', '00000000',
    'admin@iestp-ppd.edu.pe',
    crypt('Admin@2026', gen_salt('bf', 10)),
    FALSE
);

-- ============================================================
-- TABLA: tokens_invalidos  — blacklist JWT
-- RF-05: Cerrar sesión de manera segura
-- ============================================================
CREATE TABLE tokens_invalidos (
    jti           TEXT        PRIMARY KEY,
    expira_en     TIMESTAMPTZ NOT NULL,
    invalidado_en TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- TABLA: jornadas_laborales
-- RF-14: Registrar jornadas laborales de los docentes
-- ============================================================
CREATE TABLE jornadas_laborales (
    id          SERIAL PRIMARY KEY,
    nombre      VARCHAR(60) NOT NULL UNIQUE,
    hora_inicio TIME        NOT NULL,
    hora_fin    TIME        NOT NULL,
    activo      BOOLEAN     NOT NULL DEFAULT TRUE,
    CONSTRAINT ck_jornada_horas CHECK (hora_fin > hora_inicio)
);

INSERT INTO jornadas_laborales (nombre, hora_inicio, hora_fin) VALUES
    ('Mañana',        '07:00', '13:00'),
    ('Noche',         '18:00', '22:30'),
    ('Tiempo Completo','07:00', '22:30');

-- ============================================================
-- TABLA: docentes
-- RF-03: Registrar, editar y eliminar docentes
-- ============================================================
CREATE TABLE docentes (
    id             SERIAL PRIMARY KEY,
    usuario_id     INTEGER      NOT NULL UNIQUE REFERENCES usuarios(id),
    jornada_id     INTEGER      NOT NULL REFERENCES jornadas_laborales(id),
    especialidad   VARCHAR(100),
    eliminado      BOOLEAN      NOT NULL DEFAULT FALSE,
    creado_en      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    actualizado_en TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

-- ============================================================
-- TABLA: semestres  — catálogo I al VI
-- RF-09: Registro de estudiantes por semestres
-- ============================================================
CREATE TABLE semestres (
    id     SERIAL PRIMARY KEY,
    nombre VARCHAR(20) NOT NULL UNIQUE,
    numero SMALLINT    NOT NULL UNIQUE CHECK (numero BETWEEN 1 AND 6)
);

INSERT INTO semestres (nombre, numero) VALUES
    ('I',1),('II',2),('III',3),('IV',4),('V',5),('VI',6);

-- ============================================================
-- TABLA: turnos  — catálogo Mañana / Noche
-- RF-09: Registro por turno
-- ============================================================
CREATE TABLE turnos (
    id     SERIAL PRIMARY KEY,
    nombre VARCHAR(20) NOT NULL UNIQUE
);

INSERT INTO turnos (nombre) VALUES ('Mañana'), ('Noche');

-- ============================================================
-- TABLA: grupos  — combinación semestre + turno + periodo
-- RF-09: Grupos académicos
-- ============================================================
CREATE TABLE grupos (
    id          SERIAL PRIMARY KEY,
    semestre_id INTEGER     NOT NULL REFERENCES semestres(id),
    turno_id    INTEGER     NOT NULL REFERENCES turnos(id),
    periodo     VARCHAR(20) NOT NULL,
    activo      BOOLEAN     NOT NULL DEFAULT TRUE,
    creado_en   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (semestre_id, turno_id, periodo)
);

-- ============================================================
-- TABLA: tutores
-- RF-12: Registrar tutor o persona de contacto del estudiante
-- ============================================================
CREATE TABLE tutores (
    id         SERIAL PRIMARY KEY,
    nombres    VARCHAR(100) NOT NULL,
    apellidos  VARCHAR(100) NOT NULL,
    dni        CHAR(8),
    telefono   VARCHAR(15),
    correo     VARCHAR(150),
    parentesco VARCHAR(50),
    creado_en  TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

-- ============================================================
-- TABLA: estudiantes
-- RF-09: Registro de estudiantes por grupos
-- RF-10: Dar de baja (papelera) estudiantes
-- RF-12: Tutor asociado
-- ============================================================
CREATE TABLE estudiantes (
    id             SERIAL PRIMARY KEY,
    grupo_id       INTEGER      NOT NULL REFERENCES grupos(id),
    tutor_id       INTEGER      REFERENCES tutores(id),
    nombres        VARCHAR(100) NOT NULL,
    apellidos      VARCHAR(100) NOT NULL,
    dni            CHAR(8)      NOT NULL UNIQUE,
    correo         VARCHAR(150),
    telefono       VARCHAR(15),
    eliminado      BOOLEAN      NOT NULL DEFAULT FALSE,
    creado_en      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    actualizado_en TIMESTAMPTZ  NOT NULL DEFAULT NOW()
);

-- ============================================================
-- TABLA: cursos
-- RF-06: Registrar cursos
-- RF-04 CU04: Código único por semestre + turno
-- ============================================================
CREATE TABLE cursos (
    id             SERIAL PRIMARY KEY,
    semestre_id    INTEGER      NOT NULL REFERENCES semestres(id),
    turno_id       INTEGER      NOT NULL REFERENCES turnos(id),
    codigo         VARCHAR(20)  NOT NULL,
    nombre         VARCHAR(150) NOT NULL,
    creditos       SMALLINT     NOT NULL DEFAULT 3 CHECK (creditos > 0),
    descripcion    TEXT,
    eliminado      BOOLEAN      NOT NULL DEFAULT FALSE,
    creado_en      TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    actualizado_en TIMESTAMPTZ  NOT NULL DEFAULT NOW(),
    UNIQUE (codigo, semestre_id, turno_id)
);

-- ============================================================
-- TABLA: asignaciones_docente_curso
-- RF-07: Asignar docentes a cursos
-- RF-08: Un docente puede tener más de una clase
-- RF-11: Base para controlar que el docente solo acceda a sus cursos
-- ============================================================
CREATE TABLE asignaciones_docente_curso (
    id         SERIAL PRIMARY KEY,
    docente_id INTEGER     NOT NULL REFERENCES docentes(id),
    curso_id   INTEGER     NOT NULL REFERENCES cursos(id),
    periodo    VARCHAR(20) NOT NULL,
    activo     BOOLEAN     NOT NULL DEFAULT TRUE,
    creado_en  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (docente_id, curso_id, periodo)
);

-- ============================================================
-- TABLA: delegados
-- RF-13: El docente podrá registrar al delegado del curso
-- ============================================================
CREATE TABLE delegados (
    id                          SERIAL PRIMARY KEY,
    asignacion_docente_curso_id INTEGER NOT NULL REFERENCES asignaciones_docente_curso(id),
    estudiante_id               INTEGER NOT NULL REFERENCES estudiantes(id),
    desde                       DATE    NOT NULL DEFAULT CURRENT_DATE,
    hasta                       DATE,
    creado_en                   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- TABLA: aulas  — catálogo de aulas/laboratorios
-- RF-16: Validar cruce de horarios (por aula, lógica en backend)
-- ============================================================
CREATE TABLE aulas (
    id     SERIAL PRIMARY KEY,
    nombre VARCHAR(60) NOT NULL UNIQUE,
    activo BOOLEAN     NOT NULL DEFAULT TRUE
);

-- ============================================================
-- TABLA: horarios
-- RF-15: Registrar horarios de clases
-- RF-16: El backend valida cruces antes de insertar
-- RF-17: Base para mostrar el horario semanal del docente
-- RF-20: El backend usa esta tabla para habilitar el módulo de asistencia
-- ============================================================
CREATE TABLE horarios (
    id                          SERIAL PRIMARY KEY,
    asignacion_docente_curso_id INTEGER NOT NULL REFERENCES asignaciones_docente_curso(id),
    aula_id                     INTEGER REFERENCES aulas(id),
    dia_semana                  SMALLINT    NOT NULL CHECK (dia_semana BETWEEN 1 AND 7),
    hora_inicio                 TIME        NOT NULL,
    hora_fin                    TIME        NOT NULL,
    activo                      BOOLEAN     NOT NULL DEFAULT TRUE,
    creado_en                   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT ck_horario_horas CHECK (hora_fin > hora_inicio)
);

-- ============================================================
-- TABLA: sesiones_clase
-- Cada fila = una clase concreta en una fecha específica
-- RF-19: El backend marca 'SUSPENDIDA' si no se registró asistencia
-- RF-25: Fecha y hora exacta de cada sesión
-- RF-26: Unicidad horario + fecha evita sesiones duplicadas
-- ============================================================
CREATE TYPE estado_sesion AS ENUM ('PENDIENTE', 'REGISTRADA', 'SUSPENDIDA');

CREATE TABLE sesiones_clase (
    id             SERIAL PRIMARY KEY,
    horario_id     INTEGER       NOT NULL REFERENCES horarios(id),
    fecha          DATE          NOT NULL,
    hora_inicio    TIME          NOT NULL,
    hora_fin       TIME          NOT NULL,
    estado         estado_sesion NOT NULL DEFAULT 'PENDIENTE',
    creado_en      TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
    actualizado_en TIMESTAMPTZ   NOT NULL DEFAULT NOW(),
    UNIQUE (horario_id, fecha)
);

-- ============================================================
-- TABLA: tipos_asistencia  — catálogo
-- RF-22: Asistencia, Falta, Tardanza, Justificación
-- ============================================================
CREATE TABLE tipos_asistencia (
    id     SERIAL PRIMARY KEY,
    codigo CHAR(1)     NOT NULL UNIQUE,
    nombre VARCHAR(30) NOT NULL UNIQUE
);

INSERT INTO tipos_asistencia (codigo, nombre) VALUES
    ('A', 'Asistencia'),
    ('F', 'Falta'),
    ('T', 'Tardanza'),
    ('J', 'Justificación');

-- ============================================================
-- TABLA: registros_asistencia
-- RF-22: Marcar asistencia por estudiante
-- RF-25: Fecha y hora exacta guardada en registrado_en
-- RF-26: UNIQUE (sesion_id, estudiante_id) evita duplicados
-- RF-27/28: editado_hasta lo calcula el backend y lo persiste aquí
-- ============================================================
CREATE TABLE registros_asistencia (
    id                 SERIAL PRIMARY KEY,
    sesion_id          INTEGER     NOT NULL REFERENCES sesiones_clase(id),
    estudiante_id      INTEGER     NOT NULL REFERENCES estudiantes(id),
    tipo_asistencia_id INTEGER     NOT NULL REFERENCES tipos_asistencia(id),
    registrado_en      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    editado_hasta      TIMESTAMPTZ,
    registrado_por     INTEGER     NOT NULL REFERENCES usuarios(id),
    UNIQUE (sesion_id, estudiante_id)
);

-- ============================================================
-- TABLA: justificaciones
-- RF-23: Adjuntar evidencias (almacenadas en MinIO)
-- RF-24: V°B° del Jefe de Carrera
-- CU12: Flujo extendido desde CU08
-- ============================================================
CREATE TYPE estado_justificacion AS ENUM ('PENDIENTE', 'APROBADA', 'RECHAZADA');

CREATE TABLE justificaciones (
    id                     SERIAL PRIMARY KEY,
    registro_asistencia_id INTEGER               NOT NULL UNIQUE REFERENCES registros_asistencia(id),
    motivo                 TEXT                  NOT NULL,
    archivo_url            TEXT                  NOT NULL,
    archivo_nombre         VARCHAR(255)          NOT NULL,
    archivo_tipo           VARCHAR(50),
    archivo_bytes          INTEGER               CHECK (archivo_bytes <= 10485760),
    estado                 estado_justificacion  NOT NULL DEFAULT 'PENDIENTE',
    requiere_vb            BOOLEAN               NOT NULL DEFAULT FALSE,
    revisado_por           INTEGER               REFERENCES usuarios(id),
    revision_en            TIMESTAMPTZ,
    observacion_revision   TEXT,
    creado_en              TIMESTAMPTZ           NOT NULL DEFAULT NOW(),
    actualizado_en         TIMESTAMPTZ           NOT NULL DEFAULT NOW()
);

-- ============================================================
-- TABLA: configuracion_sistema
-- RF-27/28: Tiempo límite de edición configurable desde el backend
-- ============================================================
CREATE TABLE configuracion_sistema (
    clave          VARCHAR(80) PRIMARY KEY,
    valor          TEXT        NOT NULL,
    descripcion    TEXT,
    actualizado_en TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

INSERT INTO configuracion_sistema (clave, valor, descripcion) VALUES
    ('MINUTOS_EDICION_ASISTENCIA', '30',
     'Minutos que el docente puede editar un registro tras guardarlo (RF-27)'),
    ('MARGEN_APERTURA_MINUTOS', '5',
     'Minutos antes del inicio de clase en que se habilita el módulo (RF-20)'),
    ('MARGEN_CIERRE_MINUTOS', '10',
     'Minutos después de la hora fin para cerrar el registro automáticamente (RF-28)');

-- ============================================================
-- TABLA: log_auditoria
-- RNF-09: Registro de auditoría — escrito desde el backend
-- ============================================================
CREATE TABLE log_auditoria (
    id             BIGSERIAL   PRIMARY KEY,
    usuario_id     INTEGER     REFERENCES usuarios(id),
    accion         VARCHAR(80) NOT NULL,
    tabla_afectada VARCHAR(80),
    registro_id    INTEGER,
    detalle        JSONB,
    ip_origen      INET,
    creado_en      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- TABLA: notificaciones
-- RF-38: Notificar al docente cuando el registro es guardado
-- ============================================================
CREATE TABLE notificaciones (
    id         BIGSERIAL   PRIMARY KEY,
    usuario_id INTEGER     NOT NULL REFERENCES usuarios(id),
    tipo       VARCHAR(50) NOT NULL,
    mensaje    TEXT        NOT NULL,
    leida      BOOLEAN     NOT NULL DEFAULT FALSE,
    creado_en  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- TABLA: reportes_generados
-- RF-32 al RF-35: Historial de exportaciones generadas
-- ============================================================
CREATE TYPE formato_reporte AS ENUM ('PDF', 'WORD', 'EXCEL');

CREATE TABLE reportes_generados (
    id          BIGSERIAL      PRIMARY KEY,
    usuario_id  INTEGER        NOT NULL REFERENCES usuarios(id),
    tipo        VARCHAR(80)    NOT NULL,
    formato     formato_reporte NOT NULL,
    filtros     JSONB,
    archivo_url TEXT,
    generado_en TIMESTAMPTZ    NOT NULL DEFAULT NOW()
);

-- ============================================================
-- ÍNDICES
-- RNF-03: Respuesta < 3 segundos
-- RNF-11: Múltiples usuarios simultáneos
-- ============================================================
CREATE INDEX idx_usuarios_correo         ON usuarios(correo);
CREATE INDEX idx_usuarios_dni            ON usuarios(dni);
CREATE INDEX idx_docentes_usuario        ON docentes(usuario_id);
CREATE INDEX idx_estudiantes_grupo       ON estudiantes(grupo_id);
CREATE INDEX idx_estudiantes_dni         ON estudiantes(dni);
CREATE INDEX idx_cursos_semestre_turno   ON cursos(semestre_id, turno_id);
CREATE INDEX idx_asig_docente_curso      ON asignaciones_docente_curso(docente_id, curso_id);
CREATE INDEX idx_horarios_asig           ON horarios(asignacion_docente_curso_id);
CREATE INDEX idx_horarios_dia_hora       ON horarios(dia_semana, hora_inicio, hora_fin);
CREATE INDEX idx_sesiones_horario_fecha  ON sesiones_clase(horario_id, fecha);
CREATE INDEX idx_reg_asistencia_sesion   ON registros_asistencia(sesion_id);
CREATE INDEX idx_reg_asistencia_est      ON registros_asistencia(estudiante_id);
CREATE INDEX idx_justificaciones_estado  ON justificaciones(estado);
CREATE INDEX idx_log_usuario             ON log_auditoria(usuario_id);
CREATE INDEX idx_log_creado              ON log_auditoria(creado_en DESC);
CREATE INDEX idx_notif_usuario_leida     ON notificaciones(usuario_id, leida);
CREATE INDEX idx_tokens_exp              ON tokens_invalidos(expira_en);

-- ============================================================
-- FIN DEL SCRIPT
-- ============================================================
