# fairline-k8s 배포 기록

## 클러스터 정보

| 항목 | 값 |
|------|-----|
| 클러스터 | EKS (ap-northeast-2) |
| 노드 수 | 6개 (t3.medium × 5, g5.xlarge × 1) |
| Namespace | fairline |
| IngressClass | nginx |
| Ingress NLB | k8s-ingressn-ingressn-449ade50b5-641f5d73ececedf9.elb.ap-northeast-2.amazonaws.com |
| 도메인 | http://skala3-cloud1-team4.cloud.skala-ai.com |

---

## 배포 구조

```
Internet
   │
   ▼
[Ingress] skala3-cloud1-team4.cloud.skala-ai.com
   ├─ /api/* ──► [gateway - nginx:latest] :80
   │                    │
   │     ┌──────────────┼──────────────────────┐
   │     ▼              ▼                      ▼
   │  user-auth      concert-service       queue-service
   │  ticketing-service   payment-service
   │
   └─ / ────────► [frontend - Vite dev] :5173
                         │
                    [postgres :5432]
                    [redis    :6379]
```

---

## Harbor 이미지 목록

Registry: `amdp-registry.skala-ai.com/skala25a`

| 이미지 | 비고 |
|--------|------|
| team4-frontend | Vite dev server, port 5173 |
| team4-user-auth-service | Spring Boot, port 8080 |
| team4-concert-service | Spring Boot, port 8080 |
| team4-queue-service | Spring Boot, port 8080 |
| team4-ticketing-service | Spring Boot, port 8080 |
| team4-payment-service | Spring Boot, port 8080 |

> 빌드 시 반드시 `--platform linux/amd64` 필요 (EKS 노드 amd64, 로컬 Mac ARM)
> frontend는 `--no-cache` 옵션 필요 (Docker 캐시로 인해 config 변경이 미반영되는 경우 있음)

---

## 파일 구조

```
fairline-k8s/
├── namespace.yaml
├── configmap.yaml
├── secret.yaml
├── ingress.yaml
├── infra/
│   ├── postgres/
│   │   ├── pvc.yaml         (5Gi, ebs-sc)
│   │   ├── deployment.yaml
│   │   └── service.yaml
│   └── redis/
│       ├── deployment.yaml
│       └── service.yaml
├── concert-service/
│   ├── deployment.yaml
│   └── service.yaml
├── user-auth-service/
│   ├── deployment.yaml
│   └── service.yaml
├── queue-service/
│   ├── deployment.yaml
│   └── service.yaml
├── ticketing-service/
│   ├── deployment.yaml
│   └── service.yaml
├── payment-service/
│   ├── deployment.yaml
│   └── service.yaml
├── gateway/
│   ├── configmap.yaml       (nginx.conf)
│   ├── deployment.yaml
│   └── service.yaml
└── frontend/
    ├── deployment.yaml
    └── service.yaml
```

---

## 적용 순서

```bash
kubectl apply -f fairline-k8s/namespace.yaml

kubectl create secret generic harbor-secret \
  --from-file=.dockerconfigjson=$HOME/.docker/config.json \
  --type=kubernetes.io/dockerconfigjson \
  -n fairline

kubectl apply -f fairline-k8s/configmap.yaml
kubectl apply -f fairline-k8s/secret.yaml
kubectl apply -f fairline-k8s/infra/postgres/
kubectl apply -f fairline-k8s/infra/redis/
kubectl apply -f fairline-k8s/concert-service/
kubectl apply -f fairline-k8s/user-auth-service/
kubectl apply -f fairline-k8s/queue-service/
kubectl apply -f fairline-k8s/ticketing-service/
kubectl apply -f fairline-k8s/payment-service/
kubectl apply -f fairline-k8s/gateway/
kubectl apply -f fairline-k8s/frontend/
kubectl apply -f fairline-k8s/ingress.yaml
```

---

## 현재 상태 (2026-04-28 안정화 완료)

| Pod | 상태 | Node |
|-----|------|------|
| frontend | Running ✅ | t3.medium |
| gateway | Running ✅ | t3.medium |
| user-auth-service | Running ✅ | t3.medium |
| concert-service | Running ✅ | t3.medium |
| queue-service | Running ✅ | t3.medium |
| ticketing-service | Running ✅ | t3.medium |
| payment-service | Running ✅ | t3.medium |
| postgres | Running ✅ | t3.medium |
| redis | Running ✅ | t3.medium |

| PVC | 상태 |
|-----|------|
| postgres-pvc | Bound (5Gi, ebs-sc) ✅ |

| Ingress | 상태 |
|---------|------|
| fairline-ingress | Running ✅ (NLB 연결, 도메인 접속 확인) |

---

## 트러블슈팅 기록

### #1 — postgres CrashLoopBackOff

**원인**
```
initdb: error: directory "/var/lib/postgresql/data" exists but is not empty
initdb: detail: It contains a lost+found directory (EBS mount point)
```

**조치** `infra/postgres/deployment.yaml`에 `PGDATA` 서브디렉터리 설정 추가
```yaml
- name: PGDATA
  value: /var/lib/postgresql/data/pgdata
```

---

### #2 — Harbor ImagePullBackOff (플랫폼 불일치)

**원인**
```
no match for platform in manifest: not found
```
Mac(ARM)에서 빌드된 이미지를 EKS(amd64) 노드에서 pull 불가.

**조치** `docker buildx --push` 대신 `docker build + docker push` 분리 방식으로 `--platform linux/amd64` 빌드

```bash
# Spring Boot 서비스 (루트에서 실행)
docker build --platform linux/amd64 -t amdp-registry.skala-ai.com/skala25a/team4-{service}:latest \
  -f {service}/Dockerfile . && docker push ...

# frontend (context 주의)
docker build --no-cache --platform linux/amd64 \
  -t amdp-registry.skala-ai.com/skala25a/team4-frontend:latest \
  -f frontend/Dockerfile ./frontend && docker push ...
```

---

### #3 — gateway liveness probe 실패 (CrashLoopBackOff)

**원인** `httpGet /` → 404 (nginx.conf에 `/` 라우팅 없음) → probe 실패 반복

**조치** `gateway/deployment.yaml` livenessProbe를 `httpGet` → `tcpSocket`으로 변경

---

### #4 — frontend OOMKilled

**원인** Vite dev server 메모리 한도 256Mi 초과

**조치** `frontend/deployment.yaml` 메모리 limits 256Mi → 1Gi 상향

---

### #5 — frontend Blocked request (allowedHosts)

**원인** Vite 5.x 보안 기능으로 외부 도메인 접근 차단

**조치** `frontend/vite.config.ts`에 `server.allowedHosts: true` 추가 후 `--no-cache` 재빌드

---

### #6 — 전체 Deployment GPU 노드 배치 방지

**조치** 모든 Deployment에 `nodeAffinity` 추가 (g5.xlarge 제외)

```yaml
affinity:
  nodeAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
      nodeSelectorTerms:
        - matchExpressions:
            - key: node.kubernetes.io/instance-type
              operator: NotIn
              values:
                - g5.xlarge
```
