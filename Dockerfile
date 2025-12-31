# 1단계: 빌드 환경
FROM mcr.microsoft.com/dotnet/sdk:9.0 AS build
WORKDIR /src

# 1. 모든 소스 코드를 먼저 복사합니다.
# (의존 프로젝트가 많으므로 프로젝트 파일만 골라서 복사하는 것보다 전체 복사가 안전합니다.)
COPY . .

# 2. 모든 프로젝트의 의존성을 한꺼번에 복원합니다.
RUN dotnet restore "Jellyfin.Server/Jellyfin.Server.csproj"

# 3. 메인 프로젝트 폴더로 이동하여 빌드 및 게시를 진행합니다.
# --no-restore 옵션을 제거하여 누락된 에셋이 있다면 자동으로 처리하게 합니다.
WORKDIR "/src/Jellyfin.Server"
RUN dotnet publish "Jellyfin.Server.csproj" -c Release -o /app /p:UseAppHost=false

# 2단계: 실행 환경
FROM mcr.microsoft.com/dotnet/aspnet:9.0
WORKDIR /app

# 빌드 결과물 복사
COPY --from=build /app .

# 환경 변수 및 포트 설정
ENV ASPNETCORE_URLS=http://+:8096
EXPOSE 8096

# 실행 (대소문자 문제가 있을 수 있으니 실제 빌드 로그에 출력된 파일명을 확인하세요)
ENTRYPOINT ["dotnet", "Jellyfin.Server.dll"]
