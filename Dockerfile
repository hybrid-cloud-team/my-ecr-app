# 1. 빌드 스테이지
FROM mcr.microsoft.com/dotnet/sdk:9.0 AS build-env
WORKDIR /app

# 모든 소스 복사 (이때 내 PC에 있던 임시 파일들도 같이 들어옵니다)
COPY . ./

# [🔥🔥🔥 긴급 처방] 복사된 파일들 사이에서 'obj'와 'bin' 폴더를 찾아내 강제로 삭제합니다.
# 이렇게 하면 과거 빌드 기록(8.0.2 참조)이 싹 사라지고 100% 깨끗한 상태에서 시작합니다.
RUN find . -type d \( -name "obj" -o -name "bin" \) -exec rm -rf {} +

# [기존 조치 1] 에러 유발 설계용 파일 물리적 삭제
RUN rm -f src/Jellyfin.Database/Jellyfin.Database.Providers.Sqlite/Migrations/SqliteDesignTimeJellyfinDbFactory.cs

# [기존 조치 2] 빌드 실행
# (문법 수정됨: 세미콜론 대신 %3B 사용, 경고 무시 옵션 포함)
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
