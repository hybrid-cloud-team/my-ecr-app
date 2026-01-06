# [1단계] 빌드 환경 설정: .NET 9.0 SDK를 사용하여 소스 코드를 빌드합니다.
FROM mcr.microsoft.com/dotnet/sdk:9.0 AS build-env
WORKDIR /app

# 1-1. 프로젝트 파일들을 복사하고 필요한 라이브러리를 다운로드(Restore)합니다.
# (이 과정에서 Pomelo MySQL 패키지도 같이 설치됩니다.)
COPY . ./
RUN dotnet restore Jellyfin.Server/Jellyfin.Server.csproj

# 1-2. 소스 코드를 실제로 빌드하여 실행 파일(dll)을 생성합니다.
RUN dotnet publish Jellyfin.Server/Jellyfin.Server.csproj -c Release -o /app/out

# [2단계] 실행 환경 설정: 가벼운 실행 전용 이미지를 만듭니다.
FROM mcr.microsoft.com/dotnet/aspnet:9.0
WORKDIR /jellyfin

# 2-1. 위에서 빌드한 결과물(/app/out)만 쏙 가져옵니다.
COPY --from=build-env /app/out .

# 2-2. Jellyfin 구동에 필요한 필수 패키지(FFmpeg 등)를 설치합니다.
RUN apt-get update && apt-get install -y ffmpeg curl && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

# 2-3. 환경 변수 및 포트 설정
ENV JELLYFIN_DATA_DIR=/config
ENV JELLYFIN_CONFIG_DIR=/config/config
ENV JELLYFIN_LOG_DIR=/config/log
ENV JELLYFIN_CACHE_DIR=/cache
ENV ASPNETCORE_URLS=http://+:8096

# 데이터 저장을 위한 볼륨 디렉토리 생성
RUN mkdir -p /config /cache /media

EXPOSE 8096

# 2-4. 빌드된 우리의 Jellyfin 서버를 실행합니다.
ENTRYPOINT ["dotnet", "Jellyfin.Server.dll"]
