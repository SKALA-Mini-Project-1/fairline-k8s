# FairlineTicker Infra Work Log

작성일: `2026-05-02`

## 목적

이 문서는 `fairlineticker` 서비스의 EKS 기반 Kubernetes 인프라 아키텍처를 정리하기 위한 작업 기준서이자 인수인계 문서다.

- 현재 저장소 기준으로 이미 구현된 인프라와 아직 미구현인 인프라를 구분한다.
- "최종 인프라 완성 상태"를 정의해서, 앞으로 무엇을 구현해야 하는지 기준을 고정한다.
- 다른 프롬프트 창이나 다른 작업자에게 넘겨도 동일한 기준으로 작업이 이어지도록 현재 판단, 우선순위, 오픈 이슈를 남긴다.

기준 시점은 `2026-05-02`이며, 저장소 `fairline-k8s`의 실제 매니페스트와 문서를 기준으로 작성한다.

## 작업 목표

- `fairlineticker`의 현재 EKS 인프라 아키텍처를 실제 저장소 기준으로 다시 확정한다.
- 현재 아키텍처와 목표 아키텍처를 분리해서 문서 신뢰도를 높인다.
- Observability, Autoscaling, Canary, CDC처럼 아직 미완성인 축을 별도 추적 대상으로 고정한다.
- 이후 아키텍처 다이어그램 작성과 구현 우선순위 논의의 기준 문서로 사용한다.

## 현재 작업 범위

- 현재 저장소의 Kubernetes 매니페스트 점검
- Terraform 기반 RDS 구성 점검
- 실클러스터 기준 monitoring / autoscaling 현황 점검
- 현재 인프라와 목표 인프라의 구분 기준 확정
- 구현 여부 체크리스트 작성
- 다음 작업자가 이어받을 수 있는 인수인계 메모 정리

## 체크리스트

### 문서 기준 정리

- [x] 현재 인프라 아키텍처를 `Current Architecture`와 `Target Architecture`로 분리하는 원칙 정리
- [x] 메인 인프라 아키텍처에 포함할 요소와 제외할 요소 기준 정리
- [x] 최종 인프라 완성 상태 정의
- [x] 우선순위와 오픈 이슈 정리
- [x] 다음 프롬프트 창에서 이어갈 수 있는 인수인계 메모 작성

### 현재 구현 확인 완료 항목

- [x] `fairline` 네임스페이스 존재 확인
- [x] NGINX Ingress + TLS 구성 확인
- [x] `frontend`, `gateway`, 주요 백엔드 서비스 배포 매니페스트 확인
- [x] `incident-api`, `incident-agent`, `incident-detector` 배포 매니페스트 확인
- [x] `redis` 배포 매니페스트 확인
- [x] `kafka` 배포 매니페스트 확인
- [x] Terraform 기반 PostgreSQL RDS 구성 확인
- [x] RDS logical replication parameter group 구성 확인
- [x] 실클러스터 `monitoring` namespace 존재 확인
- [x] 실클러스터 Prometheus / Grafana 계열 workload 존재 확인
- [x] 실클러스터 `keda` namespace 존재 확인
- [x] 실클러스터 `HPA`, `ScaledObject` 부재 확인
- [x] 실클러스터 `metrics-server` 및 metrics API 가용성 확인
- [x] 주요 Spring 서비스가 Actuator는 포함하지만 Prometheus endpoint는 아직 미노출 상태임을 확인
- [x] 서비스별 `replicas`, `livenessProbe`, `readinessProbe` 구성 확인
- [x] 서비스별 GPU 노드 제외 `nodeAffinity` 구성 확인
- [x] 서비스별 낮은 Hikari pool 제한 구성 확인

### 현재 미구현 또는 불완전 현황

- KEDA는 실클러스터 namespace가 존재하고, 현재는 `queue-service`에 한해 적용을 시작하는 단계다.
- HPA 관련 매니페스트는 현재 저장소에 존재하며, `queue-service`는 KEDA 기반으로 전환 중이다.
- Prometheus / Grafana는 실클러스터에 존재하지만, `fairline-k8s` 저장소에서 배포 source를 확인하지 못했다.
- Loki 관련 매니페스트는 현재 저장소에서 확인되지 않았다.
- Tempo / OTel Collector / Grafana Tempo datasource / Fairline observability dashboard 초안은 현재 저장소에 추가되었다.
- 주요 Spring 서비스는 이제 `prometheus` endpoint 노출과 `ServiceMonitor` 구성이 들어간 상태이며, fan-score / queue 비즈니스 메트릭과 tracing은 재배포 대기 상태다.
- Canary 관련 Argo Rollouts / Flagger 매니페스트는 현재 저장소에서 확인되지 않았다.
- Debezium connector 매니페스트는 현재 저장소에서 확인되지 않았다.
- `NetworkPolicy` 매니페스트는 현재 저장소에서 확인되지 않았다.
- `PodDisruptionBudget` 매니페스트는 현재 저장소에서 확인되지 않았다.
- `ServiceAccount` / `IRSA` 매니페스트는 현재 저장소에서 확인되지 않았다.
- 저장소에는 `secret.yaml.example`만 있고, 실 운영 Secret 관리 방식은 이 문서만으로 확정할 수 없다.

### 구현 작업 체크리스트

- [ ] `Current Architecture` 다이어그램 초안 작성
- [ ] `Target Architecture` 다이어그램 초안 작성
- [x] `queue-service` KEDA 도입 방향 확정
- [x] HPA 1차 적용 대상 서비스 선정
- [x] HPA 1차 매니페스트 초안 작성
- [x] HPA 적용 대상 서비스 1차 클러스터 반영
- [x] `queue-service` KEDA `ScaledObject` 초안 작성
- [x] Monitoring 기준 문서 작성
- [x] HPA 기준 문서 작성
- [x] 주요 서비스 probe를 HTTP 기반으로 고도화 시작
- [x] 주요 Spring 서비스의 Prometheus scrape 초안 구성
- [x] fan-score / queue 비즈니스 메트릭 초안 추가
- [x] Tempo / OTel Collector / Grafana Tempo datasource 초안 추가
- [ ] monitoring namespace 및 observability stack 구조 설계
- [ ] Prometheus / Grafana / Loki / OTel 도입 범위 확정
- [ ] Canary 배포 전략 채택 여부 확정
- [ ] Debezium connector 및 CDC 운영 구조 설계
- [ ] `NetworkPolicy` 적용 범위 정의 및 매니페스트 작성
- [ ] `PodDisruptionBudget` 적용 대상 정의 및 매니페스트 작성
- [ ] `ServiceAccount` / `IRSA` 필요 대상 정의 및 매니페스트 작성
- [ ] Secret 관리 방식을 example 수동 주입에서 표준 운영 방식으로 전환
- [ ] KEDA/HPA가 실제 클러스터나 다른 저장소에 존재하는지 확인
- [ ] monitoring stack의 Git source of truth 정리
- [ ] Kafka가 현재 실사용인지, CDC 준비용인지 팀 기준 확정
- [ ] Secret 실제 운영 방식 확인
- [ ] in-cluster postgres 제거 여부와 제거 절차 확정
- [ ] 백업/복구 runbook 초안 작성
- [ ] Autoscaling 대상 서비스와 기준치 초안 작성
- [ ] Outbox / CDC 연결 구조 최종안 정리

## 작업 대상 파일

- [docs/infra_work_log.md](/Users/jihyunpark/Desktop/fairline-k8s/docs/infra_work_log.md)
- [docs/monitoring_work_log.md](/Users/jihyunpark/Desktop/fairline-k8s/docs/monitoring_work_log.md)
- [docs/hpa_work_log.md](/Users/jihyunpark/Desktop/fairline-k8s/docs/hpa_work_log.md)
- [monitoring/fairline-servicemonitor.yaml](/Users/jihyunpark/Desktop/fairline-k8s/monitoring/fairline-servicemonitor.yaml)
- [keda/queue-service-scaledobject.yaml](/Users/jihyunpark/Desktop/fairline-k8s/keda/queue-service-scaledobject.yaml)
- [hpa/frontend-hpa.yaml](/Users/jihyunpark/Desktop/fairline-k8s/hpa/frontend-hpa.yaml)
- [hpa/gateway-hpa.yaml](/Users/jihyunpark/Desktop/fairline-k8s/hpa/gateway-hpa.yaml)
- [hpa/user-auth-service-hpa.yaml](/Users/jihyunpark/Desktop/fairline-k8s/hpa/user-auth-service-hpa.yaml)
- [hpa/concert-service-hpa.yaml](/Users/jihyunpark/Desktop/fairline-k8s/hpa/concert-service-hpa.yaml)
- [hpa/ticketing-service-hpa.yaml](/Users/jihyunpark/Desktop/fairline-k8s/hpa/ticketing-service-hpa.yaml)
- [hpa/payment-service-hpa.yaml](/Users/jihyunpark/Desktop/fairline-k8s/hpa/payment-service-hpa.yaml)
- [README.md](/Users/jihyunpark/Desktop/fairline-k8s/README.md)
- [namespace.yaml](/Users/jihyunpark/Desktop/fairline-k8s/namespace.yaml)
- [ingress.yaml](/Users/jihyunpark/Desktop/fairline-k8s/ingress.yaml)
- [cert/cluster-issuer.yaml](/Users/jihyunpark/Desktop/fairline-k8s/cert/cluster-issuer.yaml)
- [configmap.yaml](/Users/jihyunpark/Desktop/fairline-k8s/configmap.yaml)
- [secret.yaml.example](/Users/jihyunpark/Desktop/fairline-k8s/secret.yaml.example)
- [concert-service/deployment.yaml](/Users/jihyunpark/Desktop/fairline-k8s/concert-service/deployment.yaml)
- [queue-service/deployment.yaml](/Users/jihyunpark/Desktop/fairline-k8s/queue-service/deployment.yaml)
- [ticketing-service/deployment.yaml](/Users/jihyunpark/Desktop/fairline-k8s/ticketing-service/deployment.yaml)
- [payment-service/deployment.yaml](/Users/jihyunpark/Desktop/fairline-k8s/payment-service/deployment.yaml)
- [user-auth-service/deployment.yaml](/Users/jihyunpark/Desktop/fairline-k8s/user-auth-service/deployment.yaml)
- [frontend/deployment.yaml](/Users/jihyunpark/Desktop/fairline-k8s/frontend/deployment.yaml)
- [gateway/deployment.yaml](/Users/jihyunpark/Desktop/fairline-k8s/gateway/deployment.yaml)
- [incident-api/deployment.yaml](/Users/jihyunpark/Desktop/fairline-k8s/incident-api/deployment.yaml)
- [incident-agent/deployment.yaml](/Users/jihyunpark/Desktop/fairline-k8s/incident-agent/deployment.yaml)
- [incident-detector/deployment.yaml](/Users/jihyunpark/Desktop/fairline-k8s/incident-detector/deployment.yaml)
- [infra/redis/deployment.yaml](/Users/jihyunpark/Desktop/fairline-k8s/infra/redis/deployment.yaml)
- [infra/kafka/deployment.yaml](/Users/jihyunpark/Desktop/fairline-k8s/infra/kafka/deployment.yaml)
- [terraform/fairline/main.tf](/Users/jihyunpark/Desktop/fairline-k8s/terraform/fairline/main.tf)
- [terraform/fairline/terraform.tfvars.example](/Users/jihyunpark/Desktop/fairline-k8s/terraform/fairline/terraform.tfvars.example)
- [docs/npo-requirements.md](/Users/jihyunpark/Desktop/fairline-k8s/docs/npo-requirements.md)
- [docs/rds-worklog.md](/Users/jihyunpark/Desktop/fairline-k8s/docs/rds-worklog.md)

## 작업 로그

- 2026-05-02: `fairline-k8s` 저장소의 현재 Kubernetes 매니페스트와 Terraform 구성을 다시 점검했다.
- 2026-05-02: 현재 아키텍처를 `Current Architecture`와 `Target Architecture`로 분리하는 기준을 확정했다.
- 2026-05-02: 현재 실구현 범위에 `incident-*`, `redis`, `kafka`, `RDS`를 포함해야 한다는 판단을 문서에 반영했다.
- 2026-05-02: Observability, Autoscaling, Canary, Debezium CDC는 현재 저장소 기준 미구현 또는 부분 구현으로 정리했다.
- 2026-05-02: fan-score / queue 흐름을 우선 대상으로 custom metric과 OTLP tracing 초안을 추가했다.
- 2026-05-02: `tracing/tempo.yaml`, `tracing/otel-collector.yaml`, `monitoring/tempo-datasource.yaml`, `monitoring/fairline-observability-dashboard.yaml`를 저장소에 추가했다.
- 2026-05-02: 메인 인프라 아키텍처에 넣을 것과 목표 아키텍처 또는 별도 문서로 빼야 할 것을 구분했다.
- 2026-05-02: 다음 작업자가 이어서 사용할 수 있도록 체크리스트, 오픈 이슈, 후속 작업 순서를 정리했다.
- 2026-05-02: 실클러스터 기준 monitoring / autoscaling 현황을 반영해 `docs/monitoring_work_log.md`, `docs/hpa_work_log.md`를 작성했다.
- 2026-05-02: `metrics-server`는 이미 준비되어 있고, 앱 메트릭 노출은 아직 Prometheus scrape-ready가 아니라는 점을 문서에 반영했다.
- 2026-05-02: `frontend`, `gateway`, 주요 Spring 서비스의 probe를 TCP에서 HTTP health endpoint 기반으로 전환했고, `incident-detector`는 actuator 부재로 TCP를 유지했다.
- 2026-05-02: `hpa/` 디렉터리에 CPU / memory 기반 1차 HPA 초안을 추가하고, DB 연결 여유를 고려해 보수적인 replica 상한을 적용했다.
- 2026-05-02: Prometheus registry 의존성과 `ServiceMonitor` 초안을 추가해 주요 Spring 서비스의 메트릭 수집 기반을 준비했다.
- 2026-05-02: 메트릭 노출은 코드 수정까지 포함하므로, 실제 scrape 확인 전 서비스 이미지 재빌드/재배포가 필요하다는 점을 작업 메모에 반영했다.
- 2026-05-02: `fairline-apps` ServiceMonitor와 주요 Spring 서비스의 `/actuator/prometheus` 수집이 실제 Prometheus target에서 `up == 1`로 확인되었다.
- 2026-05-02: `user-auth-service` HPA는 실부하 테스트에서 CPU 상승에 따라 `2 -> 3` scale out 되는 것을 확인했다.
- 2026-05-02: `queue-service`는 코드 기준으로 대기열 입장과 entry token 발급을 담당하므로, native HPA보다 KEDA 기반 트래픽 autoscaling 후보로 재분류했다.
- 2026-05-02: `queue-service`용 KEDA `ScaledObject`를 적용했고, 기존 native HPA 삭제 후 Prometheus request-rate 기반으로 `2 -> 3` scale out 되는 것을 확인했다.
- 2026-05-02: Spring 서비스 초기 기동 시간이 길어 초반 probe failure가 발생할 수 있어, 주요 Spring 서비스에 `startupProbe`를 추가했다.

---

## 2. 현재 판단 요약

현재 `fairlineticker`의 인프라 아키텍처는 이미 문서화할 수 있다.
다만 한 장의 완성형 아키텍처로 그리기보다 아래 두 장으로 나누는 것이 맞다.

- `Current Architecture`
  현재 EKS 위에서 실제로 배포되었거나, 저장소 기준으로 배포 구성이 존재하는 구성
- `Target Architecture`
  아직 구현되지 않았지만 최종적으로 도입을 목표로 하는 운영 고도화 구성

이 원칙을 지켜야 하는 이유는 다음과 같다.

- Observability, KEDA, Canary, Debezium CDC가 아직 완성되지 않았더라도 현재 인프라 아키텍처 자체는 충분히 설명 가능하다.
- 아직 없는 구성까지 현재 아키텍처에 넣으면 문서 신뢰도가 떨어진다.
- 발표, 보고, 설계 리뷰 시 "현재 운영 상태"와 "목표 상태"를 분리해야 질문 대응이 쉬워진다.

---

## 3. 현재 구현된 인프라 범위

### 3.1 Kubernetes / Runtime

현재 저장소 기준으로 확인되는 주요 런타임 구성은 아래와 같다.

- EKS 클러스터
- `fairline` 네임스페이스
- NGINX Ingress 기반 외부 진입
- `cert-manager` + Let's Encrypt TLS
- `frontend`
- `gateway`
- `user-auth-service`
- `concert-service`
- `ticketing-service`
- `payment-service`
- `queue-service`
- `incident-api`
- `incident-agent`
- `incident-detector`
- `redis`
- `kafka`
- PostgreSQL RDS 연동

### 3.2 현재 아키텍처에 반드시 넣어야 하는 요소

현재 아키텍처 다이어그램에는 아래 요소를 실선 기준으로 포함한다.

- Internet / Domain
- Ingress
- TLS 발급 흐름
- Frontend
- Gateway
- 주요 백엔드 서비스
- Incident 관련 서비스
- Redis
- Kafka
- RDS
- 서비스별 replica, probe, resource limit 같은 기본 운영 설정이 존재한다는 사실

### 3.3 현재 구현된 운영 안정성 요소

현재 저장소 기준으로 이미 반영된 운영성/복원력 관련 요소는 아래와 같다.

- 다수 서비스가 `replicas: 2`로 운영된다.
- 서비스별 `livenessProbe`, `readinessProbe`가 정의되어 있다.
- GPU 노드 제외용 `nodeAffinity`가 적용되어 있다.
- RDS는 logical replication 활성화가 가능하도록 parameter group이 구성되어 있다.
- RDS automated backup retention 값이 정의되어 있다.
- 서비스별 Hikari pool 제한값이 낮게 잡혀 있어 소형 RDS connection exhaustion 리스크를 줄이고 있다.

이 상태는 "운영 고도화가 완성되었다"는 뜻은 아니지만, "최소 운영 가능한 구조"는 이미 성립했다는 뜻이다.

---

## 4. 아직 미구현이거나 불완전한 항목

현재 저장소 기준으로 아래 항목은 미구현 또는 부분 구현 상태로 본다.

### 4.1 Observability

- 실클러스터에는 `monitoring` 네임스페이스와 Prometheus / Grafana가 존재한다
- 다만 `fairline-k8s` 저장소에는 Prometheus / Grafana 배포 source가 없다
- Loki / Jaeger 매니페스트 없음
- Tempo / OTel Collector / Grafana Tempo datasource / Fairline observability dashboard 초안은 현재 저장소에 추가됨
- 메트릭 수집, 대시보드, 알람 규칙 문서 없음
- 현재는 실운영 스택은 일부 존재하지만, 저장소 기준 운영 표준과 문서화는 아직 부족하다

### 4.2 Autoscaling

- `HorizontalPodAutoscaler` 매니페스트 없음
- `KEDA`는 실클러스터 namespace가 존재하지만 저장소에 관련 매니페스트는 없다
- `ScaledObject` 없음
- 실클러스터 기준 트래픽 기반 HPA/KEDA는 실제 적용되어 있지 않다
- 부하 테스트 기준치와 스케일링 임계값 미정

### 4.3 Canary / Progressive Delivery

- Argo Rollouts 없음
- Flagger 없음
- Canary 배포 정책 문서 없음
- 현재 배포는 Rolling Update 중심으로 이해하는 것이 맞다

### 4.4 Outbox / CDC

- Outbox는 서비스 코드 측 구현이 일부 진행된 것으로 대화상 파악되지만, 이 저장소만으로는 전체 완료 여부를 검증할 수 없다
- Debezium connector 매니페스트 없음
- CDC publication / replication slot 운영 절차 문서 없음
- Kafka는 존재하지만, CDC 파이프라인 전체가 완성되었다고 보기는 어렵다

### 4.5 보안 / 운영 고도화

- `secret.yaml` 실파일은 저장소에 없고 `secret.yaml.example`만 존재한다
- ExternalSecret / SealedSecret / AWS Secrets Manager 연동 운영 패턴은 아직 완성되지 않았다
- `NetworkPolicy` 없음
- `PodDisruptionBudget` 없음
- `ServiceAccount` / `IRSA` 매니페스트 없음

---

## 5. 최종 인프라 완성 상태 정의

이 문서에서 정의하는 `최종 인프라 완성 상태`는 아래 조건을 만족하는 상태다.

### 5.1 필수 완료 조건

- EKS 위에서 핵심 서비스가 안정적으로 배포되고 자동 복구된다.
- RDS, Redis, Kafka를 포함한 핵심 인프라 의존성이 문서와 실제 구성에서 일치한다.
- 현재 아키텍처와 목표 아키텍처가 문서로 분리되어 있으며, 팀원 누구나 이해 가능하다.
- 서비스별 health check와 운영 절차가 정리되어 있다.
- 최소한의 장애 진단 절차가 문서화되어 있다.

### 5.2 운영 고도화 완료 조건

- 중앙 로그 수집 경로가 존재한다.
- 메트릭 수집과 대시보드가 존재한다.
- 주요 장애에 대한 알람 기준이 정의된다.
- autoscaling 기준과 적용 대상 서비스가 정리된다.
- 부하 테스트 결과를 바탕으로 replica, resource, scaling 기준이 조정된다.

### 5.3 이벤트 기반 확장 완료 조건

- Outbox 발행 구조가 서비스별로 정리된다.
- CDC 대상이 business table 전체가 아니라 `outbox_event` 중심으로 정리된다.
- Kafka topic, connector, consumer 책임이 문서화된다.
- cross-schema 직접 조회를 줄이는 방향이 확정된다.

### 5.4 보안 및 운영 표준 완료 조건

- Secret 주입 방식이 example 수동 관리 수준을 넘어서 표준화된다.
- 백업과 복구 절차가 문서화된다.
- 인프라 변경 이력과 운영 절차가 반복 가능한 형태로 정리된다.

---

## 6. 아키텍처 문서에 넣을 것과 빼야 할 것

### 6.1 메인 인프라 아키텍처에 넣을 것

아래 항목은 메인 인프라 아키텍처 문서에 포함한다.

- EKS
- Namespace
- Ingress
- TLS
- Frontend
- Gateway
- Backend services
- Incident services
- Redis
- Kafka
- RDS
- 기본 배포 방식이 Rolling Update라는 사실
- probe 기반 기본 복원력

### 6.2 메인 아키텍처에는 "현재 상태"로 넣지 말 것

아래 항목은 현재 아키텍처에 실선으로 넣지 않는다.

- Canary 배포
- KEDA
- HPA
- Prometheus / Grafana / Loki / OTel
- Debezium connector
- 알람 체계
- 세부 부하 테스트 결과

이 항목들은 아래 둘 중 하나로 처리한다.

- `Target Architecture`의 점선 영역으로 표현
- 별도 운영 고도화 문서로 분리

### 6.3 별도 문서로 빼는 것이 더 좋은 주제

- Canary 배포 전략
- Autoscaling 정책과 부하 테스트
- Observability stack 상세
- CDC connector 운영 구조
- SLO / SLA / Alert 정책

---

## 7. 우선순위 판단

현재 시점에서 구현 우선순위는 아래처럼 둔다.

1. 현재 아키텍처 문서 최신화
2. Secret 관리 방식 정리
3. 장애 복구/운영 절차 문서화
4. Observability 최소 설계 확정
5. Autoscaling 적용 여부 결정
6. Outbox / CDC 확장 설계 고정
7. Canary 도입 검토

이 순서를 택하는 이유는 다음과 같다.

- 현재 아키텍처 문서가 먼저 정리되어야 이후 운영 고도화 논의가 흔들리지 않는다.
- Secret, 복구, 운영 절차는 지금 당장 아키텍처 신뢰도와 운영 리스크에 직접 영향을 준다.
- Observability와 Autoscaling은 중요하지만, 현재 운영 구조를 설명하기 위한 선행조건은 아니다.
- Canary는 현재 런타임 구조보다 배포 전략 성격이 강하므로 후순위가 맞다.

---

## 8. 현재 기준 권장 결정

### 8.1 NPO 관련 결정

`장애 복구 및 복원력`, `운영성`, `관측성`은 아키텍처 문서 작성의 필수 선행 완료 조건은 아니다.

다만 문서에는 아래처럼 구분해서 적는 것이 좋다.

- 현재 상태:
  probe, rollout, 로그 기반 운영
- 목표 상태:
  중앙 로그, 메트릭, 대시보드, 알람, 복구 표준화

즉, 이 영역은 "완성되어야만 아키텍처를 그릴 수 있는 요소"가 아니라 "현재 수준과 목표 수준을 구분해서 표시해야 하는 요소"다.

### 8.2 Canary 관련 결정

Canary는 현재 메인 인프라 아키텍처의 필수 구성요소로 보지 않는다.

권장 처리 방식은 아래와 같다.

- 메인 아키텍처에서는 Rolling Update 운영 중이라고 명시
- Canary는 `향후 배포 전략 고도화` 항목으로 별도 분리

### 8.3 Observability 관련 결정

Observability는 메인 인프라 아키텍처에 아예 제외하는 것이 아니라, 아래처럼 다룬다.

- 현재 아키텍처:
  probes, logs, kubectl 기반 운영만 표시
- 목표 아키텍처:
  monitoring namespace, metrics, logs, dashboard, alert를 점선 박스로 표시

### 8.4 HPA / KEDA 관련 결정

HPA/KEDA는 실제 매니페스트가 확인되기 전까지 현재 아키텍처에 넣지 않는다.

권장 표현은 아래와 같다.

- 현재:
  static replica 운영
- 목표:
  traffic-based autoscaling via KEDA/HPA

---

## 9. 다음 작업 체크리스트

다음 프롬프트 창에서 이어서 할 때는 아래 순서로 진행하는 것을 권장한다.

### 9.1 문서 작업

- `Current Architecture` 다이어그램 초안 작성
- `Target Architecture` 다이어그램 초안 작성
- README의 기존 배포 구조 그림과 실제 매니페스트 차이점 정리
- `incident-*`, `kafka`, `RDS` 반영 여부 기준 통일

### 9.2 구현/검증 작업

- KEDA/HPA가 실제 다른 저장소나 클러스터에 존재하는지 확인
- monitoring namespace 또는 observability stack의 실제 배포 여부 확인
- in-cluster postgres 제거 여부와 현재 역할 재확인
- Kafka가 현재 실사용인지, CDC 준비용인지 확인
- Secret 주입의 실제 운영 방식 확인

### 9.3 후속 설계 작업

- 복구/장애 대응 runbook 초안 작성
- autoscaling 대상 서비스 우선순위 선정
- Outbox / CDC 최종 연결 구조 정리
- Canary 도입 시점과 도입 범위 정리

---

## 10. 다른 작업자를 위한 인수인계 메모

다른 프롬프트 창이나 다른 작업자가 이 문서를 읽고 이어서 작업할 경우, 아래 전제를 유지해야 한다.

- 현재 저장소 기준으로는 Observability, KEDA, Canary, Debezium은 완성되지 않았다.
- 따라서 메인 아키텍처는 "현재 실제 운영 구조"만 기준으로 먼저 작성해야 한다.
- 목표 아키텍처는 별도 다이어그램으로 분리해야 한다.
- 현재 기준 메인 아키텍처에 포함되는 핵심 인프라는 EKS, Ingress, TLS, Frontend, Gateway, Backend services, Incident services, Redis, Kafka, RDS다.
- `README.md`의 배포 구조 그림은 최신 상태와 완전히 일치하지 않을 수 있다.
- 이 문서의 목표는 "무엇이 이미 있고 무엇이 아직 없는지"에 대한 팀 내 판단 기준을 고정하는 것이다.

---

## 11. 현재 오픈 이슈

- Kafka를 현재 운영 아키텍처의 핵심 요소로 볼지, 확장 준비 요소로 볼지 팀 합의 필요
- KEDA/HPA가 실제 클러스터에는 있고 저장소에만 없는지 확인 필요
- Observability stack이 다른 저장소에서 관리되는지 확인 필요
- Secret 실제 운영 방식 확인 필요
- in-cluster postgres를 완전히 제거할지 여부 결정 필요

---

## 12. 이 문서의 당장 사용 방법

이 문서를 기준으로 앞으로는 아래 원칙으로 아키텍처 관련 작업을 진행한다.

- 현재 구현된 것은 `Current`
- 아직 목표인 것은 `Target`
- 배포 전략은 별도
- 운영 정책은 별도
- 관측성은 현재 수준과 목표 수준을 분리

이 기준이 유지되면, 앞으로 문서 작성, 발표 자료 작성, 구현 우선순위 정리, 후속 프롬프트 인수인계가 훨씬 쉬워진다.
