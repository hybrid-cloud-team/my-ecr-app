# Jellyfin PostgreSQL Database Provider

이 프로바이더는 Jellyfin이 PostgreSQL 데이터베이스를 사용할 수 있도록 합니다.

## 설정 방법

### 1. 데이터베이스 설정 파일 생성

Jellyfin 설정 디렉토리(`/config` 또는 `%APPDATA%\Jellyfin\Server\config`)에 `database.json` 파일을 생성하거나 수정합니다:

```json
{
  "DatabaseType": "Jellyfin-PostgreSQL",
  "LockingBehavior": "NoLock",
  "CustomProviderOptions": {
    "Options": [
      {
        "Key": "Host",
        "Value": "your-rds-endpoint.amazonaws.com"
      },
      {
        "Key": "Port",
        "Value": "5432"
      },
      {
        "Key": "Database",
        "Value": "jellyfin"
      },
      {
        "Key": "Username",
        "Value": "jellyfin"
      },
      {
        "Key": "Password",
        "Value": "your-password"
      },
      {
        "Key": "SslMode",
        "Value": "Prefer"
      },
      {
        "Key": "TrustServerCertificate",
        "Value": "true"
      },
      {
        "Key": "CommandTimeout",
        "Value": "30"
      },
      {
        "Key": "Pooling",
        "Value": "true"
      },
      {
        "Key": "MinPoolSize",
        "Value": "0"
      },
      {
        "Key": "MaxPoolSize",
        "Value": "100"
      }
    ]
  }
}
```

### 2. 환경 변수를 통한 설정 (권장)

Kubernetes ConfigMap 또는 Secret을 사용하여 환경 변수로 설정할 수 있습니다:

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: jellyfin-db-config
  namespace: jellyfin
data:
  JELLYFIN_DATABASE_TYPE: "Jellyfin-PostgreSQL"
  JELLYFIN_DATABASE_HOST: "your-rds-endpoint.amazonaws.com"
  JELLYFIN_DATABASE_PORT: "5432"
  JELLYFIN_DATABASE_NAME: "jellyfin"
  JELLYFIN_DATABASE_USERNAME: "jellyfin"
---
apiVersion: v1
kind: Secret
metadata:
  name: jellyfin-db-secret
  namespace: jellyfin
type: Opaque
stringData:
  JELLYFIN_DATABASE_PASSWORD: "your-password"
```

### 3. 마이그레이션 생성

PostgreSQL 프로바이더를 위한 마이그레이션을 생성하려면:

```bash
# 환경 변수 설정
export POSTGRESQL_CONNECTION_STRING="Host=localhost;Port=5432;Database=jellyfin;Username=jellyfin;Password=jellyfin"

# 마이그레이션 생성
dotnet ef migrations add {MIGRATION_NAME} --project "src/Jellyfin.Database/Jellyfin.Database.Providers.PostgreSQL" -- --migration-provider Jellyfin-PostgreSQL
```

### 4. SQLite에서 PostgreSQL로 마이그레이션

기존 SQLite 데이터베이스에서 PostgreSQL로 데이터를 마이그레이션하려면:

1. SQLite 데이터베이스 백업
2. PostgreSQL 데이터베이스 생성 및 초기화
3. 데이터 마이그레이션 도구 사용 (예: `pgloader` 또는 수동 SQL 스크립트)

## 설정 옵션

| 옵션 | 설명 | 기본값 |
|------|------|--------|
| Host | PostgreSQL 서버 호스트 | localhost |
| Port | PostgreSQL 서버 포트 | 5432 |
| Database | 데이터베이스 이름 | jellyfin |
| Username | 데이터베이스 사용자 이름 | jellyfin |
| Password | 데이터베이스 비밀번호 | (필수) |
| SslMode | SSL 모드 (Disable, Allow, Prefer, Require, VerifyCA, VerifyFull) | Prefer |
| TrustServerCertificate | 서버 인증서 신뢰 여부 | false |
| CommandTimeout | 명령 타임아웃 (초) | 30 |
| Pooling | 연결 풀링 사용 여부 | true |
| MinPoolSize | 최소 연결 풀 크기 | 0 |
| MaxPoolSize | 최대 연결 풀 크기 | 100 |

## 주의사항

- PostgreSQL은 네트워크 기반 데이터베이스이므로 EFS와 달리 동시 접근 문제가 없습니다.
- RDS를 사용하는 경우 보안 그룹 설정을 확인하세요.
- 프로덕션 환경에서는 SSL을 사용하는 것을 권장합니다.
