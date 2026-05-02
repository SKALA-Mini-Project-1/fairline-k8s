BEGIN;

-- =============================================================
-- incident 스키마: 결제 운영 진단 Agent 전용
-- incident-detector / incident-agent / incident-api 서비스가 공유
-- =============================================================

CREATE SCHEMA IF NOT EXISTS incident;

-- -------------------------------------------------------------
-- 탐지된 사건 원장
-- -------------------------------------------------------------
CREATE TABLE IF NOT EXISTS incident.incidents (
    incident_id             UUID         NOT NULL,
    incident_type           VARCHAR(50)  NOT NULL,
    incident_key            VARCHAR(255) NOT NULL,
    status                  VARCHAR(30)  NOT NULL DEFAULT 'OPEN',
    severity                VARCHAR(20)  NOT NULL,
    confidence              NUMERIC(5,4),
    primary_payment_id      UUID,
    primary_booking_id      UUID,
    user_id                 BIGINT,
    concert_id              BIGINT,
    schedule_id             BIGINT,
    first_detected_at       TIMESTAMPTZ  NOT NULL,
    last_detected_at        TIMESTAMPTZ  NOT NULL,
    last_analyzed_at        TIMESTAMPTZ,
    latest_analysis_version INT          NOT NULL DEFAULT 0,
    needs_human_approval    BOOLEAN      NOT NULL DEFAULT FALSE,
    current_state_jsonb     JSONB,
    open_reason_signal      VARCHAR(100),
    resolved_at             TIMESTAMPTZ,
    resolved_by             VARCHAR(100),
    created_at              TIMESTAMPTZ  NOT NULL DEFAULT now(),
    updated_at              TIMESTAMPTZ  NOT NULL DEFAULT now(),
    CONSTRAINT pk_incidents PRIMARY KEY (incident_id)
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_incident_open
    ON incident.incidents (incident_type, incident_key)
    WHERE status NOT IN ('RESOLVED');

-- -------------------------------------------------------------
-- LLM 분석 이력 (버전 관리)
-- -------------------------------------------------------------
CREATE TABLE IF NOT EXISTS incident.incident_analysis_versions (
    analysis_version_id   UUID         NOT NULL,
    incident_id           UUID         NOT NULL,
    version_number        INT          NOT NULL,
    analysis_status       VARCHAR(20)  NOT NULL,
    input_schema_version  VARCHAR(100),
    output_schema_version VARCHAR(100),
    trigger_type          VARCHAR(50),
    requested_by          VARCHAR(100),
    input_snapshot_jsonb  JSONB,
    output_jsonb          JSONB,
    summary_text          TEXT,
    llm_model             VARCHAR(100),
    prompt_tokens         INT,
    completion_tokens     INT,
    latency_ms            BIGINT,
    failure_reason        TEXT,
    created_at            TIMESTAMPTZ  NOT NULL DEFAULT now(),
    started_at            TIMESTAMPTZ,
    completed_at          TIMESTAMPTZ,
    CONSTRAINT pk_analysis_versions PRIMARY KEY (analysis_version_id),
    CONSTRAINT fk_analysis_incident FOREIGN KEY (incident_id)
        REFERENCES incident.incidents (incident_id),
    CONSTRAINT uq_analysis_version UNIQUE (incident_id, version_number)
);

-- -------------------------------------------------------------
-- incident 상태 변경 이력
-- -------------------------------------------------------------
CREATE TABLE IF NOT EXISTS incident.incident_status_history (
    history_id    UUID        NOT NULL,
    incident_id   UUID        NOT NULL,
    from_status   VARCHAR(30),
    to_status     VARCHAR(30) NOT NULL,
    changed_by    VARCHAR(100),
    change_reason TEXT,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT pk_status_history PRIMARY KEY (history_id),
    CONSTRAINT fk_history_incident FOREIGN KEY (incident_id)
        REFERENCES incident.incidents (incident_id)
);

-- -------------------------------------------------------------
-- incident-detector Kafka Inbox (중복 이벤트 제거)
-- -------------------------------------------------------------
CREATE TABLE IF NOT EXISTS incident.detector_inbox_events (
    id              UUID         NOT NULL,
    dedupe_key      VARCHAR(255) NOT NULL,
    event_type      VARCHAR(100),
    source_topic    VARCHAR(100),
    received_at     TIMESTAMPTZ  NOT NULL DEFAULT now(),
    duplicate_count INT          NOT NULL DEFAULT 0,
    CONSTRAINT pk_detector_inbox PRIMARY KEY (id),
    CONSTRAINT uq_detector_inbox_dedupe UNIQUE (dedupe_key)
);

-- -------------------------------------------------------------
-- 교차 토픽 상태 추적 (유령 주문 / 미확정 결제 탐지)
-- -------------------------------------------------------------
CREATE TABLE IF NOT EXISTS incident.detector_pending_correlations (
    id                 UUID         NOT NULL,
    correlation_type   VARCHAR(50)  NOT NULL,
    key_type           VARCHAR(30)  NOT NULL,
    key_value          VARCHAR(255) NOT NULL,
    trigger_event_type VARCHAR(100),
    triggered_at       TIMESTAMPTZ  NOT NULL,
    deadline_at        TIMESTAMPTZ  NOT NULL,
    extra_jsonb        JSONB,
    resolved           BOOLEAN      NOT NULL DEFAULT FALSE,
    created_at         TIMESTAMPTZ  NOT NULL DEFAULT now(),
    CONSTRAINT pk_pending_correlations PRIMARY KEY (id),
    CONSTRAINT uq_pending_correlation UNIQUE (correlation_type, key_type, key_value)
);

CREATE INDEX IF NOT EXISTS idx_pending_correlations_unresolved
    ON incident.detector_pending_correlations (deadline_at)
    WHERE resolved = FALSE;

-- -------------------------------------------------------------
-- 좀비 예약 Redis 폴링 대상
-- -------------------------------------------------------------
CREATE TABLE IF NOT EXISTS incident.detector_zombie_candidates (
    id               UUID        NOT NULL,
    booking_id       UUID        NOT NULL,
    user_id          BIGINT,
    concert_id       BIGINT,
    schedule_id      BIGINT,
    ended_event_type VARCHAR(50),
    ended_at         TIMESTAMPTZ NOT NULL,
    check_after_at   TIMESTAMPTZ NOT NULL,
    checked          BOOLEAN     NOT NULL DEFAULT FALSE,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT pk_zombie_candidates PRIMARY KEY (id),
    CONSTRAINT uq_zombie_booking UNIQUE (booking_id)
);

CREATE INDEX IF NOT EXISTS idx_zombie_candidates_pending
    ON incident.detector_zombie_candidates (check_after_at)
    WHERE checked = FALSE;

COMMIT;
