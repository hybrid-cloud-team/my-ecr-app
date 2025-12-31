# 이 내용은 Jellyfin을 빌드하기 위한 공식 환경 설정입니다.
FROM mcr.microsoft.com/dotnet/sdk:6.0 AS build
WORKDIR /src
COPY . .
RUN dotnet publish Jellyfin.Server/Jellyfin.Server.csproj -c Release -o /app/publish

FROM mcr.microsoft.com/dotnet/aspnet:6.0
WORKDIR /app
COPY --from=build /app/publish .
EXPOSE 8096
ENTRYPOINT ["dotnet", "Jellyfin.Server.dll"]
