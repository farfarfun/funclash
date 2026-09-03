# Changelog

## [未发布]

### 修复

- `launcher/src/config/config-manager.js`：订阅拉取的错误信息与成功日志改为打印脱敏后的 URL（去掉 query 中可能携带的 token/secret），避免凭据出现在终端日志中。
- README 补充组织介绍固定区块。

### 新增

- 新增 CHANGELOG.md，按规范记录后续变更。
