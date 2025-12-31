# 1단계: 빌드 환경
FROM mcr.microsoft.com/dotnet/sdk:9.0 AS build
WORKDIR /src

# 모든 소스 코드를 복사 (의존 프로젝트 포함)
COPY . .

# 의존성 복원
RUN dotnet restore "Jellyfin.Server/Jellyfin.Server.csproj"

# 프로젝트 빌드 및 게시
WORKDIR "/src/Jellyfin.Server"
RUN dotnet publish "Jellyfin.Server.csproj" -c Release -o /app /p:UseAppHost=false

# [중요] 여기서 파일 이름을 강제로 확인합니다. 
# 빌드 로그에서 이 부분을 찾아보세요.
RUN echo "--- 실제 생성된 파일 목록 ---" && ls /app/*.dll && echo "-----------------------"

# 2단계: 실행 환경
FROM mcr.microsoft.com/dotnet/aspnet:9.0
WORKDIR /app

# 빌드 결과물 복사
COPY --from=build /app .

ENV ASPNETCORE_URLS=http://+:8096
EXPOSE 8096

# 실행 파일 이름을 대문자/소문자 모두 시도할 수 있게 수정하거나 
# 가장 확실한 이름으로 지정합니다.
# 빌드 로그 확인 후 "jellyfin.dll" 이라면 아래를 수정하세요.
ENTRYPOINT ["dotnet", "Jellyfin.Server.dll"]
