FROM mcr.microsoft.com/dotnet/sdk:9.0 AS build-env
WORKDIR /app

# 소스 전체 복사
COPY . ./

# 에러 유발 설계용 파일 물리적 삭제
RUN rm -f src/Jellyfin.Database/Jellyfin.Database.Providers.Sqlite/Migrations/SqliteDesignTimeJellyfinDbFactory.cs

# 경고를 에러로 처리하지 않도록 빌드 실행
RUN dotnet publish Jellyfin.Server/Jellyfin.Server.csproj \
    -c Release \
    -o /app/out \
    /p:TreatWarningsAsErrors=false \
    /p:NoWarn="NU1605;NU1608"

FROM mcr.microsoft.com/dotnet/aspnet:9.0
WORKDIR /jellyfin
COPY --from=build-env /app/out .

RUN apt-get update && apt-get install -y ffmpeg curl && rm -rf /var/lib/apt/lists/*

ENV JELLYFIN_DATA_DIR=/config
ENV ASPNETCORE_URLS=http://+:8096

EXPOSE 8096
ENTRYPOINT ["dotnet", "jellyfin.dll"]
