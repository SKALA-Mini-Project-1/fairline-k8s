# Fairline Monitoring Work Log

작성일: `2026-05-02`

## 목적

- `fairlineticker`의 Kubernetes 운영에서 무엇을 모니터링해야 하는지 기준을 고정한다.
- 현재 실클러스터에서 확인된 monitoring 구성과, 저장소에서 관리되지 않는 부분을 분리해서 기록한다.
- 이후 Prometheus / Grafana / 알람 / 부하 테스트 작업의 기준 문서로 사용한다.

## 현재 작업 범위

- 실클러스터 기준 monitoring 관련 namespace / workload 존재 여부 기록
- 어떤 레이어를 모니터링할지 분류
- 필수 메트릭, 대시보드, 알람 초안 정의
- 부하 테스트와 연결되는 관측 포인트 정의

## 현재 운영 중인 모니터링 도구

실클러스터 `monitoring` namespace 기준으로 현재 확인된 도구는 아래와 같다.

| 도구 | 현재 상태 | 역할 |
| --- | --- | --- |
| `Prometheus` | 운영 중 | 메트릭 수집 및 저장 |
| `Grafana` | 운영 중 | 메트릭 시각화 |
| `kube-state-metrics` | 운영 중 | Kubernetes object 상태 메트릭 제공 |
| `node-exporter` | 운영 중 | 노드 CPU / 메모리 / 디스크 / 네트워크 메트릭 제공 |
| `Prometheus Operator` | 운영 중 | `ServiceMonitor`, `PodMonitor`, `PrometheusRule` 관리 |
| `Alertmanager` | CRD만 존재, 실제 리소스 없음 | 알람 전달 미구성 상태 |
| `Loki` | 확인되지 않음 | 중앙 로그 스택 미구성 |
| `Tempo` | 확인되지 않음 | 분산 트레이싱 미구성 |
| `Jaeger` | 확인되지 않음 | 분산 트레이싱 미구성 |
| `OpenTelemetry Collector` | 확인되지 않음 | 통합 수집 파이프라인 미구성 |

즉 현재 기준으로는 `메트릭 중심 observability`는 일부 존재하지만, `로그`, `트레이싱`, `알람 체계`는 아직 미완성이다.

## 체크리스트

### 현재 상태 확인

- [x] 실클러스터에 `monitoring` namespace 존재 확인
- [x] 실클러스터에 Prometheus / Grafana 계열 workload 존재 확인
- [x] `fairline-k8s` 저장소에는 monitoring 배포 source가 없음을 확인
- [x] 주요 Spring 서비스가 Actuator는 포함하지만 `health`, `info`만 노출 중임을 확인
- [x] 주요 Spring 서비스에 Prometheus registry 의존성이 없음을 확인
- [x] 운영 관점에서 반드시 봐야 할 모니터링 대상 레이어 분류

### 모니터링 설계 체크리스트

- [x] 클러스터 레벨 모니터링 대상 정의
- [x] 애플리케이션 레벨 모니터링 대상 정의
- [x] 데이터 계층 모니터링 대상 정의
- [x] 비즈니스 레벨 모니터링 대상 정의
- [x] 필수 대시보드 초안 정의
- [x] 필수 알람 초안 정의
- [x] 주요 서비스 probe를 TCP 기반에서 HTTP 기반으로 전환 시작
- [ ] Prometheus scrape 대상 확정
- [x] 1차 Prometheus scrape 대상 서비스 확정
- [x] 1차 ServiceMonitor 매니페스트 초안 작성
- [x] 주요 Spring 서비스의 `/actuator/prometheus` 노출 설정 초안 작성
- [ ] 서비스별 `/actuator/prometheus` 실제 응답 확인
- [ ] Ingress NGINX 메트릭 수집 경로 확정
- [ ] Redis / Kafka exporter 사용 여부 확정
- [ ] RDS CloudWatch 메트릭 연계 방식 확정
- [ ] Alertmanager 또는 알람 전달 채널 확정
- [ ] 부하 테스트 시 수집할 기준 지표 확정

## 무엇을 모니터링할 것인가

## 운영 요소 역할 구분표

처음 Kubernetes 기반 Spring 운영을 볼 때 가장 헷갈리기 쉬운 요소들을 아래처럼 구분해두면 좋다.

| 구분 | 역할 | 우리 작업에서 의미 |
| --- | --- | --- |
| `Spring Boot Actuator` | 애플리케이션이 자기 상태와 운영 endpoint를 노출 | `/actuator/health`, `/actuator/info`, 추후 `/actuator/prometheus` 제공 |
| `livenessProbe` | K8s가 "프로세스가 살아 있는가"를 판단 | 실패 시 Pod 재시작 판단 근거 |
| `readinessProbe` | K8s가 "지금 트래픽을 받아도 되는가"를 판단 | 실패 시 Service 뒤 트래픽 라우팅에서 제외 |
| `Prometheus` | 애플리케이션/클러스터 메트릭 수집 | 응답시간, 에러율, JVM, 자원 사용량 수집 |
| `Grafana` | 수집된 메트릭 시각화 | 운영 대시보드, 지표 분석 화면 제공 |
| `metrics-server` | K8s 자원 메트릭 제공 | CPU / memory 기반 HPA 전제 조건 |
| `HPA` | Pod 수 자동 확장 | CPU / memory 또는 custom metric 기반 scale out / in |
| `KEDA` | 이벤트 / 외부 메트릭 기반 확장 보조 | queue depth, Kafka lag 같은 지표 기반 autoscaling 확장 후보 |

### 현재 우리 기준으로 해석하면

- `Actuator`는 Spring 서비스 내부 기능이다.
- `livenessProbe`, `readinessProbe`는 Kubernetes 기능이다.
- `Prometheus`, `Grafana`는 모니터링 스택이다.
- `metrics-server`, `HPA`, `KEDA`는 autoscaling과 연결되는 운영 구성이다.

즉 흐름은 아래처럼 이해하면 된다.

`Spring App -> Actuator -> Probe / Prometheus -> Grafana / HPA`

### 1. 클러스터 / 플랫폼 레벨

- Node Ready 상태
- 노드 CPU / 메모리 사용률
- Pod 재시작 횟수
- Pending / CrashLoopBackOff / OOMKilled 발생 여부
- Deployment unavailable replicas
- Ingress NGINX 요청 수, 응답 시간, 4xx/5xx 비율

이 레이어는 "서비스가 아예 안 뜨는 문제", "배포 직후 불안정", "노드 자원 부족"을 가장 먼저 잡기 위한 기본 축이다.

### 2. 애플리케이션 레벨

- 서비스별 요청 수
- 서비스별 p95 / p99 latency
- 서비스별 4xx / 5xx 비율
- readiness / liveness 실패 횟수
- JVM heap / GC / thread 수
- DB connection pool 사용량
- 서비스별 restart 추이

우선순위가 높은 서비스:

- `gateway`
- `frontend`
- `queue-service`
- `ticketing-service`
- `payment-service`
- `user-auth-service`
- `concert-service`
- `incident-api`

현재 코드 기준 주의점:

- 주요 Spring 서비스는 `spring-boot-starter-actuator`는 포함하고 있다.
- 하지만 현재 `management.endpoints.web.exposure.include`는 대부분 `health,info` 수준이다.
- `micrometer-registry-prometheus` 의존성은 확인되지 않았다.

즉, Prometheus가 앱 메트릭까지 안정적으로 수집하려면 서비스 코드 또는 설정 보강이 필요하다.

현재 매니페스트 기준 변화:

- `frontend`, `gateway`는 `/` HTTP 응답 기반 probe로 전환했다.
- 주요 Spring 서비스는 `/actuator/health/liveness`, `/actuator/health/readiness` 기반 probe로 전환했다.
- 단, `incident-detector`는 현재 actuator가 없어 이번 단계에서는 TCP probe를 유지한다.
- 주요 Spring 서비스에는 `MANAGEMENT_ENDPOINTS_WEB_EXPOSURE_INCLUDE=health,info,prometheus`와 애플리케이션 태그 env를 추가했다.
- `fairline` namespace 안에 `ServiceMonitor` 초안을 추가해 Prometheus Operator가 수집할 수 있는 구조를 만들었다.
- 보안 설정이 있는 Spring 서비스는 `/actuator/prometheus`를 permit 하도록 코드 수정이 필요하며, 이번 작업에 반영했다.

### 3. 데이터 / 메시징 레벨

- PostgreSQL RDS CPU
- PostgreSQL RDS free storage
- PostgreSQL RDS connection count
- PostgreSQL RDS read / write latency
- PostgreSQL RDS deadlock, error 추이
- Redis memory usage / evictions / connected clients
- Kafka broker health
- Kafka topic lag 또는 consumer lag

이 레이어는 HPA와 별개로, 부하 테스트 중 "앱이 아니라 데이터 계층이 먼저 병목인지" 판단하는 데 필요하다.

### 4. 비즈니스 레벨

- 대기열 진입 요청 수
- 대기열 현재 인원 수
- 활성 좌석 수 / 활성 예약 세션 수
- 예약 성공 / 실패 건수
- 결제 성공 / 실패 건수
- incident 발생 건수 / 상태 전이 건수

비즈니스 메트릭은 운영 이상 징후를 더 빨리 알아차리게 해준다.
예를 들어 CPU는 정상이어도 결제 실패율이 튀면 이미 사용자 영향이 시작된 상태다.

## 필수 대시보드 초안

### 1. Cluster Overview

- node 상태
- namespace별 CPU / 메모리 사용량
- Pod restart top list
- Pending / Failed Pod 목록

### 2. Ingress / API Overview

- NGINX Ingress 요청량
- path별 latency
- path별 4xx / 5xx
- `gateway` 응답 시간

### 3. Service Overview

- 주요 서비스별 RPS
- 주요 서비스별 p95 latency
- 주요 서비스별 error rate
- 주요 서비스별 restart / replica 상태

### 4. Data Layer Overview

- RDS CPU / connections / latency
- Redis memory / clients / evictions
- Kafka health / lag

### 5. Queue / Booking Business Overview

- queue depth
- booking success / fail
- payment success / fail
- incident count

## 현재 대시보드 상태와 우리가 추가로 확인해야 할 것

실클러스터 Grafana는 `kube-prometheus-stack` 기본 대시보드 구성이 이미 들어가 있다.

현재 확인된 기본 대시보드 범주:

- cluster total
- API server
- CoreDNS
- controller-manager / scheduler / etcd
- node resource usage
- pod / workload / namespace resource usage
- kubelet
- persistent volume usage
- Grafana / Prometheus overview

즉 지금 바로 볼 수 있는 것은:

- 클러스터 자원 사용량
- 노드 상태
- 네임스페이스별 자원 사용량
- Pod / workload 자원 추이

아직 부족한 것은:

- `fairline` 애플리케이션 전용 대시보드
- path 기준 latency / error rate 대시보드
- queue / booking / payment 비즈니스 대시보드
- RDS / Redis / Kafka를 한 장에 모은 데이터 계층 대시보드

## 우리가 실제로 확인해야 하는 대시보드 검증 항목

### 1. Cluster Dashboard

- 노드 6개의 CPU / memory 상태가 보이는가
- `fairline` namespace 자원 사용량이 분리되어 보이는가
- Pod restart / Pending / Failed 상태가 보이는가

### 2. Ingress / API Dashboard

- NGINX ingress request 수가 보이는가
- `4xx`, `5xx`, latency가 path 또는 service 단위로 보이는가
- `gateway`와 `frontend`의 트래픽 변화를 볼 수 있는가

### 3. App Dashboard

- `user-auth`, `concert`, `queue`, `ticketing`, `payment`, `incident-*` 메트릭이 개별 서비스별로 보이는가
- JVM / request / error / DB pool 계열 메트릭이 보이는가
- `/actuator/prometheus` 수집 이후 application tag가 구분되어 보이는가

### 4. Data Dashboard

- RDS connection / CPU / latency가 보이는가
- Redis memory / clients / evictions가 보이는가
- Kafka broker / lag가 보이는가

### 5. Business Dashboard

- queue depth
- booking success / fail
- payment success / fail
- incident count

이 다섯 축 중 현재 기본 Grafana로 바로 보이는 것은 `1번 일부`에 가깝고, 나머지는 우리가 추가로 구성해야 한다.

## 대시보드 접근 및 확인 방법

현재 `Grafana` ingress는 확인되지 않았으므로, 우선은 port-forward 기반 확인이 가장 현실적이다.

예시:

```bash
kubectl port-forward svc/kube-prometheus-stack-grafana -n monitoring 3000:80
```

그 다음 브라우저에서:

- `http://localhost:3000`

을 열어 대시보드와 datasource를 확인한다.

## 필수 알람 초안

- Pod CrashLoopBackOff 발생
- 특정 서비스 5xx 비율 급증
- 특정 서비스 p95 latency 임계치 초과
- RDS connection 수 임계치 근접
- RDS latency 급증
- Redis eviction 발생
- Kafka consumer lag 증가
- Ingress 5xx 급증
- 결제 실패율 급증
- queue depth 비정상 급증

## 부하 테스트 시 같이 봐야 할 지표

부하 테스트는 단순히 "몇 TPS까지 버티는가"보다, 어느 레이어가 먼저 한계에 도달하는지를 보는 작업이어야 한다.

부하 테스트 동안 최소한 아래를 함께 수집한다.

- 요청 수 / 성공률 / 에러율
- 서비스별 p95 / p99 latency
- Pod CPU / 메모리
- Pod restart / OOM 발생 여부
- RDS connection / CPU / latency
- Redis memory / ops
- Kafka lag

## 현재 판단

- 실클러스터에는 `monitoring` namespace와 Prometheus / Grafana가 존재한다.
- 다만 `fairline-k8s` 저장소 안에는 monitoring 배포 source가 없으므로, "운영 중이긴 하나 Git source of truth는 아직 정리되지 않았다"는 상태로 보는 것이 맞다.
- 앱 레벨에서는 아직 Prometheus scrape-ready 상태가 아니며, Actuator health/info 중심의 최소 노출만 확인되었다.
- Prometheus Operator는 `release: kube-prometheus-stack` label의 `ServiceMonitor`를 수집하도록 설정되어 있다.
- 현재 Grafana는 기본 kube-prometheus-stack 대시보드는 갖고 있지만, Fairline 전용 앱/비즈니스 대시보드는 아직 없는 상태로 보는 것이 맞다.
- 다만 실제 scrape 성공까지는 서비스 이미지 재빌드 및 재배포가 필요하다.
- 따라서 다음 단계는 "현재 대시보드가 있다"에서 끝내지 말고, 어떤 지표를 공식적으로 볼지 문서화하고 저장소 기준 관리 방식을 정하는 것이다.

## 작업 대상 파일

- [docs/monitoring_work_log.md](/Users/jihyunpark/Desktop/fairline-k8s/docs/monitoring_work_log.md)
- [docs/infra_work_log.md](/Users/jihyunpark/Desktop/fairline-k8s/docs/infra_work_log.md)
- [docs/npo-requirements.md](/Users/jihyunpark/Desktop/fairline-k8s/docs/npo-requirements.md)
- [monitoring/fairline-servicemonitor.yaml](/Users/jihyunpark/Desktop/fairline-k8s/monitoring/fairline-servicemonitor.yaml)
- [user-auth-service/service.yaml](/Users/jihyunpark/Desktop/fairline-k8s/user-auth-service/service.yaml)
- [concert-service/service.yaml](/Users/jihyunpark/Desktop/fairline-k8s/concert-service/service.yaml)
- [queue-service/service.yaml](/Users/jihyunpark/Desktop/fairline-k8s/queue-service/service.yaml)
- [ticketing-service/service.yaml](/Users/jihyunpark/Desktop/fairline-k8s/ticketing-service/service.yaml)
- [payment-service/service.yaml](/Users/jihyunpark/Desktop/fairline-k8s/payment-service/service.yaml)
- [incident-api/service.yaml](/Users/jihyunpark/Desktop/fairline-k8s/incident-api/service.yaml)
- [incident-agent/service.yaml](/Users/jihyunpark/Desktop/fairline-k8s/incident-agent/service.yaml)

## 작업 로그

- 2026-05-02: 실클러스터 기준 `monitoring` namespace와 Prometheus / Grafana 존재 여부를 확인했다.
- 2026-05-02: 저장소에는 monitoring 배포 source가 없고, 실운영 상태만 확인 가능한 상황임을 문서화했다.
- 2026-05-02: 클러스터, 애플리케이션, 데이터 계층, 비즈니스 레벨로 나눠 모니터링 대상을 정리했다.
- 2026-05-02: 부하 테스트와 바로 연결될 핵심 메트릭, 대시보드, 알람 초안을 정리했다.
- 2026-05-02: 주요 Spring 서비스들이 Actuator는 포함하지만 Prometheus endpoint와 registry 의존성은 아직 없다는 점을 반영했다.
- 2026-05-02: `frontend`, `gateway`, 주요 Spring 서비스의 probe를 HTTP health endpoint 기반으로 전환하고, `incident-detector`는 TCP 유지 대상으로 남겼다.
- 2026-05-02: Prometheus Operator의 `ServiceMonitor` selector를 확인하고, `release: kube-prometheus-stack` 기준 1차 `ServiceMonitor` 초안을 추가했다.
- 2026-05-02: 주요 Spring 서비스의 Prometheus endpoint 노출을 위한 env와 service label/port name 구성을 추가했다.
- 2026-05-02: Spring 서비스 코드에 Prometheus registry 의존성과 `/actuator/prometheus` 보안 허용을 추가했다.
- 2026-05-02: 실클러스터 기준 현재 운영 중인 observability 도구를 다시 확인했고, Grafana 기본 대시보드 범주와 미구성 항목을 정리했다.
