# 1단계: 빌드 환경 (SDK 9.0 사용)
FROM mcr.microsoft.com/dotnet/sdk:9.0 AS build
WORKDIR /src

# 모든 소스 복사
COPY . .

# 프로젝트 빌드 및 게시 (Jellyfin.Server 경로 확인)
RUN dotnet publish Jellyfin.Server/Jellyfin.Server.csproj -c Release -o /app/publish

# 2단계: 실행 환경 (Runtime 9.0 사용)
FROM mcr.microsoft.com/dotnet/aspnet:9.0
WORKDIR /app

# 빌드 결과물만 복사
COPY --from=build /app/publish .

# 권한 설정 (선택 사항이나 권장)
ENV ASPNETCORE_URLS=http://+:8096
EXPOSE 8096

ENTRYPOINT ["dotnet", "Jellyfin.Server.dll"]
