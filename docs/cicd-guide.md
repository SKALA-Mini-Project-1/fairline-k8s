# Fairline CI/CD 가이드

> 작성일: 2026-05-02  
> 대상: 팀원 전체

---

## 전체 흐름

```
개발자 코드 push (SKALA-Mini-Project-2 / dev 브랜치)
          │
          ▼
  GitHub Webhook 트리거
          │
          ▼
┌─────────────────────────────────┐
│          Jenkins (CI)           │
│                                 │
│  1. 변경된 서비스만 감지         │
│  2. Docker 빌드 (병렬)          │
│  3. ECR push (:git-sha 태그)    │
│  4. fairline-k8s repo 업데이트  │
└─────────────────────────────────┘
          │
          ▼ (fairline-k8s deployment.yaml 변경 push)
          │
          ▼
┌─────────────────────────────────┐
│          ArgoCD (CD)            │
│                                 │
│  fairline-k8s 변경 감지          │
│  → kubectl apply                │
│  → EKS 자동 배포                 │
└─────────────────────────────────┘
          │
          ▼
   EKS (fairline namespace)
```

---

## 저장소 구조

| 저장소 | 역할 | 브랜치 |
|--------|------|--------|
| `SKALA-Mini-Project-2` | 앱 소스코드 | `dev` (기준 브랜치) |
| `fairline-k8s` | K8s 매니페스트 (GitOps) | `dev` |

---

## 개발 → 배포 절차

### 일반적인 경우 (기능 개발)

```
1. feature 브랜치 생성 (dev 기반)
2. 코드 작성
3. dev-{이름} 브랜치로 push
4. GitHub에서 dev-{이름} → dev PR 생성 & 머지
5. Jenkins 자동 트리거 → 빌드 → 배포
```

### 배포 확인 방법

**Jenkins 콘솔** (빌드 상태 확인)
```
https://skala3-cloud1-team4.cloud.skala-ai.com/jenkins
```

**ArgoCD UI** (배포 상태 확인)
```
https://skala3-cloud1-team4.cloud.skala-ai.com/argocd
```
- ID: `admin`
- PW: Jenkins 담당자에게 문의

**kubectl** (직접 확인)
```bash
kubectl get pods -n fairline
kubectl get deployment {서비스명} -n fairline -o jsonpath='{.spec.template.spec.containers[0].image}'
```

---

## 빌드 대상 서비스 목록

변경된 파일이 아래 디렉토리에 포함되면 해당 서비스만 자동으로 빌드됩니다.

| 디렉토리 | ECR 이미지 |
|----------|-----------|
| `concert-service/` | `team4-concert-service` |
| `user-auth-service/` | `team4-user-auth-service` |
| `queue-service/` | `team4-queue-service` |
| `ticketing-service/` | `team4-ticketing-service` |
| `payment-service/` | `team4-payment-service` |
| `incident-detector/` | `team4-incident-detector` |
| `incident-agent/` | `team4-incident-agent` |
| `incident-api/` | `team4-incident-api` |
| `frontend/` | `team4-frontend` |

> `Jenkinsfile`만 변경된 경우 빌드 없이 파이프라인이 종료됩니다 — 정상 동작입니다.

---

## 이미지 태그 규칙

`:latest` 태그는 사용하지 않습니다. **git commit SHA 앞 8자리**를 태그로 사용합니다.

```
team4-concert-service:5ccfcb63
team4-frontend:5ccfcb63
```

- ECR에서 어떤 커밋의 코드가 배포됐는지 추적 가능
- ArgoCD가 이미지 변경을 감지해 자동 배포 트리거

---

## K8s 매니페스트 변경이 필요한 경우

서비스 코드가 아닌 **K8s 설정**(replicas, 환경변수, resource 등)을 변경하려면 `fairline-k8s` repo를 직접 수정합니다.

```
fairline-k8s repo 수정 → dev 브랜치 push
→ ArgoCD 자동 감지 → EKS 반영
```

> Jenkins를 거치지 않고 ArgoCD가 직접 처리합니다.

---

## 주의사항

### 1. dev 브랜치 직접 push 금지

`SKALA-Mini-Project-2/dev` 브랜치는 반드시 PR을 통해서만 머지합니다.  
직접 push 시 Jenkins가 트리거되어 의도치 않은 배포가 발생할 수 있습니다.

### 2. shared-kernel 수정 시 전체 빌드 유발 가능성

`shared-kernel/`을 수정하면 해당 커밋에서 감지된 서비스만 빌드됩니다.  
다른 서비스들은 다음 배포 시점까지 이전 shared-kernel 버전으로 동작하므로, **shared-kernel 변경 시에는 의존하는 모든 서비스를 함께 수정해 동시에 배포**하는 것을 권장합니다.

### 3. ArgoCD는 fairline-k8s/jenkins, fairline-k8s/argocd 디렉토리를 관리하지 않음

Jenkins와 ArgoCD 자체 설정은 ArgoCD sync 대상에서 제외되어 있습니다.  
해당 파일 변경 시에는 `kubectl apply`로 직접 적용해야 합니다.

```bash
# Jenkins 매니페스트 변경 시
kubectl apply -f fairline-k8s/jenkins/

# ArgoCD 설정 변경 시
kubectl apply -f fairline-k8s/argocd/
```

### 4. secret.yaml은 git에 포함되지 않음

`fairline-k8s/secret.yaml`은 `.gitignore`에 포함되어 있습니다.  
ArgoCD가 이 파일을 관리하지 않으므로, Secret 변경 시 수동으로 적용해야 합니다.

```bash
kubectl apply -f fairline-k8s/secret.yaml -n fairline
```

### 5. 빌드 실패 시 ArgoCD는 이전 상태 유지

Jenkins 빌드가 실패하면 fairline-k8s repo는 업데이트되지 않습니다.  
ArgoCD는 마지막으로 성공한 커밋 기준으로 EKS를 유지합니다.

---

## 인프라 접근 정보

| 시스템 | URL | 비고 |
|--------|-----|------|
| 서비스 도메인 | `https://skala3-cloud1-team4.cloud.skala-ai.com` | |
| Jenkins | `https://skala3-cloud1-team4.cloud.skala-ai.com/jenkins` | 빌드 현황 |
| ArgoCD | `https://skala3-cloud1-team4.cloud.skala-ai.com/argocd` | 배포 현황 |
| ECR | `881490135253.dkr.ecr.ap-northeast-2.amazonaws.com` | 이미지 저장소 |
| EKS namespace | `fairline` | 서비스 배포 공간 |

---

## 트러블슈팅

### Jenkins 빌드가 트리거되지 않는다

GitHub Webhook 설정 확인:
```
SKALA-Mini-Project-2 repo → Settings → Webhooks
Payload URL: https://skala3-cloud1-team4.cloud.skala-ai.com/jenkins/github-webhook/
```
Recent Deliveries에서 응답 코드가 200인지 확인합니다.

### ArgoCD가 변경을 감지하지 못한다

ArgoCD UI에서 **REFRESH** 버튼을 클릭하거나 자동 폴링 주기(기본 3분)를 기다립니다.  
즉시 반영이 필요하면 **SYNC** 버튼을 클릭합니다.

### 특정 서비스 Pod이 CrashLoopBackOff

```bash
# 로그 확인
kubectl logs -n fairline deployment/{서비스명} --tail=100

# 최근 이벤트 확인
kubectl describe pod -n fairline -l app={서비스명}
```

ArgoCD UI에서 해당 서비스 박스를 클릭하면 Pod 상태와 로그를 바로 확인할 수 있습니다.
