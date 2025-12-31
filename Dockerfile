# 1단계: 빌드 환경 (SDK 9.0 사용)
FROM mcr.microsoft.com/dotnet/sdk:9.0 AS build
WORKDIR /src

# 1. 의존성 파일(.csproj)만 먼저 복사해서 Restore 진행 (빌드 속도 개선)
# 프로젝트 구조에 따라 경로가 다를 수 있으니 주의하세요.
COPY ["Jellyfin.Server/Jellyfin.Server.csproj", "Jellyfin.Server/"]
RUN dotnet restore "Jellyfin.Server/Jellyfin.Server.csproj"

# 2. 나머지 소스 코드 전체 복사
COPY . .

# 3. 프로젝트 빌드 및 게시 (Publish)
# -o /app/publish 명령으로 실행 파일들을 특정 폴더에 모읍니다.
WORKDIR "/src/Jellyfin.Server"
RUN dotnet publish "Jellyfin.Server.csproj" -c Release -o /app/publish /p:UseAppHost=false

# 4. [디버깅 로그] 빌드 시점에 파일이 잘 생성되었는지 콘솔에 출력 (에러 방지용)
RUN echo "--- 생성된 파일 목록 확인 ---" && ls -l /app/publish && echo "-----------------------"

# 2단계: 실행 환경 (가벼운 Runtime 9.0 사용)
FROM mcr.microsoft.com/dotnet/aspnet:9.0
WORKDIR /app

# 5. 빌드 단계에서 생성된 결과물만 복사 (컨테이너 크기 최소화)
COPY --from=build /app/publish .

# 6. Jellyfin 환경 변수 및 포트 설정
ENV ASPNETCORE_URLS=http://+:8096
EXPOSE 8096

# 7. 최종 실행 명령
# 아까 로그에서 'Jellyfin.Server.dll'을 찾지 못했던 문제를 해결하기 위해 
# 빌드된 폴더 내의 정확한 파일명을 지정합니다.
ENTRYPOINT ["dotnet", "Jellyfin.Server.dll"]
