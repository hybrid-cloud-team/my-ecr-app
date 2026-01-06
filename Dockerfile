# [1] 공식 젤리핀 이미지에서 '웹 클라이언트(HTML/JS)' 파일만 가져옴
FROM jellyfin/jellyfin:latest AS stock-image

# [2] 빌드 스테이지
FROM mcr.microsoft.com/dotnet/sdk:9.0 AS build-env
WORKDIR /app

# 소스 복사 및 청소
COPY . ./
RUN find . -type d \( -name "obj" -o -name "bin" \) -exec rm -rf {} +
RUN rm -f src/Jellyfin.Database/Jellyfin.Database.Providers.Sqlite/Migrations/SqliteDesignTimeJellyfinDbFactory.cs

# 서버 빌드 (Jellyfin.Server.csproj)
RUN dotnet publish Jellyfin.Server/Jellyfin.Server.csproj \
    -c Release \
    -o /app/out \
    /p:TreatWarningsAsErrors=false \
    /p:NoWarn=NU1605%3BNU1608

# [3] 실행 스테이지
FROM mcr.microsoft.com/dotnet/aspnet:9.0
WORKDIR /jellyfin

# 빌드된 서버 실행 파일 복사
COPY --from=build-env /app/out .

# 웹 클라이언트 파일 복사 (이게 있어야 웹 접속 가능)
COPY --from=stock-image /jellyfin/jellyfin-web /jellyfin/jellyfin-web

# 필수 패키지 설치
RUN apt-get update && apt-get install -y ffmpeg curl && rm -rf /var/lib/apt/lists/*

ENV JELLYFIN_DATA_DIR=/config
ENV JELLYFIN_CONFIG_DIR=/config/config
ENV JELLYFIN_LOG_DIR=/config/log
ENV JELLYFIN_CACHE_DIR=/cache
ENV ASPNETCORE_URLS=http://+:8096

RUN mkdir -p /config /cache /media
EXPOSE 8096

# 실행 파일 이름 변경 적용
ENTRYPOINT ["dotnet", "Jellyfin.Server.dll"]
