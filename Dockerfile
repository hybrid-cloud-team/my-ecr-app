# 우리가 빌드한 서버 파일이 아니라, 이미 완성된 젤리핀 공식 이미지를 가져옵니다.
FROM jellyfin/jellyfin:latest

# 실행 환경 설정 (포트 8096 사용)
ENV ASPNETCORE_URLS=http://+:8096
EXPOSE 8096

# 공식 이미지는 이미 모든 웹 파일(/jellyfin/jellyfin-web)을 가지고 있습니다.
# 별도의 옵션 없이 바로 실행하면 서버도 살고 접속도 됩니다.
ENTRYPOINT ["dotnet", "/jellyfin/jellyfin.dll"]
