# [1] 공식 젤리핀 이미지에서 '웹 클라이언트(HTML/JS)' 파일만 훔쳐오기 위해 잠시 로드
FROM jellyfin/jellyfin:latest AS stock-image

# [2] 빌드 스테이지 (우리가 만든 C# 서버 빌드)
FROM mcr.microsoft.com/dotnet/sdk:9.0 AS build-env
WORKDIR /app

# 소스 복사 및 청소
COPY . ./
RUN find . -type d \( -name "obj" -o -name "bin" \) -exec rm -rf {} +
RUN rm -f src/Jellyfin.Database/Jellyfin.Database.Providers.Sqlite/Migrations/SqliteDesignTimeJellyfinDbFactory.cs

# 서버 빌드 (문법 수정됨)
RUN dotnet publish Jellyfin.Server/Jellyfin.Server.csproj \
    -c Release \
    -o /app/out \
    /p:TreatWarningsAsErrors=false \
    /p:NoWarn=NU1605%3BNU1608

# [3] 실행 스테이지 (최종 이미지 완성)
FROM mcr.microsoft.com/dotnet/aspnet:9.0
WORKDIR /jellyfin

# 빌드된 서버 실행 파일 복사
COPY --from=build-env /app/out .

# ★[핵심 추가]★ 공식 이미지(stock-image)에서 웹 UI 파일들을 내 거로 복사해오기
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

# [★핵심 수정] 실행할 파일 이름을 대문자 버전으로 변경
ENTRYPOINT ["dotnet", "Jellyfin.Server.dll"]
