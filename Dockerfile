# 1단계: 빌드 환경 (SDK 9.0 사용)
FROM mcr.microsoft.com/dotnet/sdk:9.0 AS build
WORKDIR /src

# 캐시 효율을 위해 프로젝트 파일만 먼저 복사하고 복원
# (루트 폴더에 Jellyfin.Server 폴더가 있는지 확인하세요)
COPY ["Jellyfin.Server/Jellyfin.Server.csproj", "Jellyfin.Server/"]
RUN dotnet restore "Jellyfin.Server/Jellyfin.Server.csproj"

# 나머지 소스 전체 복사
COPY . .

# 프로젝트 빌드 및 게시
# -o /app/publish 경로로 확실하게 결과물을 출력합니다.
WORKDIR "/src/Jellyfin.Server"
RUN dotnet publish "Jellyfin.Server.csproj" -c Release -o /app/publish /p:UseAppHost=false

# [중요] 빌드 시점에 파일 목록을 로그에 남깁니다. (빌드 중 콘솔에서 파일명 확인 가능)
RUN echo "--- CHECKING PUBLISHED FILES ---" && ls -l /app/publish && echo "----------------------------"

# 2단계: 실행 환경 (Runtime 9.0 사용)
FROM mcr.microsoft.com/dotnet/aspnet:9.0
WORKDIR /app

# 1단계에서 빌드된 결과물을 현재 디렉토리(/app)로 복사
COPY --from=build /app/publish .

# 환경 변수 및 포트 설정
ENV ASPNETCORE_URLS=http://+:8096
EXPOSE 8096

# 실행 파일명 확인: 
# 만약 로컬에서 파일명이 jellyfin.dll(소문자)인 것을 확인했다면 
# 아래 "Jellyfin.Server.dll"을 그에 맞춰 수정해야 합니다.
ENTRYPOINT ["dotnet", "Jellyfin.Server.dll"]
