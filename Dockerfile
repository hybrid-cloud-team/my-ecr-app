# 젤리핀 공식 이미지를 베이스로 사용
FROM docker.io/joshuaboniface/jellyfin-rdb:latest

# EKS 환경에 맞게 포트 설정만 열어줍니다.
ENV ASPNETCORE_URLS=http://+:8096
EXPOSE 8096
# 공식 이미지에 이미 설정된 실행 명령(Entrypoint)을 그대로 사용하도록 비워둡니다.
# 이렇게 하면 이미지 내부의 정해진 경로(/jellyfin/jellyfin)로 자동 실행됩니다.
