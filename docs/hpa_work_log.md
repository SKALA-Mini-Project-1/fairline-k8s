# Fairline HPA Work Log

작성일: `2026-05-02`

## 목적

- `fairlineticker` 서비스에 어떤 autoscaling 전략을 적용할지 기준을 정리한다.
- 실클러스터의 현재 상태와 향후 적용 대상을 분리해서 기록한다.
- 부하 테스트, HPA, KEDA 검토를 이어서 할 수 있는 기준 문서로 사용한다.

## 현재 작업 범위

- 실클러스터 기준 HPA / KEDA 현황 확인
- HPA 우선 적용 대상 서비스 선정
- 어떤 메트릭으로 스케일할지 초안 정의
- 부하 테스트와 HPA 연계 기준 정리

## 체크리스트

### 현재 상태 확인

- [x] 실클러스터에 `keda` namespace 존재 확인
- [x] 실클러스터에 `HorizontalPodAutoscaler` 없음 확인
- [x] 실클러스터에 `ScaledObject` 없음 확인
- [x] `metrics-server`와 metrics API 가용성 확인
- [x] 현재 autoscaling이 실제 적용되지 않은 상태임을 기록

### HPA 설계 체크리스트

- [x] 1차 HPA 적용 후보 서비스 선정
- [x] HPA 적용 제외 또는 후순위 서비스 분류
- [x] CPU / memory 기반 1차 메트릭 초안 정의
- [x] 트래픽 / latency 기반 2차 확장 방향 정리
- [x] 부하 테스트 선행 필요성 명시
- [x] metrics-server 준비 상태 확인
- [x] 1차 HPA 매니페스트 초안 작성
- [ ] custom metrics 준비 상태 확인
- [ ] 서비스별 minReplicas / maxReplicas 확정
- [ ] 서비스별 target CPU / memory utilization 확정
- [ ] scale up / down stabilization 정책 확정
- [ ] HPA 적용 순서 확정
- [ ] 필요 시 KEDA 도입 여부 재판단
- [ ] 부하 테스트 결과 기반 임계치 보정

## 현재 판단

- 실클러스터에는 `keda` namespace가 존재한다.
- 하지만 실제 `HPA`와 `ScaledObject`는 아직 없다.
- `metrics-server`와 `metrics.k8s.io` API는 정상 상태다.
- 따라서 현재는 "autoscaling 준비 흔적은 있으나, 운영 중인 autoscaling 정책은 없다"라고 보는 것이 맞다.

## HPA를 왜 먼저 보나

- 현재 서비스 다수가 `replicas: 2`로 운영되더라도, 실제 부하에 맞춰 자동 확장되지는 않는다.
- 발표나 운영 기준에서 "고가용성"과 "자동 확장"은 다른 이야기다.
- 따라서 HPA는 운영 안정성 고도화의 첫 단계로 별도 관리해야 한다.

## 1차 HPA 적용 후보

### 우선 적용 후보

- `gateway`
- `frontend`
- `queue-service`
- `ticketing-service`
- `payment-service`
- `user-auth-service`
- `concert-service`

선정 이유:

- 외부 트래픽 또는 내부 핵심 트랜잭션의 영향을 직접 받는다.
- 부하 테스트 시 병목이 눈에 띄기 쉽다.
- replica 증가가 비교적 자연스럽다.

### 후순위 또는 별도 검토 대상

- `incident-api`
- `incident-agent`
- `incident-detector`
- `redis`
- `kafka`

이유:

- `incident-*`는 트래픽형 서비스보다 운영/배치 성격이 강하다.
- `redis`, `kafka`는 단순 HPA보다 상태 저장 특성과 운영 방식이 더 중요하다.

## 1차 메트릭 초안

### 기본 HPA 메트릭

- CPU utilization
- memory utilization

이 단계는 가장 빠르게 적용 가능한 기본선이다.

### 현재 1차 초안 기준

- `frontend`, `gateway`: `minReplicas 2`, `maxReplicas 4`
- `user-auth-service`, `concert-service`, `queue-service`, `ticketing-service`, `payment-service`: `minReplicas 2`, `maxReplicas 3`
- 공통 목표:
  - CPU `65~70%`
  - memory `80%`
- scale down은 `300초` stabilization으로 급격한 축소를 방지

이 값들은 "즉시 운영 가능한 안전한 첫 기준"이며, 부하 테스트 결과에 따라 조정이 필요하다.

### 2차 확장 메트릭

- Ingress request rate
- service request latency
- queue depth
- active session count

이 단계는 Prometheus Adapter 또는 KEDA 같은 추가 구성이 필요할 수 있다.

## 서비스별 초안 메모

### `gateway`

- 가장 먼저 scale 대상이 될 가능성이 높다.
- `/api` 전체 진입점이므로 request 수와 latency 영향을 직접 받는다.

### `frontend`

- 외부 진입량 변화에 따라 CPU / memory 기반 확장이 자연스럽다.

### `queue-service`

- 대기열 진입 트래픽, 상태 조회 요청, 스케줄러 부하를 함께 고려해야 한다.
- 단순 CPU보다 queue depth 같은 비즈니스 메트릭도 장기적으로 의미가 있다.

### `ticketing-service`

- 예약 생성과 좌석 점유 흐름의 핵심 서비스다.
- 다만 DB 부하와 락 경합을 함께 봐야 하므로, HPA만으로 해결된다고 보면 안 된다.

### `payment-service`

- 결제 처리량 증가에 따라 scale 여지가 있다.
- 다만 외부 결제 연동과 DB 상태를 함께 봐야 한다.

## 부하 테스트와의 관계

HPA는 먼저 넣고 나중에 테스트하는 구조보다, 최소한의 부하 테스트 기준을 먼저 잡고 적용하는 편이 안전하다.

부하 테스트에서 확인할 것:

- 어느 서비스가 먼저 CPU 병목에 도달하는지
- latency가 먼저 튀는지
- DB connection이 먼저 한계에 도달하는지
- scale out 이후 latency / error rate가 실제 개선되는지

즉 HPA의 목적은 "복제 수를 늘리는 것"이 아니라, 사용자 체감 성능과 오류율을 안정시키는 것이다.

## KEDA에 대한 현재 판단

- 현재는 KEDA namespace만 존재하고 실제 스케일링 리소스는 없다.
- 따라서 1차는 native HPA 기준으로 문서화하는 것이 단순하고 안전하다.
- 이후 queue depth, Kafka lag, custom metric 기반 확장이 필요할 때 KEDA를 재도입하거나 활성화하는 것이 더 자연스럽다.

## 바로 보이는 구현 전제

- 클러스터 레벨 HPA 전제인 `metrics-server`는 이미 준비되어 있다.
- 따라서 CPU / memory 기반 HPA는 인프라 전제보다 서비스별 임계치 결정이 더 큰 과제다.
- 반대로 request rate, latency, queue depth 같은 custom metric HPA는 아직 별도 준비가 필요하다.

## 발표 시 설명 포인트

- 현재는 고정 replica 기반 운영이다.
- autoscaling은 아직 적용 전이며, HPA 도입을 위해 모니터링과 부하 테스트 기준부터 정리 중이다.
- 1차는 CPU / memory 기반 HPA, 2차는 queue depth / request rate 같은 custom metric 확장 방향으로 본다.

## 작업 대상 파일

- [docs/hpa_work_log.md](/Users/jihyunpark/Desktop/fairline-k8s/docs/hpa_work_log.md)
- [docs/infra_work_log.md](/Users/jihyunpark/Desktop/fairline-k8s/docs/infra_work_log.md)
- [docs/monitoring_work_log.md](/Users/jihyunpark/Desktop/fairline-k8s/docs/monitoring_work_log.md)
- [hpa/frontend-hpa.yaml](/Users/jihyunpark/Desktop/fairline-k8s/hpa/frontend-hpa.yaml)
- [hpa/gateway-hpa.yaml](/Users/jihyunpark/Desktop/fairline-k8s/hpa/gateway-hpa.yaml)
- [hpa/user-auth-service-hpa.yaml](/Users/jihyunpark/Desktop/fairline-k8s/hpa/user-auth-service-hpa.yaml)
- [hpa/concert-service-hpa.yaml](/Users/jihyunpark/Desktop/fairline-k8s/hpa/concert-service-hpa.yaml)
- [hpa/queue-service-hpa.yaml](/Users/jihyunpark/Desktop/fairline-k8s/hpa/queue-service-hpa.yaml)
- [hpa/ticketing-service-hpa.yaml](/Users/jihyunpark/Desktop/fairline-k8s/hpa/ticketing-service-hpa.yaml)
- [hpa/payment-service-hpa.yaml](/Users/jihyunpark/Desktop/fairline-k8s/hpa/payment-service-hpa.yaml)

## 작업 로그

- 2026-05-02: 실클러스터 기준 `keda` namespace 존재 여부와 `HPA`, `ScaledObject` 부재를 확인했다.
- 2026-05-02: 현재 autoscaling 정책이 실제 운영 중이지 않다는 점을 문서화했다.
- 2026-05-02: 1차 HPA 적용 후보와 후순위 대상을 구분했다.
- 2026-05-02: CPU / memory 기반 1차 HPA와 custom metric 기반 2차 확장 방향을 분리해서 정리했다.
- 2026-05-02: 부하 테스트가 HPA 임계치 설정의 선행 작업이라는 점을 작업 기준에 반영했다.
- 2026-05-02: `metrics-server`와 metrics API가 정상이라는 점을 확인해 CPU / memory 기반 HPA 전제가 충족됨을 반영했다.
- 2026-05-02: `frontend`, `gateway`, 주요 트랜잭션 서비스 대상 1차 HPA 매니페스트 초안을 `hpa/` 디렉터리에 추가했다.
