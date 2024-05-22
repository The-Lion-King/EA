# KOA-基础模板

基于 koa 搭建的符合 RESTful 结构后端基础脚手架

## 前言

详细搭建过程可以看这一篇：[Koa2 从零到脚手架](https://blog.azhubaby.com/2021/08/24/2021-08-24-Koa2%E4%BB%8E%E9%9B%B6%E5%88%B0%E8%84%9A%E6%89%8B%E6%9E%B6/)

## 使用的中间件

-   koa-router——路由解决方案
-   koa-bodyparser——请求体解析
-   koa-static—— 提供静态资源服务
-   @koa/cors——跨域
-   koa-json-error——处理错误
-   koa-parameter —— 参数校验
-   http-assert—— 断言

## 项目目录

````
```
├── config                          运行配置
│   ├── index.js
├── controller                      控制器，控制数据库
│   ├── home.js                     主/根
│   ├── user.js                     用户
├── db                              连接数据库
│   ├── index.js
├── models                          模型(数据库)
│   ├── User.js                     用户模型
├── public                          静态资源目录
├── routes                          路由配置
│   ├── home.js                     主/根
│   ├── index.js                    路由配置主文件
│   ├── user.js                     用户
├── .editorconfig                   统一编码配置文件
├── .gitignore
├── index.js                        入口文件
├── package.json
├── README.md
```
````

## 项目启动

```
npm run serve
```
