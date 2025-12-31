FROM mcr.microsoft.com/dotnet/sdk:9.0 AS build
WORKDIR /src

# 프로젝트 파일만 복사해서 복원
COPY ["Jellyfin.Server/Jellyfin.Server.csproj", "Jellyfin.Server/"]
RUN dotnet restore "Jellyfin.Server/Jellyfin.Server.csproj"

# 전체 소스 복사 및 빌드
COPY . .
WORKDIR "/src/Jellyfin.Server"
RUN dotnet publish "Jellyfin.Server.csproj" -c Release -o /app/publish /p:UseAppHost=false

# 실행 환경 설정
FROM mcr.microsoft.com/dotnet/aspnet:9.0
WORKDIR /app
COPY --from=build /app/publish .

ENV ASPNETCORE_URLS=http://+:8096
EXPOSE 8096

# 대소문자 주의: 반드시 Jellyfin.Server.dll 파일명이 존재하는지 확인
ENTRYPOINT ["dotnet", "Jellyfin.Server.dll"]
