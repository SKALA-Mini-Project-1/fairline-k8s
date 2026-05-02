# Jenkins CI/CD Worklog

## 개요

Jenkins를 EKS 클러스터 내 파드로 배포하고, GitHub webhook 기반으로 변경된 서비스만 빌드/push/배포하는 파이프라인 구성.

- **Jenkins 네임스페이스**: `fairline`
- **EKS 클러스터**: `skala3-cloud1-team4` (ap-northeast-2)
- **ECR 레지스트리**: Jenkins 환경변수 `ECR_REGISTRY`로 관리 (보안상 코드에서 제거)
- **접근 URL**: `https://skala3-cloud1-team4.cloud.skala-ai.com/jenkins`

---

## 아키텍처

```text
GitHub Webhook
     │
     ▼
Jenkins Pod (fairline namespace)
├── initContainer: install-tools (alpine)
│   └── kubectl v1.29, aws-cli v2 → /tools 볼륨
├── initContainer: install-docker-cli (docker:27-cli)
│   └── docker binary → /tools 볼륨
├── container: jenkins (jenkins/jenkins:lts-jdk21)
│   ├── DOCKER_HOST=tcp://localhost:2375
│   ├── PATH=/tools:$PATH (command로 주입)
│   └── ServiceAccount → kubectl in-cluster 인증
└── container: dind (docker:27-dind, privileged)
    └── docker build/push 실행 담당
          │
          ▼
    ECR Push → kubectl rollout restart → EKS Deployment
```

---

## 파이프라인 단계

| 단계 | 내용 |
| --- | --- |
| Detect Changes | `git diff` 기반으로 변경된 서비스 디렉토리 감지 |
| ECR Login | Jenkins Credentials(`aws-access-key-id`, `aws-secret-access-key`)로 ECR 인증 |
| Build & Push | 변경된 Spring 서비스만 `--platform linux/amd64` 빌드 후 ECR push |
| Build & Push Frontend | `frontend/` 변경 시 `--no-cache` 빌드 후 ECR push |
| Deploy | `kubectl rollout restart` + `rollout status` 확인 |

---

## 작업 이력

### 2026-05-01

#### 완료: Jenkins k8s 매니페스트 및 Jenkinsfile 초안 작성

##### 생성 파일

| 파일 | 설명 |
| --- | --- |
| `fairline-k8s/jenkins/serviceaccount.yaml` | Jenkins SA + Role(deployments get/patch) + RoleBinding |
| `fairline-k8s/jenkins/pvc.yaml` | 20Gi ebs-sc PVC (`jenkins-home`) |
| `fairline-k8s/jenkins/deployment.yaml` | Jenkins + DinD sidecar + init containers |
| `fairline-k8s/jenkins/service.yaml` | ClusterIP :80→8080, :50000 |
| `fairline-k8s/jenkins/ingress.yaml` | `/jenkins` 경로 nginx ingress |
| `Jenkinsfile` (루트) | 전 서비스 변경 감지 파이프라인 |

##### 주요 설계 결정

- DinD 방식 채택: 노드 Docker 소켓 마운트 대신 `docker:27-dind` 사이드카 사용 → 노드 종속성 없음
- `--prefix=/jenkins` 설정: nginx ingress `/jenkins` 경로와 일치
- init container로 도구 설치: jenkins 이미지 변경 없이 `kubectl`, `aws-cli v2`, `docker` CLI 주입
- GPU 노드 제외: 기존 서비스와 동일하게 `nodeAffinity` NotIn `g5.xlarge` 적용
- ingress 분리: 기존 `ingress.yaml` 수정 없이 `jenkins/ingress.yaml` 별도 생성 → 팀원 충돌 방지
- StorageClass: 클러스터 기본값인 `ebs-sc` (EBS CSI 드라이버) 사용
- RollingUpdate 전략: `maxUnavailable:1, maxSurge:0` → ReadWriteOnce PVC 충돌 방지

#### 완료: EKS 배포 및 트러블슈팅

##### 발생 이슈 및 해결

| 이슈 | 원인 | 해결 |
| --- | --- | --- |
| `java: not found` CrashLoop | `PATH` env 전체 오버라이드로 Java 경로 누락 | `command`로 `export PATH=/tools:$PATH` 후 jenkins.sh 실행 |
| `initialAdminPassword` 미생성 | `runSetupWizard=false` 설정으로 초기화 마법사 스킵 | JAVA_OPTS에서 해당 플래그 제거 |
| PVC 충돌로 신규 파드 Init 멈춤 | ReadWriteOnce PVC + 기본 maxSurge=1 전략 → 구 파드 PVC 미해제 교착상태 | `maxUnavailable:1, maxSurge:0`으로 구 파드 먼저 종료 후 신 파드 기동 |

#### 완료: Jenkins 초기 설정

- Jenkins 2.555.1 기동 확인 (`2/2 Running`)
- Admin 계정 생성 완료
- Suggested plugins 설치 완료
- AWS Credentials 플러그인 미포함 → `Secret text` 2개로 대체
  - ID: `aws-access-key-id`
  - ID: `aws-secret-access-key`
- ECR_REGISTRY Jenkins 전역 환경변수 등록 (public 리포 보안상 Jenkinsfile에서 분리)
- Pipeline 생성: `fairline-pipeline`
  - SCM: `https://github.com/SKALA-Mini-Project-1/SKALA-Mini-Project-2.git`
  - Branch: `*/dev`
  - Script Path: `Jenkinsfile`
  - Trigger: `GitHub hook trigger for GITScm polling` 활성화

---

## 배포 방법

```bash
# 1. k8s 리소스 적용
kubectl apply -f fairline-k8s/jenkins/serviceaccount.yaml
kubectl apply -f fairline-k8s/jenkins/pvc.yaml
kubectl apply -f fairline-k8s/jenkins/deployment.yaml
kubectl apply -f fairline-k8s/jenkins/service.yaml
kubectl apply -f fairline-k8s/jenkins/ingress.yaml

# 2. 파드 기동 확인 (init container 바이너리 다운로드로 1~2분 소요)
kubectl get pods -n fairline -w

# 3. 초기 admin 비밀번호 확인
kubectl exec -n fairline deployment/jenkins -c jenkins -- \
  cat /var/jenkins_home/secrets/initialAdminPassword
```

## Jenkins 초기 설정 요약

1. `https://skala3-cloud1-team4.cloud.skala-ai.com/jenkins` 접속 후 초기 설정 완료
2. Credentials 등록 (Secret text):
   - ID: `aws-access-key-id` / `aws-secret-access-key`
3. 전역 환경변수: `ECR_REGISTRY` = ECR 레지스트리 주소
4. Pipeline 생성: `fairline-pipeline` (SCM: SKALA-Mini-Project-2, branch: dev)
5. GitHub Webhook 등록:
   - 리포 Settings → Webhooks → Add webhook
   - Payload URL: `https://skala3-cloud1-team4.cloud.skala-ai.com/jenkins/github-webhook/`
   - Content type: `application/json`

---

## 주의사항

- DinD 사이드카는 `privileged: true` 필요. PSA 제한 시 아래 명령 먼저 실행:

  ```bash
  kubectl label namespace fairline pod-security.kubernetes.io/enforce=privileged
  ```

- Jenkins 파드는 `replicas: 1` 고정 (PVC가 ReadWriteOnce)
- ECR_REGISTRY는 Jenkins 전역 환경변수로만 관리 (코드에 절대 하드코딩 금지)
- IAM Role: 노드 Role에 `AmazonEC2ContainerRegistryPowerUser` 없음 → Secret text 액세스 키 방식 사용 중

---

## 작업 이력 (추가)

### 2026-05-02

#### 완료: CI 파이프라인 전 서비스 검증 및 최적화

##### 주요 이슈 및 해결

| 이슈 | 원인 | 해결 |
| --- | --- | --- |
| Gradle 빌드 실패 — "Configuring project ':incident-agent' without an existing directory" | `settings.gradle`에 incident 3개 서비스 추가 후 기존 Dockerfile에 해당 디렉토리 COPY 없음 | concert/user-auth/ticketing/payment Dockerfile에 incident-{detector,agent,api} COPY 라인 추가 |
| `kubectl rollout status` watch 권한 없음 | ServiceAccount Role에 `watch` verb 누락 | `serviceaccount.yaml` Role에 `watch` 추가 |
| rollout status timeout | 120s 기본값으로 롤링 업데이트 중 타임아웃 | `--timeout=300s`로 연장 |
| aws-cli `libz.so.1` not found | Jenkins init container에서 PyInstaller 빌드된 aws-cli 설치 시 공유 라이브러리 누락 | `dist/` 전체 복사 + wrapper 스크립트 방식으로 변경 |
| frontend `npm ci` 실패 — "Missing: typescript@4.9.5 from lock file" | `package-lock.json`이 npm v11로 생성됐으나 Docker `node:20-alpine`은 npm v10 사용 → peer dep 검증 기준 차이 | `frontend/Dockerfile`에 `npm ci --legacy-peer-deps` 추가 |

##### 완료 항목

- 9개 서비스 전체 빌드 & ECR push & kubectl rollout 성공 (`Finished: SUCCESS`)
- Build & Push Spring Services 스테이지 병렬화 (`parallel` 블록)
- Deploy to EKS 스테이지 병렬화
- 빌드 시간 목표: 순차 ~33분 → 병렬 이후 최초 전체 빌드 기준 대폭 단축 예상

---

## TODO

- [x] StorageClass 확인 → `ebs-sc` (EBS CSI, default)로 pvc.yaml 수정
- [x] EKS에 실제 배포 및 파드 기동 확인 (Jenkins 2/2 Running)
- [x] Jenkins 초기 설정 및 Credentials 등록
- [x] Pipeline 생성 (`fairline-pipeline`)
- [x] Jenkinsfile에서 ECR 계정 정보 제거 (Jenkins 환경변수로 분리)
- [x] Jenkinsfile `dev-jyoon` → `dev` PR 머지
- [x] GitHub webhook 등록
- [x] webhook 자동 트리거 확인
- [x] 9개 서비스 파이프라인 첫 실행 검증 (Finished: SUCCESS)
- [x] Build & Deploy 병렬화 (순차 → parallel 블록)
- [ ] **[다음] ArgoCD 도입** — Jenkins kubectl 직접 실행 방식에서 GitOps 전환
- [ ] BuildKit(buildx) 활성화 — DEPRECATED legacy builder 경고 제거

---

## 다음 작업 순서

### Step 1. ArgoCD 도입 (CD 파이프라인) 🔴 최우선

**현재 방식 문제점**:

- Jenkins Pod에서 직접 `kubectl rollout restart` 실행 → Jenkins와 K8s 배포가 강하게 결합
- 배포 이력이 Jenkins 로그에만 존재, Git에 기록 없음

**전환 목표**:

```text
현재: Jenkins → ECR push → kubectl rollout restart
목표: Jenkins → ECR push
               → fairline-k8s deployment.yaml image tag 수정 & push
     ArgoCD  → 변경 감지 → kubectl apply (자동 sync)
```

**작업 순서**:

1. ArgoCD 설치

   ```bash
   kubectl create namespace argocd
   kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
   ```

2. ArgoCD Application 생성 — `fairline-k8s` repo를 `fairline` namespace에 연결
3. Jenkinsfile 수정:
   - `Deploy to EKS` 스테이지 제거
   - 빌드 후 `fairline-k8s/{svc}/deployment.yaml`의 image tag를 `git-sha`로 수정 & push
4. ArgoCD auto sync 활성화 (또는 GitHub webhook 연결)
5. ArgoCD UI Ingress 설정 (`/argocd` 경로)

**완료 기준**: `dev` 브랜치 push → Jenkins CI → fairline-k8s tag 업데이트 → ArgoCD 자동 반영

---

### Step 2. Secret 관리 개선 🟡

**현재**: `secret.yaml` 수동 주입, example 파일만 repo에 존재

**목표**: AWS Secrets Manager 또는 ExternalSecret Operator 연동

- ANTHROPIC_API_KEY, DB credentials, JWT_SECRET 관리 방식 통일
- Jenkins Credentials도 동일 방식 검토

---

### Step 3. Observability 기본 구성 🟡

**현재**: `kubectl logs` + probe 기반 1차 운영 수준

**목표**: Prometheus + Grafana 최소 구성

- `monitoring` namespace 생성
- kube-prometheus-stack Helm 설치
- Grafana 기본 대시보드 (CPU/메모리, HTTP 응답 시간)
- 핵심 알람 (Pod CrashLoop, 응답 지연 임계치)

---

### Step 4. Autoscaling — KEDA / HPA 🟢

**현재**: `replicas: 2` 고정

- HPA 적용 대상 서비스 결정 (우선: queue-service, ticketing-service)
- KEDA Kafka consumer lag 기반 스케일링 검토
- 부하 테스트 기준치 설정 후 ScaledObject 또는 HPA 매니페스트 작성

---

### Step 5. 보안 강화 🟢

- `NetworkPolicy` 서비스 간 인바운드/아웃바운드 제한
- `PodDisruptionBudget` 롤링 업데이트 중 최소 가용 Pod 보장
- `ServiceAccount` / IRSA 역할 기반 권한 (ECR pull 등)
