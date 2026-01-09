# Jellyfin SQLite → PostgreSQL 마이그레이션 가이드

이 가이드는 Jellyfin의 데이터베이스를 SQLite에서 PostgreSQL로 변경하는 방법을 설명합니다.

## 문제점

EFS(Elastic File System)에서 SQLite를 사용할 때 발생하는 문제:
- 여러 Pod가 동시에 접근할 때 데이터베이스 파일이 손상될 수 있음
- 네트워크 파일 시스템의 지연으로 인한 성능 저하
- 동시성 제어의 한계

## 해결책

PostgreSQL을 사용하면:
- 네트워크 기반 데이터베이스로 동시 접근 문제 해결
- RDS를 사용하면 고가용성 및 자동 백업 제공
- 더 나은 성능과 확장성

## 구현 내용

PostgreSQL 프로바이더가 추가되었습니다:
- `src/Jellyfin.Database/Jellyfin.Database.Providers.PostgreSQL/`
- `Jellyfin-PostgreSQL` 프로바이더 키로 등록됨

## 설정 방법

### 1. RDS PostgreSQL 데이터베이스 준비

RDS 인스턴스가 이미 있다고 가정합니다. 없다면 AWS 콘솔에서 생성하세요.

### 2. 데이터베이스 초기화

`manifests/RDS/db-init-job.yaml` 파일을 사용하여 데이터베이스를 초기화합니다:

```bash
kubectl apply -f manifests/RDS/db-init-job.yaml
```

### 3. Jellyfin 설정 변경

Jellyfin이 PostgreSQL을 사용하도록 설정해야 합니다. 두 가지 방법이 있습니다:

#### 방법 1: ConfigMap/Secret 사용 (권장)

`manifests/PostgreSQL/database-config-example.yaml` 파일을 참고하여 ConfigMap과 Secret을 생성합니다:

```bash
# ConfigMap과 Secret 생성
kubectl apply -f manifests/PostgreSQL/database-config-example.yaml

# Jellyfin Deployment에 환경 변수 추가 (기존 Deployment 수정)
# manifests/PostgreSQL/database-config-example.yaml의 Deployment 예시 참고
```

#### 방법 2: database.xml 파일 직접 수정

Jellyfin Pod의 `/config` 디렉토리에 `database.xml` 파일을 생성하거나 수정합니다:

```xml
<?xml version="1.0" encoding="utf-8"?>
<DatabaseConfigurationOptions>
  <DatabaseType>Jellyfin-PostgreSQL</DatabaseType>
  <LockingBehavior>NoLock</LockingBehavior>
  <CustomProviderOptions>
    <Options>
      <CustomDatabaseOption>
        <Key>Host</Key>
        <Value>jellyfin-database-1.c8bacacucmpz.us-east-1.rds.amazonaws.com</Value>
      </CustomDatabaseOption>
      <CustomDatabaseOption>
        <Key>Port</Key>
        <Value>5432</Value>
      </CustomDatabaseOption>
      <CustomDatabaseOption>
        <Key>Database</Key>
        <Value>jellyfin</Value>
      </CustomDatabaseOption>
      <CustomDatabaseOption>
        <Key>Username</Key>
        <Value>jellyfin</Value>
      </CustomDatabaseOption>
      <CustomDatabaseOption>
        <Key>Password</Key>
        <Value>your-password</Value>
      </CustomDatabaseOption>
      <CustomDatabaseOption>
        <Key>SslMode</Key>
        <Value>Prefer</Value>
      </CustomDatabaseOption>
      <CustomDatabaseOption>
        <Key>TrustServerCertificate</Key>
        <Value>true</Value>
      </CustomDatabaseOption>
    </Options>
  </CustomProviderOptions>
</DatabaseConfigurationOptions>
```

### 4. 마이그레이션 실행

Jellyfin을 재시작하면 자동으로 마이그레이션이 실행됩니다. 첫 실행 시:

1. Jellyfin이 PostgreSQL 데이터베이스를 감지
2. 필요한 테이블 자동 생성
3. 기존 SQLite 데이터는 수동으로 마이그레이션 필요 (아래 참고)

### 5. SQLite 데이터 마이그레이션 (선택사항)

기존 SQLite 데이터를 PostgreSQL로 마이그레이션하려면:

#### 옵션 A: pgloader 사용 (권장)

```bash
# pgloader 설치 (로컬 또는 별도 Pod에서)
apt-get install pgloader  # 또는 brew install pgloader

# 마이그레이션 실행
pgloader sqlite:///path/to/jellyfin.db postgresql://jellyfin:password@rds-endpoint:5432/jellyfin
```

#### 옵션 B: 수동 SQL 스크립트

1. SQLite 데이터베이스에서 데이터 추출
2. PostgreSQL 형식으로 변환
3. PostgreSQL에 삽입

**주의**: 기존 데이터가 중요하지 않다면 새로 시작하는 것이 더 간단합니다.

## 배포 순서

1. **코드 빌드 및 이미지 푸시**
   ```bash
   # GitHub Actions가 자동으로 빌드하고 ECR에 푸시
   ```

2. **RDS 데이터베이스 초기화**
   ```bash
   kubectl apply -f manifests/RDS/db-init-job.yaml
   ```

3. **ConfigMap/Secret 생성**
   ```bash
   kubectl apply -f manifests/PostgreSQL/database-config-example.yaml
   ```

4. **Jellyfin Deployment 업데이트**
   - 환경 변수 추가 또는 database.xml 파일 마운트
   - ArgoCD가 자동으로 배포하거나 수동으로 업데이트

5. **Jellyfin 재시작**
   ```bash
   kubectl rollout restart deployment/jellyfin -n jellyfin
   ```

6. **로그 확인**
   ```bash
   kubectl logs -f deployment/jellyfin -n jellyfin
   ```
   
   다음 메시지가 보이면 성공:
   ```
   PostgreSQL connection string: Host=...
   ```

## 문제 해결

### 연결 오류

- RDS 보안 그룹에서 EKS 노드의 IP/보안 그룹 허용 확인
- 데이터베이스 사용자 권한 확인
- 연결 문자열 확인

### 마이그레이션 오류

- 데이터베이스가 초기화되었는지 확인 (`db-init-job.yaml` 실행)
- Jellyfin 로그에서 자세한 오류 메시지 확인

### 성능 문제

- RDS 인스턴스 크기 확인
- 연결 풀 설정 조정 (MaxPoolSize 등)

## 롤백 방법

문제가 발생하면 SQLite로 되돌릴 수 있습니다:

1. `database.xml`에서 `DatabaseType`을 `Jellyfin-SQLite`로 변경
2. Jellyfin 재시작
3. EFS의 SQLite 데이터베이스 파일이 다시 사용됨

## 추가 리소스

- PostgreSQL 프로바이더 README: `src/Jellyfin.Database/Jellyfin.Database.Providers.PostgreSQL/README.md`
- RDS 초기화 스크립트: `manifests/RDS/db-init-job.yaml`
