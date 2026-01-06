# 1. 빌드 스테이지
FROM mcr.microsoft.com/dotnet/sdk:9.0 AS build-env
WORKDIR /app

# 모든 소스 복사
COPY . ./

# [핵심 1] 에러 파일 물리적 삭제
RUN rm -f src/Jellyfin.Database/Jellyfin.Database.Providers.Sqlite/Migrations/SqliteDesignTimeJellyfinDbFactory.cs

# [핵심 2] 패키지 강제 주입
RUN dotnet add Jellyfin.Server/Jellyfin.Server.csproj package Pomelo.EntityFrameworkCore.MySql --version 8.0.2
RUN dotnet add src/Jellyfin.Database/Jellyfin.Database.Providers.Sqlite/Jellyfin.Database.Providers.Sqlite.csproj package Pomelo.EntityFrameworkCore.MySql --version 8.0.2

# [핵심 3] 빌드 실행 (버전 불일치 경고를 에러로 보지 않도록 설정 추가)
# /p:TreatWarningsAsErrors=false 옵션이 NU1608 에러를 통과시킵니다.
RUN dotnet publish Jellyfin.Server/Jellyfin.Server.csproj -c Release -o /app/out /p:TreatWarningsAsErrors=false

# 2. 실행 스테이지
FROM mcr.microsoft.com/dotnet/aspnet:9.0
WORKDIR /jellyfin
COPY --from=build-env /app/out .

RUN apt-get update && apt-get install -y ffmpeg curl && rm -rf /var/lib/apt/lists/*

ENV JELLYFIN_DATA_DIR=/config
ENV JELLYFIN_CONFIG_DIR=/config/config
ENV JELLYFIN_LOG_DIR=/config/log
ENV JELLYFIN_CACHE_DIR=/cache
ENV ASPNETCORE_URLS=http://+:8096

RUN mkdir -p /config /cache /media
EXPOSE 8096

ENTRYPOINT ["dotnet", "Jellyfin.Server.dll"]
