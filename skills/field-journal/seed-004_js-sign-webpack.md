# [种子] JS 签名逆向（Webpack + AES + 时间戳）

## 场景分类
JS 签名

## 目标概述
还原某 Web 应用接口的 `sign` 参数生成算法，实现本地复现。

## 完整执行链路

1. 浏览器抓包 → 发现 POST 请求带 `sign` 和 `timestamp` 参数
2. 搜索 JS 源码中的 "sign" → 定位到 webpack 打包的 chunk 文件
3. 在 sign 赋值处下断点 → 命中，查看调用栈
4. 调用栈回溯 → 找到签名函数（在某个 webpack module 中）
5. 分析签名逻辑：`sign = HmacSHA256(sorted_params + timestamp, secret_key)`
6. 密钥来源：硬编码在另一个 webpack module 中
7. Node.js 本地复现 → 生成的 sign 与浏览器一致
8. 验证：用复现的 sign 请求接口 → 返回正常数据

## 踩坑记录

| 问题 | 原因 | 解决方案 | 耗时 |
|------|------|---------|------|
| 搜索 "sign" 结果太多 | webpack 打包后变量名被压缩 | 改为搜索 `sign=` 或在网络面板找到请求后用 initiator 回溯 | 15min |
| 断点命中但看不懂代码 | webpack 压缩 + 变量名混淆 | 用 Chrome 的 Pretty Print 格式化，再配合 SourceMap（如果有） | 10min |
| 本地复现结果不一致 | 参数排序方式不对 | 仔细看源码中的 sort 逻辑（按 key 字母序 + 特殊字符处理） | 30min |
| timestamp 精度不对 | 服务端用秒级，我用了毫秒级 | `Math.floor(Date.now() / 1000)` | 5min |
| 密钥找不到 | 密钥在另一个 chunk 文件中通过 require 引入 | 在断点处 console.log 打印密钥变量 | 10min |

## 工具链发现

- Chrome DevTools 的 initiator 列比搜索源码更快定位签名函数
- webpack 打包的代码用 Pretty Print + 断点比硬读更高效
- 如果有 SourceMap（.map 文件），直接还原原始代码
- Node.js 的 `crypto` 模块可以直接复现大部分签名算法

## 关键代码/命令

```javascript
// Node.js 复现
const crypto = require('crypto');

function generateSign(params, timestamp, secretKey) {
    // 1. 参数按 key 字母序排序
    const sorted = Object.keys(params).sort().map(k => `${k}=${params[k]}`).join('&');
    // 2. 拼接时间戳
    const message = sorted + '&timestamp=' + timestamp;
    // 3. HMAC-SHA256
    return crypto.createHmac('sha256', secretKey).update(message).digest('hex');
}

const params = { user_id: '123', action: 'query' };
const timestamp = Math.floor(Date.now() / 1000);
const secretKey = 'hardcoded_key_from_webpack';
console.log(generateSign(params, timestamp, secretKey));
```

## 对本包的改进建议

- js-reverse 的 env-patching.md 应该加入"webpack chunk 间依赖如何处理"
- 建议加入"常见签名算法识别"速查（HMAC-SHA256 vs MD5 vs 自定义）

## 可复用的模式/脚本片段

**JS 签名逆向标准流程**：
```text
1. 抓包找到带签名的请求
2. 用 initiator/调用栈定位签名函数
3. 分析签名逻辑（参数排序 + 拼接 + 加密）
4. 找密钥来源（硬编码/接口返回/时间派生）
5. Node.js 复现
6. 对比验证
```

**常见签名模式**：
```text
- HmacSHA256(sorted_params, key) → 最常见
- MD5(params + salt + timestamp) → 较老的系统
- AES(JSON.stringify(params), key) → 加密而非签名
- RSA sign → 少见，通常是金融类
```

## 进化动作
- [ ] 无需更新路由矩阵
- [ ] 无需更新 bootstrap-manifest
- [ ] 无需更新子 skill 文档

## 环境信息
- OS: Windows
- 工具版本: Chrome DevTools, Node.js 20+
- 目标平台: Web (Webpack 打包的 SPA)

## 脱敏要求
本条目为种子数据，基于公开技术模式编写，不涉及真实目标。

---
<!-- [进化统计] 本包累计完成项目: 4 | 本次新增模式: 2 | 本次修复工具链问题: 0 -->
<!-- [社区贡献] 种子数据，无需 PR -->
