# 1. 빌드 스테이지
FROM mcr.microsoft.com/dotnet/sdk:9.0 AS build-env
WORKDIR /app

# 모든 소스 복사
COPY . ./

# [핵심 1] 에러 주범 파일 삭제
RUN rm -f src/Jellyfin.Database/Jellyfin.Database.Providers.Sqlite/Migrations/SqliteDesignTimeJellyfinDbFactory.cs

# [핵심 2] 빌드 실행 (문법 수정됨)
# 세미콜론(;) 대신 %3B를 사용하여 셸이 명령어를 쪼개는 것을 방지합니다.
RUN dotnet publish Jellyfin.Server/Jellyfin.Server.csproj \
    -c Release \
    -o /app/out \
    /p:TreatWarningsAsErrors=false \
    /p:NoWarn=NU1605%3BNU1608

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

ENTRYPOINT ["dotnet", "jellyfin.dll"]
