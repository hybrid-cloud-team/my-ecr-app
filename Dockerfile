# 1단계: 빌드 환경 (SDK 9.0 사용)
FROM mcr.microsoft.com/dotnet/sdk:9.0 AS build
WORKDIR /src

# 캐시 효율을 위해 프로젝트 파일만 먼저 복사하고 복원
# (프로젝트 구조에 따라 경로가 다를 수 있으니 확인 필요)
COPY ["Jellyfin.Server/Jellyfin.Server.csproj", "Jellyfin.Server/"]
RUN dotnet restore "Jellyfin.Server/Jellyfin.Server.csproj"

# 나머지 소스 전체 복사
COPY . .

# 프로젝트 빌드 및 게시
# -o /app/publish 경로로 확실하게 결과물을 출력합니다.
WORKDIR "/src/Jellyfin.Server"
RUN dotnet publish "Jellyfin.Server.csproj" -c Release -o /app/publish /p:UseAppHost=false

# 2단계: 실행 환경 (Runtime 9.0 사용)
FROM mcr.microsoft.com/dotnet/aspnet:9.0
WORKDIR /app

# 1단계에서 빌드된 결과물(/app/publish)을 현재 디렉토리(/app)로 복사
COPY --from=build /app/publish .

# Jellyfin 기본 포트 설정 및 환경 변수
ENV ASPNETCORE_URLS=http://+:8096
EXPOSE 8096

# 실행 파일 존재 여부를 보장하기 위해 dotnet 명령어로 dll 실행
ENTRYPOINT ["dotnet", "Jellyfin.Server.dll"]
