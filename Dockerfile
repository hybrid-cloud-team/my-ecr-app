# 1. 빌드 스테이지
FROM mcr.microsoft.com/dotnet/sdk:9.0 AS build-env
WORKDIR /app

# 모든 소스 복사
COPY . ./

# [핵심] 에러의 주범인 파일을 빌드 직전에 물리적으로 삭제합니다. 
# 이 파일은 런타임에 필요 없으므로 삭제해도 안전합니다.
RUN rm -f src/Jellyfin.Database/Jellyfin.Database.Providers.Sqlite/Migrations/SqliteDesignTimeJellyfinDbFactory.cs

# 의존성 복원 및 빌드
RUN dotnet restore Jellyfin.Server/Jellyfin.Server.csproj
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
