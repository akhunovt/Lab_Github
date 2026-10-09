-- Лабораторная работа № 2, вариант 6
-- Упрощённая БД: учебный график дисциплин факультета.
-- PostgreSQL.

DROP SCHEMA IF EXISTS university_3nf CASCADE;
CREATE SCHEMA university_3nf;

-- 1. Модель 3NF
CREATE TABLE university_3nf.study_group (
 group_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 group_code VARCHAR(30) NOT NULL UNIQUE,
 faculty_name VARCHAR(150) NOT NULL,
 admission_year SMALLINT NOT NULL CHECK (admission_year BETWEEN 2000 AND 2100)
);
COMMENT ON TABLE university_3nf.study_group IS 'Учебные группы факультета';

CREATE TABLE university_3nf.discipline (
 discipline_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 discipline_code VARCHAR(30) NOT NULL UNIQUE,
 discipline_name VARCHAR(200) NOT NULL
);
COMMENT ON TABLE university_3nf.discipline IS 'Справочник учебных дисциплин';

CREATE TABLE university_3nf.teacher (
 teacher_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 full_name VARCHAR(200) NOT NULL,
 email VARCHAR(254) UNIQUE
);
COMMENT ON TABLE university_3nf.teacher IS 'Преподаватели';

CREATE TABLE university_3nf.curriculum (
 curriculum_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 group_id BIGINT NOT NULL REFERENCES university_3nf.study_group(group_id),
 academic_year VARCHAR(9) NOT NULL,
 version_no INTEGER NOT NULL DEFAULT 1 CHECK (version_no > 0),
 UNIQUE (group_id, academic_year, version_no)
);
COMMENT ON TABLE university_3nf.curriculum IS 'Учебный график группы на учебный год';

CREATE TABLE university_3nf.curriculum_discipline (
 curriculum_id BIGINT NOT NULL REFERENCES university_3nf.curriculum(curriculum_id) ON DELETE CASCADE,
 discipline_id BIGINT NOT NULL REFERENCES university_3nf.discipline(discipline_id),
 teacher_id BIGINT NOT NULL REFERENCES university_3nf.teacher(teacher_id),
 semester_no SMALLINT NOT NULL CHECK (semester_no BETWEEN 1 AND 12),
 lecture_hours INTEGER NOT NULL DEFAULT 0 CHECK (lecture_hours >= 0),
 practice_hours INTEGER NOT NULL DEFAULT 0 CHECK (practice_hours >= 0),
 assessment_type VARCHAR(30) NOT NULL
   CHECK (assessment_type IN ('экзамен', 'зачёт', 'дифференцированный зачёт')),
 PRIMARY KEY (curriculum_id, discipline_id, semester_no)
);
COMMENT ON TABLE university_3nf.curriculum_discipline IS 'Дисциплины графика: семестр, часы, преподаватель, форма контроля';

CREATE INDEX ix_curriculum_group ON university_3nf.curriculum(group_id);
CREATE INDEX ix_curriculum_discipline_teacher ON university_3nf.curriculum_discipline(teacher_id);

-- 2. Data Vault: 4 HUB, 2 LINK, 5 SATELLITE
DROP SCHEMA IF EXISTS university_dv CASCADE;
CREATE SCHEMA university_dv;

-- HUB: бизнес-ключи и метаданные загрузки
CREATE TABLE university_dv.hub_group (
 group_hk CHAR(64) PRIMARY KEY, group_bk VARCHAR(30) NOT NULL UNIQUE,
 load_dts TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP, record_source VARCHAR(100) NOT NULL
);
CREATE TABLE university_dv.hub_discipline (
 discipline_hk CHAR(64) PRIMARY KEY, discipline_bk VARCHAR(30) NOT NULL UNIQUE,
 load_dts TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP, record_source VARCHAR(100) NOT NULL
);
CREATE TABLE university_dv.hub_teacher (
 teacher_hk CHAR(64) PRIMARY KEY, teacher_bk VARCHAR(100) NOT NULL UNIQUE,
 load_dts TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP, record_source VARCHAR(100) NOT NULL
);
CREATE TABLE university_dv.hub_curriculum (
 curriculum_hk CHAR(64) PRIMARY KEY, curriculum_bk VARCHAR(100) NOT NULL UNIQUE,
 load_dts TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP, record_source VARCHAR(100) NOT NULL
);

-- LINK: связи между HUB
CREATE TABLE university_dv.link_curriculum_group (
 curriculum_group_hk CHAR(64) PRIMARY KEY,
 curriculum_hk CHAR(64) NOT NULL REFERENCES university_dv.hub_curriculum(curriculum_hk),
 group_hk CHAR(64) NOT NULL REFERENCES university_dv.hub_group(group_hk),
 load_dts TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP, record_source VARCHAR(100) NOT NULL,
 UNIQUE (curriculum_hk, group_hk)
);
COMMENT ON TABLE university_dv.link_curriculum_group IS 'Связь учебного графика и группы';

CREATE TABLE university_dv.link_curriculum_discipline_teacher (
 curriculum_discipline_teacher_hk CHAR(64) PRIMARY KEY,
 curriculum_hk CHAR(64) NOT NULL REFERENCES university_dv.hub_curriculum(curriculum_hk),
 discipline_hk CHAR(64) NOT NULL REFERENCES university_dv.hub_discipline(discipline_hk),
 teacher_hk CHAR(64) NOT NULL REFERENCES university_dv.hub_teacher(teacher_hk),
 load_dts TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP, record_source VARCHAR(100) NOT NULL,
 UNIQUE (curriculum_hk, discipline_hk, teacher_hk)
);
COMMENT ON TABLE university_dv.link_curriculum_discipline_teacher IS 'Связь графика, дисциплины и преподавателя';

-- SATELLITE: описательные атрибуты и история
CREATE TABLE university_dv.sat_group_details (
 group_hk CHAR(64) NOT NULL REFERENCES university_dv.hub_group(group_hk),
 load_dts TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
 group_code VARCHAR(30) NOT NULL, faculty_name VARCHAR(150) NOT NULL,
 admission_year SMALLINT NOT NULL, hashdiff CHAR(64) NOT NULL, record_source VARCHAR(100) NOT NULL,
 PRIMARY KEY (group_hk, load_dts)
);
CREATE TABLE university_dv.sat_discipline_details (
 discipline_hk CHAR(64) NOT NULL REFERENCES university_dv.hub_discipline(discipline_hk),
 load_dts TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
 discipline_name VARCHAR(200) NOT NULL, hashdiff CHAR(64) NOT NULL,
 record_source VARCHAR(100) NOT NULL, PRIMARY KEY (discipline_hk, load_dts)
);
CREATE TABLE university_dv.sat_teacher_details (
 teacher_hk CHAR(64) NOT NULL REFERENCES university_dv.hub_teacher(teacher_hk),
 load_dts TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
 full_name VARCHAR(200) NOT NULL, email VARCHAR(254),
 hashdiff CHAR(64) NOT NULL, record_source VARCHAR(100) NOT NULL,
 PRIMARY KEY (teacher_hk, load_dts)
);
CREATE TABLE university_dv.sat_curriculum_details (
 curriculum_hk CHAR(64) NOT NULL REFERENCES university_dv.hub_curriculum(curriculum_hk),
 load_dts TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
 academic_year VARCHAR(9) NOT NULL, version_no INTEGER NOT NULL CHECK (version_no > 0),
 hashdiff CHAR(64) NOT NULL, record_source VARCHAR(100) NOT NULL,
 PRIMARY KEY (curriculum_hk, load_dts)
);
CREATE TABLE university_dv.sat_curriculum_discipline_details (
 curriculum_discipline_teacher_hk CHAR(64) NOT NULL
   REFERENCES university_dv.link_curriculum_discipline_teacher(curriculum_discipline_teacher_hk),
 load_dts TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
 semester_no SMALLINT NOT NULL CHECK (semester_no BETWEEN 1 AND 12),
 lecture_hours INTEGER NOT NULL DEFAULT 0 CHECK (lecture_hours >= 0),
 practice_hours INTEGER NOT NULL DEFAULT 0 CHECK (practice_hours >= 0),
 assessment_type VARCHAR(30) NOT NULL, hashdiff CHAR(64) NOT NULL,
 record_source VARCHAR(100) NOT NULL,
 PRIMARY KEY (curriculum_discipline_teacher_hk, load_dts)
);
COMMENT ON TABLE university_dv.sat_curriculum_discipline_details IS 'Семестр, часы и форма контроля; новые версии сохраняют историю';

CREATE INDEX ix_sat_curriculum_latest ON university_dv.sat_curriculum_details(curriculum_hk, load_dts DESC);
CREATE INDEX ix_sat_curriculum_discipline_latest
 ON university_dv.sat_curriculum_discipline_details(curriculum_discipline_teacher_hk, load_dts DESC);