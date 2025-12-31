# 1단계: 빌드
FROM mcr.microsoft.com/dotnet/sdk:9.0 AS build
WORKDIR /src

# 프로젝트 파일 복사 및 복원
COPY ["Jellyfin.Server/Jellyfin.Server.csproj", "Jellyfin.Server/"]
RUN dotnet restore "Jellyfin.Server/Jellyfin.Server.csproj"

# 전체 소스 복사
COPY . .

# 빌드 및 게시 (경로를 /app으로 단순화)
WORKDIR "/src/Jellyfin.Server"
RUN dotnet publish "Jellyfin.Server.csproj" -c Release -o /app --no-restore /p:UseAppHost=false

# 2단계: 실행
FROM mcr.microsoft.com/dotnet/aspnet:9.0
WORKDIR /app

# 빌드 결과물 복사
COPY --from=build /app .

# [중요] 파일명을 유연하게 잡기 위해 shell 형식으로 실행하거나, 
# 확실하게 확인된 대소문자를 사용해야 합니다.
# 보통 Jellyfin 빌드 결과물은 jellyfin.dll 혹은 Jellyfin.Server.dll 입니다.
ENTRYPOINT ["dotnet", "Jellyfin.Server.dll"]
