git pull && docker image build -t win:base .
docker image tag win:base harbor.donghwa.dev:4443/seo/windows:2016
docker image tag win:base harbor.donghwa.dev:4443/seo/windows:2022
docker image tag win:base harbor.donghwa.dev:4443/seo/windows:win10
docker image tag win:base harbor.donghwa.dev:4443/seo/windows:win11
echo done!