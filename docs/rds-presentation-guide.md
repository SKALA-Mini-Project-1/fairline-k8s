# Fairline RDS 발표 참고 문서

작성일: `2026-05-02`

## 1. 문서 목적

이 문서는 Fairline의 RDS 구조를 발표 자료에 반영할 때 참고할 기준 문서다.

목표는 아래와 같다.

- 왜 MSA 구조인데도 단일 RDS를 사용했는지 설명 근거를 정리한다.
- 같은 DB Host를 사용하더라도 서비스별 데이터 책임을 어떻게 분리했는지 설명한다.
- 현재 RDS 내부의 스키마와 테이블이 어떤 서비스와 매핑되는지 정리한다.
- 발표에서 자신 있게 말해도 되는 내용과, 과장하면 안 되는 내용을 구분한다.
- 이후 ERD 장표 작성 시 참고할 실DB 기준 구조를 남긴다.

이 문서는 아래 3가지를 함께 기준으로 작성했다.

- `fairline-k8s`의 문서/매니페스트
- 실제 EKS 클러스터를 통한 live RDS 조회 결과
- `/Users/jihyunpark/Desktop/SKALA-Mini-Project-2` 내부 실제 서비스 코드

---

## 2. 발표에서 먼저 깔고 가야 할 핵심 메시지

발표에서는 아래 4가지를 먼저 명확하게 말하는 것이 좋다.

1. 현재 Fairline은 `database-per-service`가 아니라 `shared RDS + schema-per-service` 모델을 채택했다.
2. 이 선택은 단기 운영 단순화와 트랜잭션 중심 도메인의 현실적인 제약, 그리고 이후 Outbox/CDC 확장을 함께 고려한 결과다.
3. 같은 RDS를 쓰더라도 서비스별 소유 스키마와 핵심 테이블 책임은 분리되어 있다.
4. 서비스 간 데이터 접근은 "직접 DB 조회"보다 "서비스 API 호출 또는 이벤트 기반 연계"를 지향하며, cross-schema 직접 의존은 점진적으로 줄일 계획이다.

이 네 줄이 먼저 잡혀야 이후 질문이 들어와도 설명 축이 흔들리지 않는다.

---

## 3. 왜 MSA인데 RDS를 쓰는가

발표에서는 아래 수준으로 설명하면 충분하다.

### 3.1 추천 설명

- Fairline은 예약, 좌석, 결제처럼 강한 정합성이 필요한 트랜잭션 중심 도메인을 다룬다.
- 따라서 현재 단계에서는 서비스마다 DB 인스턴스를 완전히 분리하기보다, 하나의 PostgreSQL RDS 안에서 스키마를 분리하는 방식이 운영 현실과 개발 속도 측면에서 더 적합했다.
- 대신 서비스별 소유 테이블과 스키마를 구분하고, 향후 서비스 간 데이터 연계는 Outbox/CDC 기반으로 점진 전환하는 방향을 택했다.

### 3.2 짧은 답변형 문장

- "현재는 shared RDS + schema-per-service 모델을 사용합니다."
- "완전한 DB 분리보다 정합성과 운영 단순화를 우선했고, Outbox/CDC로 점진적으로 서비스 간 데이터 결합을 줄이는 전략입니다."

### 3.3 과장하면 안 되는 표현

아래 표현은 피하는 것이 좋다.

- "서비스별 DB가 완전히 분리되어 있다"
- "서비스 간 DB 의존이 없다"
- "이미 완전한 이벤트 기반 구조다"

현재 상태는 위 세 문장을 그대로 말할 수 있는 수준은 아니다.

---

## 4. 현재 RDS 구조 요약

실제 RDS는 아래 구조로 확인되었다.

- DB Host: `fairline-dev-postgres.c90c2ii6yx10.ap-northeast-2.rds.amazonaws.com`
- Database: `concert`
- 모델: `shared RDS + schema-per-service`

### 4.1 Live Schema 목록

- `auth`
- `concert`
- `incident`
- `payment`
- `queue`
- `ticketing`
- `public`

### 4.2 발표용으로 설명할 스키마 책임

- `auth`: 사용자/인증 관련 데이터
- `concert`: 아티스트, 콘서트, 회차, 좌석 원천 데이터
- `ticketing`: 예약, 예약 좌석 매핑, 정합성 복구 작업, ticketing inbox/outbox
- `payment`: 결제, 환불, 결제 이벤트
- `queue`: 대기열/팬스코어 관련 데이터
- `incident`: 운영 진단/incident 분석 관련 데이터

---

## 5. 서비스별 데이터 책임 매핑

아래 표는 발표 자료에 거의 그대로 반영해도 되는 수준의 책임 매핑이다.

| 서비스 | 소유 스키마 | 핵심 소유 테이블 | 설명 |
| --- | --- | --- | --- |
| `user-auth-service` | `auth` | `users` | 사용자 계정 및 기본 프로필 |
| `concert-service` | `concert` | `artist`, `concerts`, `schedules`, `seats` | 공연 및 좌석의 원천 데이터 |
| `ticketing-service` | `ticketing` | `bookings`, `booking_items`, `reconciliation_tasks`, `ticketing_inbox_events`, `ticketing_outbox` | 예약 생성/확정/복구 책임 |
| `payment-service` | `payment` | `payments`, `refunds`, `payment_events` | 결제 상태와 환불, 결제 이벤트 책임 |
| `queue-service` | `queue` | `user_artist_fan_scores` | 대기열/팬스코어 계산에 필요한 데이터 책임 |
| `incident-api` / `incident-agent` / `incident-detector` | `incident` | `incidents`, `incident_analysis_versions`, `incident_status_history`, `detector_*` | 운영 진단 및 incident 분석 책임 |

### 5.1 실제 코드 근거 예시

- `user-auth-service`는 `auth.users`를 사용한다: [User.java](</Users/jihyunpark/Desktop/SKALA-Mini-Project-2/user-auth-service/src/main/java/com/example/SKALA_Mini_Project_1/modules/users/User.java:20>)
- `concert-service`는 `concert.seats`를 사용한다: [Seat.java](</Users/jihyunpark/Desktop/SKALA-Mini-Project-2/concert-service/src/main/java/com/example/SKALA_Mini_Project_1/modules/seats/domain/Seat.java:21>)
- `ticketing-service`는 `ticketing.bookings`를 사용한다: [Booking.java](</Users/jihyunpark/Desktop/SKALA-Mini-Project-2/ticketing-service/src/main/java/com/example/SKALA_Mini_Project_1/modules/bookings/domain/Booking.java:15>)
- `ticketing-service`는 `ticketing.reconciliation_tasks`를 사용한다: [ReconciliationTask.java](</Users/jihyunpark/Desktop/SKALA-Mini-Project-2/ticketing-service/src/main/java/com/example/SKALA_Mini_Project_1/modules/reconciliation/domain/ReconciliationTask.java:16>)
- `payment-service`는 `payment.payments`, `payment.payment_events`, `payment.refunds`를 사용한다:
  - [Payment.java](</Users/jihyunpark/Desktop/SKALA-Mini-Project-2/payment-service/src/main/java/com/example/SKALA_Mini_Project_1/modules/payments/domain/Payment.java:21>)
  - [PaymentEvent.java](</Users/jihyunpark/Desktop/SKALA-Mini-Project-2/payment-service/src/main/java/com/example/SKALA_Mini_Project_1/modules/payments/domain/PaymentEvent.java:18>)
  - [Refund.java](</Users/jihyunpark/Desktop/SKALA-Mini-Project-2/payment-service/src/main/java/com/example/SKALA_Mini_Project_1/modules/payments/domain/Refund.java:18>)
- `queue-service`는 `queue.user_artist_fan_scores`를 사용한다: [UserArtistFanScore.java](</Users/jihyunpark/Desktop/SKALA-Mini-Project-2/queue-service/src/main/java/com/example/SKALA_Mini_Project_1/modules/fanscore/UserArtistFanScore.java:22>)
- incident 계열 서비스는 `incident` 스키마를 사용한다:
  - [incident-api application.properties](</Users/jihyunpark/Desktop/SKALA-Mini-Project-2/incident-api/src/main/resources/application.properties:8>)
  - [Incident.java](</Users/jihyunpark/Desktop/SKALA-Mini-Project-2/incident-agent/src/main/java/com/example/incident/agent/domain/Incident.java:16>)
  - [IncidentAnalysisVersion.java](</Users/jihyunpark/Desktop/SKALA-Mini-Project-2/incident-agent/src/main/java/com/example/incident/agent/domain/IncidentAnalysisVersion.java:16>)

---

## 6. 같은 DB Host를 써도 데이터 책임 분리가 되는 이유

발표에서는 "물리적으로 같은 RDS를 바라보지만 논리 책임은 나뉜다"는 점을 명확하게 말해야 한다.

### 6.1 추천 설명

- 물리적으로는 하나의 PostgreSQL RDS를 사용한다.
- 하지만 서비스별로 기본 스키마와 소유 테이블이 다르다.
- 각 서비스는 자기 도메인의 상태를 기록하는 테이블을 소유한다.
- 다른 서비스의 원천 데이터를 직접 수정하는 대신, 원칙적으로는 API 호출이나 이벤트 기반 연계로 접근해야 한다.

### 6.2 발표에서 꼭 넣으면 좋은 문장

- "같은 RDS를 쓰더라도 서비스별 소유 테이블은 분리되어 있습니다."
- "예를 들어 사용자 정보의 원천 데이터는 `auth.users`이고, 예약 정보의 원천 데이터는 `ticketing.bookings`, 결제 정보의 원천 데이터는 `payment.payments`입니다."
- "다른 서비스가 필요한 정보를 얻을 때는 해당 서비스의 API를 통해 가져오는 것이 원칙입니다."

---

## 7. 서비스 간 데이터 접근 원칙

이 섹션은 발표에서 설득력이 중요하므로 별도로 강조하는 것이 좋다.

### 7.1 발표용 원칙

- 서비스는 자기 소유 테이블을 authoritative source로 가진다.
- 다른 서비스의 원천 정보를 직접 SQL로 조회하기보다 서비스 API 또는 이벤트를 통해 가져오는 것이 원칙이다.
- 같은 DB Host를 공유하더라도, "누가 어떤 데이터를 소유하는가"는 분리해서 본다.

### 7.2 queue-service 설명 예시

질문이 들어올 가능성이 높은 예시로 `queue-service`를 아래처럼 설명할 수 있다.

- `queue-service`는 사용자 존재 여부와 공연/회차 검증을 내부 API 호출로 처리한다.
- 실제 코드에서도 `user-auth-service`와 `concert-service`로 HTTP 호출을 보낸다.
- 따라서 사용자 원천 정보와 공연 원천 정보를 queue-service가 직접 소유하는 것은 아니다.

코드 근거:

- [UserAuthClient.java](</Users/jihyunpark/Desktop/SKALA-Mini-Project-2/queue-service/src/main/java/com/example/SKALA_Mini_Project_1/integration/userauth/UserAuthClient.java:12>)
- [ConcertServiceClient.java](</Users/jihyunpark/Desktop/SKALA-Mini-Project-2/queue-service/src/main/java/com/example/SKALA_Mini_Project_1/integration/concert/ConcertServiceClient.java:12>)

발표에서 쓸 수 있는 문장:

- "`queue-service`는 사용자와 공연의 원천 데이터를 직접 소유하지 않고, 내부 API 호출로 검증합니다."

### 7.3 단, 현재 구조에서 솔직하게 말해야 하는 점

아래는 과도기적 구조로 보는 것이 맞다.

- 일부 서비스는 `currentSchema`에 여러 스키마를 포함한다.
- 일부 테이블은 cross-schema foreign key를 가진다.
- 따라서 완전한 database isolation이 아니라, schema-per-service 기반의 논리 분리 단계라고 설명하는 것이 정직하다.
- 특히 팬점수 데이터인 `queue.user_artist_fan_scores`는 물리적으로는 `queue` 스키마에 있지만, 실제 조회/갱신 책임은 `user-auth-service` 내부 API와도 연결되어 있어 ownership 경계가 다소 과도기적으로 보인다.

이 부분을 숨기기보다 아래처럼 설명하는 것이 좋다.

- "현재는 shared RDS 안에서 schema 분리를 우선 적용했고, cross-schema 의존은 이후 Outbox/CDC 기반으로 점진 축소할 예정입니다."

### 7.4 내부 참고 메모: 팬점수 ownership

이 항목은 발표 장표에 크게 넣기보다는 내부 참고용으로 유지하면 좋다.

- `queue.user_artist_fan_scores`는 현재 `queue` 스키마에 존재한다.
- 하지만 `queue-service`는 팬점수 계산 시 `user-auth-service`의 내부 API를 호출한다.
- `user-auth-service`도 같은 `queue.user_artist_fan_scores`를 조회/갱신하는 코드가 있다.
- 따라서 현재 구조는 "팬점수 데이터가 완전히 queue-service 단독 소유다"라고 단정하기보다, 과도기적 ownership 상태로 보는 것이 안전하다.
- 지금 단계에서는 이 구조를 바로 변경하기보다, 추후 팬점수 데이터의 최종 owner를 `queue-service` 또는 `user-auth-service` 중 어디로 둘지 정리 과제로 남기는 편이 안전하다.

---

## 8. 현재 구조에서 발표 시 반드시 같이 말해야 하는 제한사항

아래 내용은 발표에 한 줄이라도 넣는 것이 좋다.

### 8.1 현재는 database-per-service가 아니다

- 현재는 shared RDS를 사용한다.
- 서비스 간 완전 물리 분리보다 논리 스키마 분리를 우선 적용한 상태다.

### 8.2 서비스별 DB 계정까지 분리된 것은 아니다

- 현재 클러스터는 동일 DB 계정을 공유한다.
- 즉 스키마 분리는 되어 있지만 role-per-service 수준의 권한 강제까지는 아직 아니다.

이 부분은 공격 포인트가 될 수 있으므로, 먼저 인정하고 "현재 단계의 현실적 선택"이라고 설명하는 것이 좋다.

추천 표현:

- "현재는 서비스별 DB 계정까지 나눈 상태는 아니고, 우선 스키마와 도메인 책임 분리를 적용한 단계입니다."

### 8.3 cross-schema 참조가 일부 존재한다

실제 FK 기준 예시:

- `ticketing.bookings -> auth.users`
- `ticketing.bookings -> concert.schedules`
- `ticketing.booking_items -> concert.seats`
- `payment.payments -> ticketing.bookings`
- `queue.user_artist_fan_scores -> auth.users`, `concert.artist`

따라서 발표에서 "서비스 간 DB 참조가 완전히 없다"는 식의 표현은 피해야 한다.

대신 아래처럼 설명하는 것이 적절하다.

- "현재는 트랜잭션 정합성을 우선한 일부 교차 참조가 존재하며, 장기적으로는 이벤트 기반으로 줄여갈 계획입니다."

---

## 9. 실DB 기준 주의할 점

실제 RDS를 확인한 결과, 발표 장표를 만들 때 아래 내용은 함께 알고 있어야 한다.

### 9.1 실DB는 초기 문서보다 더 진화해 있다

live RDS에는 아래가 이미 존재한다.

- `incident` 스키마 전체
- `ticketing_outbox`
- `ticketing_inbox_events`
- `reconciliation_tasks`

즉 발표 장표는 반드시 현재 실DB 상태를 기준으로 그리는 것이 좋다.

### 9.2 정리 후보 테이블이 보인다

실DB row count 기준:

- `concert.seats`: 사용 중
- `ticketing.seats`: 0 rows
- `queue.user_artist_fan_scores`: 사용 중
- `ticketing.user_artist_fan_scores`: 0 rows

코드 기준으로도:

- `ticketing-service`는 `concert.seats`를 사용한다
- `ticketing-service`의 팬스코어 엔티티는 `queue` 스키마를 바라본다

따라서 `ticketing.seats`, `ticketing.user_artist_fan_scores`는 현재 발표용 장표에서는 주 테이블로 강조하지 않는 것이 안전하다.

발표에서는 아래처럼 처리하는 것이 좋다.

- 장표에는 실제 책임 테이블 위주로 표기
- 정리 후보 테이블은 발표 본문보다 내부 작업 메모에 남기기

---

## 10. 발표 장표에 넣기 좋은 구성

### 10.1 슬라이드 1: 왜 shared RDS를 썼는가

- 단일 PostgreSQL RDS 사용
- schema-per-service로 논리 분리
- 정합성 우선 도메인에 맞춘 현실적 선택
- 향후 Outbox/CDC 확장 준비

### 10.2 슬라이드 2: 서비스별 데이터 책임 분리

- `auth` -> `user-auth-service`
- `concert` -> `concert-service`
- `ticketing` -> `ticketing-service`
- `payment` -> `payment-service`
- `queue` -> `queue-service`
- `incident` -> `incident-*`

### 10.3 슬라이드 3: 서비스 간 접근 원칙

- 자기 데이터는 자기 스키마가 소유
- 다른 서비스 데이터는 API 호출 또는 이벤트 기반 접근
- 예시: `queue-service`는 `user-auth-service`, `concert-service`로 내부 API 호출

### 10.4 슬라이드 4: RDS 스키마/테이블 맵

- 스키마별 테이블 이름만 간단히 표기
- 컬럼 상세는 제외
- ERD 또는 schema map 형식으로 표현

---

## 11. 발표에서 공격받기 쉬운 질문과 추천 답변

### Q1. MSA인데 왜 DB를 하나만 쓰나요?

추천 답변:

- "현재는 shared RDS + schema-per-service 모델을 채택했습니다. 예약/결제/좌석처럼 정합성이 강하게 요구되는 도메인이라 운영 복잡도와 정합성을 함께 고려한 선택이었고, 이후 Outbox/CDC로 서비스 간 결합을 점진적으로 줄일 계획입니다."

### Q2. 그러면 MSA가 아닌 것 아닌가요?

추천 답변:

- "완전한 database-per-service 단계는 아닙니다. 다만 서비스별 도메인 책임, 스키마, 소유 테이블을 분리했고 서비스 간 접근도 API 또는 이벤트 기반으로 이동시키는 과도기 구조입니다."

### Q3. 다른 서비스 테이블을 직접 보면 안 되는 것 아닌가요?

추천 답변:

- "맞습니다. 원칙적으로는 직접 참조보다 API 또는 이벤트를 우선해야 합니다. 현재 구조에는 일부 과도기적 cross-schema 의존이 있고, 이 부분은 Outbox/CDC로 점진적으로 줄일 계획입니다."

### Q4. queue-service가 user 정보를 직접 DB에서 읽나요?

추천 답변:

- "원천 사용자 정보는 `auth.users`이고, queue-service는 내부 API 호출을 통해 사용자 존재 여부와 팬스코어 관련 정보를 확인하도록 구성되어 있습니다."

---

## 12. RDS ERD 확인 방법

### 12.1 AWS 콘솔에서 바로 ERD를 그릴 수 있는가

- AWS RDS 콘솔 자체에는 일반적인 ERD 시각화 기능이 없다.
- 콘솔에서는 endpoint, 보안그룹, 파라미터 그룹, 연결 정보 확인 정도를 한다.

### 12.2 가장 현실적인 방법

- `DBeaver`
- `pgAdmin`
- `DataGrip`

같은 PostgreSQL 클라이언트로 접속해서 schema browser 또는 ERD 기능을 사용하는 것이 가장 쉽다.

### 12.3 접속 정보

- Host: `fairline-dev-postgres.c90c2ii6yx10.ap-northeast-2.rds.amazonaws.com`
- Port: `5432`
- DB: `concert`
- User: 클러스터에 설정된 `DB_USER`

단, RDS가 private endpoint라면 로컬에서 바로 접속되지 않을 수 있다.
이 경우 아래 방식 중 하나를 사용한다.

- EKS 내부 임시 pod에서 접속
- bastion/EC2를 통한 SSH tunnel

### 12.4 SSH tunnel 예시

```bash
ssh -L 5433:fairline-dev-postgres.c90c2ii6yx10.ap-northeast-2.rds.amazonaws.com:5432 <jump-host>
```

이후 클라이언트에서는 아래처럼 접속한다.

- host: `localhost`
- port: `5433`
- database: `concert`

### 12.5 발표용 ERD 작성 팁

- 컬럼을 전부 적지 말고, 스키마와 테이블 이름 위주로 그린다.
- FK가 중요한 핵심 관계만 화살표로 남긴다.
- `auth.users`, `concert.schedules`, `concert.seats`, `ticketing.bookings`, `payment.payments` 정도만 주요 흐름 관계로 표시해도 충분하다.

---

## 13. 발표용 문장 초안

아래 문장은 발표 자료 본문이나 발표 멘트로 바로 활용할 수 있다.

### 13.1 한 단락 요약

Fairline은 현재 하나의 PostgreSQL RDS를 공유하되, 서비스별 스키마를 분리하는 `shared RDS + schema-per-service` 모델을 사용한다. 이는 예약, 결제, 좌석과 같은 강한 정합성이 필요한 도메인에서 운영 단순성과 데이터 일관성을 함께 고려한 선택이다. 각 마이크로서비스는 자신이 소유한 스키마와 테이블을 기준으로 데이터를 관리하며, 다른 서비스의 원천 데이터는 직접 소유하지 않는다. 서비스 간 데이터 연계는 API 호출 또는 향후 Outbox/CDC 기반 이벤트 구조로 점진 전환할 계획이다.

### 13.2 짧은 bullet 버전

- 하나의 RDS를 사용하지만 스키마 단위로 도메인 책임을 분리했다.
- 사용자, 공연, 예약, 결제, 대기열, incident 데이터는 서비스별 소유 테이블이 다르다.
- 다른 서비스 데이터는 직접 소유하지 않고 API 또는 이벤트 연계를 원칙으로 한다.
- 현재는 과도기적 cross-schema 참조가 일부 있으며, 장기적으로 Outbox/CDC로 줄여갈 계획이다.

---

## 14. 현재 기준 후속 권장 작업

발표 자료 외에도 내부적으로 아래 항목은 정리해두는 것이 좋다.

- 서비스별 DB role 분리 가능성 검토
- `ticketing.seats`, `ticketing.user_artist_fan_scores` 정리 여부 판단
- 허용된 cross-schema 참조와 제거 대상 참조를 문서화
- Outbox/CDC 전환 시 어떤 테이블부터 direct dependency를 제거할지 우선순위 지정
