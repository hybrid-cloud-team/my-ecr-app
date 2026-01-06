# 1. 빌드 스테이지
FROM mcr.microsoft.com/dotnet/sdk:9.0 AS build-env
WORKDIR /app

# 모든 소스 복사
COPY . ./

# [핵심 1] 에러를 내는 설계용 파일을 물리적으로 삭제
RUN rm -f src/Jellyfin.Database/Jellyfin.Database.Providers.Sqlite/Migrations/SqliteDesignTimeJellyfinDbFactory.cs

# [핵심 2] 중앙 관리 시스템(CPM)을 무시하고 MySQL 패키지를 강제로 설치/업데이트
RUN dotnet add Jellyfin.Server/Jellyfin.Server.csproj package Pomelo.EntityFrameworkCore.MySql --version 8.0.2
RUN dotnet add src/Jellyfin.Database/Jellyfin.Database.Providers.Sqlite/Jellyfin.Database.Providers.Sqlite.csproj package Pomelo.EntityFrameworkCore.MySql --version 8.0.2

# 빌드 실행
RUN dotnet publish Jellyfin.Server/Jellyfin.Server.csproj -c Release -o /app/out

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
