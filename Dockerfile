# 1단계: 빌드 환경
FROM mcr.microsoft.com/dotnet/sdk:9.0 AS build
WORKDIR /src

# 모든 소스 복사 및 의존성 복원
COPY . .
RUN dotnet restore "Jellyfin.Server/Jellyfin.Server.csproj"

# 실제 빌드 진행
WORKDIR "/src/Jellyfin.Server"
RUN dotnet publish "Jellyfin.Server.csproj" -c Release -o /app /p:UseAppHost=false

# 2단계: 실행 환경
FROM mcr.microsoft.com/dotnet/aspnet:9.0
WORKDIR /app

# 빌드 결과물 복사
COPY --from=build /app .

ENV ASPNETCORE_URLS=http://+:8096
EXPOSE 8096

# [중요] 로그에서 확인된 실제 파일명(소문자)으로 수정함
ENTRYPOINT ["dotnet", "jellyfin.dll"]
