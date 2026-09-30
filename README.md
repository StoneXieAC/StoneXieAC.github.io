# 个人主页

基于 [Academic Pages](https://github.com/academicpages/academicpages.github.io) 和 Jekyll 构建的中英文个人主页，部署于 GitHub Pages。模板 MIT 许可证见 [LICENSE](LICENSE)。

## 修改内容

- `_data/profile.yml`：个人资料与栏目内容，`en` 和 `zh` 分别对应英文与中文。
- `_data/ui.yml`：界面文字。
- `_sass/_academic.scss`：自定义样式。
- `_config.yml`：网站配置；更换域名或仓库时调整 `url`、`baseurl` 和 `repository`。

## 本地预览

使用 Ruby 3.3 和 Bundler：

```sh
gem install bundler
bundle config set --local path vendor/bundle
bundle install
bundle exec jekyll serve
```

打开 `http://127.0.0.1:4000`。修改 `_config.yml` 后需重启服务。

## 部署

在 GitHub 仓库的 **Settings → Pages → Build and deployment → Source** 中选择 **GitHub Actions**。提交并推送到 `main` 分支后，现有工作流会自动构建并部署；可在 **Actions** 中查看进度和结果。
