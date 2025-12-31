# 1단계: 빌드 환경
FROM mcr.microsoft.com/dotnet/sdk:9.0 AS build
WORKDIR /src
COPY . .

# 서버 빌드
RUN dotnet restore "Jellyfin.Server/Jellyfin.Server.csproj"
WORKDIR "/src/Jellyfin.Server"
RUN dotnet publish "Jellyfin.Server.csproj" -c Release -o /app /p:UseAppHost=false

# [이 부분이 핵심!] 웹 클라이언트(화면) 패키지를 다운로드해서 /app/jellyfin-web에 넣어줍니다.
# 서버가 실행될 때 이 폴더가 있어야 종료되지 않습니다.
RUN apt-get update && apt-get install -y wget curl \
    && curl -L https://github.com/jellyfin/jellyfin-web/releases/download/v10.10.3/jellyfin-web_10.10.3_portable.tar.gz -o web.tar.gz \
    && tar -xvzf web.tar.gz -C /app \
    && mv /app/jellyfin-web_10.10.3 /app/jellyfin-web \
    && rm web.tar.gz

# 2단계: 실행 환경
FROM mcr.microsoft.com/dotnet/aspnet:9.0
WORKDIR /app
COPY --from=build /app .

ENV ASPNETCORE_URLS=http://+:8096
EXPOSE 8096

# 이제 옵션 없이 실행해도 폴더가 존재하므로 죽지 않습니다.
ENTRYPOINT ["dotnet", "jellyfin.dll"]
